"""Real Python process fixtures for diagnostic capture; no GUI, AT or synthesis."""

import os
from pathlib import Path
import signal
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import owned_pty_capture as capture_module
from owned_pty_capture import OwnedPtyCapture
from run_ios_catalog_journey import live_group_members


@unittest.skipIf(os.name == "nt", "The pilot uses a POSIX PTY on Linux")
class OwnedPtyCaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.output = self.directory / "orca-debug.log"

    def wait_for(self, predicate, timeout=2):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return True
            time.sleep(0.01)
        return False

    def test_running_orca_style_writer_is_observable_without_explicit_flush(self):
        ready = self.directory / "ready"
        expected = "SPEECH OUTPUT: '真实 reader output'\n".encode()
        script = (
            "import sys,time\nfrom pathlib import Path\n"
            "with open('/dev/stdout', 'w', encoding='utf-8') as log:\n"
            " log.write(\"SPEECH OUTPUT: '真实 reader output'\\n\")\n"
            " Path(sys.argv[1]).touch()\n"
            " time.sleep(60)\n"
        )
        capture = OwnedPtyCapture([sys.executable, "-c", script, str(ready)], self.output)
        self.addCleanup(capture.close)
        self.assertTrue(self.wait_for(ready.exists), "The fixture did not reach its unflushed write")
        self.assertIsNone(capture.process.poll(), "Evidence must be observed before the process exits")
        self.assertTrue(self.wait_for(lambda: expected in self.output.read_bytes(), timeout=0.4),
                        "A live Orca-style file write remained hidden in the producer's buffer")
        self.assertIsNone(capture.process.poll())

    def test_full_original_bytes_and_nonzero_exit_are_preserved(self):
        expected = ("raw 中文\r\nline\n\x1b[31mred\x1b[0m\x00".encode() * 5000) + b"last byte"
        payload = self.directory / "payload.bin"
        payload.write_bytes(expected)
        script = ("import sys\nfrom pathlib import Path\n"
                  "with open('/dev/stdout','wb') as log: log.write(Path(sys.argv[1]).read_bytes())\n"
                  "raise SystemExit(7)\n")
        capture = OwnedPtyCapture([sys.executable, "-c", script, str(payload)], self.output)
        self.addCleanup(capture.close)
        self.assertEqual(capture.process.wait(timeout=5), 7)
        capture.close()
        self.assertEqual(capture.process.returncode, 7)
        self.assertEqual(self.output.read_bytes(), expected)
        self.assertEqual(capture.bytes_written, len(expected))
        self.assertTrue(capture.eof)
        self.assertFalse(capture.reader_alive)
        self.assertTrue(capture.output.closed)

    def test_dead_leader_descendant_and_reader_are_owned_and_cleaned(self):
        ready = self.directory / "child.pid"
        script = (
            "import os,signal,time,sys\nfrom pathlib import Path\n"
            "if os.fork() == 0:\n"
            " signal.signal(signal.SIGTERM,signal.SIG_IGN)\n"
            " Path(sys.argv[1]).write_text(str(os.getpid()))\n"
            " print('child stream',flush=True)\n"
            " time.sleep(60)\n"
            "else:\n"
            " while not Path(sys.argv[1]).exists(): time.sleep(.01)\n"
            " os._exit(0)\n"
        )
        capture = OwnedPtyCapture([sys.executable, "-c", script, str(ready)], self.output)
        self.addCleanup(capture.close)
        self.assertEqual(capture.process.wait(timeout=3), 0)
        self.assertIn(int(ready.read_text()), live_group_members(capture.process.pid))
        capture.close(grace=0.05, kill_timeout=1)
        self.assertEqual(live_group_members(capture.process.pid), [])
        self.assertEqual(self.output.read_bytes(), b"child stream\n")
        self.assertTrue(capture.eof)
        self.assertFalse(capture.reader_alive)
        self.assertEqual(capture.process.returncode, 0)
        capture.close()  # Idempotent only after complete verified cleanup.

    def test_capture_failure_is_raised_instead_of_accepting_partial_log(self):
        class BrokenSink(OwnedPtyCapture):
            def _write(self, data):
                raise OSError("fixture evidence write failed")

        capture = BrokenSink([sys.executable, "-c", "print('diagnostic',flush=True)"], self.output)
        self.assertTrue(self.wait_for(lambda: capture.error is not None))
        with self.assertRaisesRegex(RuntimeError, "fixture evidence write failed"):
            capture.close(grace=0.05, kill_timeout=1)
        self.assertFalse(capture.reader_alive)
        self.assertTrue(capture.output.closed)
        self.assertEqual(live_group_members(capture.process.pid), [])

    def test_process_cleanup_failure_is_not_hidden_by_successful_capture(self):
        capture = OwnedPtyCapture([sys.executable, "-c", "import time; print('ready',flush=True); time.sleep(60)"], self.output)
        self.addCleanup(capture.close)
        self.assertTrue(self.wait_for(lambda: b"ready\n" in self.output.read_bytes()))
        stop = capture_module.stop_owned_process

        def failed_verification(process, **kwargs):
            stop(process, **kwargs)
            raise RuntimeError("fixture process cleanup could not be verified")

        with patch.object(capture_module, "stop_owned_process", side_effect=failed_verification):
            with self.assertRaisesRegex(RuntimeError, "fixture process cleanup could not be verified"):
                capture.close()
        self.assertFalse(capture.reader_alive)
        self.assertTrue(capture.eof)


if __name__ == "__main__":
    unittest.main()
