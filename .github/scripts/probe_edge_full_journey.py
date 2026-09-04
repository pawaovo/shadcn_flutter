#!/usr/bin/env python3
"""One full Catalog Edge journey per fresh runner, with an explicit preread condition.

The existing runner owns the adapter and Flutter processes. Browser startup,
navigation, trusted journey, timeouts and cleanup are not reimplemented here.
"""

import argparse
import json
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import time

from probe_edge_cold_start import file_identity, preread_executable, write_json
from run_catalog_input_acceptance import ROOT, run


def sampled_executable(samples, pid, expected_start=None):
    rows = [row for sample in samples for row in sample["processes"] if row["pid"] == pid]
    identities = {(row["start_ticks"], row.get("exe")) for row in rows if row.get("exe")}
    if len(identities) != 1:
        raise ValueError(f"Expected one sampled executable identity for PID {pid}, got {identities}")
    start, path = identities.pop()
    if expected_start is not None and start != expected_start:
        raise ValueError(f"Sampled driver PID {pid} did not retain its recorded start time")
    # This is deliberately after the journey and owned cleanup, including baseline.
    return {"pid": pid, "start_ticks": start, **file_identity(path)}


def post_run_evidence(output, preread):
    directory = output / "acceptance" / "journey"
    upstream = json.loads((output / "acceptance" / "input-acceptance-summary.json").read_text())
    if len(upstream["suites"]) != 1 or upstream["suites"][0]["suite"] != "journey":
        raise ValueError("The diagnostic must contain exactly one original full journey")
    if upstream["suites"][0].get("cleanup_status") != "verified":
        raise ValueError("Owned cleanup was not verified; do not hash executables while processes may remain")
    identity = json.loads((directory / "browser-identity.json").read_text())
    observation = json.loads((directory / "resources" / "observation.json").read_text())
    if observation.get("status") != "recorded":
        raise ValueError(f"Resource observation is incomplete: {observation}")
    samples = [json.loads(line) for line in (directory / "resources" / "resources.jsonl").read_text().splitlines()]
    caps = identity["capabilities"]
    if caps.get("pageLoadStrategy") != "normal" or caps.get("timeouts", {}).get("pageLoad") != 300000:
        raise ValueError("Original normal pageLoad strategy and 300000 ms timeout were not observed")
    browser = sampled_executable(samples, caps["goog:processID"])
    driver = sampled_executable(samples, observation["root_pid"], observation["root_start_ticks"])
    if preread is not None and (browser["resolved"], browser["sha256"]) != (preread["resolved"], preread["sha256"]):
        raise ValueError("Preread path/hash did not match this session's actual browser PID and post-run executable")
    if upstream["status"] == "passed":
        trusted = json.loads((directory / "trusted-journey.json").read_text())
        if trusted.get("status") != "passed":
            raise ValueError("A successful Flutter process did not supply a passing trusted journey report")
    return {"session": identity, "browser_executable_after_run": browser,
            "driver_executable_after_run": driver, "upstream": upstream}


