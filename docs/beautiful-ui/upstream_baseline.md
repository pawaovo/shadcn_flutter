# Upstream baseline

Captured: 2026-09-02 (Asia/Shanghai)
Product branch: `product/main`

This document freezes the source inputs for the first implementation cycle. A branch name or moving URL is never sufficient evidence; all adaptation and comparisons use the commits below.

## `shadcn_flutter`

| Field | Value |
|---|---|
| Official repository | `https://github.com/sunarya-thito/shadcn_flutter.git` |
| Fork | `https://github.com/pawaovo/shadcn_flutter.git` |
| Pinned commit | `5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73` |
| Release tag | `v0.0.54` |
| Core package version | `0.0.54` |
| Dart constraint | `>=3.13.0 <4.0.0` |
| Flutter constraint | `>=3.47.0` |
| Repository license | BSD 3-Clause, Copyright 2025; local copy in [`LICENSES/SHADCN_FLUTTER_REPOSITORY_BSD_3_CLAUSE.txt`](../../LICENSES/SHADCN_FLUTTER_REPOSITORY_BSD_3_CLAUSE.txt) |
| Core package license | BSD 3-Clause, Copyright 2026; local copy in [`LICENSES/SHADCN_FLUTTER_CORE_BSD_3_CLAUSE.txt`](../../LICENSES/SHADCN_FLUTTER_CORE_BSD_3_CLAUSE.txt) |

The pinned commit is the release that separates Material and Cupertino integration into companion packages and moves the core onto `package:flutter/widgets.dart`. The new package must preserve that separation.

The repository-level and package-level BSD texts contain the same terms but different copyright years. Both original files remain authoritative and must be preserved; one notice must not overwrite the other.

Repository remotes are intentionally asymmetric:

```text
origin    https://github.com/pawaovo/shadcn_flutter.git  (fetch/push)
upstream  https://github.com/sunarya-thito/shadcn_flutter.git  (fetch)
upstream  DISABLED  (push)
```

At this baseline, the root Dart Pub Workspace contains the core package, examples, Material/Cupertino companions, GenUI, documentation, and generation tools. `beautiful_ai_ui` will be added as a sibling package; it will not be placed inside `packages/shadcn_flutter`.

## Beautiful UI

| Field | Value |
|---|---|
| Official repository | `https://github.com/slev12397/beautiful-ui.git` |
| Pinned commit | `dd1ba4f323c29ef6c383b2dbf1d7100f2c26ccac` |
| Pinned branch observation | `main` and remote `HEAD` resolved to the pinned commit on 2026-09-02 |
| Registry index | `public/r/registry.json` at the pinned commit |
| Registry item count | 27: 1 foundation, 6 building blocks, 20 gallery components |
| License | MIT; local copy in [`LICENSES/BEAUTIFUL_UI_MIT.txt`](../../LICENSES/BEAUTIFUL_UI_MIT.txt) |

Beautiful UI is a design and behavior source, not a runtime dependency. React, Next.js, Tailwind, npm packages, demo timers, and scripted harness data are not copied into the Flutter package.

## Reproducible verification

Use read-only commands to check the source pins:

```bash
git rev-parse 'v0.0.54^{commit}'
git cat-file -e '5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73^{commit}'
git merge-base --is-ancestor \
  5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73 \
  product/main
git remote -v
git ls-remote https://github.com/slev12397/beautiful-ui.git HEAD refs/heads/main
```

The first command must print the pinned shadcn commit. The second and third commands succeed without output when the commit exists and remains an ancestor of the product branch. Product HEAD is expected to advance, so it is deliberately not compared directly with the upstream pin.

Expected identifiers from the commands that print revisions:

```text
shadcn_flutter  5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73  v0.0.54
Beautiful UI   dd1ba4f323c29ef6c383b2dbf1d7100f2c26ccac
```

The repository toolchain is pinned separately in `.mise.toml`. The source baseline does not by itself prove analyze, test, build, or runtime support. Those results must be recorded as dated evidence before a support claim changes from planned to verified.

## Local baseline evidence

Captured on 2026-09-02 with Flutter `3.47.0` (`4cf2416426`), Dart
`3.13.0`, macOS `15.7.9` on arm64:

| Check | Result |
|---|---|
| `flutter pub get` in a detached, clean upstream worktree | Passed; 161 dependencies resolved, with 16 newer versions outside current constraints |
| Root `flutter analyze` | Exit 1 because of 41 pre-existing info diagnostics in `packages/docs`; 0 warnings and 0 errors |
| `packages/shadcn_flutter` tests | Passed: 569 tests, 0 failures |
| `packages/docs` Web release build | Passed, including the Wasm dry run |

The baseline worktree remained clean after every command. New-package CI uses
strict `--fatal-infos --fatal-warnings` per package so the upstream docs info
diagnostics do not hide regressions and are not misattributed to new code.

Local `flutter doctor -v` reported Chrome and macOS devices, but no Android SDK,
an incomplete Xcode installation, and no CocoaPods. Native Android/iOS/macOS
support therefore remains unverified locally and must be established by the
cross-platform CI matrix and later device evidence.

## Isolated fork patch

The first vertical slice exposed one upstream-core defect: the public
`ShadcnLayer.enableThemeAnimation` setting was not read by the implementation,
so it always used the 150ms default transition. The fork changes the transition
duration to zero when the setting is false and adds two focused core tests for
enabled and disabled behavior. This patch is intentionally isolated and suitable
for proposing upstream; the Beautiful AI UI public interface does not depend on
fork-only types.

## Sync procedure

1. Fetch `upstream` and tags without pushing to it.
2. Create a dedicated `sync/upstream-<date-or-version>` branch from `product/main`.
3. Update one upstream baseline per pull request.
4. Record the old and new commit IDs, release notes, dependency resolution changes, public API diff, test/build results, and intentional golden changes.
5. Keep ordinary component work out of the sync change.
6. If an upgrade requires changes outside the internal `implementation/shadcn/` seam, review whether the public boundary has leaked upstream concepts.
7. Update this document, the parity manifest baseline, notices, and provenance only after the new pin is approved.

Shared branches are not destructively rebased during an upstream sync. Any necessary upstream-core fix is isolated in its own commit and prepared so that it can be proposed to the official project.
