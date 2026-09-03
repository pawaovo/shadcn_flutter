#!/usr/bin/env python3
"""Verify pinned dependency fonts, upstream bytes, and Flutter license coverage.

Uses only Python 3's standard library. Source verification is offline by
default. --verify-upstream downloads only the inventory's public artifacts
into a caller-selected or temporary cache. No source files are rewritten.

For a generated Flutter asset directory, --bundle verifies FontManifest,
typography bytes, and complete NOTICES/NOTICES.Z text. When icon fonts were
tree-shaken, pass the pinned SDK's --font-subset executable to reproduce each
transformation from the original font and the actual bundled Unicode cmap.
--require-complete-provenance additionally fails known acquisition gaps;
license text coverage alone is not a provenance or legal approval.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import platform
import re
import struct
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import urllib.parse
import zipfile
import zlib


SEPARATOR = "\n" + "-" * 80 + "\n"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalized(text: str) -> str:
    return " ".join(text.split())


def notice_blocks(text: str) -> dict[str, list[str]]:
    blocks: dict[str, list[str]] = {}
    for block in text.split(SEPARATOR):
        names, separator, body = block.strip().partition("\n\n")
        if not separator:
            raise ValueError("Malformed license block: missing package/body separator")
        for name in names.splitlines():
            blocks.setdefault(name, []).append(body)
    return blocks


def read_notices(path: Path) -> str:
    data = path.read_bytes()
    if data.startswith(b"\x1f\x8b"):
        data = gzip.decompress(data)
    return data.decode("utf-8")


def sfnt_tables(data: bytes) -> dict[str, bytes]:
    """Read raw OpenType/TrueType or decompressed WOFF tables."""
    tables = {}
    if data[:4] == b"wOFF":
        count = struct.unpack_from(">H", data, 12)[0]
        for index in range(count):
            tag, offset, compressed, original, _ = struct.unpack_from(
                ">4sIIII", data, 44 + 20 * index
            )
            raw = data[offset : offset + compressed]
            tables[tag.decode("ascii")] = (
                zlib.decompress(raw) if compressed < original else raw
            )
    elif data[:4] in (b"OTTO", b"\x00\x01\x00\x00", b"true"):
        count = struct.unpack_from(">H", data, 4)[0]
        for index in range(count):
            tag, _, offset, length = struct.unpack_from(
                ">4sIII", data, 12 + 16 * index
            )
            tables[tag.decode("ascii")] = data[offset : offset + length]
    else:
        raise ValueError("Unsupported font container")
    return tables


def unicode_cmap(font: bytes) -> dict[int, int]:
    """Read Unicode format 4/12 cmaps produced by Flutter's icon subsetter."""
    data = sfnt_tables(font)["cmap"]
    mappings = {}
    for index in range(struct.unpack_from(">H", data, 2)[0]):
        platform, encoding, offset = struct.unpack_from(">HHI", data, 4 + 8 * index)
        if platform != 0 and not (platform == 3 and encoding in (1, 10)):
            continue
        kind = struct.unpack_from(">H", data, offset)[0]
        if kind == 12:
            groups = struct.unpack_from(">I", data, offset + 12)[0]
            for group in range(groups):
                start, end, glyph = struct.unpack_from(
                    ">III", data, offset + 16 + 12 * group
                )
                if end - start > 0x110000:
                    raise ValueError("Invalid Unicode cmap group")
                for point in range(start, end + 1):
                    if glyph + point - start:
                        mappings[point] = glyph + point - start
        elif kind == 4:
            segments = struct.unpack_from(">H", data, offset + 6)[0] // 2
            ends = offset + 14
            starts = ends + 2 * segments + 2
            deltas = starts + 2 * segments
            ranges = deltas + 2 * segments
            for segment in range(segments):
                start = struct.unpack_from(">H", data, starts + 2 * segment)[0]
                end = struct.unpack_from(">H", data, ends + 2 * segment)[0]
                delta = struct.unpack_from(">h", data, deltas + 2 * segment)[0]
                relative = struct.unpack_from(">H", data, ranges + 2 * segment)[0]
                for point in range(start, min(end, 0xFFFE) + 1):
                    if relative:
                        location = ranges + 2 * segment + relative + 2 * (point - start)
                        glyph = struct.unpack_from(">H", data, location)[0]
                        glyph = (glyph + delta) & 0xFFFF if glyph else 0
                    else:
                        glyph = (point + delta) & 0xFFFF
                    if glyph:
                        mappings[point] = glyph
        else:
            raise ValueError(f"Unsupported Unicode cmap format {kind}")
    return mappings


