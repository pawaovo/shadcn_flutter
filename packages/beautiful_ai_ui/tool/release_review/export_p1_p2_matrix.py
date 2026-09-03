#!/usr/bin/env python3
"""Explicit 78-image review capture, with source/font identity and no auto-review."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess

from prepare_review_fonts import FILES, OUTPUT as FONTS, valid


PACKAGE = Path(__file__).resolve().parents[2]
REPO = PACKAGE.parents[1]
P3 = {
    "prompt_bar.dart", "selection_actions.dart", "diff_table.dart",
    "records_table.dart", "sidebar_nav.dart", "flowchart.dart", "insight_cards.dart",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sources():
    shadcn = REPO / "packages/shadcn_flutter"
    shadcn_sources = set((shadcn / "lib").rglob("*.dart"))
    if not shadcn_sources:
        raise RuntimeError("Resolved shadcn source inventory is empty.")
    paths = {
        p for p in (PACKAGE / "lib").rglob("*.dart") if p.name not in P3
    } | shadcn_sources
    paths.update(shadcn / name for name in (
        "pubspec.yaml", "lib/fonts/Geist-Regular.otf",
        "lib/fonts/GeistMono-Regular.otf",
    ))
    paths.update(PACKAGE / name for name in (
        "pubspec.yaml", "test/test_fonts.dart",
        "test/release_review/review_fonts.dart",
        "test/release_review/p1_p2_matrix_scenarios.dart",
        "tool/release_review/p1_p2_matrix_test.dart",
        "tool/release_review/prepare_review_fonts.py",
        "tool/release_review/export_p1_p2_matrix.py",
    ))
    paths.update((REPO / name) for name in ("pubspec.yaml", "pubspec.lock"))
    return {str(p.relative_to(REPO)): digest(p) for p in sorted(paths)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter", default="flutter")
    parser.add_argument("--output", default="build/release_review/2026-09-03-p1-p2-matrix")
    args = parser.parse_args()
    output = (PACKAGE / args.output).resolve()
    if not output.is_relative_to(PACKAGE / "build"):
        parser.error("Review artifacts must remain in the package build directory.")
    for item in FILES:
        file = FONTS / item["file"]
        if not file.exists() or not valid(file.read_bytes(), item):
            parser.error("Missing or changed font. Run prepare_review_fonts.py explicitly first.")
    output.mkdir(parents=True, exist_ok=True)
    before = sources()
    command = [
        args.flutter, "test", "--no-pub",
        "tool/release_review/p1_p2_matrix_test.dart",
        f"--dart-define=P1P2_MATRIX_OUTPUT={output}",
    ]
    start = datetime.now(timezone.utc).isoformat()
    with (output / "capture.log").open("w") as log:
        subprocess.run(command, cwd=PACKAGE, stdout=log, stderr=subprocess.STDOUT,
                       timeout=300, check=True)
    after = sources()
    if before != after:
        raise RuntimeError("Source changed during capture; review is not frozen. Rerun capture.")
    manifest = json.loads((output / "captures.json").read_text())
    captures = manifest["captures"]
    if len(captures) != 78 or any(c["rendering_errors"] for c in captures):
        raise RuntimeError("Expected all 78 clean captures; partial output is not acceptance.")
    for entry in captures:
        entry["sha256"] = digest(output / entry["file"])
        entry["visual_review"] = "unreviewed"
    source_identity = hashlib.sha256(json.dumps(before, sort_keys=True).encode()).hexdigest()
    manifest.update({
        "command": command,
        "started_at_utc": start,
        "finished_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_sha256": source_identity,
        "source_files": before,
        "source_scope": "P1/P2, shared foundation/controls, shadcn source, dependency lock and fixtures; P3 implementation excluded.",
        "fonts": json.loads((FONTS / "provenance.json").read_text()),
        "flutter": subprocess.check_output([args.flutter, "--version", "--machine"],
                                            cwd=PACKAGE, timeout=30, text=True),
    })
    (output / "capture-manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Captured 78 images; visual review remains unreviewed: {output}")
    print(f"Stable source identity: {source_identity}")


if __name__ == "__main__":
    main()
