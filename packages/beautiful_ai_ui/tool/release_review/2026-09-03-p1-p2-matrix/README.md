# Complementary P1/P2 visual review

This is an explicit release-review capture, outside the default `flutter test`
directory. It covers 13 modules under six complementary profiles (78 images),
not the full Cartesian product. The default test suite neither downloads fonts
nor writes screenshots. The ten focused motion/async and RTL-number regressions
are in `test/release_review/p1_p2_temporal_and_bidi_test.dart` and need no external
font files.

From `packages/beautiful_ai_ui`, after the normal workspace `flutter pub get`:

```sh
python3 tool/release_review/prepare_review_fonts.py
python3 tool/release_review/export_p1_p2_matrix.py
```

`--flutter /absolute/path/to/flutter` selects a pinned Flutter executable.
`--output build/release_review/a-new-review` writes a separate artifact directory.
On a Mac whose global `xcode-select` uses Command Line Tools, prefix Flutter
commands with the locally installed Xcode's `DEVELOPER_DIR`; no global switch is
required. The exporter always passes `--no-pub` and never builds native apps.

The first command downloads two pinned OFL fonts and their licenses into the
ignored `build/release_review/fonts` directory, verifies byte lengths and SHA-256,
and records immutable upstream commit URLs plus embedded copyright/version
metadata. The second command verifies those files before rendering, bounds the
capture command to five minutes, checks all 78 outputs, and rejects source changes
during capture. It writes full provenance to `capture-manifest.json` with every
image marked `unreviewed`. A successful capture does not imply visual acceptance.

The review-only `review_fonts.dart` helper adds Noto Arabic and CJK after the
production Geist styles. It preserves all production colors, dimensions, and
motion tokens. `GlobalWidgetsLocalizations` supplies Flutter's real widget locale
delegate; fixture business text and component labels are explicitly translated.
This proves specified-font rendering and layout in the headless engine. It does
not prove a platform's automatic fallback, native text editing, screen reader,
or device performance behavior. Font files are not listed in package assets and
are not distributed with the library.

The capture app uses viewports 390, 768, and 1280 logical pixels, DPR 1, with
16-pixel outer padding. Components keep their own maximum widths and adaptation
rules; viewport width is not a promise that a component fills that width. The
six profile tuples are defined in `tool/release_review/p1_p2_matrix_test.dart`.
Loading's four variants, Thinking reasoning/search, Code plus Diff, and Task
capsule/list states share their respective module image. Streaming sources and
the first Tool output are actually expanded before capture. Static images use
reduced/none/platform-disabled motion so timing cannot substitute for reviewing
the final content; dynamic behavior has separate focused tests.

The dated evidence index under `docs/beautiful-ui/quality_evidence` records only
images actually viewed, observations, hashes, corrections, and explicit scope
limits. Re-run captures are deliberately unreviewed until a reviewer views the
new pixels or verifies equality with an already reviewed image hash. Canonical
goldens are never updated by these scripts.
