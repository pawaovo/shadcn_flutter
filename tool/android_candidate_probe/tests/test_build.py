"""Real subprocess ownership regressions; no SDK, emulator, or IME is used."""

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


PROBE = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("candidate_probe_build_test", PROBE / "build.py")
build = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(build)
from run_ios_catalog_journey import live_group_members


@unittest.skipIf(os.name == "nt", "Android probe build CI uses POSIX ownership")
class BuildCommandTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.log = build.Diagnostics(self.directory / "build.log")
        self.addCleanup(self.log.close)

    def run_python(self, source, timeout=2):
        return self.log.run([sys.executable, "-c", source], env=os.environ.copy(),
                            cwd=self.directory, timeout=timeout)

    def result(self):
        lines = self.log.path.read_text().splitlines()
        return json.loads(next(line.removeprefix("command-result: ")
                               for line in reversed(lines) if line.startswith("command-result: ")))

    def test_success_retains_both_streams_and_verified_cleanup(self):
        output = self.run_python("import sys;print('stdout',flush=True);print('stderr',file=sys.stderr,flush=True)")
        self.assertEqual(output, "stdout\nstderr")
        self.assertEqual(self.result()["original_exit_code"], 0)
        self.assertEqual(self.result()["cleanup_status"], "verified")

    def test_dead_leader_descendant_is_cleaned_on_timeout_and_partial_output_survives(self):
        processes = []
        real_start = build.start_owned_process

        def capture(*args, **kwargs):
            process = real_start(*args, **kwargs)
            processes.append(process)
            return process

        with patch.object(build, "start_owned_process", side_effect=capture):
            with self.assertRaisesRegex(build.BuildError, "TimeoutExpired"):
                self.run_python("import subprocess,sys;child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(60)']);print('child',child.pid,flush=True)", timeout=0.2)
        self.assertEqual(live_group_members(processes[0].pid), [])
        self.assertEqual(self.result()["original_exit_code"], 0)
        self.assertEqual(self.result()["cleanup_status"], "verified")
        self.assertIn("child ", self.log.path.read_text())

    def test_original_exit_and_cleanup_error_are_both_preserved(self):
        real_stop = build.stop_owned_process

        def fail_after_cleanup(process, **kwargs):
            real_stop(process, **kwargs)
            raise RuntimeError("fixture cleanup verification failure")

        with patch.object(build, "stop_owned_process", side_effect=fail_after_cleanup):
            with self.assertRaisesRegex(build.BuildError, "status 7.*cleanup verification failure"):
                self.run_python("print('compiler detail',flush=True);raise SystemExit(7)")
        self.assertEqual(self.result()["original_exit_code"], 7)
        self.assertEqual(self.result()["cleanup_status"], "unverified")
        self.assertIn("compiler detail", self.log.path.read_text())


if __name__ == "__main__":
    unittest.main()
