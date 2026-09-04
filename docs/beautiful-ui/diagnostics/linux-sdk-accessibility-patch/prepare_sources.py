#!/usr/bin/env python3
"""Copy pinned source into an isolated directory and apply only the reviewable patch."""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess

REVISION = "4cf24164269a5ebf0c16a028a00727d0e77bbb05"
NODE = Path("engine/src/flutter/shell/platform/linux/fl_accessible_node.cc")
HEADERS = (
    "engine/src/flutter/shell/platform/linux/fl_accessible_node.h",
    "engine/src/flutter/shell/platform/linux/fl_engine_private.h",
    "engine/src/flutter/shell/platform/embedder/embedder.h",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    sdk, output = args.sdk_root.resolve(), args.output.resolve()
    if output == sdk or sdk in output.parents:
        raise SystemExit("Refusing to write into the installed SDK")
    if output.exists() and any(output.iterdir()):
        raise SystemExit("Use a new empty output directory; existing evidence is never overwritten")
    patch = Path(__file__).with_name("flutter-3.47.0-atk-name-expanded.patch")
    sources = {}
    for relative in (str(NODE), *HEADERS):
        actual = (sdk / relative).read_bytes()
        pinned = subprocess.check_output(["git", "-C", str(sdk), "show", f"{REVISION}:{relative}"])
        if actual != pinned:
            raise SystemExit(f"SDK file differs from pinned revision: {relative}")
        sources[relative] = hashlib.sha256(actual).hexdigest()
    for variant in ("original", "patched"):
        target = output / variant / NODE
        target.parent.mkdir(parents=True)
        target.write_bytes((sdk / NODE).read_bytes())
    subprocess.run(["git", "apply", "--check", str(patch)], cwd=output / "patched", check=True)
    subprocess.run(["git", "apply", str(patch)], cwd=output / "patched", check=True)
    manifest = {
        "framework_version": "3.47.0", "framework_revision": REVISION,
        "original_file_sha256": sources,
        "patched_source_sha256": hashlib.sha256((output / "patched" / NODE).read_bytes()).hexdigest(),
        "patch_sha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
        "installed_sdk_mutated": False,
        "scope": "Source-level unit proof; no app, Dart engine or screen-reader acceptance",
    }
    (output / "source-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(output)


if __name__ == "__main__":
    main()