def declared_fonts(pubspec: Path) -> dict[str, dict]:
    """Parse the pinned explicit font declarations; reject unexpected shapes.

    This intentionally does not implement arbitrary YAML aliases/tags. Such a
    pubspec migration needs an explicit inventory/parser update rather than
    silently bypassing verification.
    """
    family = None
    current = None
    fonts = {}
    in_fonts = False
    for line in pubspec.read_text().splitlines():
        if line.strip() == "fonts:" and family is None:
            in_fonts = True
            continue
        if not in_fonts:
            continue
        if line and not line[0].isspace() and not line.startswith("#"):
            break
        match = re.fullmatch(r"\s*- family:\s*['\"]?([^'\"]+)['\"]?\s*", line)
        if match:
            family = match.group(1).strip()
            current = None
            continue
        match = re.fullmatch(r"\s*- asset:\s*['\"]?([^'\"]+)['\"]?\s*", line)
        if match:
            if family is None:
                raise ValueError("Font asset has no family")
            current = match.group(1).strip()
            if current in fonts:
                raise ValueError(f"Duplicate font declaration: {current}")
            fonts[current] = {"family": family, "weight": 400, "style": "normal"}
            continue
        match = re.fullmatch(r"\s*(weight|style):\s*(\S+)\s*", line)
        if match and current:
            key, value = match.groups()
            fonts[current][key] = int(value) if key == "weight" else value
        elif line.strip() not in ("", "fonts:") and not line.lstrip().startswith("#"):
            raise ValueError(f"Unrecognized font declaration line: {line!r}")
    if not fonts:
        raise ValueError("No font declarations found")
    return fonts


def check_coverage(blocks: dict[str, list[str]], label: str, body: str) -> bool:
    return any(normalized(body) == normalized(text) for text in blocks.get(label, []))


def find_font_subset(root: Path) -> Path | None:
    config = root / ".dart_tool/package_config.json"
    if not config.is_file():
        return None
    for package in json.loads(config.read_text())["packages"]:
        if package["name"] != "flutter":
            continue
        uri = urllib.parse.urlparse(
            urllib.parse.urljoin(config.as_uri(), package["rootUri"])
        )
        if uri.scheme != "file":
            return None
        sdk = Path(urllib.request.url2pathname(uri.path)).parents[1]
        hosts = {
            "Darwin": ("darwin-arm64", "darwin-x64"),
            "Linux": ("linux-arm64", "linux-x64"),
            "Windows": ("windows-x64",),
        }.get(platform.system(), ())
        executable = "font-subset.exe" if platform.system() == "Windows" else "font-subset"
        for host in hosts:
            candidate = sdk / "bin/cache/artifacts/engine" / host / executable
            if candidate.is_file():
                return candidate
    return None


