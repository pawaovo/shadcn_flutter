# Dependency asset and generated-license audit

Date: 2026-09-03 (Asia/Shanghai)
Dependency baseline: `shadcn_flutter 0.0.54`, source commit
`5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73`
Toolchain: Flutter `3.47.0`, Dart `3.13.0`, local macOS arm64
Status: source/hash, generated LicenseRegistry, and refreshed JavaScript,
Wasm, and macOS release artifact coverage verified

## Result and scope

The audit identified and repaired a real distribution omission: the Catalog
declared **34 Geist typography files and three icon fonts**, but its generated
Web `NOTICES` contained none of their Geist/OFL, Bootstrap, Lucide/Feather,
or Radix notices. The nested `lib/fonts/LICENSE.txt` was not collected by
Flutter and preserved only the older 2023 notice, while the modern fonts
identify the 2024 Geist Project Authors.

`packages/shadcn_flutter/NOTICES` now preserves the dependency's original BSD
text and full asset notices in Flutter's supported format. The source `LICENSE`
and all font/icon binaries are unchanged. The transitive flag-icons MIT
notice, identified by the separate media audit, is included too. The actual
Flutter `LicenseRegistry` probe now reads **13 complete package/asset labels**
from a freshly generated `NOTICES.Z`; it does not inject synthetic entries.

The machine-readable inventory is
[`legal/dependency_assets.json`](../../../legal/dependency_assets.json).
It records each of 43 source font files individually: 37 declared runtime
fonts/icons plus six undeclared sibling OTF files. Every entry includes file
size/SHA256, family, declared weight/style where applicable, internal name-table
metadata, fixed dependency version/commit, upstream acquisition artifact, and
license IDs. Each license has a preserved full-text file, source URL, SHA256,
and expected generated registry labels.

The policy in [`legal/assets.yaml`](../../../legal/assets.yaml) accepts a
source version **or hash**. This audit checks those concrete acquisition
boundaries and does not invent an unavailable original generator version.
Asset distribution approval remains in that policy file, not in a passing
hash-check result.

## Exact asset origins

| Group | Source files / declared runtime files | Verified origin |
|---|---:|---|
| Modern Geist Sans | 18 / 15 | Every source file exactly matches the official Geist `1.5.1` release ZIP; embedded font version `1.510` |
| Modern Geist Mono | 18 / 15 | Every source file exactly matches the same official `1.5.1` release ZIP; embedded font version `1.510` |
| Legacy Geist Sans UltraLight/UltraBlack | 2 / 2 | Both files exactly match official Geist `1.1.0` release `Geist.zip`; embedded font version `1.002` |
| Legacy Geist Mono UltraLight/UltraBlack | 2 / 2 | Both files exactly match official Geist `1.1.0` release `Geist.Mono.zip`; embedded font version `1.002` |
| Bootstrap Icons | 1 / 1 | All SFNT tables in the inherited OTF exactly match the decompressed official `1.11.3` WOFF |
| Lucide | 1 / 1 | `LucideIcons.ttf` exactly matches `package/font/lucide.ttf` from the published `lucide-static 0.479.0` archive |
| Radix Icons | 1 / 1 | Binary exactly matches the file in the fixed `shadcn_flutter` source commit; that dependency explicitly attributes the mapped constants to Radix Icons |

