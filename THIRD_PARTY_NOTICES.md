# Third-party notices

This repository contains `shadcn_flutter` and is preparing `beautiful_ai_ui`, an independent Flutter reimplementation informed by Beautiful UI. The project is not an official Beautiful UI, Turbo, or `shadcn_flutter` product.

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

The foundation, six shared building-block patterns, and twenty composite-component patterns recorded in [`legal/component_provenance.yaml`](legal/component_provenance.yaml) are planned as independent Flutter adaptations of visual, state, and interaction intent. The React/Next.js/Tailwind implementation, npm runtime, scripted harness data, source logos, Central Icons package, and externally hosted Surfer video are not part of the distributable Flutter library.

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

## Assets and transitive packages

[`legal/assets.yaml`](legal/assets.yaml) is the authoritative allow/deny inventory for project assets. In particular:

- Central Icons are excluded; an approved open icon set will be used instead.
- The remote Surfer video shown by a Beautiful UI loading variant is excluded and will not be fetched at runtime.
- Beautiful UI and Turbo logos or brand assets are excluded from package and catalog branding.
- Assets already supplied by `shadcn_flutter` remain governed by their upstream notices and are not duplicated into `beautiful_ai_ui` without a separate record.

Flutter/Dart dependencies and their bundled assets may carry additional licenses. Before distribution, the release process must inspect resolved dependency versions, preserve applicable notices, verify the generated Flutter license registry, and update this file when the shipped inventory changes.

This file records engineering attribution and redistribution obligations; it is not legal advice.
