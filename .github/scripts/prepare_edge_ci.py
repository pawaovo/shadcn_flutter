#!/usr/bin/env python3
"""Explicit Linux Edge CI setup and post-run executable binding; no browser calls."""

import argparse
import json
import os
from pathlib import Path
import signal
import sys
import time

from edge_resource_observation import proc_row
from probe_edge_cold_start import file_identity, preread_executable, write_json


def preread(output, executable, timeout=60):
    output.mkdir(parents=True, exist_ok=False)
    report = {"status": "started", "upstream_status": "not_started",
              "condition": "once_only_edge_elf_preread", "timeout_seconds": timeout,
              "source_sha": os.environ.get("GITHUB_SHA"), "started_epoch": time.time(),
              "runner": {key: os.environ.get(key) for key in
                         ("ImageOS", "ImageVersion", "RUNNER_OS", "RUNNER_ARCH")}}
    previous = None
    try:
        write_json(output / "setup.json", report)
        if sys.platform != "linux" or not 0 < timeout <= 60:
            raise ValueError("Edge preread requires Linux and a deadline of at most 60 seconds")

        def expired(*_):
            raise TimeoutError(f"Edge ELF preread exceeded {timeout} seconds")

        previous = signal.signal(signal.SIGALRM, expired)
        signal.setitimer(signal.ITIMER_REAL, timeout)
        report["preread"] = preread_executable(executable, output)
        report["status"] = "ready"
    except Exception as error:
        report.update(status="failed", error=f"{type(error).__name__}: {error}")
    finally:
        if previous is not None:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous)
        report["completed_epoch"] = time.time()
        write_json(output / "setup.json", report)
    return report


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def sampled_identity(samples, pid, expected_start=None):
    identities = {(row["start_ticks"], row["exe"])
                  for sample in samples for row in sample["processes"]
                  if row["pid"] == pid and row.get("exe")}
    if len(identities) != 1:
        raise ValueError(f"Expected one sampled executable identity for PID {pid}")
    start, path = identities.pop()
    if expected_start is not None and start != expected_start:
        raise ValueError(f"Driver PID {pid} start time did not match its observation")
    return {"pid": pid, "start_ticks": start, "path": path}


def observed_nonrunning(observation, samples):
    identities = {tuple(identity) for identity in observation["observed_process_identities"]}
    sampled = {(row["pid"], row["start_ticks"])
               for sample in samples for row in sample["processes"]}
    if not identities or identities != sampled:
        raise ValueError("Recorded observed identities do not match the resource samples")
    records = []
    for pid, start in sorted(identities):
        record = {"pid": pid, "start_ticks": start}
        try:
            current = proc_row(pid)
        except (FileNotFoundError, ProcessLookupError):
            records.append(dict(record, state="absent"))
            continue
        if current["start_ticks"] == start and current["state"] != "Z":
            raise ValueError(f"Observed process identity is still live: {pid}/{start}")
        records.append(dict(record, state="zombie" if current["start_ticks"] == start else "pid_reused"))
    return records


