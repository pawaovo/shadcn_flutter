#!/usr/bin/env python3
"""Export review candidates and exact provenance without updating goldens."""

import argparse
import datetime
import hashlib
import html
import json
import os
from pathlib import Path
import shutil
import subprocess
from urllib.parse import unquote, urljoin, urlparse


PACKAGE = Path(__file__).resolve().parents[2]
REPO = PACKAGE.parents[1]
PACKAGE_CONFIG = REPO / ".dart_tool/package_config.json"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_hashes():
    paths = set()
    for folder in (PACKAGE / "lib", PACKAGE / "test/release_review",
                   PACKAGE / "tool/release_review",
                   PACKAGE.parent / "shadcn_flutter/lib"):
        paths.update(path for path in folder.rglob("*")
                     if path.is_file() and "__pycache__" not in path.parts
                     and path.suffix != ".pyc")
    paths.update((PACKAGE / "test/test_fonts.dart", REPO / "pubspec.lock",
                  REPO / "pubspec.yaml", PACKAGE / "pubspec.yaml",
                  PACKAGE.parent / "shadcn_flutter/pubspec.yaml", PACKAGE_CONFIG))
    paths.update((PACKAGE.parent / "shadcn_flutter/lib/fonts").glob("*Regular.otf"))
    return {str(path.relative_to(REPO)): digest(path) for path in sorted(paths)}


def validate_resolution():
    if not PACKAGE_CONFIG.exists():
        raise SystemExit("Resolve the Pub workspace with flutter pub get first.")
    packages = json.loads(PACKAGE_CONFIG.read_text())["packages"]
    expected = {"beautiful_ai_ui": PACKAGE,
                "shadcn_flutter": PACKAGE.parent / "shadcn_flutter"}
    resolved = {}
    for name, folder in expected.items():
        entry = next((item for item in packages if item["name"] == name), None)
        if not entry:
            raise SystemExit(f"Missing resolved local package: {name}")
        uri = urlparse(urljoin(PACKAGE_CONFIG.as_uri(), entry["rootUri"]))
        root = Path(unquote(uri.path)).resolve()
        if uri.scheme != "file" or root != folder.resolve():
            raise SystemExit(f"{name} resolves outside the hashed workspace: {root}")
        resolved[name] = str(root)
    return resolved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=PACKAGE / "build/release_review")
    parser.add_argument("--only", help="Comma-separated module IDs, for iteration only")
    args = parser.parse_args()
    flutter = os.environ.get("FLUTTER_BIN") or shutil.which("flutter")
    if not flutter:
        parser.error("Set FLUTTER_BIN to the Flutter executable or add flutter to PATH.")
    resolved = validate_resolution()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    raw = output / "captures.json"
    # An interrupted run must not leave an old index claiming that partly
    # overwritten image files still match a previously accepted manifest.
    for name in ("captures.json", "manifest.json", "index.html"):
        (output / name).unlink(missing_ok=True)
    before = source_hashes()
    command = [flutter, "test", "tool/release_review/export_test.dart", "--no-pub",
               "--concurrency=1", f"--dart-define=RELEASE_REVIEW_OUTPUT={output}"]
    if args.only:
        command.append(f"--dart-define=RELEASE_REVIEW_ONLY={args.only}")
    result = subprocess.run(command, cwd=PACKAGE, check=False)
    if not raw.exists():
        raise SystemExit(result.returncode or "The renderer did not produce captures.json.")
    data = json.loads(raw.read_text())
    after = source_hashes()
    data.update({
        "captured_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "command": command,
        "git_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
        "flutter": json.loads(subprocess.check_output([flutter, "--version", "--machine"], cwd=PACKAGE, text=True)),
        "render_validation_exit_code": result.returncode,
        "sources_unchanged_during_capture": before == after,
        "source_sha256": before,
        "resolved_local_packages": resolved,
        "human_review_note": "Export is unreviewed. Record inspected images and their SHA-256 separately. Static images do not prove temporal motion behavior or device accessibility.",
    })
    for entry in data["captures"]:
        path = output / entry["file"]
        entry["sha256"] = digest(path)
        entry["bytes"] = path.stat().st_size
        header = path.read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            raise SystemExit(f"Not a PNG: {path}")
        entry["pixel_width"] = int.from_bytes(header[16:20], "big")
        entry["pixel_height"] = int.from_bytes(header[20:24], "big")
    manifest = output / "manifest.json"
    manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    cards = []
    for profile in data["profiles"]:
        cards.append(f'<h2>{html.escape(profile["id"])}</h2><div class="grid">')
        for entry in data["captures"]:
            if entry["profile"] != profile["id"]:
                continue
            name = html.escape(entry["file"])
            cards.append(f'<figure><a href="{name}"><img loading="lazy" src="{name}" alt="{name}"></a>'
                         f'<figcaption>{name}<br>{entry["width"]} × {entry["height"]}'
                         f'<br><code>{entry["sha256"]}</code></figcaption></figure>')
        cards.append('</div>')
    (output / "index.html").write_text(
        '<!doctype html><html lang="en"><meta charset="utf-8"><title>Beautiful AI UI visual review</title>'
        '<style>body{font:15px system-ui;margin:32px;color:#18212b;background:#eef1f4}'
        '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:24px;align-items:start}'
        'figure{margin:0;background:white;padding:12px}img{width:100%;height:auto}figcaption{overflow-wrap:anywhere}code{font-size:11px}</style>'
        '<h1>Supplemental visual review candidates</h1>'
        '<p>Open each image at full size. Exporting does not mark visual acceptance; '
        'see the separately recorded manual review and <a href="manifest.json">exact manifest</a>.</p>'
        + ''.join(cards) + '</html>\n'
    )
    print(f"Manifest: {manifest}\nSHA-256: {digest(manifest)}\nImages: {len(data['captures'])}")
    if before != after:
        raise SystemExit("Source files changed during capture. Re-export before accepting evidence.")
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
