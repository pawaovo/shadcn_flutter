# P1/P2 complementary visual and state review — 2026-09-03

The explicit P1/P2 matrix passed: **13 modules × 6 complementary profiles =
78 individually viewed images**, with zero remaining rendering errors or
blocking visual findings in those tuples. The primary reviewer viewed 52
images; an independent reviewer viewed the two medium profiles (26 images).
Every accepted entry in the [JSON index](2026-09-03-p1-p2-complementary-review.json)
has its final image SHA-256, reviewer, method, and observation.

This extends the earlier
[49-image review](2026-09-03-accessibility-visual-review.md), which used English
text even in its RTL profile. It adds real Chinese and Arabic glyphs, compact
dark, medium light/dark, expanded light, long host labels, and a second set of
component variants. It is **not a full Cartesian product** of all dimensions and
states. The older report remains tied to its own historical source snapshot.

| Profile | Viewport | Theme | Text | Host content / direction | Motion during capture |
| --- | ---: | --- | ---: | --- | --- |
| compact-dark-long-en-2x | 390 | dark | 200% | long English / LTR | none |
| compact-light-hc-ar-rtl-2x | 390 | light, high contrast | 200% | Arabic / RTL | system + platform disabled |
| medium-light-zh-2x | 768 | light | 200% | Chinese / LTR | reduced |
| medium-dark-hc-long-en-1x | 768 | dark, high contrast | 100% | long English / LTR | none |
| expanded-light-ar-rtl-1x | 1280 | light | 100% | Arabic / RTL | reduced |
| expanded-dark-zh-2x | 1280 | dark | 200% | Chinese / LTR | system + platform disabled |

All widths are logical pixels at DPR 1, with 16-pixel outer padding. Components
retain their own maximum widths and text-scale adaptations. A wide viewport
does not force a narrow card or Search into a full-width surface. High contrast
is exercised in both brightness modes, but not for every locale/width pair.

| Module | Visible states in each of the six images | Related interaction and motion coverage |
| --- | --- | --- |
| Loading | all four variants, elapsed value, licensed-media fallback | existing continuous-motion policy and Surfer entrance/ticker tests |
| Thinking | reasoning working + search complete, both expanded | existing disclosure/keyboard and new long-trace tests; new signed-count glyph regression |
| Context | success/destructive cards, source chips and long body previews | existing expansion/source, resize, and reduced-entrance tests |
| Recommendation | selected proposal, confidence and alternatives/action labels | new in-flight option transition, pending deduplication, failure and accepted retry under motion changes |
| Search | localized query and two long results | existing keyboard, IME, focus and resizing tests |
| Code | code and diff, line numbers, copy action and counts | new focused copy, pending, failure, timed reset, retry and disposal under motion changes |
| Streaming | completed answer, selected positive feedback, actually expanded source, follow-up | existing generation, async action, source and feedback tests |
| Approval | multi-choice selection, editable custom-answer placeholder and navigation | existing draft/IME/submit/failure tests; new visual current/total glyph regression |
| Tool | completed read with output actually expanded, failed write and diff summary | existing disclosure/status/motion tests; new signed-count glyph regression |
| Task | capsule complete/running and list pending/failed | existing retry, disclosure, focus and active-spinner policy tests |
| Chat | user/assistant messages, two tabs, draft and send action | existing draft/selection/focus, pending, stop and IME tests |
| Filter | all filter counts, completed/running rows, cards/table adaptation | existing filtering/keyboard/semantics tests; new unequal-count RTL glyph regression |
| Fine Tune | selected grid, numeric values and increment/decrement, selected type | existing host acceptance, bounds, scrub, keyboard, IME and resizing tests |

The last column maps applicable existing tests and the new focused work. It does
not claim that every interaction appears in the static images or that all
existing tests were rerun in this narrowly scoped review. The existing test files
live under `packages/beautiful_ai_ui/test/widget` and `test/semantics` with the
corresponding component names. Shared pressed/focus/contrast acceptance is
tracked separately in `action_control_contrast_test.dart`; the shared control's
cancel/disable cleanup was also inspected without an additional product change.

Four real numeric-order defects were corrected:

- Approval's current/total indicator painted `1 / 12` in reverse visual order
  under RTL. Its numeric text now has explicit LTR direction.
