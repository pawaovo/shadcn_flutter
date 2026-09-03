#!/usr/bin/env python3
"""Opt-in, pinned OFL fonts for headless release review, never package assets."""

import hashlib
import json
from pathlib import Path
import urllib.request


PACKAGE = Path(__file__).resolve().parents[2]
OUTPUT = PACKAGE / "build/release_review/fonts"
FILES = [
    {
        "file": "NotoSansCJKsc-Regular.otf",
        "url": "https://raw.githubusercontent.com/notofonts/noto-cjk/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf",
        "sha256": "2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b",
        "bytes": 16437364,
        "copyright": "© 2014-2021 Adobe (http://www.adobe.com/).",
        "version": "2.004",
        "license_file": "NotoSansCJK-OFL.txt",
    },
    {
        "file": "NotoSansCJK-OFL.txt",
        "url": "https://raw.githubusercontent.com/notofonts/noto-cjk/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/LICENSE",
        "sha256": "6a73f9541c2de74158c0e7cf6b0a58ef774f5a780bf191f2d7ec9cc53efe2bf2",
        "bytes": 4301,
    },
    {
        "file": "NotoSansArabic.ttf",
        "url": "https://raw.githubusercontent.com/google/fonts/f265cc2d8e08067dac782ba633458b97661ab85d/ofl/notosansarabic/NotoSansArabic%5Bwdth,wght%5D.ttf",
        "sha256": "63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e",
        "bytes": 844676,
        "copyright": "Copyright 2022 The Noto Project Authors (https://github.com/notofonts/arabic)",
        "version": "2.012",
        "license_file": "NotoSansArabic-OFL.txt",
    },
    {
        "file": "NotoSansArabic-OFL.txt",
        "url": "https://raw.githubusercontent.com/google/fonts/f265cc2d8e08067dac782ba633458b97661ab85d/ofl/notosansarabic/OFL.txt",
        "sha256": "07fc70bfeb985cc1a87a8587d0a0c80bab11c86c9dc3fd95b6f0cb332f983e96",
        "bytes": 4382,
    },
]


def valid(data, item):
    return len(data) == item["bytes"] and hashlib.sha256(data).hexdigest() == item["sha256"]


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for item in FILES:
        target = OUTPUT / item["file"]
        if target.exists() and valid(target.read_bytes(), item):
            continue
        with urllib.request.urlopen(item["url"], timeout=60) as response:
            data = response.read(item["bytes"] + 1)
        if not valid(data, item):
            raise RuntimeError(f"Pinned font verification failed: {item['file']}")
        target.write_bytes(data)
    manifest = {
        "schema": 1,
        "purpose": "Explicit test-only fallback; not shipped or evidence of native automatic fallback.",
        "license": "SIL Open Font License 1.1",
        "copyright_source": "Font name table, name ID 0; both font licenses are retained beside assets.",
        "files": FILES,
    }
    (OUTPUT / "provenance.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Verified {len(FILES)} pinned review font/license files: {OUTPUT}")


if __name__ == "__main__":
    main()
