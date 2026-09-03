# Transitive runtime media audit

Captured: 2026-09-03 (Asia/Shanghai)
Inventory: `legal/transitive_media_assets.json`
Verifier: `tool/audit_transitive_media.py` (Python standard library only)
Actual JavaScript/Wasm results: `legal/transitive_media_runtime_evidence.json`

## Fixed distributable source

The Catalog's actual Web bundle contains 266 scalable-image binary files from `country_flags` 4.1.2, totaling **2,601,667 bytes**. Each inventory entry records its package-relative path, bundle-relative path, byte size, and SHA-256. Every bundled flag was compared byte for byte with the resolved package cache.

The root `pubspec.lock` fixes the package to the official pub.dev archive:

- Archive: https://pub.dev/api/archives/country_flags-4.1.2.tar.gz
- Archive bytes: 13,091,633
- SHA-256: `f022d18337f3861f1f4e319b936cb53920de9259f38cb09e169eace9942e2b79`
- Official published timestamp: `2026-01-26T05:57:46.211625Z`
- Registry metadata: https://pub.dev/api/packages/country_flags/versions/4.1.2
- Declared runtime asset directory: `res/si/`

A fresh official archive download matched the locked hash. Its 266 media members plus `LICENSE`, `README.md`, `pubspec.yaml`, and `CHANGELOG.md` all matched the resolved cache exactly: **270 verified archive members**. The package's own `pubspec.yaml` declares version 4.1.2 and its MIT license names Arturo Grau. All four source-document hashes are retained in the inventory.

## Artwork attribution and notices

The fixed package README, line 122, credits `lipis/flag-icons` for the original SVG flags. It also identifies `jovial_svg` as the binary-image renderer. The README does not declare the specific original SVG revision; this is recorded explicitly. The shipped SI files remain precisely identified by the locked pub archive and per-file hashes. Reconstructing an unrecorded upstream conversion is not an additional release gate.

Two complete official notices are preserved:

| File | Copyright | SHA-256 |
| --- | --- | --- |
| `LICENSES/COUNTRY_FLAGS_4_1_2_MIT.txt` | Arturo Grau | `cd0268576305886aa32fa26c31787a434761efb0bd0740d20e0434574d66362f` |
| `LICENSES/FLAG_ICONS_MIT.txt` | 2013 Panayiotis Lipiridis | `8f1195d55a2fd315a07d812328470ca9ba2abb78c8d317ff19619d5125e00cea` |

The first notice is copied directly from the verified pub archive. The second is copied directly from the official source at https://raw.githubusercontent.com/lipis/flag-icons/086f7e97d657358203916dbe84f61c2bccaa81eb/LICENSE. That commit fixes the license evidence; it is **not** asserted as the undisclosed SVG revision used by `country_flags`.

Fresh JavaScript and Wasm Web builds both passed the generated-notice check: the full Arturo Grau MIT appears under `country_flags`, and the full Panayiotis Lipiridis MIT appears under `flag-icons`. These notices are now supplied by the unified registry. The media audit's bundle gate requires both full MIT bodies under their respective labels and fails if either is absent. It reads both ordinary `NOTICES` and gzip `NOTICES.Z` when present.

## Complete runtime media coverage

The actual inspected Web output has exactly **271 standalone media files**: 266 transitive flag files and the five already registered original Web images (`favicon.png` and four launcher/maskable PNGs). No other standalone images, audio files, or video files were found. The original artwork is checked against `legal/catalog_original_assets.json`; fonts remain in the separate dependency-font inventory.

The verifier scans all Web output files using media extensions and common binary/XML signatures, including the observed scalable-image header. A new, missing, modified, or unregistered media file fails the bundle audit. The package's documentation/example screenshots are present in its pub archive but are not in the actual runtime bundle.

An isolated synthetic fixture verified one complete positive case and five rejection cases: a PNG disguised with a `.bin` extension, an extra WAV, modified flag bytes, a missing flag, and the omitted upstream MIT notice. These probes did not modify the dependency cache or actual Web output.

Fresh **JavaScript and Wasm builds both passed** the complete runtime media audit. Each reports 271 registered media files, comprising 266 flag binaries and five original icons, with zero audio/video files and both complete MIT notices. The actual JSON results and source-log hashes are saved in `legal/transitive_media_runtime_evidence.json`. A subsequent read-only check of the current Wasm output matched all 271 media hashes and both complete license bodies again. The earlier stale favicon and missing upstream-notice findings are resolved.

## Commands

```sh
# Offline: fixed lock/cache, exact flag bytes, and local license copies.
python3 tool/audit_transitive_media.py

# Freshly built Web artifact: all media bytes and both full MIT notices.
python3 tool/audit_transitive_media.py \
  --bundle packages/beautiful_ai_ui_catalog/build/web

# Official upstream archive + official fixed license. Downloads are read-only.
python3 tool/audit_transitive_media.py --verify-upstream

# The archive can instead be supplied from a previous verified download.
python3 tool/audit_transitive_media.py --verify-upstream \
  --archive /tmp/country_flags-4.1.2.tar.gz
```

Central inventory registration is present in `legal/assets.yaml` as `country_flags_transitive_media`, with inherited MIT distribution and this exhaustive path/hash inventory. The original Catalog launcher entry is approved separately. Both copyright notices are included in the generated license registry, as verified in the fresh JavaScript and Wasm results.
