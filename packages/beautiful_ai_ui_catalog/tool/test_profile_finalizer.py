"""Exercise the real Dart finalizer, including missing/duplicated suite IDs."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


CATALOG = Path(__file__).resolve().parents[1]
P3 = ["prompt_bar", "diff_table", "records_table", "sidebar_nav", "flowchart", "insight_cards", "selection_actions"]
P1P2 = ["search_long_catalog", "code_block_long_source", "thinking_long_trace", "streaming_long_answer", "tool_chips_large_output", "chat_long_transcript", "filter_table_large_dataset", "task_rows_large_workflow"]


class FinalizerContractTests(unittest.TestCase):
    def finalize(self, ids, *, suite="p3", report_suite=None, phase="workloads_complete", driver=0):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "p3_performance.json"
            path.write_text(json.dumps({
                "status": phase,
                "suite": f"beautiful_ai_ui_{report_suite or suite}_native_profile",
                "scenarios": [{"id": item, "status": "complete"} for item in ids],
            }))
            result = subprocess.run(
                [os.environ.get("P3_MISE_BIN", "/opt/homebrew/bin/mise"), "exec", "--", "dart", "run", "test_driver/p3_performance_driver.dart", "--finalize", directory, str(driver)],
                cwd=CATALOG, env={**os.environ, "P3_PERF_SUITE": suite},
                capture_output=True, text=True, timeout=40, check=False,
            )
            report = json.loads(path.read_text())
            return result.returncode, report

    def test_default_p3_and_new_all_require_their_exact_scenario_sets(self):
        for suite, ids in (("p3", P3), ("p1p2", P1P2), ("all", P3 + P1P2)):
            with self.subTest(suite=suite):
                code, report = self.finalize(ids, suite=suite)
                self.assertEqual(code, 0)
                self.assertEqual(report["status"], "complete")

    def test_duplicate_replacement_cannot_pass_by_count(self):
        code, report = self.finalize(P3[:-1] + [P3[0]])
        self.assertEqual(code, 1)
        self.assertEqual(report["status"], "failed")

    def test_wrong_target_and_failed_preparation_remain_failures(self):
        for kwargs in ({"report_suite": "all"}, {"phase": "failed_native_viewport_too_small"}, {"driver": 1}):
            with self.subTest(kwargs=kwargs):
                code, report = self.finalize(P3, **kwargs)
                self.assertNotEqual(code, 0)
                self.assertEqual(report["status"], "failed")


if __name__ == "__main__":
    unittest.main()
