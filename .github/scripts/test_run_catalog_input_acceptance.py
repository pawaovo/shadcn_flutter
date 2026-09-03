"""Process/evidence regressions; no Flutter app, browser, or AT is launched."""

import argparse
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

    def run_fixture(self, script):
        self.flutter.write_text(f"#!{sys.executable}\n" + script, encoding="utf-8")
        self.flutter.chmod(0o755)
        args = argparse.Namespace(platform="linux", device="fixture", include_journey=False,
                                  artifacts=self.output)
        with patch.object(acceptance, "executable", return_value=str(self.flutter)), \
                patch.dict(os.environ, {"DISPLAY": ":fixture"}):
            acceptance.run(args)

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
