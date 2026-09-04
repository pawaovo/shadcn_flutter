"""Paired-diagnostic boundaries; no browser, Flutter build or real executable preread."""

import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import probe_edge_full_journey as diagnostic


class FullJourneyDiagnosticTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)

    def test_baseline_never_prereads_and_runs_only_one_original_journey(self):
        with patch.object(diagnostic, "preread_executable") as preread, \
                patch.object(diagnostic, "run") as run, \
                patch.object(diagnostic, "post_run_evidence", return_value={}) as evidence:
            report = diagnostic.run_condition(self.directory / "baseline", "a" * 40, "baseline")
        preread.assert_not_called()
        self.assertEqual(run.call_count, 1)
        self.assertTrue(run.call_args.args[0].journey_only)
        self.assertFalse(run.call_args.args[0].include_journey)
        self.assertEqual(report["status"], "passed")
        evidence.assert_called_once_with((self.directory / "baseline").resolve(), None)

    def test_preread_is_once_before_run_and_its_cost_remains_in_report(self):
        calls = []
        preread = {"elapsed_seconds": 1.25, "resolved": "/actual/edge", "sha256": "hash"}
        with patch.object(diagnostic, "preread_executable", side_effect=lambda *_: calls.append("preread") or preread), \
                patch.object(diagnostic, "run", side_effect=lambda *_: calls.append("journey")), \
                patch.object(diagnostic, "post_run_evidence", side_effect=lambda *_: calls.append("post_hash") or {}):
            report = diagnostic.run_condition(self.directory / "preread", "a" * 40, "preread", Path("/actual/edge"))
        self.assertEqual(calls, ["preread", "journey", "post_hash"])
        self.assertEqual(report["preread"], preread)
        self.assertIn("elapsed_seconds_including_preread_and_cleanup", report)

    def test_evidence_error_cannot_replace_original_run_failure_or_retry_it(self):
        with patch.object(diagnostic, "run", side_effect=RuntimeError("original renderer timeout 300.000")) as run, \
                patch.object(diagnostic, "post_run_evidence", side_effect=ValueError("observer missing")):
            report = diagnostic.run_condition(self.directory / "failure", "a" * 40, "baseline")
        self.assertEqual(run.call_count, 1)
        self.assertEqual(report["upstream_status"], "failed")
        self.assertIn("original renderer timeout 300.000", report["original_run_error"])
        self.assertIn("observer missing", report["evidence_error"])
        self.assertEqual(report["status"], "failed")

    def evidence_fixture(self):
        output = self.directory / "post"
        journey = output / "acceptance" / "journey"
        (journey / "resources").mkdir(parents=True)
        (output / "acceptance" / "input-acceptance-summary.json").write_text(json.dumps({
            "status": "failed", "suites": [{"suite": "journey", "cleanup_status": "verified", "exit_code": 7}]}))
        (journey / "browser-identity.json").write_text(json.dumps({"capabilities": {
            "goog:processID": 10, "pageLoadStrategy": "normal", "timeouts": {"pageLoad": 300000}}}))
        (journey / "resources" / "observation.json").write_text(json.dumps({
            "status": "recorded", "root_pid": 9, "root_start_ticks": 90}))
        (journey / "resources" / "resources.jsonl").write_text(json.dumps({"processes": [
            {"pid": 9, "start_ticks": 90, "exe": "/actual/driver"},
            {"pid": 10, "start_ticks": 100, "exe": "/actual/edge"},
            {"pid": 11, "start_ticks": 101, "exe": "/wrong/child"}]}))
        return output

    def test_preread_must_match_actual_browser_pid_path_and_post_hash(self):
        output = self.evidence_fixture()
        with patch.object(diagnostic, "file_identity", side_effect=lambda path: {"resolved": path, "sha256": "posthash"}):
            evidence = diagnostic.post_run_evidence(output, {"resolved": "/actual/edge", "sha256": "posthash"})
            self.assertEqual(evidence["upstream"]["suites"][0]["exit_code"], 7)
            for preread in ({"resolved": "/wrong/child", "sha256": "posthash"},
                            {"resolved": "/actual/edge", "sha256": "different"}):
                with self.assertRaisesRegex(ValueError, "Preread path/hash"):
                    diagnostic.post_run_evidence(output, preread)

    def test_unverified_cleanup_prevents_executable_hashing(self):
        output = self.evidence_fixture()
        summary = output / "acceptance" / "input-acceptance-summary.json"
        value = json.loads(summary.read_text())
        value["suites"][0]["cleanup_status"] = "unverified"
        summary.write_text(json.dumps(value))
        with patch.object(diagnostic, "file_identity") as identity:
            with self.assertRaisesRegex(ValueError, "Owned cleanup"):
                diagnostic.post_run_evidence(output, None)
        identity.assert_not_called()

    def test_pair_requires_actual_image_versions_hashes_and_preserves_failure(self):
        baseline = {"condition": "baseline", "source_sha": "a" * 40, "upstream_status": "failed",
                    "original_run_error": "original timeout", "evidence_status": "recorded",
                    "runner": {"ImageOS": "ubuntu24", "ImageVersion": "fixture-image", "RUNNER_OS": "Linux", "RUNNER_ARCH": "X64"},
                    "evidence": {"session": {"capabilities": {"browserVersion": "152.0.4191.53", "msedge": {"msedgedriverVersion": "152.0.4191.53 fixture"}}},
                                 "browser_executable_after_run": {"sha256": "browser-hash"}, "driver_executable_after_run": {"sha256": "driver-hash"}}}
        preread = copy.deepcopy(baseline)
        preread.update(condition="preread", upstream_status="passed")
        first, second = self.directory / "baseline.json", self.directory / "preread.json"
        first.write_text(json.dumps(baseline))
        second.write_text(json.dumps(preread))
        result = diagnostic.compare_reports(first, second)
        self.assertEqual(result["comparison_status"], "provenance_matched")
        self.assertEqual(result["conditions"][0]["original_run_error"], "original timeout")
        for field in ("image", "version", "hash"):
            changed = copy.deepcopy(preread)
            if field == "image":
                changed["runner"]["ImageVersion"] = "other-image"
            elif field == "version":
                changed["evidence"]["session"]["capabilities"]["browserVersion"] = "other-version"
            else:
                changed["evidence"]["browser_executable_after_run"]["sha256"] = "other-hash"
            second.write_text(json.dumps(changed))
            self.assertEqual(diagnostic.compare_reports(first, second)["comparison_status"], "blocked")
        second.unlink()
        self.assertEqual(diagnostic.compare_reports(first, second)["comparison_status"], "blocked")


if __name__ == "__main__":
    unittest.main()
