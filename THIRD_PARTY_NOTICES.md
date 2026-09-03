# Third-party notices

This repository contains `shadcn_flutter` and `beautiful_ai_ui`, an independent Flutter reimplementation informed by Beautiful UI. The project is not an official Beautiful UI, Turbo, or `shadcn_flutter` product.

This notice covers the pinned implementation baseline. Dependency and asset inventories must be regenerated and reviewed for each release candidate.

## Project-created code

Newly authored `beautiful_ai_ui` Dart code is distributed under the BSD 3-Clause License. The package-level terms, together with the Beautiful UI MIT notice required for adapted portions, are preserved in [`packages/beautiful_ai_ui/LICENSE`](packages/beautiful_ai_ui/LICENSE).

## Beautiful UI

- Project: Beautiful UI
- Source: <https://github.com/slev12397/beautiful-ui>
- Pinned source commit: `dd1ba4f323c29ef6c383b2dbf1d7100f2c26ccac`
- Copyright: Copyright (c) 2026 Shane Levine
- License: MIT
- Local license copy: [`LICENSES/BEAUTIFUL_UI_MIT.txt`](LICENSES/BEAUTIFUL_UI_MIT.txt)

The foundation and all twenty Gallery components have independent Flutter
implementations of visual, state, and interaction intent. Source paths and
the remaining acceptance status of every registry item are recorded in
[`legal/component_provenance.yaml`](legal/component_provenance.yaml).
The React/Next.js/Tailwind implementation,
npm runtime, scripted harness data, source logos, Central Icons package, and
externally hosted Surfer video are not part of the distributable Flutter
library.

The MIT license requires the copyright and permission notice to accompany copies or substantial portions. The full text is preserved in the local license copy above.

## shadcn_flutter

- Project: shadcn_flutter
- Source: <https://github.com/sunarya-thito/shadcn_flutter>
- Pinned source commit: `5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73`
- Release: `v0.0.54`
- Repository copyright: Copyright 2025 Thito Yalasatria Sunarya
- Core and companion package copyright: Copyright 2026 Thito Yalasatria Sunarya
- License: BSD 3-Clause
- Repository license copy: [`LICENSES/SHADCN_FLUTTER_REPOSITORY_BSD_3_CLAUSE.txt`](LICENSES/SHADCN_FLUTTER_REPOSITORY_BSD_3_CLAUSE.txt)
- Core package license copy: [`LICENSES/SHADCN_FLUTTER_CORE_BSD_3_CLAUSE.txt`](LICENSES/SHADCN_FLUTTER_CORE_BSD_3_CLAUSE.txt)

The fork retains the upstream repository and package-level license files. Their terms are the same, but their copyright years differ, so neither notice replaces the other. `beautiful_ai_ui` depends only on the public `shadcn_flutter` package interface and does not use the upstream author or contributor names to endorse the derived project.

The dependency's [`NOTICES`](packages/shadcn_flutter/NOTICES) preserves its
original BSD text and the full font/icon notices below in Flutter's supported
multi-license format. Flutter collects this package-root file into generated
`NOTICES`/`NOTICES.Z`, which the default `LicenseRegistry` reads. Keeping a
license only in a nested font directory does not add it to that registry.

The separately publishable
[`beautiful_ai_ui/NOTICES`](packages/beautiful_ai_ui/NOTICES) also carries the
complete verified dependency notices. It begins with the unchanged full
`beautiful_ai_ui/LICENSE`, preserving both its own BSD and Beautiful UI MIT
blocks. This makes notice delivery independent of whether a consumer uses
this fork or the unmodified hosted `shadcn_flutter 0.0.54`, which does not
contain the fork's added `NOTICES`. The source audit checks both carriers and
preservation of the package's own license. The
[standalone consumer report](docs/beautiful-ui/quality_evidence/hosted-consumer-after.json)
verifies all 13 required full texts in generated notices and the real
`LicenseRegistry`, using an unchanged hosted core and a temporary BAI
publication-surface copy. This is recorded separately from workspace evidence
and is not a claim that BAI has already been published.

## Bundled dependency fonts and icon fonts

The exact file inventory is
[`legal/dependency_assets.json`](legal/dependency_assets.json). It records
SHA256, size, runtime declaration, internal font version, upstream artifact,
license text hash, and the evidence for each file. At this baseline, Flutter
declares **37 dependency font files**: 17 Geist Sans, 17 Geist Mono, and three
icon fonts. Six further Geist OTF files are present in the source font
directory but are not declared into the Catalog runtime.

