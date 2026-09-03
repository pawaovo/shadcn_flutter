"""Exercise launcher evidence/exit handling without starting Dart or Flutter."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


RUNNER = Path(__file__).with_name("run_p3_profile.sh")


class RunnerEvidenceTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.output = self.root / "evidence"
        self.calls = self.root / "calls.jsonl"
        # Preserve the real runner's catalog/tool topology, while replacing
        # external commands with deterministic fixtures rather than test knobs.
        fixture_tool = self.root / "catalog" / "tool"
        fixture_tool.mkdir(parents=True)
        self.runner = fixture_tool / RUNNER.name
        self.runner.write_bytes(RUNNER.read_bytes())
        (fixture_tool / "profile_source_snapshot.py").write_text("""
import json
import os
from pathlib import Path
import sys

operation, before, *after = sys.argv[1:]
with Path(os.environ['MOCK_CALLS']).open('a') as stream:
    stream.write(json.dumps(['snapshot', *sys.argv[1:]]) + '\\n')
if operation == 'capture':
    code = int(os.environ.get('MOCK_CAPTURE_EXIT', '0'))
    if not code:
        Path(before).write_text('{}')
else:
    code = int(os.environ.get('MOCK_SOURCE_EXIT', '0'))
    Path(after[0]).write_text('{}')
    print(json.dumps({'source_unchanged': code == 0}))
sys.exit(code)
""")
        self.mise = self.root / "fake-mise"
        self.mise.write_text(f"#!{sys.executable}\n" + """
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with Path(os.environ['MOCK_CALLS']).open('a') as stream:
    stream.write(json.dumps(args) + '\\n')
if args[:3] == ['exec', '--', 'dart']:
    sys.exit(int(os.environ.get('MOCK_FINALIZER_EXIT', '0')))
if '--version' in args:
    print('{}')
    sys.exit(int(os.environ.get('MOCK_VERSION_EXIT', '0')))
if 'pub' in args:
    print('mock pub get')
    sys.exit(int(os.environ.get('MOCK_PUB_EXIT', '0')))
