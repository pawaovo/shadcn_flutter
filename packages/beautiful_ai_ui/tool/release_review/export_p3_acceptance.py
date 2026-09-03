#!/usr/bin/env python3
"""Opt-in P3 matrix and screenshot export; never updates canonical goldens."""

import argparse
import datetime
import hashlib
import html
import json
import os
from pathlib import Path
import shutil
import subprocess

from export import PACKAGE, REPO, source_hashes, validate_resolution


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def p3_source_hashes():
    # Record actual renderer/helper inputs; unrelated P1/P2 test edits cannot
    # change these pictures and are intentionally outside this inventory.
    tests = {"p3_acceptance_scenarios.dart", "review_fonts.dart"}
    tools = {"export.py", "export_p3_acceptance.py", "p3_visual_acceptance_test.dart", "prepare_review_fonts.py", "selection_highlight_probe_test.dart"}
    return {
        path: value for path, value in source_hashes().items()
        if ("/test/release_review/" not in path or Path(path).name in tests)
        and ("/tool/release_review/" not in path or Path(path).name in tools)
    }


def fonts():
    directory = PACKAGE / "build/release_review/fonts"
    provenance = directory / "provenance.json"
    if not provenance.exists():
        raise SystemExit("Run python3 tool/release_review/prepare_review_fonts.py explicitly first.")
    records = json.loads(provenance.read_text())
    result = {}
    for record in records["files"]:
        path = directory / record["file"]
        actual = digest(path)
        if actual != record["sha256"]:
            raise SystemExit(f"Review font/license checksum mismatch: {path}")
        result[str(path.relative_to(REPO))] = actual
    result[str(provenance.relative_to(REPO))] = digest(provenance)
    return result, records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=PACKAGE / "build/p3_visual_acceptance/final")
    parser.add_argument("--capture-only", action="store_true", help="Iteration only: render the 12 pictured profiles, not all 144.")
    parser.add_argument("--only-module", help="Iteration only: one P3 module ID.")
    parser.add_argument("--only-profile", help="Iteration only: one exact profile ID.")
    args = parser.parse_args()
    flutter = os.environ.get("FLUTTER_BIN") or shutil.which("flutter")
    if not flutter:
        parser.error("Run through mise exec, or set FLUTTER_BIN to an absolute Flutter executable.")
    resolved = validate_resolution()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    for name in ("captures.json", "manifest.json", "index.html"):
        (output / name).unlink(missing_ok=True)
    before = p3_source_hashes()
    before_fonts, font_provenance = fonts()
    command = [flutter, "test", "tool/release_review/p3_visual_acceptance_test.dart",
               "--no-pub", "--concurrency=1", "--reporter=expanded",
               "--dart-define=P3_VISUAL_EXPORT=true", f"--dart-define=P3_VISUAL_OUTPUT={output}"]
    if args.capture_only:
        command.append("--dart-define=P3_VISUAL_CAPTURE_ONLY=true")
    if args.only_module:
        command.append(f"--dart-define=P3_VISUAL_ONLY_MODULE={args.only_module}")
    if args.only_profile:
        command.append(f"--dart-define=P3_VISUAL_ONLY_PROFILE={args.only_profile}")
    environment = os.environ.copy()
    if Path("/Applications/Xcode.app/Contents/Developer").is_dir():
        environment.setdefault("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer")
    print(f"P3 opt-in export: {output}", flush=True)
    with (output / "render.log").open("w") as log:
        result = subprocess.run(command, cwd=PACKAGE, env=environment,
                                stdout=log, stderr=subprocess.STDOUT, check=False)
    raw = output / "captures.json"
    if not raw.exists():
        raise SystemExit(f"Renderer exited {result.returncode} without captures.json; inspect {output / 'render.log'}")
    data = json.loads(raw.read_text())
    after = p3_source_hashes()
    after_fonts, _ = fonts()
    complete_matrix = not (args.capture_only or args.only_module or args.only_profile)
    issues = []
    if result.returncode:
        issues.append(f"Renderer failed with exit code {result.returncode}")
    if before != after:
        issues.append("Render source/configuration changed during capture")
    if before_fonts != after_fonts:
        issues.append("Review font/license files changed during capture")
    if complete_matrix and len(data["cases"]) != 1008:
        issues.append(f"Expected 1008 completed cases, observed {len(data['cases'])}")
    for entry in data["captures"]:
        path = output / entry["file"]
        header = path.read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            issues.append(f"Invalid PNG: {entry['file']}")
            continue
        entry.update(sha256=digest(path), bytes=path.stat().st_size,
                     pixel_width=int.from_bytes(header[16:20], "big"),
                     pixel_height=int.from_bytes(header[20:24], "big"))
    data.update({
        "status": "render_validation_passed_unreviewed" if not issues else "failed",
        "validation_issues": issues,
        "complete_matrix": complete_matrix,
        "captured_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "command": command,
        "developer_dir": environment.get("DEVELOPER_DIR"),
        "render_validation_exit_code": result.returncode,
        "render_log_sha256": digest(output / "render.log"),
        "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
        "sources_unchanged_during_capture": before == after,
        "source_sha256": before,
        "font_sha256": before_fonts,
        "font_provenance": font_provenance,
        "resolved_local_packages": resolved,
        "flutter": json.loads(subprocess.check_output([flutter, "--version", "--machine"], cwd=PACKAGE, env=environment, text=True)),
        "human_review_note": "The matrix proves the listed layout/actions only. Every accepted PNG must be independently viewed or byte-identical to an already-viewed accepted PNG. Fonts are explicit test-only OFL fallbacks; no claim about automatic platform glyph fallback.",
    })
    (output / "manifest.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    cards = []
    for profile in data["profiles"]:
        entries = [entry for entry in data["captures"] if entry["profile"] == profile["id"]]
        if not entries:
            continue
        cards.append(f'<h2>{html.escape(profile["id"])}</h2><div class="grid">')
        for entry in entries:
            name = html.escape(entry["file"])
            cards.append(f'<figure><a href="{name}"><img loading="lazy" src="{name}" alt="{name}"></a>'
                         f'<figcaption>{html.escape(entry["module"])} / {html.escape(entry["state"])}'
                         f'<br>{entry["pixel_width"]} × {entry["pixel_height"]}'
                         f'<br><code>{entry["sha256"]}</code></figcaption></figure>')
        cards.append('</div>')
    (output / "index.html").write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8"><title>P3 visual acceptance candidates</title>'
        '<style>body{font:15px system-ui;margin:28px;background:#eef1f4;color:#18212b}'
        '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:22px;align-items:start}'
        'figure{margin:0;background:white;padding:12px}img{width:100%;height:auto}figcaption{overflow-wrap:anywhere}code{font-size:10px}</style>'
        f'<h1>P3 finite visual acceptance candidates</h1><p>{len(data["cases"])} matrix cases; '
        f'{len(data["captures"])} PNGs. Status: {html.escape(data["status"])}. '
        'Open at full size; export is not visual approval. <a href="manifest.json">Exact manifest</a>.</p>'
        + ''.join(cards) + '</html>\n')
    print(f"Cases: {len(data['cases'])}; PNGs: {len(data['captures'])}; manifest SHA-256: {digest(output / 'manifest.json')}")
    if issues:
        raise SystemExit("; ".join(issues))


if __name__ == "__main__":
    main()
