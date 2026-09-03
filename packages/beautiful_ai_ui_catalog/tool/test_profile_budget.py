"""Acceptance boundaries for the native evidence budget assessor."""

from copy import deepcopy
import gzip
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CLI = Path(__file__).with_name("assess_profile_budget.py")
SPEC = importlib.util.spec_from_file_location("profile_budget", CLI)
budget = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(budget)


def independently_summarize(rows):
    result = {}
    for metric in ("build_us", "raster_us", "total_span_us", "vsync_overhead_us"):
        ordered = sorted(row[metric] for row in rows)
        values = {"sample_count": len(rows), "min": min(ordered), "max": max(ordered),
                  "mean": sum(ordered) / len(ordered), "percentile_method": "nearest rank"}
        for p in (50, 90, 95, 99):
            values[f"p{p}"] = ordered[math.ceil(len(ordered) * p / 100) - 1]
        result[metric] = values
    return result


class BudgetAcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.frames = {}
        self.memory = {}
        scenarios = []
        for position, name in enumerate(budget.P3_IDS):
            rows = [{"frame_number": position * 1000 + index,
                     "build_us": 500, "raster_us": 500, "vsync_overhead_us": 100,
                     "total_span_us": 1100, "raster_finish_epoch_us": 1_000_000_000 + position * 1_000_000 + index * 1000}
                    for index in range(100)]
            self.frames[name] = rows
            memory = [{"phase": "before_interactions" if index == 0 else (
                       "after_interactions" if index == 9 else "during_interactions"),
                       "elapsed_us": index * 100_000, "current_rss_bytes": 128 * 1024 * 1024,
                       "process_lifetime_max_rss_bytes": 200 * 1024 * 1024}
                      for index in range(10)]
            self.memory[name] = memory
            scenarios.append({"id": name, "status": "complete", "warmup_rounds": 1,
                              "measured_rounds": 3, "interaction_wall_time_us": 900050,
                              "interaction_steps": [{"name": "exercise", "round": index,
                                                     "wall_time_us": 300000} for index in range(3)],
                              "sampled_frame_count": 100, "received_frame_count": 101,
                              "excluded_outside_window_frame_count": 1,
                              "frame_timing_summary_us": independently_summarize(rows),
                              "rss_sample_count": 10, "rss_observed_peak_bytes": 128 * 1024 * 1024})
        self.report = {"schema_version": 1, "status": "complete",
                       "workload_phase_status": "workloads_complete",
                       "integration_driver_exit_code": 0, "final_script_exit_code": 0,
                       "runtime": {"build_mode": "profile", "display_refresh_rate_hz": 100,
                                   "device_pixel_ratio": 2,
                                   "native_view_logical_dp": {"width": 1728, "height": 1080}},
                       "scenarios": scenarios}

    def save(self, compressed=False, raw=False):
        path = self.root / ("p3_performance.json" if raw else "summary.json")
        path.write_text(json.dumps(self.report))
        for name, data in (("p3_frame_samples", self.frames), ("p3_memory_samples", self.memory)):
            blob = json.dumps(data).encode()
            if compressed:
                (self.root / f"{name}.json.gz").write_bytes(gzip.compress(blob))
            else:
                (self.root / f"{name}.json").write_bytes(blob)
        return path

    def evaluate(self):
        self.save()
        return budget.assess(self.root)

    def update_frames(self):
        for scenario in self.report["scenarios"]:
            rows = self.frames[scenario["id"]]
            scenario["sampled_frame_count"] = len(rows)
            scenario["received_frame_count"] = len(rows) + 1
            scenario["frame_timing_summary_us"] = independently_summarize(rows)

    def change_builds(self, values):
        for row, value in zip(self.frames["prompt_bar"], values):
            row["build_us"] = value
            row["total_span_us"] = value + 600
        self.update_frames()

    def first_gate(self, result, name):
        return next(gate for gate in result["scenarios"][0]["gates"] if gate["name"] == name)

    def add_epoch_intervals(self):
        scenario = self.report["scenarios"][0]
        base = self.frames["prompt_bar"][0]["raster_finish_epoch_us"]
        scenario["sampling_start_epoch_us"] = base
        scenario["sampling_end_epoch_us"] = base + 900050
        scenario["interaction_steps"] = []
        scenario["interaction_rounds"] = []
        for round_index in range(3):
            begin = base + round_index * 300000
            scenario["interaction_rounds"].append({"round": round_index,
                                                   "start_epoch_us": begin, "end_epoch_us": begin + 300000})
            for step_index, name in enumerate(("first", "second")):
                scenario["interaction_steps"].append({"round": round_index, "name": name,
                                                      "wall_time_us": 149900,
                                                      "start_epoch_us": begin + step_index * 150000,
                                                      "end_epoch_us": begin + (step_index + 1) * 150000})
        return scenario, base

    def add_source_snapshots(self):
        self.report["revision"] = "a" * 40
        self.report["driver"] = {"source_revision": "a" * 40}
        files = [{"path": "lib/示例.dart", "sha256": hashlib.sha256(b"source").hexdigest(), "bytes": 6},
                 {"path": "pubspec.lock", "sha256": hashlib.sha256(b"lock").hexdigest(), "bytes": 4}]
        before = {"schema_version": 1, "revision": self.report["revision"],
                  "source_worktree_status": " M lib/示例.dart\n", "files": files,
                  "manifest_algorithm": budget.source_snapshot.ALGORITHM}
        self.refresh_manifest(before)
        after = deepcopy(before)
        after["source_worktree_status"] += " M docs/notes.md\n"
        integrity = budget.source_snapshot.comparison(before, after)
        self.write_source_snapshots(before, after, integrity)
        return before, after, integrity

    def refresh_manifest(self, snapshot):
        content = "\n".join(row["path"] + "\0" + row["sha256"] for row in snapshot["files"])
        snapshot["manifest_sha256"] = hashlib.sha256(content.encode("utf-8")).hexdigest()

    def write_source_snapshots(self, before, after, integrity):
        for name, value in zip(budget.SOURCE_ARTIFACTS, (before, after, integrity)):
            (self.root / name).write_text(json.dumps(value))

    def add_native_environment(self):
        scenario, base = self.add_epoch_intervals()
        state = {"native_view_physical_px": {"width": 3456, "height": 2160},
                 "native_view_logical_dp": {"width": 1728, "height": 1080},
                 "device_pixel_ratio": 2, "application_lifecycle_state": "resumed",
                 "frames_enabled": True, "platform_semantics_enabled": False,
                 "framework_semantics_enabled": True}
        monitor = {"status": "verified_stable", "initial": state,
                   "final": deepcopy(state), "changes": [],
                   "start_epoch_us": base + 5, "end_epoch_us": base + 900100}
        scenario["native_environment_during_measurement"] = monitor
        for key in ("runtime_before_measurement", "runtime_after_measurement"):
            scenario[key] = {**deepcopy(self.report["runtime"]), **deepcopy(state)}
        return scenario, monitor

    def test_complete_compact_and_compressed_evidence_pass_without_release_claim(self):
        self.save(compressed=True)
        result = budget.assess(self.root)
        self.assertEqual(result["status"], "pass")
        self.assertFalse(result["all_platform_release_accepted"])
        self.assertEqual(result["component_memory_assessment"], "unassessed")
        self.assertEqual(result["leak_assessment"], "unassessed")
        self.assertEqual(result["approval_status"], "engineering_default_not_product_approved")

    def test_exact_frame_interval_and_twice_interval_are_inclusive(self):
        self.change_builds([10000] * 100)
        self.assertEqual(self.evaluate()["status"], "pass")
        self.change_builds([20000] + [500] * 99)
        result = self.evaluate()
        self.assertEqual(result["status"], "pass")
        self.assertEqual(self.first_gate(result, "build_or_raster_over_interval_fraction")["observed"], .01)
        self.change_builds([20001] + [500] * 99)
        result = self.evaluate()
        self.assertEqual(result["status"], "budget_fail")
        self.assertFalse(self.first_gate(result, "build_max_us")["passed"])

    def test_more_than_one_percent_over_interval_fails_even_with_fast_p95(self):
        self.change_builds([10001, 10001])
        result = self.evaluate()
        self.assertTrue(self.first_gate(result, "build_p95_us")["passed"])
        self.assertFalse(self.first_gate(result, "build_or_raster_over_interval_fraction")["passed"])
        self.assertEqual(result["status"], "budget_fail")

    def test_120_hz_fractional_threshold_is_not_rounded_up(self):
        self.report["runtime"]["display_refresh_rate_hz"] = 120
        self.change_builds([8333, 8334])
        result = self.evaluate()
        self.assertEqual(result["scenarios"][0]["build_or_raster_over_interval_count"], 1)
        self.assertEqual(result["scenarios"][0]["interval_exceedances"]["reference_60_hz"]["build_us"]["count"], 0)

    def test_large_total_span_can_fail_while_build_and_raster_pass(self):
        for row in self.frames["prompt_bar"]:
            row["vsync_overhead_us"] = 19500
            row["total_span_us"] = 20500
        self.update_frames()
        result = self.evaluate()
        self.assertTrue(self.first_gate(result, "build_p95_us")["passed"])
        self.assertFalse(self.first_gate(result, "total_span_p95_us")["passed"])

    def test_memory_peak_and_growth_are_separate_inclusive_process_risk_gates(self):
        rows = self.memory["prompt_bar"]
        for row in rows:
            row["current_rss_bytes"] = 448 * 1024 * 1024
            row["process_lifetime_max_rss_bytes"] = 700 * 1024 * 1024
        rows[-1]["current_rss_bytes"] = 512 * 1024 * 1024
        self.report["scenarios"][0]["rss_observed_peak_bytes"] = 512 * 1024 * 1024
        self.assertEqual(self.evaluate()["status"], "pass")
        rows[-1]["current_rss_bytes"] += 1
        self.report["scenarios"][0]["rss_observed_peak_bytes"] += 1
        result = self.evaluate()
        self.assertFalse(self.first_gate(result, "measured_process_rss_sample_peak_bytes")["passed"])
        self.assertFalse(self.first_gate(result, "measured_process_rss_positive_end_minus_start_bytes")["passed"])

    def test_negative_memory_delta_does_not_claim_leak_absence(self):
        self.memory["prompt_bar"][-1]["current_rss_bytes"] -= 1
        result = self.evaluate()
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["scenarios"][0]["measured_process_rss"]["signed_end_minus_start_bytes"], -1)
        self.assertEqual(result["leak_assessment"], "unassessed")

    def test_insufficient_frame_samples_invalid_despite_fast_values(self):
        self.frames["prompt_bar"].pop()
        self.update_frames()
        with self.assertRaisesRegex(budget.InvalidEvidence, "insufficient FrameTiming"):
            self.evaluate()

    def test_insufficient_rounds_or_rss_samples_invalid(self):
        self.report["scenarios"][0]["measured_rounds"] = 2
        with self.assertRaisesRegex(budget.InvalidEvidence, "measured_rounds"):
            self.evaluate()
        self.report["scenarios"][0]["measured_rounds"] = 3
        self.memory["prompt_bar"].pop(1)
        self.report["scenarios"][0]["rss_sample_count"] = 9
        with self.assertRaisesRegex(budget.InvalidEvidence, "insufficient RSS"):
            self.evaluate()

    def test_duplicate_missing_and_unknown_scenarios_invalid(self):
        original = deepcopy(self.report["scenarios"])
        for mutation in (original[:-1], original + [original[0]], original + [{"id": "unknown"}]):
            with self.subTest(ids=[sc["id"] for sc in mutation]):
                self.report["scenarios"] = mutation
                with self.assertRaises(budget.InvalidEvidence):
                    self.evaluate()

    def test_corrupted_distribution_duplicate_frame_or_bad_duration_invalid(self):
        self.report["scenarios"][0]["frame_timing_summary_us"]["build_us"]["p95"] = 1
        with self.assertRaisesRegex(budget.InvalidEvidence, "disagrees with raw samples"):
            self.evaluate()
        self.update_frames()
        self.frames["prompt_bar"][1]["frame_number"] = self.frames["prompt_bar"][0]["frame_number"]
        with self.assertRaisesRegex(budget.InvalidEvidence, "duplicated/unordered"):
            self.evaluate()
        self.frames["prompt_bar"][1]["frame_number"] = 1
        self.frames["prompt_bar"][1]["build_us"] = True
        with self.assertRaisesRegex(budget.InvalidEvidence, "integer"):
            self.evaluate()

    def test_missing_finalization_nonzero_exit_and_nonprofile_invalid(self):
        self.report["status"] = "workloads_complete"
        with self.assertRaisesRegex(budget.InvalidEvidence, "finalized"):
            self.evaluate()
        self.report["status"] = "complete"
        self.report["integration_driver_exit_code"] = 1
        with self.assertRaisesRegex(budget.InvalidEvidence, "integration driver"):
            self.evaluate()
        self.report["integration_driver_exit_code"] = 0
        self.report["runtime"]["build_mode"] = "debug"
        with self.assertRaisesRegex(budget.InvalidEvidence, "profile"):
            self.evaluate()

    def test_raw_report_requires_real_final_exit_sidecar(self):
        del self.report["final_script_exit_code"]
        self.report["suite"] = "beautiful_ai_ui_p3_native_profile"
        self.save(raw=True)
        with self.assertRaisesRegex(budget.InvalidEvidence, "final script success is missing"):
            budget.assess(self.root)
        (self.root / "exit_code.txt").write_text("0\n")
        self.assertEqual(budget.assess(self.root)["status"], "pass")
        (self.root / "driver_exit_code.txt").write_text("1\n")
        with self.assertRaisesRegex(budget.InvalidEvidence, "driver_exit_code.txt is not 0"):
            budget.assess(self.root)

    def test_sampling_window_and_changed_viewport_invalid(self):
        sc = self.report["scenarios"][0]
        sc["sampling_start_epoch_us"] = self.frames["prompt_bar"][0]["raster_finish_epoch_us"] + 1
        sc["sampling_end_epoch_us"] = self.frames["prompt_bar"][-1]["raster_finish_epoch_us"] + 1
        with self.assertRaisesRegex(budget.InvalidEvidence, "outside sampling window"):
            self.evaluate()
        del sc["sampling_start_epoch_us"], sc["sampling_end_epoch_us"]
        sc["runtime_after_measurement"] = deepcopy(self.report["runtime"])
        sc["runtime_after_measurement"]["native_view_logical_dp"]["width"] = 800
        with self.assertRaisesRegex(budget.InvalidEvidence, "changed"):
            self.evaluate()

    def test_memory_unordered_missing_boundaries_and_stale_peak_invalid(self):
        self.memory["prompt_bar"][1]["elapsed_us"] = 0
        with self.assertRaisesRegex(budget.InvalidEvidence, "duplicated/unordered"):
            self.evaluate()
        self.memory["prompt_bar"][1]["elapsed_us"] = 100000
        self.memory["prompt_bar"][0]["phase"] = "during_interactions"
        with self.assertRaisesRegex(budget.InvalidEvidence, "phase boundaries"):
            self.evaluate()
        self.memory["prompt_bar"][0]["phase"] = "before_interactions"
        self.report["scenarios"][0]["rss_observed_peak_bytes"] += 1
        with self.assertRaisesRegex(budget.InvalidEvidence, "recorded RSS peak"):
            self.evaluate()

    def test_conflicting_gzip_and_json_and_duplicate_json_keys_invalid(self):
        self.save(compressed=True)
        self.frames["prompt_bar"][0]["build_us"] = 501
        self.save()
        with self.assertRaisesRegex(budget.InvalidEvidence, "conflicting compressed"):
            budget.assess(self.root)
        (self.root / "summary.json").write_text('{"schema_version":1,"schema_version":1}')
        with self.assertRaisesRegex(budget.InvalidEvidence, "duplicate JSON key"):
            budget.assess(self.root)

    def test_nonfinite_refresh_and_json_numbers_invalid(self):
        self.report["runtime"]["display_refresh_rate_hz"] = 0
        with self.assertRaises(budget.InvalidEvidence):
            self.evaluate()
        self.report["runtime"]["display_refresh_rate_hz"] = float("nan")
        with self.assertRaisesRegex(budget.InvalidEvidence, "invalid JSON number"):
            self.evaluate()

    def test_all_named_suites_require_every_expected_workload(self):
        original = deepcopy(self.report["scenarios"][0])
        original_frames = deepcopy(self.frames["prompt_bar"])
        original_memory = deepcopy(self.memory["prompt_bar"])
        for suite in ("p1p2", "all"):
            with self.subTest(suite=suite):
                self.frames = {}
                self.memory = {}
                self.report["scenarios"] = []
                self.report["suite"] = f"beautiful_ai_ui_{suite}_native_profile"
                self.report["driver"] = {"performance_suite": suite}
                for index, name in enumerate(budget.SUITES[suite]):
                    scenario = deepcopy(original)
                    scenario["id"] = name
                    rows = deepcopy(original_frames)
                    for row in rows:
                        row["frame_number"] += index * 1000
                        row["raster_finish_epoch_us"] += index * 1_000_000
                    self.report["scenarios"].append(scenario)
                    self.frames[name] = rows
                    self.memory[name] = deepcopy(original_memory)
                result = self.evaluate()
                self.assertEqual(result["suite"], suite)
                self.assertEqual(result["status"], "pass")
                with self.assertRaisesRegex(budget.InvalidEvidence, "requested p3"):
                    budget.assess(self.root, requested_suite="p3")
                self.report["driver"]["performance_suite"] = "p3"
                with self.assertRaisesRegex(budget.InvalidEvidence, "suite disagree"):
                    self.evaluate()

    def test_contradictory_suite_declarations_cannot_be_shadowed(self):
        self.report["suite"] = "beautiful_ai_ui_p3_native_profile"
        self.report["driver"] = {"performance_suite": "p3"}
        self.report["performance_suite"] = "p1p2"
        with self.assertRaisesRegex(budget.InvalidEvidence, "suite disagree"):
            self.evaluate()

    def test_contradictory_source_revisions_cannot_be_shadowed(self):
        self.report["revision"] = "a" * 40
        for other in ("driver", "source_revision"):
            with self.subTest(other=other):
                self.report.pop("driver", None)
                self.report.pop("source_revision", None)
                self.report[other] = {"source_revision": "b" * 40} if other == "driver" else "b" * 40
                with self.assertRaisesRegex(budget.InvalidEvidence, "source revisions disagree"):
                    self.evaluate()

    def test_source_snapshots_verify_hashes_and_allow_dirty_out_of_scope_status_changes(self):
        self.add_source_snapshots()
        result = self.evaluate()
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["source_integrity"]["status"], "verified_unchanged")
        self.assertFalse(result["source_integrity"]["source_worktree_status_unchanged"])
        for name in budget.SOURCE_ARTIFACTS:
            path = self.root / name
            entry = result["input_artifacts"][str(path.resolve())]
            self.assertEqual(entry["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
            self.assertEqual(entry["bytes"], path.stat().st_size)

    def test_historical_source_stability_is_explicitly_unavailable(self):
        self.report["revision"] = "a" * 40
        self.assertEqual(self.evaluate()["source_integrity"]["status"], "unavailable_pre_snapshot_capture")
        self.report["source_integrity"] = {"status": "verified_unchanged"}
        with self.assertRaisesRegex(budget.InvalidEvidence, "claim lacks"):
            self.evaluate()

    def test_partial_source_artifact_trio_is_invalid(self):
        self.add_source_snapshots()
        for name in budget.SOURCE_ARTIFACTS[:-1]:
            (self.root / name).unlink()
            with self.assertRaisesRegex(budget.InvalidEvidence, "artifacts are incomplete"):
                self.evaluate()

    def test_source_manifest_self_hash_path_and_file_hash_validation(self):
        before, after, integrity = self.add_source_snapshots()
        cases = (
            ("claimed digest", lambda value: value.update(manifest_sha256="0" * 64)),
            ("malformed file hash", lambda value: value["files"][0].update(sha256="not-a-hash")),
            ("duplicate path", lambda value: value["files"].append(deepcopy(value["files"][0]))),
            ("unordered paths", lambda value: value["files"].reverse()),
            ("absolute path", lambda value: value["files"][0].update(path="/tmp/source.dart")),
            ("invalid size", lambda value: value["files"][0].update(bytes=True)),
            ("invalid revision", lambda value: value.update(revision="not-a-git-revision")),
        )
        for side in ("before", "after"):
            for name, mutate in cases:
                with self.subTest(side=side, defect=name):
                    original = deepcopy(before if side == "before" else after)
                    mutate(original)
                    self.write_source_snapshots(original if side == "before" else before,
                                                original if side == "after" else after, integrity)
                    with self.assertRaises(budget.InvalidEvidence):
                        self.evaluate()

    def test_changed_source_or_revision_cannot_use_forged_unchanged_comparison(self):
        before, after, integrity = self.add_source_snapshots()
        after["files"][0]["sha256"] = hashlib.sha256(b"changed").hexdigest()
        self.refresh_manifest(after)
        self.write_source_snapshots(before, after, integrity)
        with self.assertRaisesRegex(budget.InvalidEvidence, "source inputs changed"):
            self.evaluate()
        after = deepcopy(before)
        after["revision"] = "b" * 40
        self.write_source_snapshots(before, after, integrity)
        with self.assertRaisesRegex(budget.InvalidEvidence, "snapshot revisions disagree"):
            self.evaluate()
        after = deepcopy(before)
        self.report["revision"] = self.report["driver"]["source_revision"] = "c" * 40
        self.write_source_snapshots(before, after, integrity)
        with self.assertRaisesRegex(budget.InvalidEvidence, "snapshot revisions disagree"):
            self.evaluate()

    def test_recorded_source_comparison_must_match_recomputed_values_and_types(self):
        before, after, integrity = self.add_source_snapshots()
        for key, value in (("status", "invalid_source_changed"), ("before_file_count", 1),
                           ("revision_unchanged", 1), ("schema_version", True),
                           ("after_manifest_sha256", "0" * 64), ("changed_paths", ["lib/missing.dart"]),
                           ("source_worktree_status_unchanged", True)):
            with self.subTest(field=key):
                changed = {**integrity, key: value}
                self.write_source_snapshots(before, after, changed)
                with self.assertRaisesRegex(budget.InvalidEvidence, "source_integrity"):
                    self.evaluate()

    def test_embedded_source_integrity_cannot_contradict_valid_artifacts(self):
        self.add_source_snapshots()
        for claim in ({"status": "invalid_source_changed"},
                      {"status": "verified_unchanged", "before_revision": "b" * 40},
                      {"status": "verified_unchanged", "revision_unchanged": 1}):
            with self.subTest(claim=claim):
                self.report["source_integrity"] = claim
                with self.assertRaisesRegex(budget.InvalidEvidence, "report.source_integrity"):
                    self.evaluate()

    def test_missing_or_duplicated_round_actions_do_not_count_as_complete_measurement(self):
        steps = self.report["scenarios"][0]["interaction_steps"]
        last = steps.pop()
        with self.assertRaisesRegex(budget.InvalidEvidence, "rounds are incomplete"):
            self.evaluate()
        steps.append(last)
        steps.append(last)
        with self.assertRaisesRegex(budget.InvalidEvidence, "duplicate measured interaction"):
            self.evaluate()
        steps.pop()
        steps[-1]["wall_time_us"] = 500000
        with self.assertRaisesRegex(budget.InvalidEvidence, "exceed interaction wall"):
            self.evaluate()

    def test_each_round_requires_the_same_complete_ordered_step_sequence(self):
        scenario, _ = self.add_epoch_intervals()
        original = deepcopy(scenario["interaction_steps"])
        for mutation in ("missing", "reordered", "renamed"):
            with self.subTest(mutation=mutation):
                steps = deepcopy(original)
                if mutation == "missing":
                    del steps[3]
                elif mutation == "reordered":
                    steps[2], steps[3] = steps[3], steps[2]
                else:
                    steps[3]["name"] = "unrelated operation"
                scenario["interaction_steps"] = steps
                with self.assertRaisesRegex(budget.InvalidEvidence, "round step sequences disagree"):
                    self.evaluate()

    def test_native_environment_stability_matches_runtime_and_old_capture_is_unavailable(self):
        self.assertEqual(self.evaluate()["scenarios"][0]["native_environment_validation"]["status"],
                         "unavailable_pre_environment_monitor")
        self.add_native_environment()
        self.assertEqual(self.evaluate()["scenarios"][0]["native_environment_validation"]["status"],
                         "verified_stable")

    def test_native_environment_rejects_changes_nonresumed_frames_and_invalid_viewport(self):
        scenario, monitor = self.add_native_environment()
        original = deepcopy(monitor)
        cases = (
            ("status", lambda value: value.update(status="invalid_environment_changed")),
            ("changes", lambda value: value.update(changes=[{"phase": "lifecycle_callback"}])),
            ("inactive", lambda value: value["initial"].update(application_lifecycle_state="inactive")),
            ("frames disabled", lambda value: value["initial"].update(frames_enabled=False)),
            ("boolean type", lambda value: value["initial"].update(platform_semantics_enabled=0)),
            ("small viewport", lambda value: value["initial"]["native_view_logical_dp"].update(width=1119)),
            ("physical mismatch", lambda value: value["initial"]["native_view_physical_px"].update(width=3455)),
            ("final differs", lambda value: value["final"].update(platform_semantics_enabled=True)),
        )
        for name, mutate in cases:
            with self.subTest(defect=name):
                value = deepcopy(original)
                mutate(value)
                scenario["native_environment_during_measurement"] = value
                with self.assertRaises(budget.InvalidEvidence):
                    self.evaluate()

    def test_native_environment_rejects_contradictory_boundary_runtime_semantics(self):
        scenario, _ = self.add_native_environment()
        for key in ("runtime_before_measurement", "runtime_after_measurement"):
            original = deepcopy(scenario[key])
            for field, value in (("platform_semantics_enabled", True), ("framework_semantics_enabled", False),
                                 ("application_lifecycle_state", "inactive"), ("semantics_enabled", True),
                                 ("platform_semantics_enabled", 0), ("frames_enabled", False)):
                with self.subTest(runtime=key, field=field, value=value):
                    scenario[key] = {**original, field: value}
                    with self.assertRaises(budget.InvalidEvidence):
                        self.evaluate()
            scenario[key] = original

    def test_native_monitor_interval_must_cover_sampling_and_have_ordered_epochs(self):
        scenario, monitor = self.add_native_environment()
        original = deepcopy(monitor)
        for start, end in ((-1, original["end_epoch_us"]),
                           (original["end_epoch_us"], original["start_epoch_us"]),
                           (scenario["sampling_start_epoch_us"] + 1001, original["end_epoch_us"]),
                           (original["start_epoch_us"], scenario["sampling_end_epoch_us"] - 1001)):
            with self.subTest(start=start, end=end):
                scenario["native_environment_during_measurement"] = {
                    **original, "start_epoch_us": start, "end_epoch_us": end}
                with self.assertRaises(budget.InvalidEvidence):
                    self.evaluate()

    def test_slowest_frames_are_ranked_by_max_build_or_raster_and_cross_step_overlap(self):
        _, base = self.add_epoch_intervals()
        rows = self.frames["prompt_bar"]
        rows[-2].update(raster_us=4000, total_span_us=4600)
        rows[-1].update(build_us=2000, total_span_us=3000, raster_finish_epoch_us=base + 150500)
        self.update_frames()
        assessed = self.evaluate()["scenarios"][0]
        slow = assessed["slowest_frames"]
        self.assertEqual(len(slow), 10)
        self.assertEqual([row["frame_number"] for row in slow[:2]], [98, 99])
        self.assertEqual(slow[1]["frame_interval_start_epoch_us"], base + 147500)
        association = slow[1]["temporal_association"]
        self.assertEqual([(row["name"], row["overlap_duration_us"])
                          for row in association["overlapping_steps"]], [("first", 2500), ("second", 500)])
        self.assertEqual([row["round"] for row in association["overlapping_rounds"]], [0])
        self.assertFalse(association["cpu_causality_established"])

    def test_one_frame_may_overlap_two_real_rounds(self):
        _, base = self.add_epoch_intervals()
        self.frames["prompt_bar"][-1].update(build_us=2000, total_span_us=3000,
                                             raster_finish_epoch_us=base + 300500)
        self.update_frames()
        association = self.evaluate()["scenarios"][0]["slowest_frames"][0]["temporal_association"]
        self.assertEqual([(row["round"], row["name"], row["overlap_duration_us"])
                          for row in association["overlapping_steps"]], [(0, "second", 2500), (1, "first", 500)])
        self.assertEqual([row["round"] for row in association["overlapping_rounds"]], [0, 1])

    def test_old_capture_has_no_inferred_step_or_round_timestamps(self):
        assessed = self.evaluate()["scenarios"][0]
        validation = assessed["epoch_interval_validation"]
        self.assertEqual(validation["steps"], "unavailable_pre_epoch_capture")
        self.assertEqual(validation["rounds"], "unavailable_pre_epoch_capture")
        for frame in assessed["slowest_frames"]:
            association = frame["temporal_association"]
            self.assertEqual(association["steps_status"], "unavailable_pre_epoch_capture")
            self.assertEqual(association["overlapping_steps"], [])
            self.assertEqual(association["overlapping_rounds"], [])

    def test_small_boundary_clock_gaps_are_recorded_without_changing_budget(self):
        scenario, base = self.add_epoch_intervals()
        scenario["interaction_steps"][-1]["end_epoch_us"] = base + 900070
        scenario["interaction_rounds"][-1]["end_epoch_us"] = base + 900080
        result = self.evaluate()
        self.assertEqual(result["status"], "pass")
        validation = result["scenarios"][0]["epoch_interval_validation"]
        self.assertTrue(validation["association_uses_original_intervals_without_tolerance"])
        self.assertEqual(sorted(gap["after_end_us"] for gap in validation["tolerated_boundary_gaps"]), [20, 30])

    def test_association_does_not_expand_interval_using_validation_tolerance(self):
        scenario, base = self.add_epoch_intervals()
        scenario["interaction_steps"][1]["start_epoch_us"] = base + 150600
        self.frames["prompt_bar"][-1].update(build_us=2000, total_span_us=3000,
                                             raster_finish_epoch_us=base + 150500)
        self.update_frames()
        association = self.evaluate()["scenarios"][0]["slowest_frames"][0]["temporal_association"]
        self.assertEqual([row["name"] for row in association["overlapping_steps"]], ["first"])

    def test_reversed_partial_and_outside_epoch_intervals_are_invalid(self):
        scenario, base = self.add_epoch_intervals()
        original = deepcopy(scenario)
        scenario["interaction_steps"][0]["end_epoch_us"] = base - 1
        with self.assertRaisesRegex(budget.InvalidEvidence, "end_epoch_us"):
            self.evaluate()
        self.report["scenarios"][0] = scenario = deepcopy(original)
        del scenario["interaction_steps"][0]["end_epoch_us"]
        with self.assertRaisesRegex(budget.InvalidEvidence, "end_epoch_us"):
            self.evaluate()
        self.report["scenarios"][0] = scenario = deepcopy(original)
        scenario["interaction_steps"][-1]["end_epoch_us"] = base + 901051
        with self.assertRaisesRegex(budget.InvalidEvidence, "outside its containing epoch"):
            self.evaluate()

    def test_round_epoch_membership_duplicates_and_order_are_validated(self):
        scenario, base = self.add_epoch_intervals()
        original = deepcopy(scenario)
        scenario["interaction_rounds"][0]["end_epoch_us"] = base + 150000
        with self.assertRaisesRegex(budget.InvalidEvidence, "in its declared round"):
            self.evaluate()
        self.report["scenarios"][0] = scenario = deepcopy(original)
        scenario["interaction_rounds"][1]["round"] = 0
        with self.assertRaisesRegex(budget.InvalidEvidence, "round epoch identifiers"):
            self.evaluate()
        self.report["scenarios"][0] = scenario = deepcopy(original)
        scenario["interaction_steps"][1]["start_epoch_us"] = base + 148999
        with self.assertRaisesRegex(budget.InvalidEvidence, "overlap out of order"):
            self.evaluate()

    def test_cli_does_not_overwrite_input_or_budget(self):
        report_path = self.save()
        original = report_path.read_bytes()
        command = [sys.executable, str(CLI), str(self.root), "--output", str(report_path)]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("overwrite source evidence", json.loads(result.stdout)["error"])
        self.assertEqual(report_path.read_bytes(), original)

    def test_cli_does_not_overwrite_invalid_source_integrity_evidence(self):
        self.add_source_snapshots()
        self.save()
        path = self.root / "source_integrity.json"
        path.write_text('{"status":"invalid_source_changed"}')
        original = path.read_bytes()
        result = subprocess.run([sys.executable, str(CLI), str(self.root), "--output", str(path)],
                                capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("overwrite source evidence", json.loads(result.stdout)["error"])
        self.assertEqual(path.read_bytes(), original)

    def test_cli_exit_codes_and_output_match(self):
        output = self.root / "assessment.json"
        self.save()
        command = [sys.executable, str(CLI), str(self.root), "--output", str(output)]
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout), json.loads(output.read_text()))
        self.change_builds([25000])
        self.save()
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(json.loads(result.stdout)["status"], "budget_fail")
        self.report["final_script_exit_code"] = 1
        self.save()
        result = subprocess.run(command, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout)["status"], "invalid_evidence")


if __name__ == "__main__":
    unittest.main()
