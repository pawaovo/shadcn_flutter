#!/usr/bin/env python3
"""Identify profile inputs before building and verify them after the capture.

The manifest format preserves the original September 3 capture algorithm.
This records local inputs; it does not claim to hash external dependency code.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
SCOPES = (
    "lib", "assets", "packages/shadcn_flutter/lib", "packages/beautiful_ai_ui/lib",
    "packages/beautiful_ai_ui_catalog/lib",
    "packages/beautiful_ai_ui_catalog/integration_test",
    "packages/beautiful_ai_ui_catalog/test_driver",
    "packages/beautiful_ai_ui_catalog/macos/Runner",
    "packages/beautiful_ai_ui_catalog/macos/Runner.xcodeproj",
    "packages/beautiful_ai_ui_catalog/macos/Runner.xcworkspace",
)
EXPLICIT = (
    ".mise.toml", "pubspec.yaml", "pubspec.lock", "pubspec_overrides.yaml",
    "packages/shadcn_flutter/pubspec.yaml",
    "packages/beautiful_ai_ui/pubspec.yaml",
    "packages/beautiful_ai_ui_catalog/pubspec.yaml",
    "packages/beautiful_ai_ui_catalog/macos/Flutter/GeneratedPluginRegistrant.swift",
    "packages/beautiful_ai_ui_catalog/macos/Flutter/Flutter-Debug.xcconfig",
    "packages/beautiful_ai_ui_catalog/macos/Flutter/Flutter-Release.xcconfig",
    "packages/beautiful_ai_ui_catalog/macos/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift",
    "packages/beautiful_ai_ui_catalog/tool/run_p3_profile.sh",
    "packages/beautiful_ai_ui_catalog/tool/profile_source_snapshot.py",
    "packages/beautiful_ai_ui_catalog/tool/assess_profile_budget.py",
    "docs/beautiful-ui/quality_evidence/performance/engineering_budget_v1.json",
)
ALGORITHM = (
    "SHA-256 of UTF-8 path + NUL + per-file SHA-256, ordered by path and joined "
    "with LF; no trailing LF."
)


def manifest_digest(files):
    manifest = "\n".join(row["path"] + "\0" + row["sha256"] for row in files)
    return hashlib.sha256(manifest.encode()).hexdigest()


def capture(root=ROOT):
    paths = {root / item for item in EXPLICIT if (root / item).is_file()}
    for scope in SCOPES:
        for path in (root / scope).rglob("*"):
            if path.is_file() and not any(
                part in ("xcuserdata", ".DS_Store") for part in path.parts
            ):
                paths.add(path)
    files = []
    for path in sorted(paths, key=lambda value: value.relative_to(root).as_posix()):
        contents = path.read_bytes()
        files.append({"path": str(path.relative_to(root)),
                      "sha256": hashlib.sha256(contents).hexdigest(),
                      "bytes": len(contents)})
    return {
        "schema_version": 1,
        "captured_at_utc": datetime.now(timezone.utc).isoformat(),
        "revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "source_worktree_status": subprocess.check_output(
            ["git", "status", "--porcelain"], cwd=root, text=True),
        "scope": (
            "Complete core/library/Catalog runtime sources and core font/icon assets, "
            "all integration targets/drivers, native macOS sources/project and plugin "
            "registrant, dependency/toolchain pins, generated Swift package manifest, "
            "profile runner/snapshot tool/evaluator/budget. xcuserdata and timestamp-bearing "
            ".flutter-plugins-dependencies excluded; external package implementation is "
            "represented by the lockfile and compiled bundle inventory."
        ),
        "manifest_sha256": manifest_digest(files),
        "manifest_algorithm": ALGORITHM,
        "files": files,
    }


def validate(snapshot):
    files = snapshot["files"]
    paths = [row["path"] for row in files]
    if paths != sorted(set(paths)) or snapshot["manifest_sha256"] != manifest_digest(files):
        raise ValueError("Source manifest content does not match its claimed SHA-256")


def comparison(before, after):
    validate(before)
    validate(after)
    previous = {row["path"]: row["sha256"] for row in before["files"]}
    current = {row["path"]: row["sha256"] for row in after["files"]}
    changed = [path for path in sorted(previous.keys() | current.keys())
               if previous.get(path) != current.get(path)]
    same_revision = before["revision"] == after["revision"]
    same = same_revision and not changed
    return {
        "schema_version": 1,
        "status": "verified_unchanged" if same else "invalid_source_changed",
        "revision_unchanged": same_revision,
        "before_revision": before["revision"],
        "after_revision": after["revision"],
        "before_manifest_sha256": before["manifest_sha256"],
        "after_manifest_sha256": after["manifest_sha256"],
        "before_file_count": len(before["files"]),
        "after_file_count": len(after["files"]),
        "changed_paths": changed,
        "source_worktree_status_unchanged": (
            before["source_worktree_status"] == after["source_worktree_status"]),
        "scope_note": (
            "Acceptance checks the listed build/runtime inputs and git revision. "
            "Changes to out-of-scope documentation/tests are reported by worktree "
            "status and do not alter this manifest."
        ),
    }


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    first = subcommands.add_parser("capture")
    first.add_argument("output", type=Path)
    second = subcommands.add_parser("compare")
    second.add_argument("before", type=Path)
    second.add_argument("after", type=Path)
    args = parser.parse_args()
    current = capture()
    if args.command == "capture":
        write(args.output, current)
        print(json.dumps({"file_count": len(current["files"]),
                          "manifest_sha256": current["manifest_sha256"],
                          "destination": str(args.output)}))
        return 0
    write(args.after, current)
    result = comparison(json.loads(args.before.read_text()), current)
    print(json.dumps(result, indent=2))
    return 0 if result["status"] == "verified_unchanged" else 2


if __name__ == "__main__":
    sys.exit(main())