def run_condition(output, source_sha, condition, preread_path=None):
    if (condition == "preread") != (preread_path is not None):
        raise ValueError("Only the explicit preread condition requires an actual ELF path")
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    started = time.monotonic()
    report = {"condition": condition, "source_sha": source_sha,
              "started_epoch": time.time(), "upstream_status": "not_started", "evidence_status": "pending",
              "runner": {key: os.environ.get(key) for key in (
                  "ImageOS", "ImageVersion", "RUNNER_OS", "RUNNER_ARCH", "GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT")},
              "platform": platform.platform(), "clock_ticks_per_second": os.sysconf("SC_CLK_TCK"),
              "page_size_bytes": os.sysconf("SC_PAGE_SIZE"),
              "scope": "one original full Catalog journey; no automatic retry",
              "executable_hash_timing": "after journey and owned cleanup; preread hashes its one intentional read"}
    preread = None
    try:
        write_json(output / "report.json", report)
        if preread_path is not None:
            preread = preread_executable(preread_path, output)
            report["preread"] = preread
        report["upstream_status"] = "started"
        write_json(output / "report.json", report)
        run(argparse.Namespace(platform="edge", device=None, include_journey=False,
                               journey_only=True, artifacts=output / "acceptance"))
        report["upstream_status"] = "passed"
    except BaseException as error:
        report["upstream_status"] = "failed" if report["upstream_status"] == "started" else "not_started"
        report["original_run_error"] = f"{type(error).__name__}: {error}"
        if not isinstance(error, Exception):
            raise
    finally:
        report["elapsed_seconds_including_preread_and_cleanup"] = round(time.monotonic() - started, 6)
        report["completed_epoch"] = time.time()
        # Evidence errors never replace the runner's original result or artifacts.
        try:
            report["evidence"] = post_run_evidence(output, preread)
            report["evidence_status"] = "recorded"
        except Exception as error:
            report["evidence_status"] = "unavailable"
            report["evidence_error"] = f"{type(error).__name__}: {error}"
        report["status"] = ("passed" if report["upstream_status"] == "passed" and
                            report["evidence_status"] == "recorded" else "failed")
        write_json(output / "report.json", report)
    return report


def compare_reports(baseline, preread):
    reports = []
    blockers = []
    for path in (baseline, preread):
        try:
            reports.append(json.loads(Path(path).read_text()))
        except (OSError, ValueError) as error:
            reports.append({"report_unavailable": str(error)})
    signatures = []
    for report, condition in zip(reports, ("baseline", "preread")):
        if report.get("condition") != condition or report.get("evidence_status") != "recorded":
            blockers.append(f"{condition}: missing matching condition or complete evidence")
            continue
        try:
            evidence = report["evidence"]
            caps = evidence["session"]["capabilities"]
            signature = {"source_sha": report["source_sha"],
                         "image": {key: report["runner"][key] for key in ("ImageOS", "ImageVersion", "RUNNER_OS", "RUNNER_ARCH")},
                         "browser_version": caps["browserVersion"],
                         "driver_version": caps["msedge"]["msedgedriverVersion"],
                         "browser_sha256": evidence["browser_executable_after_run"]["sha256"],
                         "driver_sha256": evidence["driver_executable_after_run"]["sha256"]}
            if not all(signature["image"].values()) or not re.fullmatch(r"[0-9a-f]{40}", signature["source_sha"]):
                blockers.append(f"{condition}: runner image or exact source identity unavailable")
            signatures.append(signature)
        except (KeyError, TypeError) as error:
            blockers.append(f"{condition}: missing provenance: {error}")
    if len(signatures) == 2 and signatures[0] != signatures[1]:
        blockers.append("Actual source, runner image, browser/driver version or post-run executable hashes differ")
    return {"comparison_status": "blocked" if blockers else "provenance_matched",
            "blockers": blockers, "provenance": signatures, "conditions": reports,
            "interpretation": "Matching provenance permits inspecting this one pair; it does not establish causality, a repair, or a reproduction rate. Every original outcome remains visible."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    execute = commands.add_parser("run")
    execute.add_argument("--source-sha", required=True)
    execute.add_argument("--condition", choices=("baseline", "preread"), required=True)
    execute.add_argument("--output", type=Path, required=True)
    execute.add_argument("--preread-browser-executable", type=Path)
    compare = commands.add_parser("compare")
    compare.add_argument("--baseline", type=Path, required=True)
    compare.add_argument("--preread", type=Path, required=True)
    compare.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "compare":
        result = compare_reports(args.baseline, args.preread)
        write_json(args.output, result)
        return 0 if result["comparison_status"] == "provenance_matched" else 1
    if sys.platform != "linux":
        parser.error("Actual full-journey conditions require Linux /proc")
    actual_sha = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", args.source_sha) or args.source_sha != actual_sha:
        parser.error("--source-sha must match the exact checked-out commit")

    def interrupted(signum, _frame):
        raise KeyboardInterrupt(f"Interrupted by signal {signum}")

    signal.signal(signal.SIGTERM, interrupted)
    report = run_condition(args.output, args.source_sha, args.condition, args.preread_browser_executable)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
