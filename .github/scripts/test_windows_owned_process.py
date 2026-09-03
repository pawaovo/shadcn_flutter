"""Windows CI regressions for owned process trees; launches Python fixtures only."""

import ctypes
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import windows_owned_process as owned


@unittest.skipUnless(os.name == "nt", "Real Job Object checks require Windows CI")
class WindowsOwnedProcessTests(unittest.TestCase):
    def query_handle(self, job):
        # Keep a non-inheritable duplicate solely to query the real job after
        # stop_owned_process has closed its production ownership handle.
        api = job.api
        api.GetCurrentProcess.argtypes = []
        api.GetCurrentProcess.restype = owned.HANDLE
        api.DuplicateHandle.argtypes = [owned.HANDLE, owned.HANDLE, owned.HANDLE,
                                       ctypes.POINTER(owned.HANDLE), owned.DWORD,
                                       owned.BOOL, owned.DWORD]
        api.DuplicateHandle.restype = owned.BOOL
        current = api.GetCurrentProcess()
        duplicate = owned.HANDLE()
        # JOB_OBJECT_QUERY, no inheritance and no DUPLICATE_SAME_ACCESS.
        owned._checked(api.DuplicateHandle(current, job.handle, current,
                       ctypes.byref(duplicate), 0x0004, False, 0), "DuplicateHandle")
        self.addCleanup(lambda: owned._checked(api.CloseHandle(duplicate), "CloseHandle(test job)"))
        return duplicate

    def assert_job_empty(self, job, handle):
        accounting = owned._Accounting()
        owned._checked(job.api.QueryInformationJobObject(
            handle, owned.JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION,
            ctypes.byref(accounting), ctypes.sizeof(accounting), None),
            "QueryInformationJobObject(test)")
        self.assertEqual(accounting.ActiveProcesses, 0)

    def test_exited_leader_does_not_hide_live_descendant(self):
        with tempfile.TemporaryDirectory() as temporary:
            ready = Path(temporary) / "child.pid"
            child = (
                "import os,signal,sys,time; from pathlib import Path; "
                "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
                "signal.signal(signal.SIGBREAK, signal.SIG_IGN); "
                "Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(120)"
            )
            leader = (
                "import subprocess,sys,time; from pathlib import Path; "
                "subprocess.Popen([sys.executable, '-c', sys.argv[1], sys.argv[2]], "
                "stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); "
                "deadline=time.monotonic()+15\n"
                "while not Path(sys.argv[2]).exists():\n"
                " if time.monotonic() >= deadline: raise SystemExit(2)\n"
                " time.sleep(0.02)\n"
            )
            process = owned.start_owned_process(
                [sys.executable, "-c", leader, child, str(ready)],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.addCleanup(owned.stop_owned_process, process)
            job = process._owned_job
            handle = self.query_handle(job)
            self.assertEqual(process.wait(timeout=20), 0)
            self.assertGreater(int(ready.read_text()), 0)
            self.assertGreater(job.active_processes(), 0)

            # An independent owned fixture with the same executable must survive.
            unrelated = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"],
                                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                         stderr=subprocess.DEVNULL)
            try:
                owned.stop_owned_process(process)
                self.assert_job_empty(job, handle)
                self.assertEqual(process.returncode, 0)
                self.assertIsNone(unrelated.poll())
                owned.stop_owned_process(process)  # Verified cleanup is idempotent.
            finally:
                unrelated.kill()
                unrelated.wait(timeout=5)

    def test_cleanup_failure_is_raised_and_can_be_retried(self):
        process = owned.start_owned_process([sys.executable, "-c", "import time; time.sleep(120)"],
                                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                            stderr=subprocess.DEVNULL)
        self.addCleanup(owned.stop_owned_process, process)
        job = process._owned_job
        handle = self.query_handle(job)
        with patch.object(job.api, "TerminateJobObject", side_effect=OSError("injected failure")):
            with self.assertRaisesRegex(OSError, "injected failure"):
                owned.stop_owned_process(process)
        self.assertIsNotNone(job.handle)
        self.assertIsNone(process.poll())
        owned.stop_owned_process(process)
        self.assert_job_empty(job, handle)


if __name__ == "__main__":
    unittest.main()