- Tool diff counts placed `+` and `−` after their digits. Each signed count now
  preserves LTR numeric order within the RTL container.
- Thinking's coding count span reordered signed additions/deletions. Only that
  span now has explicit LTR direction, preserving the separate bounded-entrance
  and hidden-ticker performance changes.
- Filter's unequal matching/total ratio reversed inside an Arabic paragraph.
  LRI/PDI isolates only that numeric run in RTL. The translated prefix retains
  its direction, and the semantic announcement remains plain text.

All four new glyph-coordinate regressions failed against the prior rendering and
passed after their corresponding fixes. The new test file contains **10 cases**:
those four regressions, plus Copy and Recommendation lifecycle cases for runtime
changes to reduced, none, and platform-disabled motion. They verify actual
pending/error/success behavior, retry de-duplication, retained selection, finite
animation settling, and timer disposal. They do not download or require Noto.

The targeted runs passed **47/47** (new first nine, Approval, Tool, Thinking and
Thinking long trace) and **25/25** (final new ten, Filter widget and semantics).
Nine cases overlap; these are not 72 unique tests. Targeted Dart analysis reported
no issues, Python scripts compiled, and `git diff --check` was clean. The exact
logs and hashes are listed in the JSON index and retained beside the generated
images.

Rendering used Flutter **3.47.0** on macOS, with source identity
`e2bcc12029aca5247f4acdaf6c3ea3f620d7dd4856f07c33c409772da5a55106`.
The final full capture completed at the UTC time recorded in the index. The
exporter hashes P1/P2, shared controls/foundation, shadcn source, dependency lock,
and fixtures before and after capture; source files were checked again after
review. The last numeric correction changed only the two Arabic Filter PNGs;
both were viewed again. The other 76 final PNG hashes matched the preceding
capture. Both compact profiles were also viewed again after all corrections.
Final provenance verification resolved the shadcn source directory to
`packages/shadcn_flutter/lib` and included both loaded Geist font files, yielding
198 source files. A final complete capture with that corrected inventory produced
the same SHA-256 for all 78 already reviewed PNGs.

The first Chinese/Arabic probes exposed missing glyphs in the headless font
environment and were rejected. Accepted captures explicitly load review-only
**Noto Sans CJK SC 2.004** and **Noto Sans Arabic 2.012** after Geist, with fixed
upstream commits, SHA-256, byte lengths, embedded copyright, and both OFL license
texts retained in `build/release_review/fonts`. The pinned sources are the
[Noto CJK repository](https://github.com/notofonts/noto-cjk/tree/f8d157532fbfaeda587e826d4cd5b21a49186f7c)
and [Google Fonts Arabic directory](https://github.com/google/fonts/tree/f265cc2d8e08067dac782ba633458b97661ab85d/ofl/notosansarabic).
No Apple font or new distribution font asset is included. Flutter's official
`GlobalWidgetsLocalizations` is supplied, while business text and component
labels are translated by the fixtures.

This accepts specified-font headless rendering, not native automatic fallback.
Arabic shaping and Chinese glyph coverage were actually viewed before acceptance.
Native editing, platform font discovery, assistive technology, physical-device
behavior, browser input and performance remain separate acceptance workstreams;
none is marked complete by this report. Static motion-reduced images are also
not evidence of temporal animation behavior.

Reproduction is explicit and leaves the default test suite unchanged. From
`packages/beautiful_ai_ui`:

```sh
python3 tool/release_review/prepare_review_fonts.py
python3 tool/release_review/export_p1_p2_matrix.py --flutter /absolute/path/to/flutter
flutter test --no-pub test/release_review/p1_p2_temporal_and_bidi_test.dart
```

The [capture instructions](../../../packages/beautiful_ai_ui/tool/release_review/2026-09-03-p1-p2-matrix/README.md)
describe the optional output path and local Xcode environment. PNGs, fonts, logs,
and the complete capture provenance stay under the ignored
`packages/beautiful_ai_ui/build/release_review/2026-09-03-p1-p2-matrix` directory.
Only scripts, fixtures, tests, the small component corrections, and this evidence
index are source changes. Re-running the capture marks every new output
`unreviewed`; it never updates canonical goldens or grants visual approval.
