"""Process/evidence regressions; no Flutter app, browser, or AT is launched."""

import argparse
import io
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import run_catalog_input_acceptance as acceptance
from run_ios_catalog_journey import live_group_members


@unittest.skipIf(os.name == "nt", "The fixture uses a POSIX executable; CI runs this on Ubuntu")
class InputAcceptanceRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.output = self.directory / "evidence"
        self.flutter = self.directory / "flutter"

    def run_fixture(self, script, platform="linux", journey_only=False):
        # A sleeping Python process stands in for the owned WebDriver. The
        # ready response only tests runner orchestration, never browser input.
        preamble = ("import sys,time\n"
                    "if '--port=4444' in sys.argv:\n time.sleep(60)\n raise SystemExit(0)\n")
        self.flutter.write_text(f"#!{sys.executable}\n" + preamble + script, encoding="utf-8")
        self.flutter.chmod(0o755)
        args = argparse.Namespace(platform=platform, device="fixture", include_journey=False,
                                  journey_only=journey_only, artifacts=self.output)
        with patch.object(acceptance, "executable", return_value=str(self.flutter)), \
                patch.object(acceptance.urllib.request, "urlopen",
                             side_effect=lambda *_a, **_k: io.BytesIO(b'{"value":{"ready":true}}')), \
                patch.dict(os.environ, {"DISPLAY": ":fixture"}):
            acceptance.run(args)

    def browser_fixture(self, browser_exit=0):
        return (
            "import json,os\nfrom pathlib import Path\n"
            "output=Path(os.environ['BEAUTIFUL_INPUT_EVIDENCE'])\n"
            "if any('catalog_platform_input_test.dart' in arg for arg in sys.argv):\n"
            " print('CATALOG_INPUT_REPORT: {\"status\":\"failed\"}')\n"
            " raise SystemExit(4)\n"
            "(output/'browser-input.json').write_text('{\"status\":\"passed\"}')\n"
            f"raise SystemExit({browser_exit})\n"
        )

    def test_journey_only_uses_original_full_target_once_with_owned_cleanup(self):
        self.run_fixture("raise SystemExit(0)\n", platform="chrome", journey_only=True)
        summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
        self.assertEqual([(s["suite"], s["status"], s["cleanup_status"]) for s in summary["suites"]],
                         [("journey", "passed", "verified")])
        command = summary["suites"][0]["command"]
        self.assertIn("--target=integration_test/catalog_journey_test.dart", command)
        self.assertIn("--driver=integration_test/driver/catalog_trusted_journey_driver.dart", command)
        self.assertFalse((self.output / "framework").exists())
        self.assertFalse((self.output / "browser").exists())

    def test_failed_framework_still_runs_independent_browser_and_fails_overall(self):
        with self.assertRaisesRegex(RuntimeError, "framework input suite failed with 4"):
            self.run_fixture(self.browser_fixture(), platform="chrome")
        summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
        self.assertEqual(summary["status"], "failed")
        self.assertEqual([(suite["suite"], suite["status"], suite["exit_code"])
                          for suite in summary["suites"]],
                         [("framework", "failed", 4), ("browser", "passed", 0)])
        self.assertTrue(all(suite["cleanup_status"] == "verified" for suite in summary["suites"]))
        self.assertEqual(json.loads((self.output / "framework/framework-input.json").read_text()),
                         {"status": "failed"})
        self.assertEqual(json.loads((self.output / "browser/browser-input.json").read_text()),
                         {"status": "passed"})

    def test_each_suite_failure_keeps_its_original_exit_status(self):
        with self.assertRaisesRegex(RuntimeError, "framework input suite failed with 4.*browser input suite failed with 5"):
            self.run_fixture(self.browser_fixture(browser_exit=5), platform="chrome")
        summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
        self.assertEqual([suite["exit_code"] for suite in summary["suites"]], [4, 5])
        self.assertEqual([suite["status"] for suite in summary["suites"]], ["failed", "failed"])

    def test_unverified_flutter_or_driver_cleanup_stops_remaining_suites(self):
        stop = acceptance.stop_owned_process
        for owner in ("flutter", "driver"):
            with self.subTest(owner=owner):
                self.output = self.directory / f"evidence-{owner}"

                def fail_verification(process, **kwargs):
                    # Clean the actual fixture first so this injected failure
                    # never leaks a process from the regression itself.
                    stop(process, **kwargs)
                    is_driver = "--port=4444" in process.args
                    if is_driver == (owner == "driver"):
                        raise RuntimeError("fixture cleanup verification failed")

                with patch.object(acceptance, "stop_owned_process", side_effect=fail_verification):
                    with self.assertRaisesRegex(RuntimeError, "fixture cleanup verification failed"):
                        self.run_fixture(self.browser_fixture(), platform="chrome")
                summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
                self.assertEqual(summary["status"], "failed")
                self.assertEqual(len(summary["suites"]), 1)
                self.assertEqual(summary["suites"][0]["status"], "failed")
                self.assertIn("cleanup_error", summary["suites"][0])
                self.assertFalse((self.output / "browser").exists())

    def test_startup_without_verified_cleanup_stops_remaining_suites(self):
        start = acceptance.start_owned_process
        for owner in ("flutter", "driver"):
            with self.subTest(owner=owner):
                self.output = self.directory / f"evidence-{owner}"

                def fail_startup(argv, **kwargs):
                    is_driver = "--port=4444" in argv
                    if is_driver == (owner == "driver"):
                        raise RuntimeError("startup cleanup failed")
                    return start(argv, **kwargs)

                with patch.object(acceptance, "start_owned_process", side_effect=fail_startup):
                    with self.assertRaisesRegex(RuntimeError, "startup cleanup failed"):
                        self.run_fixture(self.browser_fixture(), platform="chrome")
                summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
                self.assertEqual(len(summary["suites"]), 1)
                self.assertIn("cleanup_error", summary["suites"][0])
                self.assertNotIn("cleanup_status", summary["suites"][0])
                self.assertFalse((self.output / "browser").exists())

    def test_timeout_and_cleanup_failure_both_remain_in_evidence(self):
        start = acceptance.start_owned_process
        stop = acceptance.stop_owned_process

        def timeout_process(argv, **kwargs):
            process = start(argv, **kwargs)
            wait = process.wait
            first_wait = True

            def timeout_once(timeout=None):
                nonlocal first_wait
                if first_wait:
                    first_wait = False
                    raise subprocess.TimeoutExpired(argv, timeout)
                return wait(timeout=timeout)

            process.wait = timeout_once
            return process

        def failed_cleanup(process, **kwargs):
            stop(process, **kwargs)
            raise RuntimeError("cleanup failed after timeout")

        with patch.object(acceptance, "start_owned_process", side_effect=timeout_process), \
                patch.object(acceptance, "stop_owned_process", side_effect=failed_cleanup):
            with self.assertRaisesRegex(RuntimeError, "cleanup failed after timeout"):
                self.run_fixture('print(\'CATALOG_INPUT_REPORT: {"status":"passed"}\')\n')
        summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
        entry = summary["suites"][0]
        self.assertTrue(entry["timed_out"])
        self.assertIn("timed out", entry["error"])
        self.assertEqual(entry["cleanup_error"], "cleanup failed after timeout")

    def test_failed_native_run_keeps_exact_structured_report(self):
        with self.assertRaisesRegex(RuntimeError, "failed with 4"):
            self.run_fixture('print(\'CATALOG_INPUT_REPORT: {"status":"failed","text":"中文"}\')\nraise SystemExit(4)\n')
        report = json.loads((self.output / "framework/framework-input.json").read_text())
        self.assertEqual(report, {"status": "failed", "text": "中文"})
        summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
        self.assertEqual(summary["status"], "failed")
        self.assertEqual(summary["suites"][0]["exit_code"], 4)

    def test_successful_process_without_required_report_is_not_accepted(self):
        with self.assertRaisesRegex(RuntimeError, "required evidence"):
            self.run_fixture('print("no evidence supplied")\n')
        summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
        self.assertEqual(summary["status"], "failed")

    def test_preexisting_report_cannot_accept_a_new_silent_success(self):
        previous = self.output / "framework/framework-input.json"
        previous.parent.mkdir(parents=True)
        previous.write_text('{"status":"passed","run":"previous"}', encoding="utf-8")
        with self.assertRaisesRegex(FileExistsError, "Refusing to reuse"):
            self.run_fixture('raise SystemExit(0)\n')
        self.assertEqual(json.loads(previous.read_text()), {"status": "passed", "run": "previous"})
        self.assertFalse((self.output / "input-acceptance-summary.json").exists())

    def test_failed_report_with_zero_process_exit_is_not_accepted(self):
        with self.assertRaisesRegex(RuntimeError, "did not accept"):
            self.run_fixture('print(\'CATALOG_INPUT_REPORT: {"status":"failed"}\')\n')
        summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
        self.assertEqual(summary["status"], "failed")

    def test_owned_process_group_cleanup_reaches_child(self):
        marker = self.directory / "terminated"
        ready = self.directory / "ready"
        child = self.directory / "child.py"
        child.write_text(
            "import signal,time,sys\nfrom pathlib import Path\n"
            "def stop(*_):\n Path(sys.argv[1]).write_text('terminated')\n raise SystemExit(0)\n"
            "signal.signal(signal.SIGTERM, stop)\nPath(sys.argv[2]).touch()\ntime.sleep(60)\n"
        )
        process = acceptance.start_owned_process(
            [sys.executable, "-c", "import subprocess,sys,time; subprocess.Popen(sys.argv[1:]); time.sleep(60)",
             sys.executable, str(child), str(marker), str(ready)],
        )
        self.addCleanup(lambda: acceptance.stop_owned_process(process))
        deadline = time.monotonic() + 3
        while not ready.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertTrue(ready.exists())
        acceptance.stop_owned_process(process)
        deadline = time.monotonic() + 2
        while not marker.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        self.assertEqual(marker.read_text(), "terminated")
        self.assertIsNotNone(process.poll())

    def test_exited_leader_does_not_hide_child_ignoring_term(self):
        marker = self.directory / "child.pid"
        script = (
            "import os,signal,time,sys\n"
            "if os.fork() == 0:\n"
            " signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
            " open(sys.argv[1],'w').write(str(os.getpid()))\n"
            " time.sleep(60)\n"
            "else:\n"
            " while not os.path.exists(sys.argv[1]): time.sleep(.01)\n"
            " os._exit(0)\n"
        )
        process = acceptance.start_owned_process([sys.executable, "-c", script, str(marker)])
        try:
            self.assertEqual(process.wait(timeout=3), 0)
            child = int(marker.read_text())
            self.assertIn(child, live_group_members(process.pid))
            acceptance.stop_owned_process(process, grace=0.05, kill_timeout=2)
            self.assertEqual(live_group_members(process.pid), [])
        finally:
            if live_group_members(process.pid):
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass

    def test_cleanup_failure_prevents_success_report(self):
        with patch.object(acceptance, "stop_owned_process", side_effect=RuntimeError("cleanup failed")):
            with self.assertRaisesRegex(RuntimeError, "cleanup failed"):
                self.run_fixture('print(\'CATALOG_INPUT_REPORT: {"status":"passed"}\')\n')
        summary = json.loads((self.output / "input-acceptance-summary.json").read_text())
        self.assertEqual(summary["status"], "failed")
        self.assertEqual(summary["suites"][0]["status"], "failed")


if __name__ == "__main__":
    unittest.main()