print('mock driver')
sys.exit(int(os.environ.get('MOCK_DRIVER_EXIT', '0')))
""")
        self.mise.chmod(0o755)

    def run_launcher(self, **settings):
        env = {**os.environ, "P3_MISE_BIN": str(self.mise),
               "P3_PERF_OUTPUT_DIR": str(self.output), "P3_PERF_SUITE": "p3",
               "MOCK_CALLS": str(self.calls), "MOCK_VERSION_EXIT": "0",
               "MOCK_PUB_EXIT": "0", "MOCK_DRIVER_EXIT": "0",
               "MOCK_FINALIZER_EXIT": "0", "MOCK_CAPTURE_EXIT": "0",
               "MOCK_SOURCE_EXIT": "0", **settings}
        return subprocess.run(["bash", str(self.runner), "mock-device"],
                              env=env, capture_output=True, text=True,
                              timeout=10, check=False)

    def assert_exit_evidence(self, code, phase):
        self.assertEqual((self.output / "exit_code.txt").read_text(), f"{code}\n")
        self.assertEqual(json.loads((self.output / "runner_status.json").read_text()),
                         {"status": "complete" if code == 0 else "failed",
                          "phase": phase, "exit_code": code})

    def test_reused_successful_evidence_is_untouched_before_preflight_failure(self):
        self.output.mkdir()
        previous = {"p3_performance.json": '{"status":"complete"}\n',
                    "exit_code.txt": "0\n", "driver_exit_code.txt": "0\n",
                    "flutter_version.json": '{"frameworkVersion":"old"}\n',
                    "p3_frame_samples.json": '{"original":[]}\n'}
        for name, content in previous.items():
            (self.output / name).write_text(content)
        before = {path.name: (path.read_bytes(), path.stat().st_mtime_ns)
                  for path in self.output.iterdir()}
        result = self.run_launcher(MOCK_PUB_EXIT="23")
        self.assertEqual(result.returncode, 2)
        self.assertIn("Evidence directory is not empty", result.stderr)
        self.assertFalse(self.calls.exists())
        self.assertEqual(before, {path.name: (path.read_bytes(), path.stat().st_mtime_ns)
                                  for path in self.output.iterdir()})

    def test_hidden_entries_also_reject_output_reuse(self):
        self.output.mkdir()
        (self.output / ".previous-run").write_text("preserve")
        result = self.run_launcher()
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.calls.exists())
        self.assertEqual([path.name for path in self.output.iterdir()], [".previous-run"])

    def test_preflight_failures_write_actual_exit_without_claiming_driver_success(self):
        for phase, setting, code in (("flutter_version", "MOCK_VERSION_EXIT", 17),
                                     ("pub_get", "MOCK_PUB_EXIT", 23),
                                     ("source_capture", "MOCK_CAPTURE_EXIT", 2)):
            with self.subTest(phase=phase):
                self.output = self.root / phase
                result = self.run_launcher(**{setting: str(code)})
                self.assertEqual(result.returncode, code)
                self.assert_exit_evidence(code, phase)
                self.assertFalse((self.output / "driver_exit_code.txt").exists())
                self.assertFalse((self.output / "p3_performance.json").exists())

    def test_missing_mise_records_preflight_failure(self):
        result = self.run_launcher(P3_MISE_BIN=str(self.root / "missing-mise"))
        self.assertEqual(result.returncode, 2)
        self.assert_exit_evidence(2, "preflight")
        self.assertFalse(self.calls.exists())

    def test_driver_failure_precedes_finalizer_and_empty_directories_are_allowed(self):
        for driver, finalizer, expected in ((0, 0, 0), (0, 1, 1), (7, 0, 7), (7, 1, 7)):
            with self.subTest(driver=driver, finalizer=finalizer):
                self.output = self.root / f"matrix-{driver}-{finalizer}"
                self.output.mkdir()
                result = self.run_launcher(MOCK_DRIVER_EXIT=str(driver),
                                           MOCK_FINALIZER_EXIT=str(finalizer))
                self.assertEqual(result.returncode, expected)
                self.assert_exit_evidence(expected, "finalized")
                self.assertEqual((self.output / "driver_exit_code.txt").read_text(), f"{driver}\n")
                final_call = json.loads(self.calls.read_text().splitlines()[-1])
                self.assertEqual(final_call[-3:], ["--finalize", str(self.output), str(driver)])

    def test_source_mismatch_fails_successful_capture_without_hiding_other_failures(self):
        for driver, finalizer, expected in ((0, 0, 2), (0, 1, 1), (7, 0, 7), (7, 1, 7)):
            with self.subTest(driver=driver, finalizer=finalizer):
                self.output = self.root / f"changed-source-{driver}-{finalizer}"
                result = self.run_launcher(MOCK_DRIVER_EXIT=str(driver),
                                           MOCK_FINALIZER_EXIT=str(finalizer),
                                           MOCK_SOURCE_EXIT="2")
                self.assertEqual(result.returncode, expected)
                self.assert_exit_evidence(expected, "finalized")
                self.assertEqual((self.output / "driver_exit_code.txt").read_text(), f"{driver}\n")
                self.assertEqual(json.loads((self.output / "source_integrity.json").read_text()),
                                 {"source_unchanged": False})
                self.assertTrue((self.output / "source_before.json").is_file())
                self.assertTrue((self.output / "source_after.json").is_file())
                calls = [json.loads(line) for line in self.calls.read_text().splitlines()]
                self.assertEqual([call[1] if call[0] == "snapshot" else call[3]
                                  for call in calls[-6:]],
                                 ["--version", "pub", "capture", "drive", "compare", "run"])
                self.assertEqual(calls[-1][-3:], ["--finalize", str(self.output), str(driver)])


if __name__ == "__main__":
    unittest.main()
