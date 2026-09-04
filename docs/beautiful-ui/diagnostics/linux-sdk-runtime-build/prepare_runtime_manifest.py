#!/usr/bin/env python3
"""Bind a completed full engine build to an explicit owned Catalog fixture."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--atk-bridge-artifact", type=Path,
                        help="Optional independently built native geometry dependency artifact")
    args = parser.parse_args()
    root = args.catalog_root.resolve()
    sys.path.insert(0, str(root / ".github/scripts"))
    from isolated_sdk_runtime import SDK_REVISION, build_command, linked_library_inventory, record, validate_manifest
    from probe_catalog_orca_linux import source_inventory

    if args.output.exists():
        raise SystemExit("Use a fresh manifest path; previous evidence is retained")
    work = Path("/work")
    artifact_path = work / "engine-artifact.json"
    artifact = json.loads(artifact_path.read_text())
    if artifact.get("status") != "built_not_runtime_accepted":
        raise SystemExit("A completed actual engine build is required")
    data = {
        "schema_version": 1, "scope": "isolated_sdk_runtime_diagnostic",
        "build_mode": "debug", "sdk_revision": SDK_REVISION,
        "sdk_root": str(work / "flutter"), "catalog_root": str(root),
        "catalog_git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip(),
        "fixture_tracked_changes": subprocess.check_output(["git", "diff", "--name-only", "HEAD"], cwd=root, text=True).splitlines(),
        "fixture_untracked_files": subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard"], cwd=root, text=True).splitlines(),
        "fixture_source_sha256": source_inventory(),
        "container_identity": record(work / "container-identity.json"),
        "source_build_binding": record(work / "source-build-binding.json"),
        "engine_artifact": record(artifact_path),
        "engine_library": record(Path(artifact["library"])),
        "patch": record(Path("/proof/flutter-3.47.0-atk-name-expanded.patch")),
        "application_acceptance": "not_accepted", "performance_acceptance": "not_applicable",
    }
    data["expected_build_command"] = build_command(data)
    if args.atk_bridge_artifact is not None:
        bridge = json.loads(args.atk_bridge_artifact.read_text())
        library = Path(bridge["library"])
        data["native_atk_bridge"] = {
            "build_artifact": record(args.atk_bridge_artifact), "library": record(library),
            "patch": record(Path(__file__).parent / "atspi-geometry/at-spi2-core-2.52-same-process-geometry.patch"),
            "linked_libraries": linked_library_inventory(library),
        }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, indent=2) + "\n")
    validate_manifest(args.output, root, current_sources=source_inventory())
    print(args.output)


if __name__ == "__main__":
    main()
