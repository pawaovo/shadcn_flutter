# P3 visual, localization and temporal acceptance

Date: 2026-09-03. Environment: macOS 15.7.9 arm64, Flutter 3.47.0, DPR 1.

**The declared 1,008-case P3 matrix passed, and all 127 exported PNGs received
direct `view_image` inspection.** The final capture has no rendering errors and
its source/configuration/font hashes were unchanged throughout the run. It
includes 84 primary images and 43 disclosure, detail, chart, focus and held
pointer images. The machine-readable [review index](./2026-09-03-p3-visual-localization-temporal-review.json)
records the exact source/font inventory, every final PNG hash, and individual
visual observations.

Final renderer manifest SHA-256:
`1c8fcbc5904aeba6efdbf971fb6dc6dc4a72eb0a113be7ce3dddab966f4e3fd7`.
Capture completed at `2026-09-03T14:23:23.049524+00:00`. The exact inventory,
rather than Git HEAD alone, binds these images to the concurrent uncommitted
release fixes. The full manifest and [HTML gallery](../../../packages/beautiful_ai_ui/build/p3_visual_acceptance/final/index.html)
are generated under `packages/beautiful_ai_ui/build/p3_visual_acceptance/final`.
Canonical golden files were not read or updated by this exporter.

## Finite matrix and pictured profiles

Each of the seven modules completed every combination below: 144 combinations
per module, 1,008 in total. Each case renders the real translated fixture,
checks the actual available constraints, direction and text scale, and performs
its declared editing/disclosure/navigation actions. It does not manufacture
success from a screenshot existing.

| Factor | Values |
|---|---|
| Module | Prompt Bar, Diff Table, Records Table, Sidebar Nav, Flowchart, Insight Cards, Selection Actions |
| Actual test viewport width | 390, 800, 1,280 logical pixels |
| Available component width | 358, 768, 1,248dp after 16dp padding; Sidebar may retain its natural 64/288dp width |
| Theme | Light, dark |
| Contrast | Normal, high contrast |
| Text scale | 100%, 200% |
| Content and labels | Long English, Simplified Chinese, Arabic with RTL |
| Motion input | System policy with platform animations enabled; reduced policy |

Flowchart's documented accessible steps presentation is expected below 1,024dp
or above 130% text. The 200% expanded-width cases therefore verify the steps
fallback; they do not force a spatial canvas into an unsuitable text scale.

Twelve complementary profiles were selected for full-size visual inspection:

| Width | Theme | Contrast | Text | Language/direction | Motion |
|---|---|---|---|---|---|
| Compact | Light | Normal | 200% | Long English / LTR | System |
| Compact | Dark | High | 200% | Arabic / RTL | Reduced |
| Compact | Light | High | 200% | Chinese / LTR | Reduced |
| Compact | Dark | Normal | 100% | Chinese / LTR | System |
| Medium | Light | High | 200% | Arabic / RTL | System |
| Medium | Dark | Normal | 200% | Long English / LTR | Reduced |
| Medium | Light | Normal | 100% | Chinese / LTR | Reduced |
| Medium | Dark | High | 100% | Arabic / RTL | System |
| Expanded | Light | Normal | 200% | Arabic / RTL | Reduced |
| Expanded | Dark | High | 200% | Chinese / LTR | System |
| Expanded | Light | High | 100% | Long English / LTR | System |
| Expanded | Dark | Normal | 100% | Long English / LTR | Reduced |

The test app installs the official `GlobalWidgetsLocalizations` delegate for
`en`, `zh` and `ar`. Public component labels and business strings are explicitly
translated. Host-formatted values include Arabic digits, Arabic punctuation,
dates in words and localized percentages where those APIs accept strings.
Diff/Records internal counters continue to use their existing ASCII-digit
composition; this review does not introduce or claim a locale numeral/plural
formatter API.

## Font environment

Headless tests cannot infer native glyph fallback from the host desktop.
The export explicitly adds test-only Noto fallbacks to the production typography
through the existing public theme API. Geist remains the primary Latin font;
no Apple font is copied and no font is added to the library's distributed assets.

| Test-only fallback | Fixed version | SHA-256 |
|---|---|---|
| Noto Sans CJK SC Regular | 2.004 | `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b` |
| Noto Sans Arabic | 2.012 | `63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e` |

Both use SIL Open Font License 1.1. Fixed upstream commit URLs, copyright,
download hashes and both complete license texts are retained by the shared
[preparation script](../../../packages/beautiful_ai_ui/tool/release_review/prepare_review_fonts.py)
under `build/release_review/fonts`, and copied as metadata into the review
index. Tests never download fonts implicitly. Chinese glyphs, Arabic joining,
diacritics, RTL wrapping and punctuation were inspected in the actual PNGs;
missing-character boxes were not accepted as localization evidence.

## Pictured states and observations

