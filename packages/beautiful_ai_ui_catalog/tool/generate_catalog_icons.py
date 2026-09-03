#!/usr/bin/env python3
"""Rebuild original Catalog artwork from SVG using Python's standard library.

SPDX-License-Identifier: BSD-3-Clause
Original generator and numeric artwork authored by Codex for Beautiful AI UI,
2026-09-03. No third-party graphic, font, logo, network, or imaging package is used.

Run from any directory:
  python3 packages/beautiful_ai_ui_catalog/tool/generate_catalog_icons.py
  python3 packages/beautiful_ai_ui_catalog/tool/generate_catalog_icons.py --check

The intentionally small renderer supports the SVG's solid rounded rectangles.
It integrates horizontal pixel coverage at eight vertical samples. PNGs have
fixed sRGB declarations and no timestamps; ICO uses PNG at 256px and 32-bit DIB
at 16/32/48px. RGB iOS/maskable files are opaque; other outputs retain alpha.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import xml.etree.ElementTree as ET
import zlib

ROOT = Path(__file__).resolve().parents[3]
CATALOG = ROOT / "packages/beautiful_ai_ui_catalog"
SOURCE = CATALOG / "branding/catalog-icon.svg"
MANIFEST = ROOT / "legal/catalog_original_assets.json"
HASHES = ROOT / "legal/catalog_original_assets.sha256"
CREATED = "2026-09-03"
SVG_NS = "{http://www.w3.org/2000/svg}"
SAMPLES = 8
DARK = (0x17, 0x18, 0x1a, 255)


def rects() -> list[dict]:
    root = ET.parse(SOURCE).getroot()
    if root.get("viewBox") != "0 0 1024 1024":
        raise ValueError("The artwork requires a 1024-square SVG viewBox.")
    result = []
    for element in root:
        if element.tag in (SVG_NS + "title", SVG_NS + "desc"):
            continue
        if element.tag != SVG_NS + "rect":
            raise ValueError("Only solid SVG rounded rectangles are supported.")
        color = element.attrib["fill"]
        if len(color) != 7 or not color.startswith("#"):
            raise ValueError("Artwork colors must be six-digit hexadecimal.")
        shape = {key: float(element.get(key, "0"))
                 for key in ("x", "y", "width", "height", "rx")}
        shape.update(id=element.attrib["id"],
                     color=tuple(int(color[i:i + 2], 16) for i in (1, 3, 5)))
        result.append(shape)
    return result


def paint_rect(pixels: bytearray, size: int, shape: dict) -> None:
    scale = size / 1024
    left, top = shape["x"] * scale, shape["y"] * scale
    width, height = shape["width"] * scale, shape["height"] * scale
    radius = min(shape["rx"] * scale, width / 2, height / 2)
    color = shape["color"]
    solid = bytes((*color, 255))
    for y in range(max(0, math.floor(top)), min(size, math.ceil(top + height))):
        spans = []
        for sample in range(SAMPLES):
            sy = y + (sample + 0.5) / SAMPLES
            if not top <= sy < top + height:
                continue
            dy = max(top + radius - sy, sy - (top + height - radius), 0)
            inset = radius - math.sqrt(max(0, radius * radius - dy * dy))
            spans.append((left + inset, left + width - inset))
        if not spans:
            continue
        start = max(0, math.floor(min(a for a, _ in spans)))
        end = min(size, math.ceil(max(b for _, b in spans)))
        full_start = min(end, max(start, math.ceil(max(a for a, _ in spans))))
        full_end = max(full_start, min(end, math.floor(min(b for _, b in spans))))
        if len(spans) != SAMPLES:
            full_start = full_end = start
        if full_end > full_start:
            offset = (y * size + full_start) * 4
            pixels[offset:offset + (full_end - full_start) * 4] = (
                solid * (full_end - full_start))
        for a, b in ((start, full_start), (full_end, end)):
            for x in range(a, b):
                coverage = sum(max(0, min(x + 1, hi) - max(x, lo))
                               for lo, hi in spans) / SAMPLES
                alpha = min(255, round(coverage * 255))
                if alpha <= 0:
                    continue
                offset = (y * size + x) * 4
                previous = pixels[offset:offset + 4]
                retained = previous[3] * (255 - alpha) / 255
                output_alpha = alpha + retained
                pixels[offset:offset + 4] = bytes((
                    *(round((color[i] * alpha + previous[i] * retained) /
                            output_alpha) for i in range(3)),
                    round(output_alpha)))


def raster(size: int, profile: str, shapes: list[dict]) -> bytes:
    pixels = bytearray(bytes(DARK if profile == "opaque" else (0, 0, 0, 0))
                       * size * size)
    for shape in shapes:
        if shape["id"] == "background" and profile in ("opaque", "mark"):
            continue
        paint_rect(pixels, size, shape)
    return bytes(pixels)


def chunk(kind: bytes, payload: bytes) -> bytes:
    return (struct.pack(">I", len(payload)) + kind + payload +
            struct.pack(">I", zlib.crc32(kind + payload) & 0xffffffff))


def png(size: int, rgba: bytes, opaque: bool) -> bytes:
    channels = 3 if opaque else 4
    if opaque:
        if any(rgba[index] != 255 for index in range(3, len(rgba), 4)):
            raise ValueError("An opaque platform image contains transparency.")
        rgb = bytearray(size * size * 3)
        for channel in range(3):
            rgb[channel::3] = rgba[channel::4]
        data = bytes(rgb)
    else:
        data = rgba
    stride = size * channels
    scanlines = b"".join(b"\0" + data[y * stride:(y + 1) * stride]
                         for y in range(size))
    return (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8,
                                       2 if opaque else 6, 0, 0, 0)) +
            chunk(b"sRGB", b"\0") + chunk(b"IDAT", zlib.compress(scanlines, 9)) +
            chunk(b"IEND", b""))


def ico(frames: dict[int, tuple[bytes, bytes]]) -> bytes:
    sizes = (256, 48, 32, 16)
    payloads = []
    for size in sizes:
        image, rgba = frames[size]
        if size == 256:
            payloads.append(image)
            continue
        row_width = size * 4
        bitmap = bytearray()
        for y in range(size - 1, -1, -1):
            row = rgba[y * row_width:(y + 1) * row_width]
            for x in range(size):
                red, green, blue, alpha = row[x * 4:x * 4 + 4]
                bitmap.extend((blue, green, red, alpha))
        mask_stride = ((size + 31) // 32) * 4
        mask = bytearray(mask_stride * size)
        for y in range(size):
            for x in range(size):
                if rgba[((size - 1 - y) * size + x) * 4 + 3] == 0:
                    mask[y * mask_stride + x // 8] |= 1 << (7 - x % 8)
        header = struct.pack("<IiiHHIIiiII", 40, size, size * 2, 1, 32, 0,
                             len(bitmap) + len(mask), 0, 0, 0, 0)
        payloads.append(header + bitmap + mask)
    offset = 6 + 16 * len(sizes)
    directory = bytearray(struct.pack("<HHH", 0, 1, len(sizes)))
    for size, data in zip(sizes, payloads):
        directory.extend(struct.pack("<BBBBHHII", size % 256, size % 256,
                                     0, 0, 1, 32, len(data), offset))
        offset += len(data)
    return bytes(directory) + b"".join(payloads)


def output_specs() -> dict[Path, tuple[int, str]]:
    specs = {}
    for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                          ("xxhdpi", 144), ("xxxhdpi", 192)):
        resources = CATALOG / "android/app/src/main/res"
        specs[resources / f"mipmap-{density}/ic_launcher.png"] = (size, "icon")
        specs[resources / f"drawable-{density}/catalog_launch_mark.png"] = (
            size * 2, "mark")
    for platform, profile in (("ios", "opaque"), ("macos", "icon")):
        assets = CATALOG / platform / "Runner/Assets.xcassets/AppIcon.appiconset"
        for item in json.loads((assets / "Contents.json").read_text())["images"]:
            logical = float(item["size"].split("x")[0])
            scale = float(item["scale"].removesuffix("x"))
            specs[assets / item["filename"]] = (round(logical * scale), profile)
    launch = CATALOG / "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for scale in (1, 2, 3):
        suffix = "" if scale == 1 else f"@{scale}x"
        specs[launch / f"LaunchImage{suffix}.png"] = (96 * scale, "mark")
    specs[CATALOG / "web/favicon.png"] = (16, "icon")
    for size in (192, 512):
        specs[CATALOG / f"web/icons/Icon-{size}.png"] = (size, "icon")
        specs[CATALOG / f"web/icons/Icon-maskable-{size}.png"] = (size, "opaque")
    return specs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="Verify exact generated bytes and manifest without writing.")
    args = parser.parse_args()
    shapes = rects()
    specs = output_specs()
    cache = {}
    outputs = {}
    records = []
    for path, (size, profile) in sorted(specs.items()):
        key = (size, profile)
        if key not in cache:
            rgba = raster(size, profile, shapes)
            cache[key] = (png(size, rgba, profile == "opaque"), rgba)
        outputs[path] = cache[key][0]
        records.append({"path": str(path.relative_to(ROOT)), "kind": "png",
                        "width": size, "height": size, "profile": profile})
    frames = {}
    for size in (256, 48, 32, 16):
        key = (size, "icon")
        if key not in cache:
            rgba = raster(size, "icon", shapes)
            cache[key] = (png(size, rgba, False), rgba)
        frames[size] = cache[key]
    icon = CATALOG / "windows/runner/resources/app_icon.ico"
    outputs[icon] = ico(frames)
    records.append({"path": str(icon.relative_to(ROOT)), "kind": "ico",
                    "frames": [256, 48, 32, 16], "profile": "icon"})
    sources = [SOURCE, Path(__file__).resolve(),
               CATALOG / "android/app/src/main/res/drawable/launch_background.xml",
               CATALOG / "android/app/src/main/res/drawable-v21/launch_background.xml",
               CATALOG / "ios/Runner/Base.lproj/LaunchScreen.storyboard",
               CATALOG / "web/manifest.json"]
    for path in sources:
        records.append({"path": str(path.relative_to(ROOT)),
                        "kind": "source" if path.suffix in (".py", ".svg") else
                        "platform_resource_configuration"})
    for record in records:
        path = ROOT / record["path"]
        data = outputs[path] if path in outputs else path.read_bytes()
        record["sha256"] = hashlib.sha256(data).hexdigest()
    records.sort(key=lambda record: record["path"])
    manifest = {
        "schema_version": 1, "asset_id": "catalog_original_panel_mark",
        "created_date": CREATED,
        "creator": "Codex AI assistant, original code-authored geometry for Beautiful AI UI",
        "source_inputs": ["Original numeric rounded-rectangle geometry",
                          "Project dark and blue color palette"],
        "external_artwork_fonts_logos_or_trademarks": False,
        "license": "BSD-3-Clause", "license_file": "LICENSE",
        "source_svg": str(SOURCE.relative_to(ROOT)),
        "generator": str(Path(__file__).resolve().relative_to(ROOT)),
        "generation_method": "Python standard library SVG rectangle rasterizer; "
                             "8 vertical coverage samples; deterministic PNG and ICO",
        "reproduction_command": "python3 packages/beautiful_ai_ui_catalog/tool/"
                                "generate_catalog_icons.py --check",
        "profile_notes": {
            "icon": "Rounded dark tile with transparent corners; original panel artwork.",
            "opaque": "RGB dark background; all panels inside the central 80% maskable circle.",
            "mark": "Transparent panel-only launch mark in a 96dp logical canvas."},
        "replaces": "flutter_generated_catalog_launcher_assets",
        "records": records,
    }
    outputs[MANIFEST] = (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode()
    outputs[HASHES] = "".join(f'{r["sha256"]}  {r["path"]}\n'
                              for r in records).encode()
    mismatches = []
    for path, data in outputs.items():
        if args.check:
            if not path.is_file() or path.read_bytes() != data:
                mismatches.append(str(path.relative_to(ROOT)))
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
    if mismatches:
        print("Generated artwork differs:\n" + "\n".join(mismatches), file=sys.stderr)
        return 1
    verb = "Verified" if args.check else "Generated"
    print(f"{verb} {len(specs)} PNGs, one four-frame ICO, and two asset manifests; "
          f"{len(records)} hashed artwork/source/configuration records.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
