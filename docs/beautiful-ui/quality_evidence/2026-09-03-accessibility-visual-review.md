# Supplemental accessibility visual review

Date: 2026-09-03. Platform: macOS 15.7.9 arm64, Flutter 3.47.0
(`4cf24164269a5ebf0c16a028a00727d0e77bbb05`), DPR 1, bundled Geist Sans/Mono.

**49 final images covering all 20 modules were visually reviewed for the
specific static scenarios below.** The final render exported without layout
errors. Every final PNG was opened with `view_image`, or was byte-identical by
SHA-256 to an image opened earlier in this review. After the final frozen
palette and muted-ticker fixes, all six changed light high-contrast images
were opened again; the other 43 images matched earlier inspected bytes.
Test success alone was not used as visual acceptance.

The machine-readable [review index](./2026-09-03-accessibility-visual-review.json)
records each exact PNG hash, dimensions, scenario, observations, Flutter version,
and 249 source/configuration/font hashes. The renderer's manifest SHA-256 is
`31612099bcb0a461d0748007528bb71642221d2a11d57d1af70136bf6f04f686`.
Capture finished at `2026-09-03T08:48:09.245071+00:00` with source files unchanged
throughout capture. The base Git HEAD was `37a56e0e28c5a3dcadd16678a02c92037932fec2`;
the exact source inventory includes the concurrent uncommitted fixes and is
therefore more precise than that commit alone.

## Export and scope

Run the [independent export script](../../../packages/beautiful_ai_ui/tool/release_review/export.py)
from `packages/beautiful_ai_ui`:

```sh
python3 tool/release_review/export.py
```

Set `FLUTTER_BIN=/absolute/path/to/flutter` if Flutter is not on `PATH`. The
resolved Pub workspace must already exist. The script validates the two local
package paths, hashes both implementation trees and package resolution, makes
missed test taps fatal, checks resulting disclosure/page/submission states,
and never changes approved golden images. See its
[usage and limitations](../../../packages/beautiful_ai_ui/tool/release_review/README.md).

The generated [HTML index](../../../packages/beautiful_ai_ui/build/release_review/index.html)
links to full-size PNGs under `build/release_review/`. Those generated files are
local supplemental evidence, not committed canonical baselines. Re-run the
export to regenerate them; accepted hashes remain in the review index above.

| Profile | Viewport | Text | Direction | Contrast | Motion input |
|---|---|---|---|---|---|
| Compact light | 390dp | 200% | RTL | High contrast | Platform disables animations; package system policy |
| Expanded dark | 1,280dp | 100% | LTR | High contrast | Package reduced-motion policy |

There is 16dp padding on each side. Available component width is at most 358dp
or 1,248dp; components may retain their own smaller width. Sidebar uses its
natural 288dp lane. The tallest final image is 1,527px; the exporter rejects
root images taller than 4,096 logical pixels. Fixed-height descendant viewports
remain visible as viewports and are not represented as complete long datasets.

## Reviewed module snapshots

Each row was reviewed in both profiles. The states are deliberately small and
representative, with public APIs and explicit host-supplied data.

| Module | Pictured states and observations |
|---|---|
| Loading State | Drive, Dots, Orbit, Surfer; label, fixed elapsed time and media fallback readable. |
| Thinking | Working expanded Steps and completed expanded Coding; details and change counts visible. |
| Context Cards | Two source cards with different tones, wrapping body text and source controls. |
| Recommendation Card | Selected recommendation, confidence, alternatives and readable primary action. |
| Search | Populated query and two visible matching results. |
| Code Block | Code and Diff retain LTR code, line numbers and explicit change marks in the RTL surface. |
| Streaming Text | Completed answer, expanded citation source, follow-up, and clearly selected positive feedback. |
| Approval Card | Multiple-choice selection and successful submission; native check marks replace missing glyphs. |
| Tool Chips | Completed read with expanded output, failed write, and file-change counts. |
| Task Rows | Capsules/List with completed, 65% running, pending and failed states, plus retry. |
| Chat | Two messages, selected context, populated draft and primary action inside a bounded panel. |
| Filter Table | All filter selected, two records with text status; compact cards and expanded table. |
| Fine-tune Card | Selected Grid, width/opacity inputs, increment/decrement controls and current type. |
| Prompt Bar | Rounded tall composer, removable attachment, multiline draft, model and dictate/send controls. |
| Diff Table | Added, removed and excluded modified rows with complete before/after data and inclusion marks. |
| Records Table | Two rows with selection and a failure; additional full-detail captures expose the complete error. |
| Sidebar Nav | Open compact drawer and expanded lane; an additional compact closed-trigger capture. |
| Flowchart | Compact ordered steps with an open condition, plus expanded canvas with both nodes and connectors. |
| Insight Cards | Comparison with complete textual data; anomaly and allocation as separate captures; visible accepted selections. |
| Selection Actions | Seeded text range and host-returned preview, with original/replacement and Keep/Discard/Retry actions. |

## Findings fixed and rechecked

1. The closed Sidebar drawer used a fixed 56dp height and overflowed by 7px
   with the default label at 200% text. It now sizes from its contents. Both
   the closed trigger and open 288dp navigation lane were re-rendered and viewed.
2. Approval's selected and submitted check marks used a glyph that rendered as
   a missing-character box with the fixed fonts. Both now use a native path
   painter. Selected and successful states were separately viewed.
3. Primary action text assumed a light foreground over a bright accent fill.
   The original light/dark pairs measured approximately 3.375:1 and 2.602:1.
   Shared action controls now choose a contrasting foreground; the final images
   show readable dark text on the accent fill. Pixel viewing does not replace
   the separate contrast calculations and interaction-state tests.
4. Accepted feedback and Insight metric selection previously had no distinct
   visible treatment. Selected actions now have a distinct fill and thicker
   border, also visible in Approval, Chat, Filter, Fine-tune and Flowchart.
5. Normal-theme secondary metadata and placeholder text used overly faint
   `inkSubtle`. The final palette uses light `#66696f` and dark `#9c9fa5`;
   all eight changed normal macOS P1/P2/P3 golden images were separately
   re-rendered and viewed. Light `accentInk` is now `#0067cb`; the six changed
   high-contrast images show the updated code, citation, adjustment, workflow,
   comparison and allocation colors with no new clipping or missing marks.

The frozen source inventory also includes the action control's immediate color
update while `TickerMode` is disabled. Static images do not establish the
dynamic dark-to-light transition; that issue retains its separate widget and
Safari evidence. The final macOS golden update and subsequent strict comparison
each passed all 12 tests; Loading's two macOS PNGs and all ten Linux PNGs stayed
byte-identical. This review did not change Linux baselines or golden test source.

No unresolved clipping, missing mark, or missing selected-state distinction
was observed in these final fixture images. Records intentionally truncates a
bounded row summary; its additional detail images display the full error.

## Remaining matrix

- Compact dark, expanded light, medium widths and the complete combination
  matrix of text scaling, direction, contrast and motion remain separate checks.
- RTL uses English fixture text to examine direction and wrapping. Real
  Arabic/Hebrew translations, locale-specific punctuation and glyph coverage
  are not accepted by these images.
- Static images do not prove temporal motion behavior, hover/focus/pressed
  transitions, native selection handles, screen-reader output or physical-device
  accessibility. The profiles document the applied motion inputs only.
- Small visual fixtures do not establish large-data realization, profile/release
  frame timing, memory behavior, platform journeys or the exhaustive interactive
  state matrix. Those release gates retain their independent evidence.

This review contributes supplemental visual evidence to the support matrix; it
does not mark every component's stable-release acceptance complete.
