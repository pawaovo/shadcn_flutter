# Search visual regression addendum — 2026-09-04

All **six Search PNGs are byte-identical** to the individually reviewed Search
captures in the [September 3 P1/P2 evidence](2026-09-03-p1-p2-complementary-review.md).
Each fresh SHA-256 matches both the accepted JSON entry and the retained original
PNG. There are six unique expected profiles, zero changed images, and zero
rendering errors. The prior visual conclusions therefore carry forward by image
identity; no newly viewed images are claimed. The September 3 evidence and images
remain unchanged.

The replay reused the existing opt-in Dart capture test with
`P1P2_MATRIX_ONLY=search`, the same six complementary tuples, DPR 1, Flutter
3.47.0, Geist, and the pinned review-only Noto Arabic/CJK fonts. All four pinned
font/license files were checked against their SHA-256 and byte lengths. The full
78-image Python wrapper was not run; its existing source-inventory and font
validation functions were reused, and the filtered six-image count was checked
explicitly.

This fixture displays a **localized nonempty query with two title-only results**.
It does not exercise the empty-query first-five state, subtitles/groups,
highlighted/focused/empty states, or the more-than-five lazy branch. Its six
tuples cover compact/medium/expanded widths, light/dark, selected high-contrast
configurations, English/Chinese/Arabic, RTL, and 100%/200% text. Search retains its
288 logical-pixel surface cap; profile component width describes available host
width.

The existing 198-file capture inventory changed only in `search.dart` since the
accepted baseline. Before/after capture snapshots matched and were checked again
after the behavior tests. The new aggregate source identity is
`efa09fcc76dd02d3264519274b6e56590eb971ca0237cc4e2a7a110ec93f0688`;
the Search source SHA-256 is
`b8bdaddec0ce41c1792a5664232933306e8104506075c3db274df45e608bd1e3`.

A fresh behavior run passed **43/43**: 20 existing Search widget/semantics tests,
13 long-catalog regressions, and 10 P1/P2 temporal/bidirectional tests. The 13 new
cases exercise all 1,000 entries, ten broad-match keyboard moves, first ArrowUp
and wrap to item 999, measurement-cache invalidation, same-list and nested-keyword
republishing, semantic selection, and retained focus after scrolling/reordering.
The new test source is hashed separately because the capture inventory excludes
it. These checks do not establish native frame-time or memory-budget acceptance.

The [JSON addendum](2026-09-04-search-visual-regression-addendum.json) records all
six hashes, exact commands, timestamps, source/test identity, font checks and log
hashes. Generated PNGs, complete source inventory, logs and capture provenance
remain in the ignored
`packages/beautiful_ai_ui/build/release_review/2026-09-04-search-regression`
directory.

To reproduce the six captures from `packages/beautiful_ai_ui`, with the existing
verified review fonts present:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Users/zzz/.local/share/mise/installs/flutter/3.47.0/bin/flutter test --no-pub \
  tool/release_review/p1_p2_matrix_test.dart \
  --dart-define=P1P2_MATRIX_ONLY=search \
  --dart-define=P1P2_MATRIX_OUTPUT=/absolute/path/under/package/build/release_review/search-replay
```

Acceptance remains limited to specified-font headless rendering of these exact
fixtures. Native font fallback, real assistive technology, platform input,
physical devices, and native performance require their separate evidence.
