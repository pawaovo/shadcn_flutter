"""Exercise launch/discovery boundaries without an app or a simulator."""

import json
import errno
from datetime import datetime, timezone
import os
from pathlib import Path
import signal
import sys
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

from run_ios_catalog_journey import (
    Journey, LoggedProcess, capture_query_snapshot, discover_service, launch_pid,
    live_group_members, query_unified_service, redact,
    service_uri, stop_process_group, unified_service_uri,
)


class IOSLaunchTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name)

    def descriptor_holder_fixture(self, name, *, separate_group=True):
        marker = self.path / f"{name}.pid"
        command = (
            "import os,time\n"
            "if os.fork() == 0:\n"
            f" {'os.setsid()' if separate_group else 'pass'}\n"
            f" open({str(marker)!r},'w').write(str(os.getpid()))\n"
            " time.sleep(30)\n"
            "else:\n"
            f" while not os.path.exists({str(marker)!r}): time.sleep(.01)\n"
            " print('The Dart VM service is listening on http://127.0.0.1:12345/private-token/', flush=True)\n"
            " os._exit(0)\n"
        )
        return [sys.executable, "-u", "-c", command], marker

    def stop_holder(self, marker):
        if marker.exists():
            try:
                os.kill(int(marker.read_text()), signal.SIGKILL)
            except ProcessLookupError:
                pass

    def test_snapshot_command_exit_does_not_wait_for_external_descriptor_eof(self):
        command, marker = self.descriptor_holder_fixture("snapshot")
        path = self.path / "snapshot.log"
        start = time.monotonic()
        try:
            lines, code = capture_query_snapshot(command, path, 1)
            self.assertEqual(code, 0)
            self.assertIn("private-token", "".join(lines))
            self.assertNotIn("private-token", path.read_text())
            status = json.loads(path.with_suffix(".json").read_text())
            self.assertEqual(status["exit_code"], 0)
            self.assertFalse(status["timed_out"])
            self.assertFalse(status["stdout_eof"])
            self.assertTrue(status["host_group_clean"])
            self.assertLess(time.monotonic() - start, 2)
        finally:
            self.stop_holder(marker)

    def test_generic_logged_process_still_rejects_a_retained_external_pipe(self):
        command, marker = self.descriptor_holder_fixture("generic")
        process = LoggedProcess(command, self.path / "generic.log")
        try:
            self.assertEqual(process.process.wait(timeout=1), 0)
            with self.assertRaisesRegex(RuntimeError, "retained its output pipe"):
                process.close(grace=0)
        finally:
            self.stop_holder(marker)
            process.close(grace=0)

    def test_snapshot_timeout_rejects_a_valid_record_already_read(self):
        path = self.path / "timeout.log"
        lines, code = capture_query_snapshot([
            sys.executable, "-u", "-c",
            "import time; print('The Dart VM service is listening on http://127.0.0.1:12345/private-token/'); time.sleep(30)",
        ], path, 0.1)
        self.assertEqual((lines, code), ([], 124))
        status = json.loads(path.with_suffix(".json").read_text())
        self.assertTrue(status["timed_out"])
        self.assertTrue(status["host_group_clean"])
        self.assertNotIn("private-token", path.read_text())

    def test_reaped_group_does_not_require_available_ps(self):
        with subprocess.Popen([sys.executable, "-c", "pass"], start_new_session=True) as process:
            self.assertEqual(process.wait(timeout=2), 0)
            with self.assertRaises(ProcessLookupError):
                os.killpg(process.pid, 0)
            unavailable = subprocess.TimeoutExpired(
                ["/bin/ps", "-axo", "pid=,pgid=,stat="], timeout=1,
            )
            with patch("run_ios_catalog_journey.subprocess.check_output", side_effect=unavailable) as ps:
                self.assertEqual(live_group_members(process.pid), [])
                ps.assert_not_called()

    def test_snapshot_cannot_pass_when_its_host_group_still_has_a_live_child(self):
        command, marker = self.descriptor_holder_fixture("live-group", separate_group=False)
        path = self.path / "live-group.log"
        try:
            with patch("run_ios_catalog_journey.stop_process_group"):
                with self.assertRaisesRegex(RuntimeError, "still has live members"):
                    capture_query_snapshot(command, path, 1)
            status = json.loads(path.with_suffix(".json").read_text())
            self.assertFalse(status["host_group_clean"])
            self.assertIn("still has live members", status["error"])
        finally:
            self.stop_holder(marker)

    def assert_snapshot_ps_cause(self, cause, expected_details):
        path = self.path / "ps-cause.log"
        real_check_output = subprocess.check_output
        real_killpg = os.killpg
        cleanup_complete = False

        def finish_cleanup(process, *args, **kwargs):
            nonlocal cleanup_complete
            stop_process_group(process, *args, **kwargs)
            cleanup_complete = True

        def signal_group(group_id, sig):
            if cleanup_complete and sig == 0:
                raise PermissionError(errno.EPERM, "membership unknown")
            return real_killpg(group_id, sig)

        def inspect(command, *args, **kwargs):
            if cleanup_complete and command[0] == "/bin/ps":
                self.assertEqual(command, ["/bin/ps", "-axo", "pid=,pgid=,stat="])
                self.assertEqual(kwargs["timeout"], 1)
                raise cause
            return real_check_output(command, *args, **kwargs)

        # The query, timeout and termination remain real. The final kernel probe
        # explicitly cannot verify absence, so failed ps inspection must still
        # reject cleanup and retain its original cause.
        with patch("run_ios_catalog_journey.stop_process_group", side_effect=finish_cleanup), \
                patch("run_ios_catalog_journey.os.killpg", side_effect=signal_group), \
                patch("run_ios_catalog_journey.subprocess.check_output", side_effect=inspect):
            with self.assertRaisesRegex(RuntimeError, "Cannot verify process group membership") as raised:
                capture_query_snapshot([
                    sys.executable, "-u", "-c",
                    "import time; print('query started', flush=True); time.sleep(30)",
                ], path, 0.1)
        self.assertIs(raised.exception.__cause__, cause)
        status = json.loads(path.with_suffix(".json").read_text())
        self.assertEqual(status["exit_code"], 124)
        self.assertTrue(status["timed_out"])
        self.assertFalse(status["host_group_clean"])
        self.assertEqual(status["error"], "Cannot verify process group membership")
        self.assertEqual(status["cause"]["type"], type(cause).__name__)
        self.assertEqual(status["cause"]["message"], redact(str(cause)))
        for key, value in expected_details.items():
            self.assertEqual(status["cause"][key], value)
        self.assertNotIn("private-ps-token", path.with_suffix(".json").read_text())

    def test_snapshot_preserves_ps_timeout_cause_without_accepting_cleanup(self):
        cause = subprocess.TimeoutExpired(
            ["/bin/ps", "http://127.0.0.1:12345/private-ps-token/"], timeout=1,
        )
        self.assert_snapshot_ps_cause(cause, {"timeout": 1})

    def test_snapshot_preserves_ps_exit_cause_without_accepting_cleanup(self):
        cause = subprocess.CalledProcessError(
            7, ["/bin/ps", "http://127.0.0.1:12345/private-ps-token/"],
        )
        self.assert_snapshot_ps_cause(cause, {"returncode": 7})

    def test_snapshot_drain_cannot_convert_a_late_exit_zero_into_success(self):
        path = self.path / "slow-drain.log"
        release = self.path / "release-output"
        real_open = Path.open

        class SlowLog:
            def __init__(self, file):
                self.file = file

            def __enter__(self):
                return self

            def __exit__(self, *args):
                self.file.close()

            def write(self, text):
                self.file.write(text)
                release.touch()
                time.sleep(0.05)

            def flush(self):
                self.file.flush()

        def open_log(file_path, *args, **kwargs):
            file = real_open(file_path, *args, **kwargs)
            return SlowLog(file) if file_path == path else file

        command = [sys.executable, "-u", "-c", (
            "import pathlib,time\n"
            "print('query ready',flush=True)\n"
            f"while not pathlib.Path({str(release)!r}).exists(): time.sleep(.001)\n"
            "for _ in range(100): print('The Dart VM service is listening on http://127.0.0.1:12345/private-token/')\n"
            "time.sleep(.05)\n"
        )]
        start = time.monotonic()
        with patch.object(Path, "open", open_log):
            lines, code = capture_query_snapshot(command, path, 1)
        self.assertEqual((lines, code), ([], 124))
        status = json.loads(path.with_suffix(".json").read_text())
        self.assertTrue(status["timed_out"])
        self.assertEqual(status["host_returncode"], 0)
        self.assertFalse(status["final_drain_complete"])
        self.assertLess(time.monotonic() - start, 4)
        self.assertNotIn("private-token", path.read_text())

    def test_hung_launch_command_is_a_bounded_failure(self):
        journey = Journey(self.path, "fixture-device")
        start = time.monotonic()
        with self.assertRaisesRegex(RuntimeError, "launch failed"):
            journey.run("launch", [sys.executable, "-c", "import time; time.sleep(30)"], 0.1)
        self.assertEqual(journey.report["stages"][0]["exit_code"], 124)
        self.assertLess(time.monotonic() - start, 2)

    def test_vm_uri_is_loopback_and_process_logs_are_stored_without_credential(self):
        uri = "http://127.0.0.1:54321/sensitive-token=/"
        journey = Journey(self.path, "fixture-device")
        journey.run("launch", [sys.executable, "-c",
                               f"print('The Dart VM service is listening on {uri}')"], 1)
        self.assertEqual(service_uri(f"The Dart VM service is listening on {uri}"), uri)
        self.assertNotIn("sensitive-token", (self.path / "launch.log").read_text())
        self.assertNotIn("sensitive-token", redact(f"--use-existing-app={uri}"))
        with self.assertRaisesRegex(ValueError, "non-loopback"):
            service_uri("The Dart VM service is listening on http://example.com:54321/token/")

    def test_driver_failure_does_not_turn_into_success(self):
        journey = Journey(self.path, "fixture-device")
        with self.assertRaisesRegex(RuntimeError, "native-flutter-driver failed"):
            journey.run("native-flutter-driver", [sys.executable, "-c", "raise SystemExit(7)"], 1)
        report = json.loads((self.path / "ios-journey.json").read_text())
        self.assertFalse(report["passed"])
        self.assertEqual(report["stages"][0]["exit_code"], 7)

    def test_real_unreaped_zombie_group_closes_without_permission_failure(self):
        process = LoggedProcess([sys.executable, "-c", "pass"], self.path / "zombie.log")
        try:
            deadline = time.monotonic() + 2
            while time.monotonic() < deadline:
                state = subprocess.check_output(
                    ["/bin/ps", "-p", str(process.process.pid), "-o", "stat="],
                    text=True, timeout=1,
                ).strip()
                if state.startswith("Z"):
                    break
                time.sleep(0.01)
            self.assertTrue(state.startswith("Z"), state)
            if sys.platform == "darwin":
                with self.assertRaises(PermissionError):
                    os.killpg(process.process.pid, 0)
            process.close(grace=0.05)
            self.assertTrue(process.process.stdout.closed)
        finally:
            process.process.wait(timeout=2)
            process.close(grace=0.05)

    def test_permission_failure_with_a_live_group_member_is_not_ignored(self):
        command = (
            "import os, signal, time\n"
            "if os.fork() == 0:\n"
            " signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
            " print('live', flush=True)\n"
            " time.sleep(30)\n"
            "else:\n"
            " time.sleep(0.05)\n"
            " os._exit(0)\n"
        )
        process = LoggedProcess([sys.executable, "-u", "-c", command], self.path / "live.log")
        self.assertEqual(process.lines.get(timeout=1).strip(), "live")
        self.assertEqual(process.process.wait(timeout=1), 0)
        try:
            with patch("run_ios_catalog_journey.os.killpg", side_effect=PermissionError(errno.EPERM, "denied")):
                with self.assertRaises(PermissionError):
                    process.close(grace=0.05)
            self.assertTrue(process.reader.is_alive())
        finally:
            process.close(grace=0.05)

    def test_current_launch_uri_can_be_discovered_only_in_raw_unified_history(self):
        launched_at = datetime(2026, 9, 3, 10, 26, 59, tzinfo=timezone.utc)
        uri = "http://127.0.0.1:52715/fixture-credential=/"
        event = f"2026-09-03 10:27:01.266 Df Runner[31511:17d7d] (Flutter) flutter: The Dart VM service is listening on {uri}\n"
        details = {}
        with patch("run_ios_catalog_journey.query_unified_service", return_value=([event], 0)) as query:
            result = discover_service(31511, "device", "Runner", self.path,
                                      launched_at, time.monotonic() + 10, details)
        self.assertEqual(result, uri)
        self.assertEqual(query.call_args.args[1:3], (31511, launched_at))
        self.assertEqual(details["source"], "unified-log-history")
        self.assertNotIn("fixture-credential", json.dumps(details))

    def test_completed_non_u_child_yields_buffered_bundle_pid(self):
        journey = Journey(self.path, "fixture-device")
        # This child deliberately uses ordinary block-buffered stdout: neither
        # -u nor flush=True is present. EOF, not live output, releases the PID.
        command = [sys.executable, "-c",
                   "import time; print('fixture.catalog: 26703'); time.sleep(0.05)"]
        output = journey.run("launch", command, 1)
        self.assertEqual(launch_pid(output, "fixture.catalog"), 26703)
        self.assertEqual(journey.report["stages"][0]["exit_code"], 0)
        self.assertIn("fixture.catalog: 26703", (self.path / "launch.log").read_text())
        for invalid in (
            "Warning: Runner[26703] started",
            "other.catalog: 26703",
            "All tests passed.",
            "fixture.catalog: 0",
            "fixture.catalog: 26703\nfixture.catalog: 26704",
        ):
            with self.assertRaisesRegex(RuntimeError, "exactly one valid PID"):
                launch_pid(invalid, "fixture.catalog")

    def test_unified_history_rejects_other_pid_and_events_before_this_launch(self):
        launched_at = datetime(2026, 9, 3, 10, 26, 59, tzinfo=timezone.utc)
        tail = " (Flutter) flutter: The Dart VM service is listening on http://127.0.0.1:52715/old-token/"
        for prefix in (
            "2026-09-03 10:27:01.266 Df Runner[99999:17d7d]",
            "2026-09-03 10:26:58.999 Df Runner[31511:17d7d]",
            "2026-09-03 10:27:01.266 Df OtherApp[31511:17d7d]",
        ):
            self.assertIsNone(unified_service_uri(prefix + tail, 31511, "Runner", launched_at))

    def test_history_query_keeps_raw_uri_only_in_memory_and_rejects_command_failure(self):
        launched_at = datetime(2026, 9, 3, 10, 26, 59, tzinfo=timezone.utc)
        event = ("2026-09-03 10:27:01.266 Df Runner[31511:17d7d] (Flutter) flutter: "
                 "The Dart VM service is listening on http://127.0.0.1:52715/private-fixture-token/")
        real_popen = subprocess.Popen
        for exit_code in (0, 7):
            with self.subTest(exit_code=exit_code):
                def fixture_process(command, *args, **kwargs):
                    if command[0] == "xcrun":
                        self.assertEqual(command[1:4], ["simctl", "spawn", "fixture-device"])
                        self.assertIn("--no-pager", command)
                        self.assertEqual(command[command.index("--start") + 1], "2026-09-03 10:26:59+0000")
                        self.assertIn("processIdentifier == 31511", command[-1])
                        command = [sys.executable, "-u", "-c", f"print({event!r}); raise SystemExit({exit_code})"]
                    return real_popen(command, *args, **kwargs)

                log = self.path / f"history-{exit_code}.log"
                with patch("run_ios_catalog_journey.subprocess.Popen", side_effect=fixture_process):
                    lines, code = query_unified_service("fixture-device", 31511, launched_at, log, 1)
                self.assertEqual(code, exit_code)
                if code == 0:
                    self.assertIn("private-fixture-token", "".join(lines))
                else:
                    self.assertEqual(lines, [])
                self.assertNotIn("private-fixture-token", log.read_text())

    def test_history_discovery_keeps_one_global_deadline(self):
        start = time.monotonic()
        with patch("run_ios_catalog_journey.query_unified_service") as query:
            with self.assertRaisesRegex(TimeoutError, "launch deadline"):
                discover_service(31511, "device", "Runner", self.path,
                                 datetime.now(timezone.utc), start + 0.05, {})
            query.assert_not_called()  # Insufficient time for query + bounded cleanup.
        self.assertLess(time.monotonic() - start, 1)

    @unittest.skipUnless(hasattr(os, "fork"), "CLI process groups require POSIX")
    def test_exited_leader_does_not_hide_term_ignoring_child(self):
        command = (
            "import os, signal, time\n"
            "if os.fork() == 0:\n"
            " signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
            " print('child-ready', flush=True)\n"
            " time.sleep(30)\n"
            "else:\n"
            " time.sleep(0.05)\n"
            " os._exit(0)\n"
        )
        process = LoggedProcess([sys.executable, "-u", "-c", command], self.path / "child.log")
        self.assertEqual(process.lines.get(timeout=1).strip(), "child-ready")
        self.assertEqual(process.process.wait(timeout=1), 0)
        start = time.monotonic()
        process.close(grace=0.05)
        self.assertLess(time.monotonic() - start, 2)
        self.assertFalse(process.reader.is_alive())
        self.assertTrue(process.process.stdout.closed)


if __name__ == "__main__":
    unittest.main()