The official modern [Geist release](https://github.com/vercel/geist-font/releases/tag/1.5.1)
archive SHA256 is
`2e5495158a952ac839dfbb371d4910d2f6f0ea8e0253f103bc6cf66041886e4c`.
The release ZIP is the matching source: the repository's same-named tag files
do not all match that release binary, including older Mono content and header
timestamps. The inventory records the actual matching archive members rather
than asserting a byte match against those different tag files.

The legacy source is the official
[Geist 1.1.0 release](https://github.com/vercel/geist-font/releases/tag/1.1.0).
Its copyright notice and the modern
[Geist OFL notice](https://github.com/vercel/geist-font/blob/3c80bfcc1ba4988ece0eda46a282e15d29e61bbf/OFL.txt)
are preserved separately. Inter and JetBrains Mono are not in this declared
asset set. The six undeclared siblings are ExtraBold, ExtraBoldItalic, and
ExtraLight for both Geist families; the audit tracks them without treating
them as Catalog runtime assets.

The source icon font hashes are:

| File | SHA256 |
|---|---|
| `BootstrapIcons.otf` | `497a6cf64228ef94f377a6d1fbd115fa9c8f95f34906e84fce2fd76ca00ec22d` |
| `LucideIcons.ttf` | `b71c60320ddba98adc44e8b0257fb810f6f04b4c74ba46e81569ad9f4449ff95` |
| `RadixIcons.otf` | `581783cc200858b1d9dc57bace8cffc31f419faaa86b748d8b4af080028665af` |

Their internal generic font `Version 1.0` strings are not evidence of the
Bootstrap, Lucide, or Radix library release. Bootstrap's conversion is
verified against the [fixed official WOFF](https://github.com/twbs/icons/blob/8d88686c03c3768a2d82ba4f20c3c4e1b100fa29/font/fonts/bootstrap-icons.woff).
Lucide's font is pinned to the official npm release and its
[ISC notice](https://github.com/lucide-icons/lucide/blob/aefb710e5c64b3d569b6e3eafa7516c273a1bf4a/LICENSE);
the notice identifies Feather-derived material, so the full Feather MIT text
is preserved as a separate block as well.

For Radix, the [fixed dependency binary](https://github.com/sunarya-thito/shadcn_flutter/blob/5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73/packages/shadcn_flutter/lib/icons/RadixIcons.otf)
and its [Radix attribution](https://github.com/sunarya-thito/shadcn_flutter/blob/5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73/packages/shadcn_flutter/lib/src/icons/radix_icons.dart)
establish the audited acquisition boundary. The
[official Radix MIT notice](https://github.com/radix-ui/icons/blob/112af91ad275a63c3a29b0da2588342af74ef9bf/LICENSE)
is preserved. The original SVG release and Iconly conversion recipe are not
recorded, and this audit makes no claim to have reproduced that earlier
conversion. Recovering an unspecified original tool version is not added as
a new requirement beyond the existing version-or-hash policy.

## Notification repair and real registry coverage

The dependency-root `NOTICES` has eight full-text blocks: shadcn BSD, modern
Geist OFL, legacy Geist OFL, Bootstrap MIT, Lucide ISC, Feather MIT, Radix MIT,
and flag-icons MIT. Geist blocks each carry both relevant family labels.
The generated registry also retains `beautiful_ai_ui`, `beautiful-ui`, and
the original `country_flags` MIT block supplied by those packages.

The additional country flag notice applies to 266 `.si` files supplied by
`country_flags 4.1.2`, whose README attributes the SVGs to `lipis/flag-icons`.
The flag-icons license commit identifies the notice source; it is not claimed
as the exact source revision of the compiled `.si` files. The separate media
inventory fixes their published package archive and individual hashes.

Flutter's pinned `LicenseCollector` reads a package-root `NOTICES` before
falling back to `LICENSE`. It splits multi-license files at a line of exactly
80 hyphens and expects package labels before each text block. The default
`ServicesBinding` then loads generated `NOTICES` on Web or `NOTICES.Z` on
native platforms into `LicenseRegistry`.

The new probe uses the production `WidgetsFlutterBinding`, because
`TestWidgetsFlutterBinding.initLicenses` deliberately suppresses normal
license registration. The probe compares the complete normalized paragraph
text for every expected label; it does not merely search for a copyright
keyword or register a replacement collector.

## Reproducible checks

From the repository root, verify source assets, all local notice texts,
font declarations, and recorded provenance gates:

```sh
python3 tool/audit_dependency_assets.py --require-complete-provenance
```

Add official artifact comparison. The cache is outside the repository, and
downloaded bytes must match the recorded archive hashes before inspection:

```sh
python3 tool/audit_dependency_assets.py \
  --verify-upstream \
  --cache /tmp/beautiful-ui-license-audit \
  --require-complete-provenance
```

For a fresh generated Web or native asset directory:

```sh
python3 tool/audit_dependency_assets.py \
  --bundle packages/beautiful_ai_ui_catalog/build/web/assets \
  --require-complete-provenance \
  --json-output /tmp/beautiful-ui-web-license-audit.json
```

The script locates `font-subset` through the resolved Flutter SDK in
`.dart_tool/package_config.json`; `--font-subset /absolute/path/to/font-subset`
can override that location. If a built icon font differs from its original,
the script extracts its actual Unicode cmap, invokes that pinned subsetter
against the original font, and requires identical output bytes. An unknown
icon transformation fails. Non-icon typography must remain byte-identical.
Each built font's size/hash and transformation result is recorded in JSON.

To run the real registry probe from `packages/beautiful_ai_ui_catalog`:

```sh
flutter test ../../tool/probe_dependency_license_registry.dart --no-pub
```

When adding a new package-root notice, ensure the generated asset bundle is
fresh. Flutter's test command uses `build/unit_test_assets/AssetManifest.bin`
as its rebuild sentinel; removing only the generated `NOTICES.Z` does not
force a rebuild. A fresh test asset directory, or removing that generated
manifest before the probe, makes the Flutter tool collect and write current
notices. No source asset or license is generated by the audit scripts.

## Recorded execution

| Check | Result |
|---|---|
| All source hashes and font declarations | Passed: 43 files, including all 37 declared runtime files |
| Official upstream acquisition comparison | Passed: 43 assets at the documented origin boundary; Radix's earlier conversion remains explicitly unclaimed |
| Complete dependency-root notice text | Passed: ten asset/package labels across eight full license blocks |
| Negative hash guard | A temporary inventory with a forged source hash correctly exited 1 |
| Negative provenance gate | A temporary inventory containing a deliberate unresolved gate correctly exited 1 with `--require-complete-provenance` |
| Old Web artifact | Correctly failed for missing font/icon notices; all three icon subsets were nevertheless reproduced byte-for-byte |
| Fresh Flutter test bundle | Passed: all 37 assets and required generated notice text |
| Real Flutter `LicenseRegistry` | Passed: one focused probe verified 13 complete labels from generated `NOTICES.Z` |
| Fresh macOS release artifact | Build and `--require-complete-provenance` audit passed; all 37 runtime files match original source bytes, with complete generated notices |
| Fresh Web JavaScript release artifact | Build, strict asset audit, and media audit passed; 34 typography files match source bytes and all three icon subsets were reproduced exactly |
| Fresh Web Wasm release artifact | Build, strict asset audit, and media audit passed; 34 typography files match source bytes and all three icon subsets were reproduced exactly |

Source verification is captured in
[`2026-09-03-dependency-asset-source-audit.json`](./2026-09-03-dependency-asset-source-audit.json).
The generated test bundle is captured in
[`2026-09-03-dependency-asset-test-bundle-audit.json`](./2026-09-03-dependency-asset-test-bundle-audit.json),
including the compressed `NOTICES.Z` hash
`b49422cd5111fd827b4d7b60d46b3b679c83ecfbbf0eaa8cec7585708fd35b24`.
This hash is specific to that generated bundle and its resolved workspace
license set; it is not a universal hash for all consumer applications.

The refreshed release artifacts are recorded in:

- [`native-release-assets.json`](./native-release-assets.json): ordinary
  macOS release app, with assets under
  `build/macos/Build/Products/Release/beautiful_ai_ui_catalog.app/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets`.
  Its compressed `NOTICES.Z` SHA256 is
  `b49422cd5111fd827b4d7b60d46b3b679c83ecfbbf0eaa8cec7585708fd35b24`.
- [`web-js-release-assets.json`](./web-js-release-assets.json): JavaScript
  release asset directory. The independent media audit also passed, including
  both complete country_flags and flag-icons MIT notices.
- [`web-wasm-release-assets.json`](./web-wasm-release-assets.json): latest
  Wasm release asset directory, also passing the independent media audit.
  Both Web releases contain uncompressed `NOTICES` with SHA256
  `490f72033cd29e11a4d401e74863d3f2dd1ce0ee2ddae397dddad722d549e911`.

Each report records 43 checked source files, all 37 runtime font/icon files,
their exact built hashes and transformations, no errors, and `passed: true`.
A read-only follow-up confirmed the currently present macOS and Wasm notice
bytes match their saved report hashes. The Web output directory now contains
the latest Wasm build; the JavaScript report records its preceding build.
The authoritative font/icon and flag inventory references have also been
merged into `legal/assets.yaml` under the inherited-dependency policy.

## Remaining release boundaries

- The recorded checks apply to these generated artifacts and their pinned
  asset inventory. Future dependency/resource changes or separately built
  artifacts require their own proportionate verification; these results do
  not automatically certify every consumer or platform build.
- Keep the documented Radix original-conversion limitation and the distinct
  source revision versus notice revision for country flag artwork.
- Catalog launcher branding, platform media, and other dependency assets are
  addressed by their separate inventories. This record does not grant brand
  rights or assert that every third-party dependency has been exhaustively
  audited.
- Actual screen-reader, physical-device, browser, and profile-performance
  evidence remains in the support matrix; this notification repair does not
  close those separate release gates.
