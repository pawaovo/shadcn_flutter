# Original Catalog icon and launch artwork

Date: 2026-09-03 (Asia/Shanghai)
Asset identity: `catalog_original_panel_mark`
Creator: Codex AI assistant, creating original numeric geometry for the Beautiful AI UI project at the user's request.
Distribution license: BSD-3-Clause, under the repository `LICENSE`.

The artwork is an original arrangement of three rounded rectangles: a vertical navigation panel beside two stacked content cards. It uses the project's dark surface and blue palette. No external reference image, downloaded logo, font, brand mark, trademark text, or third-party artwork was used. The SVG is the editable source of truth.

Source: `packages/beautiful_ai_ui_catalog/branding/catalog-icon.svg`
Generator: `packages/beautiful_ai_ui_catalog/tool/generate_catalog_icons.py`
Per-file provenance and SHA-256: `legal/catalog_original_assets.json`
Portable hash list: `legal/catalog_original_assets.sha256`

## Reproduction

```sh
python3 packages/beautiful_ai_ui_catalog/tool/generate_catalog_icons.py
python3 packages/beautiful_ai_ui_catalog/tool/generate_catalog_icons.py --check
shasum -a 256 -c legal/catalog_original_assets.sha256
```

The generator uses only Python's standard library. It reads solid rounded-rectangle geometry from the SVG, integrates horizontal pixel coverage over eight vertical samples, and writes PNG/ICO directly. PNGs carry an sRGB declaration and no timestamps. Windows receives a 256px PNG frame plus 48/32/16px 32-bit DIB frames with alpha masks. No network, external renderer, or imaging dependency is required.

Exact regeneration was checked with Python 3.12.13 and Python 3.14.6, both using zlib 1.2.12. Both runs reproduced all checked-in image and manifest bytes.

## Platform coverage

| Destination | Generated image contract |
| --- | --- |
| Android launcher | Existing 48, 72, 96, 144, and 192px resources; rounded dark tile with alpha corners |
| Android launch screen | New density-matched 96, 144, 192, 288, and 384px transparent marks, corresponding to a 96dp logical image; existing drawable and drawable-v21 backgrounds center the mark over `#17181a` |
| iOS AppIcon | All 15 existing filenames and `Contents.json` sizes retained, from 20 to 1024px; opaque RGB background |
| iOS launch screen | Existing three 1x/2x/3x filenames retained, replacing 1px transparent placeholders with 96/192/288px marks; storyboard intrinsic size is 96x96 and its background matches the dark surface |
| macOS AppIcon | All seven existing filenames and sizes retained: 16, 32, 64, 128, 256, 512, and 1024px |
| Web | Existing 16px favicon and 192/512px normal and maskable icons; maskable images are opaque RGB and their mark is inside the central circle of radius 40% of image width; manifest theme/background colors match the artwork |
| Windows | Existing `app_icon.ico` replaced with unique 16, 32, 48, and 256px frames; redundant template bit-depth variants are removed |

Total: 40 PNG files and one four-frame ICO. The independent manifest contains 47 hashed artwork, generator, source, and resource-configuration records. All 36 paths listed in `legal/catalog_template_assets.sha256` are covered, and every previous template image hash has changed. That old manifest remains historical evidence; the new manifest is the active inventory for these destinations.

## Verification evidence

- Generation followed by `--check` passed without modifications on both recorded Python runtimes.
- All 47 file hashes were checked against disk. All PNG signatures, IHDR dimensions/color types, chunk CRCs, decompressed lengths, and scanline filters were validated.
- Every iOS/macOS `Contents.json` image reference matches its expected scaled dimensions. All generated iOS and maskable PNGs use RGB without an alpha channel.
- The Windows directory and each 256/48/32/16px frame were parsed. macOS `sips` successfully decoded the ICO for independent visual inspection.
- Both Android launch XML files and the iOS launch storyboard parse successfully. Existing image asset-set identities remain intact.
- `view_image` inspection covered the 512px rounded icon, 512px opaque maskable icon, 288px transparent launch mark, the actual 16px favicon, and the independently decoded Windows icon. All showed the intended three-panel geometry with clean boundaries and no text, missing glyphs, clipping, or inherited Flutter logo.

This evidence closes the inherited launcher-art replacement requirement. Fresh platform builds remain the place to validate packaging and launch presentation; ignored `build/` outputs were not edited as source assets.

## Suggested central inventory update

Replace the `flutter_generated_catalog_launcher_assets` entry in `legal/assets.yaml` with an approved, distributable original-artwork entry named `catalog_original_launcher_assets`, or keep the existing ID and clearly mark its replacement. Point `hash_manifest` to `legal/catalog_original_assets.sha256` and the detailed source/creator/generation record to `legal/catalog_original_assets.json`. Include the new Android `drawable-*/catalog_launch_mark.png` paths and retained launch configurations in its destinations. Remove the local/CI-only restriction and Flutter-logo statement for these replaced artwork paths. The inherited Flutter SDK software notice remains independent of this artwork replacement.
