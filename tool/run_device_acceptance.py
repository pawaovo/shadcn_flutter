#!/usr/bin/env python3
"""Capture a device acceptance record and optionally run the existing journey.

This does not operate a screen reader or mark manual cases as passed.
"""

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "packages/beautiful_ai_ui_catalog"
TEMPLATE = ROOT / "docs/beautiful-ui/device-acceptance/record-template.json"
TARGETS = {"android": "android", "ios": "ios", "macos": "darwin",
           "windows": "windows", "linux": "linux"}


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")


def capture(command, output, env, timeout=90):
    result = subprocess.run(command, cwd=CATALOG, env=env, capture_output=True,
                            text=True, encoding="utf-8", errors="replace",
                            timeout=timeout, check=False)
    output.write_text(result.stdout, encoding="utf-8")
    output.with_suffix(".stderr.log").write_text(result.stderr, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {command!r}")
    return result.stdout


def stop(process):
    # Only the process group created for this invocation is targeted.
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                       capture_output=True, timeout=15, check=False)
    else:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    process.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["prepare", "journey"])
    parser.add_argument("--platform", required=True, choices=TARGETS)
    parser.add_argument("--device", help="Exact ID from flutter devices --machine")
    parser.add_argument("--output", type=Path, help="New output directory; never overwritten")
    parser.add_argument("--flutter-bin", help="Flutter executable; defaults to mise exec -- flutter")
    parser.add_argument("--timeout", type=int, default=1800,
                        help="Journey build/install/test deadline in seconds (default 1800)")
    args = parser.parse_args()
    if args.timeout < 1:
        parser.error("--timeout must be positive")
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S.%fZ")
    output = (args.output or CATALOG / "build/device-acceptance" /
              f"{stamp}-{args.platform}").resolve()
    output.mkdir(parents=True, exist_ok=False)
    print(f"Evidence directory: {output}", flush=True)
    record = json.loads(TEMPLATE.read_text(encoding="utf-8"))
    record.update({"created_at_utc": now(), "platform": args.platform,
                   "host": platform.platform(), "invocation": sys.argv,
                   "device_id_requested": args.device})
    result_path = output / "record.json"
    env = os.environ.copy()
    if args.platform in ("ios", "macos") and Path(
            "/Applications/Xcode.app/Contents/Developer").is_dir():
        env.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    try:
        if args.flutter_bin:
            flutter = [str(Path(args.flutter_bin).expanduser().resolve())]
        else:
            mise = shutil.which("mise") or "/opt/homebrew/bin/mise"
            flutter = [mise, "exec", "--", "flutter"]
        record["source_revision"] = capture(
            ["git", "rev-parse", "HEAD"], output / "revision.txt", env).strip()
        record["working_tree_status"] = capture(
            ["git", "status", "--porcelain=v1"], output / "working-tree.txt", env)
        version = json.loads(capture(flutter + ["--version", "--machine"],
                                     output / "flutter-version.json", env))
        record["flutter_version"] = version
        devices = json.loads(capture(flutter + ["devices", "--machine"],
                                     output / "devices.json", env))
        target = TARGETS[args.platform]
        eligible = [d for d in devices if d.get("isSupported") is True and
                    (d.get("targetPlatform") == target or
                     d.get("targetPlatform", "").startswith(target + "-")) and
                    d.get("emulator") is False]
        record["eligible_device_ids"] = [d["id"] for d in eligible]
        selected = next((d for d in eligible if d["id"] == args.device), None)
        record["device"] = selected
        record["environment"]["device_model"] = selected.get("name") if selected else None
        record["environment"]["os_version"] = selected.get("sdk") if selected else None
        if args.mode == "prepare":
            record["preparation"] = "ready_to_select_device" if eligible else "device_unavailable"
            save(result_path, record)
            print("Preparation only; no journey or manual acceptance was executed.")
            print(f"Eligible device IDs: {record['eligible_device_ids']}")
            return 0
        if selected is None:
            raise RuntimeError("No matching supported physical/native device. "
                               "Select an exact eligible ID; mobile simulators are rejected.")
        if version.get("frameworkVersion") != "3.47.0" or not re.match(
                r"^3\.13\.0(?:\s|$)", version.get("dartSdkVersion", "")):
            raise RuntimeError("Expected pinned Flutter 3.47.0 / Dart 3.13.0.")
        command = flutter + ["test", "integration_test/catalog_journey_test.dart",
                             "--device-id", args.device, "--reporter", "expanded"]
        journey = record["automated_journey"]
        journey.update({"status": "running", "started_at_utc": now(),
                        "command": command, "log": "journey.log",
                        "timeout_seconds": args.timeout})
        save(result_path, record)
        started = time.monotonic()
        with (output / "journey.log").open("wb") as log:
            options = {"start_new_session": True} if os.name != "nt" else {
                "creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
            process = subprocess.Popen(command, cwd=CATALOG, env=env,
                                       stdin=subprocess.DEVNULL, stdout=log,
                                       stderr=subprocess.STDOUT, **options)
            interrupted = None
            try:
                code = process.wait(timeout=args.timeout)
            except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
                interrupted = type(error).__name__
                stop(process)
                code = process.returncode
        raw = (output / "journey.log").read_bytes()
        success_marker = bool(re.search(rb"All tests passed[.!]", raw))
        passed = code == 0 and success_marker and interrupted is None
        journey.update({"status": "passed" if passed else "failed", "exit_code": code,
                        "elapsed_seconds": round(time.monotonic() - started, 3),
                        "finished_at_utc": now(), "interruption": interrupted,
                        "success_marker_present": success_marker,
                        "log_sha256": hashlib.sha256(raw).hexdigest()})
        save(result_path, record)
        print(f"Automated journey: {journey['status']}; manual cases remain not_run.")
        return 0 if passed else 1
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        if record["automated_journey"]["status"] == "running":
            record["automated_journey"]["status"] = "failed"
        elif args.mode == "journey":
            record["automated_journey"]["status"] = "blocked"
        record["error"] = str(error)
        save(result_path, record)
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