| Module | Images | Accepted observations |
|---|---:|---|
| Prompt Bar | 17 | Translated multiline draft, removable attachment, model and send controls; localized source popup; keyboard focus and held-pointer feedback. The bounded editor does not claim to picture the whole draft at once. |
| Diff Table | 14 | Added/removed/modified rows, before/after meaning, inclusion/exclusion and apply action remain readable; focus and held-pointer outlines are visible. |
| Records Table | 17 | Selected record, status/error summaries and actual record detail in English, Chinese and Arabic. Intentional row ellipsis is supplemented by full-detail captures and a reachable close action. |
| Sidebar Nav | 25 | Closed/open compact navigation, medium rail and expansion, expanded lane, recent-items scrolling, focus and held-pointer states. A long workspace name may use its documented two-line summary; the screenshot does not claim all offscreen recents are simultaneously visible. |
| Flowchart | 17 | Ordered steps and expanded canvas, node/edge meaning, condition options, measured connectors, focus and held-pointer controls. |
| Insight Cards | 20 | Comparison with textual data, separate anomaly and allocation pages, selected metric/segment, keyboard focus and held-pointer controls. |
| Selection Actions | 17 | Exact selected source passage, native bounded document, translated actions/instruction, original/replacement preview, Keep/Discard/Retry, keyboard focus and held-pointer feedback. |

Each initial PNG was opened directly. Visual review found an actual native RTL
selection-paint defect: Flutter's default `BoxWidthStyle.max` could highlight
unselected following Arabic words despite a correct UTF-16 selection. The
document now requests tight selection boxes. A public native-renderer probe
first failed on the old behavior, then passed all six width/scale combinations;
the full matrix also asserts that selected paint does not intersect the next
unselected word's glyph boxes. Logical ranges, callbacks, gestures and clipboard
behavior are preserved.

After that fix and an unused-import cleanup in the font helper, the exporter
was rerun. **Six changed PNGs were opened again; the other 121 final PNGs are
byte-identical to the images already inspected.** The final Arabic highlight
ends at the intended passage. English/Chinese wrapped selection also remains
precise. No unresolved clipping, missing glyph, overlap or indistinguishable
pictured control state was observed in the declared images.

## Temporal, focus and input behavior

The default small regression suite gained 71 focused cases across four files:

| Test file | New cases | Evidence |
|---|---:|---|
| `p3_editors_tables_temporal_test.dart` | 26 | Actual elapsed hover frames, held press/cancel/release, disabled state, Arabic draft/selection and keyboard focus retention across responsive changes; Records checkbox behavior. |
| `p3_navigation_charts_temporal_test.dart` | 25 | Actual RGBA frame changes for Sidebar/Flow controls; pointer cancellation returns to hover; Tab/Enter; real Flowchart fling inertia; RTL observation inspection; lazy full-text accessibility and End interruption/convergence. |
| `p3_selection_temporal_test.dart` | 9 | Actual hover/pressed frames, cancellation without activation, single activation on release, host-controlled pending/result transitions, exact range and document focus across resize/Escape, and disabling during a held press. |
| `p3_prompt_measurement_cache_test.dart` | 11 | Original 1,000-source workload, repeated reopening, layout-input invalidation, same-ID text replacement and actual same-family `FontLoader` invalidation. |

These tests inspect evaluated paint or pixels after real input and elapsed
frames, rather than only comparing declared durations. Normal and reduced
policies intentionally retain short control transitions. Platform-disabled
animations and `none` produce immediate feedback. Normal Flowchart fling
continues between sampled frames; reduced/none/platform-disabled modes stop
inertia. Switching into reduced motion stops an already-running fling and does
not replay it later.

The review fixed missing held-pointer feedback in Sidebar buttons, Flowchart
node headers and Records checkboxes, alongside the root-owned shared action
control fix. Pointer cancel and disabled transitions clear pressed feedback.
Focus and selection outlines do not change layout dimensions.

Two bounded performance-related changes preserve their original data and real
operations:

- Prompt caches complete option measurement inputs, invalidates on font/style/
  locale/scaler/width/text changes, and retains actual access to source 999.
  Variable-height keyboard reveal uses the measured extents instead of an early
  lazy-list estimate. The default regression measures repeated layout work,
  not elapsed milliseconds.
- Insight keeps small textual datasets at natural height and realizes larger
  datasets in a 320dp lazy viewport. All 512 observations and four series remain
  available through pointer, keyboard and semantic scrolling. Home/End reach
  the real boundaries; data replacement and wheel/drag input cancel pending End
  seeks. These tests do not claim native profile frame times or memory results.

Recorded targeted runs passed: 123 tests for Prompt/Diff/Records and their new
cases; 89 for Sidebar/Flow/Insight before the three additional End cases; the
final Insight-focused run passed 47; Selection's old/new tests plus the explicit
font-dependent geometry probe passed 53. These overlapping runs are not summed
into an invented independent total.

## Reproduce explicitly

The large matrix lives under `tool/`, so ordinary `flutter test` and the existing
default test scan do not run it. From `packages/beautiful_ai_ui` on this Mac:

```sh
python3 tool/release_review/prepare_review_fonts.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /opt/homebrew/bin/mise exec -- python3 tool/release_review/export_p3_acceptance.py
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /opt/homebrew/bin/mise exec -- flutter test --no-pub \
  tool/release_review/selection_highlight_probe_test.dart
```

The exporter accepts `FLUTTER_BIN=/absolute/path/to/flutter` on another host.
Its default executes all 1,008 cases. `--capture-only`, `--only-module`, and
`--only-profile` are clearly marked iteration modes and must not be described
as a complete matrix run. Render failures, missing cases or source/font changes
produce a nonzero result. A generated manifest remains **unreviewed** until the
individual PNG observations and hashes are independently recorded.

The source-captioned images and exact manifest are supplemental visual
evidence. They do not substitute for canonical golden acceptance, real
assistive-technology output, physical-device input, or separately recorded
profile/release performance. Those gates remain owned by their corresponding
release evidence.