def verify(args: argparse.Namespace) -> dict:
    root = args.root.resolve()
    inventory = json.loads((root / args.inventory).read_text())
    errors: list[str] = []
    gaps = list(inventory["release_provenance_gaps"])
    result = {
        "inventory": args.inventory,
        "errors": errors,
        "provenance_gaps": gaps,
        "provenance_limitations": inventory.get("provenance_limitations", []),
    }
    notices = notice_blocks((root / inventory["dependency"]["notices"]).read_text())
    license_text = {}
    for item in inventory["licenses"]:
        data = (root / item["file"]).read_bytes()
        if sha256(data) != item["sha256"]:
            errors.append(f"License hash changed: {item['file']}")
        license_text[item["id"]] = data.decode()
        for label in item["notice_labels"]:
            if not check_coverage(notices, label, data.decode()):
                errors.append(f"Package NOTICES does not cover complete license for {label}")

    for item in inventory["required_additional_notices"]:
        if "sha256" in item and sha256((root / item["license_file"]).read_bytes()) != item["sha256"]:
            errors.append(f"Additional license hash changed: {item['license_file']}")
    pubspec = root / inventory["dependency"]["pubspec"]
    version = re.search(r"^version:\s*(\S+)\s*$", pubspec.read_text(), re.MULTILINE)
    if version is None or version.group(1) != inventory["dependency"]["version"]:
        errors.append("Dependency package version differs from the audited inventory")
    declarations = declared_fonts(pubspec)
    assets = inventory["assets"]
    runtime = [a for a in assets if a["runtime_declared"]]
    expected = {}
    for asset in assets:
        source = root / asset["path"]
        if not source.is_file() or sha256(source.read_bytes()) != asset["sha256"]:
            errors.append(f"Source asset hash changed or missing: {asset['path']}")
        if not asset.get("license_ids") or any(
            license_id not in license_text for license_id in asset["license_ids"]
        ):
            errors.append(f"Asset lacks a registered complete license: {asset['path']}")
        if asset["runtime_declared"]:
            path = asset["path"].removeprefix("packages/shadcn_flutter/")
            expected[path] = {k: asset[k] for k in ("family", "weight", "style")}
    if declarations != expected:
        errors.append("pubspec font declarations differ from registered paths/families/weights/styles")
    siblings = {
        str(path.relative_to(root))
        for directory in ("fonts", "icons")
        for path in (root / "packages/shadcn_flutter/lib" / directory).iterdir()
        if path.suffix.lower() in (".otf", ".ttf")
    }
    if siblings != {a["path"] for a in assets}:
        errors.append("Unregistered or removed font/icon source files")
    result["source_assets_checked"] = len(assets)
    result["runtime_fonts_checked"] = len(runtime)
    result["complete_notice_labels_checked"] = sum(
        len(item["notice_labels"]) for item in inventory["licenses"]
    )

    if args.verify_upstream:
        fetched = {}
        cache = args.cache.resolve() if args.cache else Path(tempfile.mkdtemp(prefix="font-audit-"))
        cache.mkdir(parents=True, exist_ok=True)
        for key, artifact in inventory["upstream_artifacts"].items():
            path = cache / artifact["cache_name"]
            if not path.exists():
                with urllib.request.urlopen(artifact["url"], timeout=60) as response:
                    path.write_bytes(response.read())
            data = path.read_bytes()
            if sha256(data) != artifact["sha256"]:
                errors.append(f"Upstream artifact hash changed: {key}")
                continue
            fetched[key] = data
        count = 0
        for asset in assets:
            key = asset.get("upstream_artifact")
            if not key or key not in fetched:
                continue
            artifact = inventory["upstream_artifacts"][key]
            data = fetched[key]
            if artifact["format"] == "zip":
                with zipfile.ZipFile(io.BytesIO(data)) as archive:
                    data = archive.read(asset["upstream_member"])
            elif artifact["format"] == "tar.gz":
                with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
                    member = archive.extractfile(asset["upstream_member"])
                    if member is None:
                        raise ValueError("Missing registered tar member")
                    data = member.read()
            source = (root / asset["path"]).read_bytes()
            equal = (
                sfnt_tables(source) == sfnt_tables(data)
                if asset["upstream_comparison"] == "all_sfnt_tables_equal"
                else source == data
            )
            if not equal:
                errors.append(f"Upstream bytes/tables differ: {asset['path']}")
            count += 1
        result["upstream_assets_verified"] = count

    if args.bundle:
        bundle = args.bundle.resolve()
        font_manifest = json.loads((bundle / "FontManifest.json").read_text())
        actual = {}
        for family in font_manifest:
            for font in family["fonts"]:
                if font["asset"] in actual:
                    errors.append(f"Duplicate bundled font: {font['asset']}")
                actual[font["asset"]] = {
                    "family": family["family"].removeprefix("packages/shadcn_flutter/"),
                    "weight": font.get("weight", 400),
                    "style": font.get("style", "normal"),
                }
        expected_manifest = {"packages/shadcn_flutter/" + key: value for key, value in expected.items()}
        if actual != expected_manifest:
            errors.append("Generated FontManifest differs from the registered runtime font set")
        notice_file = next((bundle / name for name in ("NOTICES", "NOTICES.Z") if (bundle / name).is_file()), None)
        if notice_file is None:
            raise ValueError("Bundle has neither NOTICES nor NOTICES.Z")
        bundle_notices = notice_blocks(read_notices(notice_file))
        for item in inventory["licenses"]:
            for label in item["notice_labels"]:
                if not check_coverage(bundle_notices, label, license_text[item["id"]]):
                    errors.append(f"Built NOTICES lacks complete {label} license")
        for item in inventory["required_additional_notices"]:
            body = (root / item["license_file"]).read_text()
            if "source_label" in item:
                body = notice_blocks(body)[item["source_label"]][0]
            if not check_coverage(bundle_notices, item["label"], body):
                errors.append(f"Built NOTICES lacks complete {item['label']} license")
        built_assets = []
        font_subset = args.font_subset or find_font_subset(root)
        with tempfile.TemporaryDirectory(prefix="font-subset-audit-") as temporary:
            for asset in runtime:
                path = bundle / asset["path"]
                if not path.is_file():
                    errors.append(f"Bundled font missing: {asset['path']}")
                    continue
                data = path.read_bytes()
                status = "exact_source_bytes"
                if sha256(data) != asset["sha256"]:
                    if "/icons/" not in asset["path"]:
                        errors.append(f"Unexpected typography transform: {asset['path']}")
                        status = "unexpected_transform"
                    elif font_subset:
                        points = sorted(unicode_cmap(data))
                        if not points:
                            errors.append(f"Bundled icon font has no Unicode cmap: {asset['path']}")
                            continue
                        output = Path(temporary) / path.name
                        process = subprocess.run(
                            [str(font_subset.resolve()), str(output), str(root / asset["path"])],
                            input=" ".join(map(str, points)) + "\n", text=True,
                            capture_output=True, check=False,
                        )
                        if process.returncode != 0 or not output.exists() or output.read_bytes() != data:
                            errors.append(f"Cannot reproduce icon subset exactly: {asset['path']}")
                            status = "subset_mismatch"
                        else:
                            status = "reproduced_flutter_icon_subset"
                    else:
                        errors.append(f"Icon transform requires --font-subset verification: {asset['path']}")
                        status = "unverified_icon_transform"
                built_assets.append({"path": asset["path"], "bytes": len(data), "sha256": sha256(data), "status": status})
        result["bundle"] = str(bundle)
        result["notice_sha256"] = sha256(notice_file.read_bytes())
        result["built_assets"] = built_assets
        result["font_subset"] = str(font_subset.resolve()) if font_subset else None
        result["built_notice_labels"] = [label for item in inventory["licenses"] for label in item["notice_labels"]]
    if args.require_complete_provenance and gaps:
        errors.extend("Release provenance incomplete: " + gap for gap in gaps)
    result["passed"] = not errors
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--inventory", default="legal/dependency_assets.json")
    parser.add_argument("--bundle", type=Path, help="Directory containing FontManifest.json and NOTICES(.Z)")
    parser.add_argument("--font-subset", type=Path, help="Override the font-subset executable located from the resolved Flutter SDK")
    parser.add_argument("--verify-upstream", action="store_true")
    parser.add_argument("--cache", type=Path, help="Cache directory for public upstream artifacts")
    parser.add_argument("--require-complete-provenance", action="store_true")
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()
    try:
        result = verify(args)
    except (OSError, ValueError, KeyError, struct.error, zipfile.BadZipFile, tarfile.TarError) as error:
        result = {"passed": False, "errors": [str(error)]}
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