| Asset | Recorded origin and version | Preserved notices |
|---|---|---|
| Geist Sans / Geist Mono, modern files | Official Geist `1.5.1` release archive; font metadata `1.510`; all 36 source files match the release bytes, including the 30 declared runtime files | [OFL 1.1, 2024 Geist Project Authors](LICENSES/GEIST_1_5_1_OFL_1_1.txt) from the [pinned official license](https://github.com/vercel/geist-font/blob/3c80bfcc1ba4988ece0eda46a282e15d29e61bbf/OFL.txt) |
| Geist Sans / Geist Mono, UltraLight and UltraBlack | Official Geist `1.1.0` release archives; font metadata `1.002`; all four files match exactly and are declared at runtime | [OFL 1.1, 2023 Vercel / basement.studio](LICENSES/GEIST_1_1_0_OFL_1_1.txt) from the [official release](https://github.com/vercel/geist-font/releases/tag/1.1.0) |
| Bootstrap Icons | `1.11.3`; every SFNT table in the inherited OTF matches the decompressed official WOFF | [Bootstrap Authors MIT](LICENSES/BOOTSTRAP_ICONS_1_11_3_MIT.txt), [pinned official license](https://github.com/twbs/icons/blob/8d88686c03c3768a2d82ba4f20c3c4e1b100fa29/LICENSE) |
| Lucide | `lucide-static 0.479.0`; the inherited TTF exactly matches `package/font/lucide.ttf` in the official npm release | [Lucide ISC](LICENSES/LUCIDE_0_479_0_ISC.txt), [pinned official license](https://github.com/lucide-icons/lucide/blob/aefb710e5c64b3d569b6e3eafa7516c273a1bf4a/LICENSE); [Feather MIT](LICENSES/FEATHER_4_29_2_MIT.txt) is also preserved for Feather-derived icons |
| Radix Icons | Exact font bytes and Radix attribution from pinned `shadcn_flutter 0.0.54`; internal family `iconly`, generic generated-font version `1.0`; original SVG release and conversion recipe remain unrecorded | [WorkOS MIT](LICENSES/RADIX_ICONS_MIT.txt) from the [official Radix source](https://github.com/radix-ui/icons/blob/112af91ad275a63c3a29b0da2588342af74ef9bf/LICENSE); acquisition is verified at the fixed dependency/hash boundary |

The generated icon fonts' generic `Version 1.0` strings are not the original
icon libraries' release versions. Flutter may tree-shake icon fonts; the
audit tool records built hashes and can reproduce those exact bytes with
the pinned SDK's `font-subset` executable and the built font's Unicode cmap.
Typography files are checked against the original bytes. Inter and JetBrains
Mono are not bundled by this package.

Run [`tool/audit_dependency_assets.py`](tool/audit_dependency_assets.py) for
source/notice checks, add `--verify-upstream` for artifact comparison, and use
`--bundle` plus `--font-subset` to verify a generated asset directory.
`--require-complete-provenance` fails any unresolved acquisition gate recorded
in the inventory. The policy permits a source version or hash; it does not
require inventing a Radix release or recovering an unspecified generator
version. The original Radix conversion remains a documented limitation.
The separate
[`LicenseRegistry` probe](tool/probe_dependency_license_registry.dart) checks
complete text through Flutter's actual generated asset loader. Dated results
and remaining gaps are in the
[license audit](docs/beautiful-ui/quality_evidence/2026-09-03-license-audit.md).
The recorded audit passed for freshly generated JavaScript, Wasm, and macOS
release assets, in addition to a real Flutter `LicenseRegistry` probe. Those
artifact-specific results do not replace the remaining platform, brand, or
unrelated dependency acceptance requirements.
Final [CI `33748054504`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33748054504)
passed all 12 jobs for code `c2bde85dd5da7c33b0f7881234ae312f3be1826c`,
including another downloaded and verified hosted-consumer result with all
13 complete required notices. This remains validation rather than an actual
package publication.

## Country flag images

The resolved `country_flags 4.1.2` dependency also contributes 266 compiled
`.si` flag images to the Catalog artifact. Its published archive SHA256 is
`f022d18337f3861f1f4e319b936cb53920de9259f38cb09e169eace9942e2b79`.
The package's [Arturo Grau MIT notice](LICENSES/COUNTRY_FLAGS_4_1_2_MIT.txt)
is preserved separately. Its README attributes the SVG artwork to
[`lipis/flag-icons`](https://github.com/arturograu/country_flags); the full
[Panayiotis Lipiridis MIT notice](LICENSES/FLAG_ICONS_MIT.txt) is therefore
also included in the dependency's generated `NOTICES` coverage.

The flag-icons license was verified at
[`086f7e97d657358203916dbe84f61c2bccaa81eb`](https://github.com/lipis/flag-icons/blob/086f7e97d657358203916dbe84f61c2bccaa81eb/LICENSE).
That commit identifies the notice source; it is not a claim that the 266
compiled images were generated from that exact SVG revision. The published
country_flags package version/archive hash and individual image hashes fix
the actual acquisition boundary. These images are tracked separately from
the 37-font inventory in `legal/assets.yaml` and the dependency-media audit.

## Assets and transitive packages

[`legal/assets.yaml`](legal/assets.yaml) is the authoritative allow/deny inventory for project assets. In particular:

- Central Icons are excluded. Component-specific replacement symbols are
  independently drawn; dependency icon fonts remain subject to the inventory
  and provenance review above.
- The remote Surfer video shown by a Beautiful UI loading variant is excluded and will not be fetched at runtime.
- Beautiful UI and Turbo logos or brand assets are excluded from package and catalog branding.
- Assets already supplied by `shadcn_flutter` remain governed by their upstream notices and are not duplicated into `beautiful_ai_ui` without a separate record.

Flutter/Dart dependencies and their bundled assets may carry additional
licenses. This audit closes the identified dependency-font notice omission;
it does not approve all transitive packages, source-package acquisition,
Catalog launcher branding, or future asset substitutions. Release checks must
use the actual resolved package graph and built artifact, preserve applicable
notices, and update the inventory when the shipped files change.

This file records engineering attribution and redistribution obligations; it is not legal advice.
