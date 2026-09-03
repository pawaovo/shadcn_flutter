#!/usr/bin/env python3
"""Recompute an explicit engineering budget from native FrameTiming/RSS evidence.

Exit 0: observed-run engineering gates pass; 1: a budget is exceeded;
2: invalid/incomplete evidence. No outcome grants all-platform release acceptance.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
import zlib


P3_IDS = (
    "prompt_bar", "diff_table", "records_table", "sidebar_nav", "flowchart",
    "insight_cards", "selection_actions",
)
P1P2_IDS = (
    "search_long_catalog", "code_block_long_source", "thinking_long_trace",
    "streaming_long_answer", "tool_chips_large_output", "chat_long_transcript",
    "filter_table_large_dataset", "task_rows_large_workflow",
)
SUITES = {"p3": P3_IDS, "p1p2": P1P2_IDS, "all": P3_IDS + P1P2_IDS}
SUITE_NAMES = {
    "beautiful_ai_ui_p3_native_profile": "p3",
    "beautiful_ai_ui_p1p2_native_profile": "p1p2",
    "beautiful_ai_ui_all_native_profile": "all",
}
METRICS = ("build_us", "raster_us", "total_span_us", "vsync_overhead_us")
SOURCE_ARTIFACTS = ("source_before.json", "source_after.json", "source_integrity.json")
SNAPSHOT_SPEC = importlib.util.spec_from_file_location(
    "profile_source_snapshot", Path(__file__).with_name("profile_source_snapshot.py"))
source_snapshot = importlib.util.module_from_spec(SNAPSHOT_SPEC)
SNAPSHOT_SPEC.loader.exec_module(source_snapshot)
# Independent DateTime/Stopwatch reads and final bookkeeping can differ by a
# few microseconds. This validation tolerance never changes budget thresholds
# or the original intervals used to associate frames with recorded actions.
EPOCH_BOUNDARY_TOLERANCE_US = 1000
DEFAULT_BUDGET = (
    Path(__file__).resolve().parents[3]
    / "docs/beautiful-ui/quality_evidence/performance/engineering_budget_v1.json"
)


class InvalidEvidence(ValueError):
    """Evidence is absent, contradictory or insufficient for assessment."""


def require(condition, message):
    if not condition:
        raise InvalidEvidence(message)


def integer(value, label, minimum=0):
    require(type(value) is int and value >= minimum,
            f"{label} must be an integer >= {minimum}")
    return value


def number(value, label, minimum=0, positive=False):
    require(type(value) in (int, float) and math.isfinite(value),
            f"{label} must be a finite number")
    require(value > minimum if positive else value >= minimum,
            f"{label} is outside its allowed range")
    return value


def object_value(value, label):
    require(isinstance(value, dict), f"{label} must be an object")
    return value


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def decode_json(blob, label):
    try:
        return json.loads(
            blob, object_pairs_hook=unique_object,
            parse_constant=lambda value: (_ for _ in ()).throw(
                InvalidEvidence(f"{label}: invalid JSON number {value}")),
        )
    except (UnicodeError, json.JSONDecodeError) as error:
        raise InvalidEvidence(f"{label}: {error}") from error


def load_json(path, evidence):
    blob = path.read_bytes()
    evidence[str(path)] = {"bytes": len(blob), "sha256": hashlib.sha256(blob).hexdigest()}
    if path.suffix == ".gz":
        blob = gzip.decompress(blob)
    return decode_json(blob, str(path))


def load_array_file(root, stem, evidence):
    paths = [root / f"{stem}.json", root / f"{stem}.json.gz"]
    existing = [path for path in paths if path.is_file()]
    require(bool(existing), f"missing {stem}.json[.gz]")
    values = [load_json(path, evidence) for path in existing]
    require(all(value == values[0] for value in values[1:]),
            f"conflicting compressed and uncompressed {stem}")
    return object_value(values[0], stem)


def distribution(values):
    ordered = sorted(values)
    n = len(ordered)
    result = {"sample_count": n, "min": ordered[0], "max": ordered[-1],
              "mean": sum(ordered) / n, "percentile_method": "nearest rank"}
    for percentile in (50, 90, 95, 99):
        result[f"p{percentile}"] = ordered[(n * percentile + 99) // 100 - 1]
    return result


def validate_budget(budget):
    object_value(budget, "budget")
    require(type(budget.get("schema_version")) is int and budget["schema_version"] == 1,
            "unsupported budget schema")
    require(budget.get("approval_status") == "engineering_default_not_product_approved",
            "budget must explicitly identify its unapproved engineering scope")
    require(budget.get("all_platform_release_accepted") is False,
            "budget cannot grant all-platform release acceptance")
    frame = object_value(budget.get("frame_budget"), "frame_budget")
    for key in (
        "build_p95_max_frame_intervals", "raster_p95_max_frame_intervals",
        "build_max_frame_intervals", "raster_max_frame_intervals",
        "total_span_p95_max_frame_intervals",
    ):
        number(frame.get(key), f"frame_budget.{key}", positive=True)
    ratio = number(frame.get("build_or_raster_over_interval_max_fraction"),
                   "frame_budget.build_or_raster_over_interval_max_fraction")
    require(ratio <= 1, "over-budget fraction must be <= 1")
    memory = object_value(budget.get("measured_process_rss"), "measured_process_rss")
    integer(memory.get("sample_peak_max_bytes"), "sample_peak_max_bytes", 1)
    integer(memory.get("positive_end_minus_start_max_bytes"),
            "positive_end_minus_start_max_bytes")
    rules = object_value(budget.get("evidence_requirements"), "evidence_requirements")
    for key in ("minimum_warmup_rounds", "minimum_measured_rounds",
                "minimum_frame_samples_per_scenario", "minimum_rss_samples_per_scenario"):
        integer(rules.get(key), f"evidence_requirements.{key}", 1)


def runtime_values(runtime, label):
    object_value(runtime, label)
    require(runtime.get("build_mode") == "profile", f"{label} is not a profile build")
    hz = number(runtime.get("display_refresh_rate_hz"), f"{label}.refresh_rate", positive=True)
    ratio = number(runtime.get("device_pixel_ratio"), f"{label}.device_pixel_ratio", positive=True)
    viewport = object_value(runtime.get("native_view_logical_dp"), f"{label}.viewport")
    width = number(viewport.get("width"), f"{label}.viewport.width", positive=True)
    height = number(viewport.get("height"), f"{label}.viewport.height", positive=True)
    return hz, ratio, width, height


def validate_exit_codes(report, root, compact, evidence):
    require(type(report.get("integration_driver_exit_code")) is int
            and report["integration_driver_exit_code"] == 0,
            "integration driver must have a recorded exit code of 0")
    final = report.get("final_script_exit_code")
    if final is not None:
        require(type(final) is int and final == 0, "final script did not exit 0")
    elif compact:
        raise InvalidEvidence("compact summary lacks final_script_exit_code")
    for name in ("driver_exit_code.txt", "exit_code.txt"):
        path = root / name
        if path.is_file():
            blob = path.read_bytes()
            evidence[str(path)] = {"bytes": len(blob), "sha256": hashlib.sha256(blob).hexdigest()}
            require(blob.strip() == b"0", f"{name} is not 0")
            if name == "exit_code.txt":
                final = 0
    require(final == 0, "final script success is missing; workload completion alone is insufficient")


def infer_suite(report, scenario_ids, requested):
    declared = report.get("suite")
    if declared is not None:
        require(declared in SUITE_NAMES, f"unsupported suite: {declared}")
        suite = SUITE_NAMES[declared]
    else:
        matches = [name for name, ids in SUITES.items() if set(ids) == set(scenario_ids)]
        require(len(matches) == 1, "cannot infer a complete known suite")
        suite = matches[0]
    driver = report.get("driver", {})
    object_value(driver, "driver")
    for extra in (driver.get("performance_suite"), report.get("performance_suite")):
        if extra is not None:
            require(extra == suite, "driver and report suite disagree")
    if requested:
        require(requested == suite, f"requested {requested}, evidence identifies {suite}")
    require(set(scenario_ids) == set(SUITES[suite]),
            f"suite {suite} has missing or unexpected scenarios")
    return suite


def source_revision(report):
    driver = object_value(report.get("driver", {}), "driver")
    revisions = [value for value in (
        report.get("revision"), report.get("source_revision"), driver.get("source_revision"),
    ) if value is not None]
    for revision in revisions:
        require(isinstance(revision, str) and bool(revision.strip()), "source revision is invalid")
    require(not revisions or all(value == revisions[0] for value in revisions),
            "source revisions disagree between report and driver")
    return revisions[0] if revisions else None


def validate_source_snapshot(snapshot, label):
    object_value(snapshot, label)
    require(type(snapshot.get("schema_version")) is int and snapshot["schema_version"] == 1,
            f"{label}: unsupported source snapshot schema")
    require(snapshot.get("manifest_algorithm") == source_snapshot.ALGORITHM,
            f"{label}: unsupported source manifest algorithm")
    revision = snapshot.get("revision")
    require(isinstance(revision, str) and len(revision) in (40, 64)
            and all(char in "0123456789abcdef" for char in revision),
            f"{label}: source revision must be a full Git object ID")
    require(isinstance(snapshot.get("source_worktree_status"), str),
            f"{label}: source worktree status is missing")
    files = snapshot.get("files")
    require(isinstance(files, list) and bool(files), f"{label}: source files are missing")
    for row in files:
        object_value(row, f"{label}.file")
        name = row.get("path")
        require(isinstance(name, str) and bool(name) and not name.startswith("/")
                and all(part not in ("", ".", "..") for part in name.split("/"))
                and "\0" not in name and "\n" not in name,
                f"{label}: invalid source file path")
        digest = row.get("sha256")
        require(isinstance(digest, str) and len(digest) == 64
                and all(char in "0123456789abcdef" for char in digest),
                f"{label}: invalid source file SHA-256")
        integer(row.get("bytes"), f"{label}.{name}.bytes")
    paths = [row["path"] for row in files]
    require(paths == sorted(set(paths)), f"{label}: source paths are duplicated or unordered")
    digest = snapshot.get("manifest_sha256")
    require(isinstance(digest, str) and len(digest) == 64
            and all(char in "0123456789abcdef" for char in digest),
            f"{label}: invalid source manifest SHA-256")
    try:
        source_snapshot.validate(snapshot)
    except ValueError as error:
        raise InvalidEvidence(f"{label}: source manifest SHA-256 disagrees with its contents") from error


def validate_source_integrity(report, root, evidence):
    revision = source_revision(report)
    paths = [root / name for name in SOURCE_ARTIFACTS]
    if not any(path.exists() or path.is_symlink() for path in paths):
        require(report.get("source_integrity") is None,
                "source integrity claim lacks its source snapshot artifacts")
        return revision, {
            "status": "unavailable_pre_snapshot_capture",
            "scope_note": "No before/after source snapshots are available; the reported revision is not independently verified by this assessment.",
        }
    require(all(path.is_file() for path in paths), "source snapshot artifacts are incomplete")
    before, after, recorded = [load_json(path, evidence) for path in paths]
    validate_source_snapshot(before, "source_before")
    validate_source_snapshot(after, "source_after")
    object_value(recorded, "source_integrity")
    require(revision is not None, "source snapshots require a report source revision")
    require(before["revision"] == after["revision"] == revision,
            "source snapshot revisions disagree with each other or the report")
    recomputed = source_snapshot.comparison(before, after)
    require(recomputed["status"] == "verified_unchanged",
            "source inputs changed between before and after snapshots")
    verified = {key: value for key, value in recomputed.items() if key != "scope_note"}
    for key, expected in verified.items():
        require(type(recorded.get(key)) is type(expected) and recorded[key] == expected,
                f"source_integrity.{key} disagrees with the source snapshots")
    if report.get("source_integrity") is not None:
        claim = object_value(report["source_integrity"], "report.source_integrity")
        require(claim.get("status") == verified["status"],
                "report.source_integrity.status disagrees with the source snapshots")
        for key, expected in verified.items():
            if key in claim:
                require(type(claim[key]) is type(expected) and claim[key] == expected,
                        f"report.source_integrity.{key} disagrees with the source snapshots")
    return revision, {
        **verified,
        "scope_note": "Recomputed from the recorded source manifests. Listed input hashes and git revision are unchanged; this does not claim a clean worktree or rehash unavailable historical source contents.",
    }


def validate_native_environment(sc):
    label = sc["id"]
    if "native_environment_during_measurement" not in sc:
        return {"status": "unavailable_pre_environment_monitor"}
    monitor = object_value(sc["native_environment_during_measurement"], f"{label}.native_environment")
    require(monitor.get("status") == "verified_stable", f"{label}: native environment is not verified stable")
    require(monitor.get("changes") == [], f"{label}: native environment records changes")
    begin = integer(monitor.get("start_epoch_us"), f"{label}.native_environment.start_epoch_us", 1)
    finish = integer(monitor.get("end_epoch_us"), f"{label}.native_environment.end_epoch_us", begin + 1)
    sampling_start = integer(sc.get("sampling_start_epoch_us"), f"{label}.sampling_start_epoch_us", 1)
    sampling_end = integer(sc.get("sampling_end_epoch_us"), f"{label}.sampling_end_epoch_us", sampling_start + 1)
    tolerance = EPOCH_BOUNDARY_TOLERANCE_US
    require(begin <= sampling_start + tolerance and finish + tolerance >= sampling_end,
            f"{label}: native environment monitor does not cover the sampling window")
    initial = object_value(monitor.get("initial"), f"{label}.native_environment.initial")
    final = object_value(monitor.get("final"), f"{label}.native_environment.final")
    for name, state in (("initial", initial), ("final", final)):
        require(state.get("application_lifecycle_state") == "resumed"
                and state.get("frames_enabled") is True,
                f"{label}: native environment {name} is not resumed with frames enabled")
        for key in ("platform_semantics_enabled", "framework_semantics_enabled"):
            require(type(state.get(key)) is bool, f"{label}: native environment {key} must be boolean")
        ratio = number(state.get("device_pixel_ratio"), f"{label}.native_environment.pixel_ratio", positive=True)
        logical = object_value(state.get("native_view_logical_dp"), f"{label}.native_environment.logical_view")
        physical = object_value(state.get("native_view_physical_px"), f"{label}.native_environment.physical_view")
        for axis, minimum in (("width", 1120), ("height", 720)):
            logical_size = number(logical.get(axis), f"{label}.native_environment.logical.{axis}", minimum)
            physical_size = number(physical.get(axis), f"{label}.native_environment.physical.{axis}", positive=True)
            require(math.isclose(physical_size / ratio, logical_size, rel_tol=1e-12, abs_tol=1e-9),
                    f"{label}: native environment physical and logical viewport disagree")
    require(initial == final, f"{label}: native environment initial and final values disagree")
    for key in ("runtime_before_measurement", "runtime_after_measurement"):
        runtime = object_value(sc.get(key), f"{label}.{key}")
        for field in ("native_view_physical_px", "native_view_logical_dp", "device_pixel_ratio",
                      "application_lifecycle_state", "platform_semantics_enabled", "framework_semantics_enabled"):
            actual = runtime.get(field)
            if field.endswith("semantics_enabled"):
                require(type(actual) is bool, f"{label}: {key}.{field} must be boolean")
            if field == "native_view_physical_px":
                object_value(actual, f"{label}.{key}.{field}")
                for axis in ("width", "height"):
                    number(actual.get(axis), f"{label}.{key}.{field}.{axis}", positive=True)
            require(actual == initial[field], f"{label}: native environment contradicts {key}.{field}")
        if "semantics_enabled" in runtime:
            require(type(runtime["semantics_enabled"]) is bool
                    and runtime["semantics_enabled"] == initial["platform_semantics_enabled"],
                    f"{label}: native environment contradicts {key}.semantics_enabled")
        if "frames_enabled" in runtime:
            require(runtime["frames_enabled"] is True,
                    f"{label}: native environment contradicts {key}.frames_enabled")
    return {"status": "verified_stable", "initial": initial, "final": final, "changes": [],
            "start_epoch_us": begin, "end_epoch_us": finish,
            "sampling_boundary_tolerance_us": tolerance}


def validate_epoch_intervals(sc, steps, sampling_start, sampling_end):
    """Validate optional newer epoch evidence without inventing old timestamps."""
    label = sc["id"]
    tolerance = EPOCH_BOUNDARY_TOLERANCE_US
    gaps = []

    def bounded(inner_start, inner_end, outer_start, outer_end, name):
        before = max(0, outer_start - inner_start)
        after = max(0, inner_end - outer_end)
        require(before <= tolerance and after <= tolerance,
                f"{label}: {name} falls outside its containing epoch interval")
        if before or after:
            gaps.append({"interval": name, "before_start_us": before, "after_end_us": after})

    def read_interval(row, name):
        begin = integer(row.get("start_epoch_us"), f"{label}.{name}.start_epoch_us", 1)
        finish = integer(row.get("end_epoch_us"), f"{label}.{name}.end_epoch_us", begin + 1)
        require(sampling_start is not None, f"{label}: epoch intervals require the sampling window")
        bounded(begin, finish, sampling_start, sampling_end, name)
        return begin, finish

    steps_have_epoch = ["start_epoch_us" in row or "end_epoch_us" in row for row in steps]
    require(not any(steps_have_epoch) or all(steps_have_epoch),
            f"{label}: step epoch evidence is only partially recorded")
    timed_steps = []
    if all(steps_have_epoch):
        previous_end = None
        previous_round = -1
        for step in steps:
            name = f"step[{step['round']}:{step['name']}]"
            begin, finish = read_interval(step, name)
            require(step["round"] >= previous_round, f"{label}: epoch steps are out of round order")
            if previous_end is not None:
                require(begin + tolerance >= previous_end, f"{label}: measured step epoch intervals overlap out of order")
                if begin < previous_end:
                    gaps.append({"interval": name, "previous_end_overlap_us": previous_end - begin})
            timed_steps.append({"round": step["round"], "name": step["name"],
                                "start_epoch_us": begin, "end_epoch_us": finish})
            previous_end, previous_round = finish, step["round"]

    timed_rounds = []
    rounds = sc.get("interaction_rounds")
    if rounds is not None:
        require(isinstance(rounds, list) and len(rounds) == sc["measured_rounds"],
                f"{label}: interaction round epoch intervals are incomplete")
        previous_end = None
        for expected, row in enumerate(rounds):
            object_value(row, f"{label}.interaction_round")
            require(integer(row.get("round"), f"{label}.interaction_round.round") == expected,
                    f"{label}: round epoch identifiers are duplicated, missing or unordered")
            begin, finish = read_interval(row, f"round[{expected}]")
            if previous_end is not None:
                require(begin + tolerance >= previous_end, f"{label}: measured round epoch intervals overlap out of order")
                if begin < previous_end:
                    gaps.append({"interval": f"round[{expected}]", "previous_end_overlap_us": previous_end - begin})
            timed_rounds.append({"round": expected, "start_epoch_us": begin, "end_epoch_us": finish})
            previous_end = finish
        by_round = {row["round"]: row for row in timed_rounds}
        for step in timed_steps:
            containing = by_round[step["round"]]
            bounded(step["start_epoch_us"], step["end_epoch_us"],
                    containing["start_epoch_us"], containing["end_epoch_us"],
                    f"step[{step['round']}:{step['name']}] in its declared round")

    return timed_steps, timed_rounds, {
        "steps": "verified" if timed_steps else "unavailable_pre_epoch_capture",
        "rounds": "verified" if timed_rounds else "unavailable_pre_epoch_capture",
        "boundary_validation_tolerance_us": tolerance,
        "tolerated_boundary_gaps": gaps,
        "association_uses_original_intervals_without_tolerance": True,
    }


def associate_frame_intervals(frames, steps, rounds):
    """Return temporal intersections; their presence is not CPU attribution."""
    results = []
    for frame in sorted(frames, key=lambda row: (
        max(row["build_us"], row["raster_us"]), row["build_us"], row["raster_us"],
    ), reverse=True)[:10]:
        finish = frame["raster_finish_epoch_us"]
        begin = finish - frame["total_span_us"]

        def intersections(intervals):
            overlaps = []
            for interval in intervals:
                left = max(begin, interval["start_epoch_us"])
                right = min(finish, interval["end_epoch_us"])
                if left <= right:
                    overlaps.append({**interval, "overlap_start_epoch_us": left,
                                     "overlap_end_epoch_us": right, "overlap_duration_us": right - left})
            return overlaps

        step_overlaps, round_overlaps = intersections(steps), intersections(rounds)
        results.append({
            **frame, "sort_duration_us": max(frame["build_us"], frame["raster_us"]),
            "frame_interval_start_epoch_us": begin, "frame_interval_end_epoch_us": finish,
            "temporal_association": {
                "steps_status": "available" if steps else "unavailable_pre_epoch_capture",
                "rounds_status": "available" if rounds else "unavailable_pre_epoch_capture",
                "overlapping_steps": step_overlaps, "overlapping_rounds": round_overlaps,
                "cpu_causality_established": False,
            },
        })
    return results


def assess_scenario(sc, frames, memory, runtime, budget, globally_seen):
    label = sc["id"]
    require(sc.get("status") == "complete", f"{label}: workload is not complete")
    environment_validation = validate_native_environment(sc)
    rules = budget["evidence_requirements"]
    integer(sc.get("warmup_rounds"), f"{label}.warmup_rounds", rules["minimum_warmup_rounds"])
    integer(sc.get("measured_rounds"), f"{label}.measured_rounds", rules["minimum_measured_rounds"])
    require(isinstance(frames, list) and len(frames) >= rules["minimum_frame_samples_per_scenario"],
            f"{label}: insufficient FrameTiming samples")
    require(isinstance(memory, list) and len(memory) >= rules["minimum_rss_samples_per_scenario"],
            f"{label}: insufficient RSS samples")
    runtime_key = runtime_values(runtime, "runtime")
    for key in ("runtime", "runtime_before_measurement", "runtime_after_measurement"):
        if key in sc:
            require(runtime_values(sc[key], f"{label}.{key}") == runtime_key,
                    f"{label}: native viewport, DPR, refresh rate or build mode changed")
    if "native_view_logical_dp" in sc:
        require(sc["native_view_logical_dp"] == runtime["native_view_logical_dp"],
                f"{label}: compact scenario viewport contradicts runtime")
    hz = runtime_key[0]
    wall = integer(sc.get("interaction_wall_time_us"), f"{label}.interaction_wall_time_us", 1)
    steps = sc.get("interaction_steps")
    require(isinstance(steps, list) and bool(steps), f"{label}: measured interaction steps are missing")
    observed_rounds = set()
    names_by_round = {}
    step_keys = set()
    step_wall_sum = 0
    for step in steps:
        object_value(step, f"{label}.interaction_step")
        round_index = integer(step.get("round"), f"{label}.interaction_step.round")
        name = step.get("name")
        require(isinstance(name, str) and bool(name.strip()), f"{label}: interaction name is missing")
        require((round_index, name) not in step_keys, f"{label}: duplicate measured interaction step")
        step_keys.add((round_index, name))
        observed_rounds.add(round_index)
        names_by_round.setdefault(round_index, []).append(name)
        step_wall_sum += integer(step.get("wall_time_us"), f"{label}.interaction_step.wall_time_us", 1)
    require(observed_rounds == set(range(sc["measured_rounds"])),
            f"{label}: recorded interaction rounds are incomplete or unexpected")
    require(all(names_by_round[index] == names_by_round[0]
                for index in range(sc["measured_rounds"])),
            f"{label}: measured round step sequences disagree")
    require(step_wall_sum <= wall, f"{label}: recorded step durations exceed interaction wall duration")
    selected = integer(sc.get("sampled_frame_count"), f"{label}.sampled_frame_count", 1)
    received = integer(sc.get("received_frame_count"), f"{label}.received_frame_count", 1)
    excluded = integer(sc.get("excluded_outside_window_frame_count"), f"{label}.excluded_frames")
    require(selected == len(frames) and received == selected + excluded,
            f"{label}: FrameTiming count accounting disagrees")
    start = sc.get("sampling_start_epoch_us")
    end = sc.get("sampling_end_epoch_us")
    require((start is None) == (end is None), f"{label}: incomplete sampling window")
    if start is not None:
        integer(start, f"{label}.sampling_start_epoch_us", 1)
        integer(end, f"{label}.sampling_end_epoch_us", start + 1)
    timed_steps, timed_rounds, epoch_validation = validate_epoch_intervals(sc, steps, start, end)
    previous_frame = previous_epoch = -1
    for frame in frames:
        object_value(frame, f"{label}.frame")
        frame_id = integer(frame.get("frame_number"), f"{label}.frame_number")
        epoch = integer(frame.get("raster_finish_epoch_us"), f"{label}.raster_finish_epoch_us", 1)
        require(frame_id > previous_frame and epoch > previous_epoch,
                f"{label}: frame identifiers or timestamps are duplicated/unordered")
        require(frame_id not in globally_seen, f"{label}: frame reused across scenarios")
        globally_seen.add(frame_id)
        previous_frame, previous_epoch = frame_id, epoch
        for metric in METRICS:
            integer(frame.get(metric), f"{label}.{metric}")
        require(frame["total_span_us"] > 0 and frame["total_span_us"]
                >= frame["build_us"] + frame["raster_us"] + frame["vsync_overhead_us"],
                f"{label}: contradictory frame durations")
        if start is not None:
            require(start <= epoch <= end, f"{label}: frame falls outside sampling window")
    stats = {metric: distribution([row[metric] for row in frames]) for metric in METRICS}
    recorded = object_value(sc.get("frame_timing_summary_us"), f"{label}.frame_timing_summary_us")
    for metric, values in stats.items():
        stored = object_value(recorded.get(metric), f"{label}.summary.{metric}")
        for key, value in values.items():
            actual = stored.get(key)
            if key == "mean":
                number(actual, f"{label}.summary.{metric}.{key}")
                valid = math.isclose(actual, value, rel_tol=1e-12, abs_tol=1e-9)
            elif key == "percentile_method":
                valid = actual == value
            else:
                valid = type(actual) is int and actual == value
            require(valid, f"{label}: reported {metric}.{key} disagrees with raw samples")
    require(integer(sc.get("rss_sample_count"), f"{label}.rss_sample_count", 1) == len(memory),
            f"{label}: RSS count disagrees")
    elapsed = []
    rss = []
    lifetime = []
    for index, row in enumerate(memory):
        object_value(row, f"{label}.rss_sample")
        expected_phase = "before_interactions" if index == 0 else (
            "after_interactions" if index == len(memory) - 1 else "during_interactions")
        require(row.get("phase") == expected_phase, f"{label}: RSS phase boundaries are invalid")
        elapsed.append(integer(row.get("elapsed_us"), f"{label}.rss.elapsed_us"))
        rss.append(integer(row.get("current_rss_bytes"), f"{label}.rss.current_rss_bytes", 1))
        lifetime.append(integer(row.get("process_lifetime_max_rss_bytes"),
                                f"{label}.rss.process_lifetime_max_rss_bytes", 1))
        require(lifetime[-1] >= rss[-1], f"{label}: lifetime RSS peak is below current RSS")
    require(all(left < right for left, right in zip(elapsed, elapsed[1:])),
            f"{label}: RSS timestamps are duplicated/unordered")
    require(all(left <= right for left, right in zip(lifetime, lifetime[1:])),
            f"{label}: process lifetime RSS peak decreases")
    interval_ms = integer(sc.get("memory_sample_interval_ms", 100), f"{label}.memory_sample_interval_ms", 1)
    require(elapsed[0] <= interval_ms * 1000 and 0 <= wall - elapsed[-1] <= interval_ms * 1000,
            f"{label}: RSS samples do not span measured interactions")
    require(integer(sc.get("rss_observed_peak_bytes"), f"{label}.rss_observed_peak_bytes", 1) == max(rss),
            f"{label}: recorded RSS peak disagrees with raw samples")
    lifecycle = {}
    for key in ("rss_before_fixture", "rss_after_fixture", "rss_after_mount",
                "rss_after_workload", "rss_after_unmount"):
        if key in sc:
            snapshot = object_value(sc[key], f"{label}.{key}")
            current = integer(snapshot.get("current_rss_bytes"), f"{label}.{key}.current_rss_bytes", 1)
            peak = integer(snapshot.get("process_lifetime_max_rss_bytes"),
                           f"{label}.{key}.process_lifetime_max_rss_bytes", current)
            lifecycle[key] = {"current_rss_bytes": current, "process_lifetime_max_rss_bytes": peak}
    gates = []

    def gate(name, observed, limit):
        gates.append({"name": name, "observed": observed, "maximum": limit, "passed": observed <= limit})

    limits = budget["frame_budget"]
    for metric in ("build", "raster"):
        for stat in ("p95", "max"):
            limit_key = f"{metric}_max_frame_intervals" if stat == "max" else f"{metric}_p95_max_frame_intervals"
            gate(f"{metric}_{stat}_us", stats[f"{metric}_us"][stat],
                 limits[limit_key] * 1_000_000 / hz)
    over_count = sum(max(row["build_us"], row["raster_us"]) * hz > 1_000_000 for row in frames)
    gate("build_or_raster_over_interval_fraction", over_count / len(frames),
         limits["build_or_raster_over_interval_max_fraction"])
    gate("total_span_p95_us", stats["total_span_us"]["p95"],
         limits["total_span_p95_max_frame_intervals"] * 1_000_000 / hz)
    memory_limits = budget["measured_process_rss"]
    gate("measured_process_rss_sample_peak_bytes", max(rss), memory_limits["sample_peak_max_bytes"])
    gate("measured_process_rss_positive_end_minus_start_bytes", max(0, rss[-1] - rss[0]),
         memory_limits["positive_end_minus_start_max_bytes"])
    exceedance = {}
    for rate_name, rate in (("observed_refresh_rate", hz), ("reference_60_hz", 60)):
        exceedance[rate_name] = {"refresh_rate_hz": rate, "frame_interval_us": 1_000_000 / rate,
                                 "reference_only": rate_name == "reference_60_hz"}
        for metric in METRICS:
            count = sum(row[metric] * rate > 1_000_000 for row in frames)
            exceedance[rate_name][metric] = {"count": count, "fraction": count / len(frames)}
    gaps = [right - left for left, right in zip(elapsed, elapsed[1:])]
    return {
        "id": label, "status": "pass" if all(item["passed"] for item in gates) else "budget_fail",
        "frame_samples": len(frames), "rss_samples": len(memory),
        "warmup_rounds": sc["warmup_rounds"], "measured_rounds": sc["measured_rounds"],
        "display_refresh_rate_hz": hz, "frame_interval_us": 1_000_000 / hz,
        "sampling_window_validation": "verified" if start is not None else "unavailable_in_compact_summary",
        "epoch_interval_validation": epoch_validation,
        "native_environment_validation": environment_validation,
        "frame_timing_summary_us": stats, "interval_exceedances": exceedance,
        "largest_build_frames": sorted(frames, key=lambda row: row["build_us"], reverse=True)[:10],
        "largest_raster_frames": sorted(frames, key=lambda row: row["raster_us"], reverse=True)[:10],
        "slowest_frame_association_note": "Top 10 ordered by max(build_us, raster_us). Closed frame intervals [raster_finish_epoch_us - total_span_us, raster_finish_epoch_us] are intersected with original recorded step and round intervals. Temporal overlap includes scheduling and pipelining; it does not establish CPU causality. No cumulative-duration timestamp inference is used.",
        "slowest_frames": associate_frame_intervals(frames, timed_steps, timed_rounds),
        "build_or_raster_over_interval_count": over_count,
        "measured_process_rss": {
            "start_bytes": rss[0], "end_bytes": rss[-1], "signed_end_minus_start_bytes": rss[-1] - rss[0],
            "sample_peak_bytes": max(rss), "process_lifetime_max_at_last_sample_bytes": lifetime[-1],
            "maximum_sample_gap_us": max(gaps), "nominal_sample_interval_ms": interval_ms,
            "component_memory_assessment": "unassessed", "leak_assessment": "unassessed",
            "lifecycle_snapshots_outside_measured_gate": lifecycle,
            "scope": memory_limits["scope"],
        },
        "gates": gates,
    }


def assess(path, budget_path=DEFAULT_BUDGET, requested_suite=None):
    evidence = {}
    path = Path(path).resolve()
    root = path if path.is_dir() else path.parent
    if path.is_dir():
        choices = [root / "summary.json", root / "p3_performance.json"]
        available = [candidate for candidate in choices if candidate.is_file()]
        require(len(available) == 1, "input directory must contain exactly one summary.json or p3_performance.json; specify a file if both exist")
        path = available[0]
    report = object_value(load_json(path, evidence), "report")
    # Some exports deliberately wrap the original report, without changing it.
    if "report" in report and "scenarios" not in report:
        report = object_value(report["report"], "report.report")
    require(type(report.get("schema_version")) is int and report["schema_version"] == 1,
            "unsupported evidence schema")
    require(report.get("status") == "complete", "report is not finalized complete")
    require(report.get("workload_phase_status") == "workloads_complete", "workload phase is not complete")
    if "failure_count" in report:
        require(type(report["failure_count"]) is int and report["failure_count"] == 0,
                "report records workload/test failures")
    if "source_matches_revision" in report:
        require(report["source_matches_revision"] is True, "source integrity was not confirmed")
    compact = "final_script_exit_code" in report or path.name == "summary.json"
    validate_exit_codes(report, root, compact, evidence)
    revision, source_integrity = validate_source_integrity(report, root, evidence)
    runtime = object_value(report.get("runtime"), "runtime")
    runtime_values(runtime, "runtime")
    scenarios = report.get("scenarios")
    require(isinstance(scenarios, list) and bool(scenarios), "scenarios must be a nonempty list")
    ids = []
    for scenario in scenarios:
        object_value(scenario, "scenario")
        require(isinstance(scenario.get("id"), str), "scenario id is missing")
        ids.append(scenario["id"])
    require(len(ids) == len(set(ids)), "duplicate scenario ids")
    suite = infer_suite(report, ids, requested_suite)
    frames = load_array_file(root, "p3_frame_samples", evidence)
    memory = load_array_file(root, "p3_memory_samples", evidence)
    require(set(frames) == set(ids) and set(memory) == set(ids), "raw sample scenario ids disagree with report")
    budget = load_json(Path(budget_path).resolve(), evidence)
    validate_budget(budget)
    seen = set()
    results = [assess_scenario(sc, frames[sc["id"]], memory[sc["id"]], runtime, budget, seen)
               for sc in scenarios]
    if "totals" in report:
        expected = {"workloads": len(results), "frame_samples": sum(map(len, frames.values())),
                    "rss_samples": sum(map(len, memory.values()))}
        require(report["totals"] == expected, "summary totals disagree with raw samples")
    passed = all(result["status"] == "pass" for result in results)
    return {
        "schema_version": 1, "assessment": "observed_run_engineering_budget",
        "status": "pass" if passed else "budget_fail", "budget_id": budget["budget_id"],
        "approval_status": budget["approval_status"], "all_platform_release_accepted": False,
        "suite": suite, "source_revision": revision, "source_integrity": source_integrity,
        "run_id": report.get("run_id", root.name), "runtime": runtime,
        "component_memory_assessment": "unassessed", "leak_assessment": "unassessed",
        "repeat_run_stability": "unassessed", "other_platforms_and_devices": "unassessed",
        "scenarios": results, "budget": budget, "input_artifacts": evidence,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="Native run directory or its summary/report JSON")
    parser.add_argument("--budget", type=Path, default=DEFAULT_BUDGET)
    parser.add_argument("--suite", choices=tuple(SUITES), help="Require the requested complete workload suite")
    parser.add_argument("--output", "--output-json", type=Path,
                        help="Also save the same JSON assessment to this path")
    args = parser.parse_args(argv)
    try:
        result = assess(args.input, args.budget, args.suite)
        exit_code = 0 if result["status"] == "pass" else 1
    except (InvalidEvidence, OSError, EOFError, KeyError, TypeError, OverflowError, zlib.error) as error:
        result = {"schema_version": 1, "assessment": "observed_run_engineering_budget",
                  "status": "invalid_evidence", "all_platform_release_accepted": False,
                  "error": str(error)}
        exit_code = 2
    rendered = json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False) + "\n"
    if args.output:
        try:
            destination = args.output.resolve()
            input_path = args.input.resolve()
            input_root = input_path if input_path.is_dir() else input_path.parent
            protected = {input_path, args.budget.resolve()}
            protected.update(Path(item).resolve() for item in result.get("input_artifacts", {}))
            protected.update(input_root / name for name in (
                "summary.json", "p3_performance.json", "p3_frame_samples.json",
                "p3_frame_samples.json.gz", "p3_memory_samples.json", "p3_memory_samples.json.gz",
                "exit_code.txt", "driver_exit_code.txt", "artifact_manifest.json", "source_hashes.json",
                *SOURCE_ARTIFACTS,
            ))
            require(destination not in protected, "output would overwrite source evidence or budget")
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(rendered, encoding="utf-8")
        except (OSError, InvalidEvidence) as error:
            result = {"schema_version": 1, "assessment": "observed_run_engineering_budget",
                      "status": "invalid_evidence", "all_platform_release_accepted": False,
                      "error": f"cannot write output: {error}"}
            rendered = json.dumps(result, indent=2) + "\n"
            exit_code = 2
    sys.stdout.write(rendered)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
