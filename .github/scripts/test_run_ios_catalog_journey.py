"""Exercise console-start boundaries without macOS, an app, or a simulator."""

import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest

from run_ios_catalog_journey import Journey, LoggedProcess, redact, service_uri


class IOSLaunchTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name)

    def test_mounted_console_without_vm_is_a_bounded_failure(self):
        process = LoggedProcess([sys.executable, "-u", "-c",
                                 "import time; print('app launched'); time.sleep(30)"],
                                self.path / "launch.log")
        start = time.monotonic()
        try:
            with self.assertRaisesRegex(TimeoutError, "No Dart VM Service"):
                process.wait_for_service(0.1)
        finally:
            process.close()
        self.assertLess(time.monotonic() - start, 2)

    def test_console_vm_uri_is_real_loopback_and_stored_without_credential(self):
        uri = "http://127.0.0.1:54321/sensitive-token=/"
        process = LoggedProcess([sys.executable, "-u", "-c",
                                 f"print('The Dart VM service is listening on {uri}')"],
                                self.path / "launch.log")
        try:
            self.assertEqual(process.wait_for_service(1), uri)
        finally:
            process.close()
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