def verify(output, suites, run_outcome, summary_path=None):
    report = {"status": "started", "run_step_outcome": run_outcome,
              "upstream_status": {"success": "passed", "failure": "failed", "cancelled": "cancelled"}.get(run_outcome, "not_started"),
              "cleanup_scope": "owned_group_cleanup_verified" if summary_path else "observed_identity_no_live_processes",
              "unobserved_descendant_absence_claimed": False, "suites": [],
              "started_epoch": time.time()}
    try:
        if sys.platform != "linux":
            raise ValueError("Post-run Edge identity verification requires Linux /proc")
        setup = read_json(output / "setup.json")
        if setup["status"] != "ready":
            report["upstream_status"] = "not_started"
            raise ValueError("Preread setup did not complete; the original suites were not started")
        before = read_json(output / "preread.json")
        if before.get("status") != "read_complete" or before != setup["preread"]:
            raise ValueError("Preread evidence is incomplete or inconsistent with setup")
        if run_outcome not in ("success", "failure"):
            raise ValueError("Original suite execution did not complete")
        if not suites or len(set(suites)) != len(suites):
            raise ValueError("Expected distinct suite evidence directories")
        if summary_path is not None:
            upstream = read_json(summary_path)
            report["upstream"] = upstream
            if upstream.get("platform") != "edge" or upstream.get("status") not in ("passed", "failed"):
                raise ValueError("Missing completed original Edge input result")
            if upstream["status"] != report["upstream_status"]:
                raise ValueError("Original input result and workflow outcome disagree")
            entries = upstream["suites"]
            if [entry["suite"] for entry in entries] != [path.name for path in suites]:
                raise ValueError("Original input suite list does not match the expected suites")
            if any(entry.get("cleanup_status") != "verified" for entry in entries):
                raise ValueError("Original input runner did not verify owned group cleanup")
        # Check all suites before any executable hashing. No processes are stopped here.
        for directory in suites:
            identity = read_json(directory / "browser-identity.json")
            observation = read_json(directory / "resources/observation.json")
            if observation.get("status") != "recorded":
                raise ValueError(f"Incomplete resource observation: {directory}")
            samples = [json.loads(line) for line in
                       (directory / "resources/resources.jsonl").read_text().splitlines()]
            caps = identity["capabilities"]
            if caps.get("browserName") != "MicrosoftEdge":
                raise ValueError("Session did not identify Microsoft Edge")
            if caps.get("pageLoadStrategy") != "normal" or caps.get("timeouts", {}).get("pageLoad") != 300000:
                raise ValueError("Original normal pageLoad strategy and 300000 ms timeout were not observed")
            browser = sampled_identity(samples, caps["goog:processID"])
            driver = sampled_identity(samples, observation["root_pid"], observation["root_start_ticks"])
            if browser["path"] != before["resolved"]:
                raise ValueError("Preread ELF did not match the actual session browser PID executable")
            nonrunning = observed_nonrunning(observation, samples)
            report["suites"].append({"suite": str(directory), "session": identity,
                                     "no_live_observed_identities": nonrunning,
                                     "browser": browser, "driver": driver})
        hashes = {}
        for suite in report["suites"]:
            for kind in ("browser", "driver"):
                path = suite[kind]["path"]
                if path not in hashes:
                    hashes[path] = file_identity(path)
                suite[kind]["post_run_executable"] = hashes[path]
            after = suite["browser"]["post_run_executable"]
            if (after["resolved"], after["bytes"], after["sha256"]) != (
                    before["resolved"], before["bytes"], before["sha256"]):
                raise ValueError("Actual browser executable post-run hash differs from the preread")
        report["status"] = "verified"
    except Exception as error:
        report.update(status="failed", evidence_error=f"{type(error).__name__}: {error}")
    finally:
        report["completed_epoch"] = time.time()
        output.mkdir(parents=True, exist_ok=True)
        write_json(output / "verification.json", report)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    setup = commands.add_parser("preread")
    setup.add_argument("--executable", type=Path, required=True)
    setup.add_argument("--output", type=Path, required=True)
    setup.add_argument("--timeout", type=float, default=60)
    final = commands.add_parser("verify")
    final.add_argument("--output", type=Path, required=True)
    final.add_argument("--suite", type=Path, action="append", required=True)
    final.add_argument("--run-outcome", choices=("success", "failure", "cancelled", "skipped"), required=True)
    final.add_argument("--input-summary", type=Path)
    args = parser.parse_args()
    if args.command == "preread":
        result = preread(args.output, args.executable, args.timeout)
        return 0 if result["status"] == "ready" else 1
    result = verify(args.output, args.suite, args.run_outcome, args.input_summary)
    return 0 if result["status"] == "verified" else 1


if __name__ == "__main__":
    raise SystemExit(main())
