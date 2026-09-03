# Dependency asset and generated-license audit

Date: 2026-09-03 (Asia/Shanghai)
Dependency baseline: `shadcn_flutter 0.0.54`, source commit
`5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73`
Toolchain: Flutter `3.47.0`, Dart `3.13.0`, local macOS arm64
Status: workspace source/assets/registry coverage verified; portable package
notice source checks and independent hosted-consumer execution passed

Latest automated acceptance is [CI `33748054504`, attempt 1](https://github.com/pawaovo/shadcn_flutter/actions/runs/33748054504):
all 12 jobs passed for code `c2bde85dd5da7c33b0f7881234ae312f3be1826c`.
The downloaded hosted-consumer artifact `9890573744` again verifies 209
unchanged files, 12 theme observations and all 13 required complete notices.
Its result SHA256 is
`cfe7abbf71529b044e236fe93b53de05d36e0cfa9f82d3bd3cbd49ba4f28be45`.
The [compact final CI record](./2026-09-03-final-ci-33748054504.json) preserves
this result separately from older workspace and consumer snapshots below.

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

A later publication-boundary check identified a separate gap: unmodified
hosted `shadcn_flutter 0.0.54` has a package `LICENSE`, but does not carry this
fork's added `NOTICES`. Workspace success alone therefore did not prove that
publishing `beautiful_ai_ui` independently would deliver its dependency asset
notices. The publishable `packages/beautiful_ai_ui/NOTICES` now starts with the
complete unchanged BAI `LICENSE` and carries the full verified dependency
notice set itself. The core notice remains available to this fork's users.

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

The BAI carrier has ten blocks: its own complete BSD and Beautiful UI MIT
blocks first, followed by all eight core-carried blocks. Its SHA256 is
`30ea1bec73647df83b3716f1107ab27a56c945ec4cc2693b8e1cdc13768854e7`.
The source audit verifies all ten dependency labels in **both** package
carriers, pins the original BAI `LICENSE` hash, and requires that entire
original file to be the byte-for-byte prefix of BAI's `NOTICES`. It also
checks each original license block individually. No font binary or dependency
version constraint changed in this repair.

The source result is recorded in
[`2026-09-03-portable-notice-source-audit.json`](./2026-09-03-portable-notice-source-audit.json).
Temporary negative fixtures that removed BAI's own license or altered its
Geist notice were correctly rejected. The checker refused to export
independent-consumer expectations from either failing fixture.

The independent consumer resolves the real hosted `shadcn_flutter 0.0.54`
without a workspace override or copied sibling package. A fresh disposable
`PUB_CACHE` was used, and all 209 hosted runtime files were matched against
the official archive SHA256
`403a9e790447dc4b6bae73a810d7ffa52baece4d7b29b32de56d0dd769be080e`.
That archive contains `LICENSE` and no package-root `NOTICES`.

The [before report](./hosted-consumer-before.json) reproduced the publication
gap: generated `NOTICES.Z` and real `LicenseRegistry` covered only four of
13 expected full-text labels, missing the nine asset labels. The
[after report](./hosted-consumer-after.json) passed all four stages: public
dependency resolution, strict consumer analysis, two public-integration/theme
tests, and one production-registry probe. Both generated notices and the
registry now contain all 13 complete expected texts with no missing labels.

The BAI publication-surface copy in that passing consumer records the same
portable notice hash `30ea1bec73647df83b3716f1107ab27a56c945ec4cc2693b8e1cdc13768854e7`.
Its generated `NOTICES.Z` hash is
`803026de97a191d81e842aedf1285d2daa52c68184f8a5ea4cae65d8d076995f`.
The consumer is outside the repository, has no dependency overrides, and
does not modify the hosted core or inject license entries. BAI itself is a
temporary copy of its publication surface used as a path dependency, not an
already completed pub.dev publication. These results are recorded separately
from the larger workspace license graph below.

The cloud publish job in
[run `33741053163`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33741053163)
independently repeated this boundary successfully. Downloaded artifact
`9887907974` confirms 209 unchanged hosted files, 12 theme observations, and
all 13 complete notice/registry labels; its result SHA256 is
`ff2e38c34a3eb304567c1e40ee0692bddc0f3d0a5d0fcc2191f524281b00ef40`.
The same job's publish dry-run reported 3 MB and zero warnings. Compact cloud
metadata is retained in `toolchain.json`; the overall CI run still failed in
the separate Apple launcher self-test and is not represented as all green.

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

For a separately resolved consumer, export the expected full texts only after
the source audit succeeds:

```sh
python3 tool/audit_dependency_assets.py \
  --require-complete-provenance \
  --expectations-output /tmp/beautiful-ai-ui-expected-notices.json
```

The JSON is a `Map<String, String>` of label to complete original license
text, read from the independently audited license files. The registry probe
accepts `--dart-define=EXPECTED_LICENSES_FILE=/absolute/path/to/expectations.json`
to run outside this repository. This supplies assertions only; it does not
register licenses, replace the generated asset bundle, or inject a collector.

The complete separate-resolution publication check is repeatable from the
repository root:

```sh
python3 tool/verify_hosted_consumer.py \
  --output /tmp/beautiful-ai-ui-hosted-consumer.json
```

It creates a disposable consumer/publication-surface copy and fresh package
cache, resolves the real hosted core, preserves resolution and source hashes,
and runs the integration and production-registry probes. The copied BAI
`NOTICES` hash is part of the report; a workspace sibling does not supply it.

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
| Portable BAI notice carrier | Passed: all ten dependency labels match both carriers; the unchanged original BAI LICENSE is preserved as a complete prefix and as two individually checked blocks |
| Portable notice negative guards | Missing BAI terms or altered Geist attribution correctly exited 1 and did not export consumer expectations |
| Negative hash guard | A temporary inventory with a forged source hash correctly exited 1 |
| Negative provenance gate | A temporary inventory containing a deliberate unresolved gate correctly exited 1 with `--require-complete-provenance` |
| Old Web artifact | Correctly failed for missing font/icon notices; all three icon subsets were nevertheless reproduced byte-for-byte |
| Fresh Flutter test bundle | Passed: all 37 assets and required generated notice text |
| Real Flutter `LicenseRegistry` | Passed: one focused probe verified 13 complete labels from generated `NOTICES.Z` |
| Fresh macOS release artifact | Build and `--require-complete-provenance` audit passed; all 37 runtime files match original source bytes, with complete generated notices |
| Fresh Web JavaScript release artifact | Build, strict asset audit, and media audit passed; 34 typography files match source bytes and all three icon subsets were reproduced exactly |
| Fresh Web Wasm release artifact | Build, strict asset audit, and media audit passed; 34 typography files match source bytes and all three icon subsets were reproduced exactly |
| Independent hosted consumer before repair | Correctly reproduced missing nine labels: generated notices and real registry covered four of 13 required texts |
| Independent hosted consumer after repair | Passed all four stages with unchanged hosted shadcn_flutter 0.0.54, 209 matching runtime files, two integration/theme tests and one real-registry probe; all 13 texts covered |

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
These three records were generated in the workspace using the local sibling
dependency. They remain valid for those built asset bytes, but do not by
themselves prove the newly repaired standalone publication path.

## Remaining release boundaries

- Keep the portable BAI carrier and independent hosted-consumer check in the
  publication path. Dependency upgrades or changes to distributed licenses
  require a corresponding inventory/consumer refresh. The current proof uses
  a publication-surface copy of BAI and does not claim the package was published.
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
