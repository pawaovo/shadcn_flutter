# Readonly selection controls — 2026-09-04

The root task reported that a trusted ArrowRight left the full selection at
`[0,109]` in three local in-app-browser controls: a native HTML readonly textarea,
stock Flutter `EditableText`, and `BeautifulSelectionActions`. A separate stock
control that routed arrows through Flutter's existing selection intents collapsed
the selection to `[109,109]`. These are bounded diagnostic observations; no CI,
clipboard, accessibility, or platform acceptance result is changed.

The [structured observation record](2026-09-04-readonly-selection-control.json)
is a **compact transcription of root task messages**, not an export of the full
browser trace. Complete runtime exports were not supplied or found in the local
diagnostic directories at archival time. Missing timestamps and identity values
are left unknown rather than reconstructed from source code or build logs.

| Control | ArrowRight observation | Selection afterward | Other supplied observations |
| --- | --- | --- | --- |
| Native HTML readonly textarea | Trusted; modifiers `0`; `defaultPrevented: false` | `[0,109]` | Text length 109, readonly/focus/identity retained |
| Stock Flutter readonly `EditableText` | Trusted; modifiers `0`; `defaultPrevented: false` | `[0,109]` | Text length 109, readonly/focus/identity retained |
| `BeautifulSelectionActions` readonly document | Trusted; modifiers `0`; `defaultPrevented: false` | `[0,109]` | Text length 109, readonly/focus/identity retained |
| Stock Flutter with SDK selection intents | Keydown trusted and `defaultPrevented: true`; keyup `defaultPrevented: false` | `[109,109]` | Text length 109, readonly/focus retained; state `243876494`, controller `858759108` unchanged |

The stock variant adds a `Shortcuts` map for plain/Shift Left/Right using
`ExtendSelectionByCharacterIntent`, with the original `EditableText` Actions.
It does not implement character-offset arithmetic or write DOM selections.
Its observers are passive with respect to input state, but the experiment itself
**changes keyboard routing**. Only the supplied ArrowRight observation is
recorded as exercised; the additional mapped keys and full copy/cut/paste journey
have no result in this local observation record.

The supplied stock-variant event times are probe-relative milliseconds:

| Recorded phase | Elapsed ms | `defaultPrevented` | `isTrusted` |
| --- | ---: | --- | --- |
| Keydown capture | 18639 | true | true |
| Keydown animation-frame observation | 18657 | true | true |
| Keydown timer observation | 18659 | true | true |
| Keyup capture | 18676 | false | true |

The root task clarified the stock variant's sequence: click, then Meta+A produced
DOM and Dart selection `[0,109]`; one ArrowRight produced `[109,109]`. The initial
selection snapshot is therefore **after Meta+A / before ArrowRight**.

Additional baseline timestamps were supplied without a phase mapping: native
HTML `49272, 49274, 49277, 49278, 49280, 49283`; stock Flutter
`360429, 360447, 360449, 360470`; product
`387786, 387806, 387808, 387834`. They are retained as unassigned elapsed-time
lists in JSON. They are not labeled as keydown, keyup, capture, animation frame,
or timer observations without the complete trace.

The initial controls use **exactly the CI document text**: a single line of 109 UTF-16
code units with no newline. In commit `f39faedf`,
`packages/beautiful_ai_ui_catalog/lib/p3_examples.dart:729–730` contains adjacent
Dart literals joined by the first literal's trailing space. Their source-file
line break does not enter the value. The archived HTML and both Dart constants
were compared against that commit's value and match exactly. An earlier claim
that CI used different multiline text was incorrect. The original
[SDK variant manifest](../diagnostics/readonly-selection-control/readonly-sdk-shortcuts-manifest.json)
is retained unchanged, including its superseded text-equivalence wording; the
correction is explicit in this record and the provenance inventory.

The browser surface was Codex's in-app browser. Its browser/engine version was
not captured. The Flutter controls were release builds; the compared W3C CI
suite used debug builds. Exact text equality does not establish equivalence of
browser host, build mode, layout, timing, or complete input sequence. The local
observations identify keyboard routing as a useful experimental variable; they
do not establish the cause of native default behavior or a product-only defect.

The earlier `f39faedf` CI trace audit remains separately bounded: Chrome's 104
and Edge's 94 post-Arrow snapshots all retained DOM and Flutter selection
`[0,109]`. Polling does not exclude a transient change between samples. Safari's
WebDriver log was empty, so its retained Flutter state and pre-Arrow DOM
observation do not establish a post-Arrow DOM trajectory. Firefox's original
W3C suite passed. This archive task did not rerun those tests.

The [source archive](../diagnostics/readonly-selection-control/README.md) contains
the three byte-identical source copies, both build logs, and the historical SDK
variant manifest. The [provenance inventory](../diagnostics/readonly-selection-control/provenance.json)
records source/main-JS/log SHA-256 values, current SDK and relevant dependency
source hashes, output metadata, and complete output-tree inventory digests.
The baseline Flutter output has 341 files / 49,601,663 bytes; the SDK variant has
341 files / 49,305,609 bytes. Compiled JS, fonts, and engine assets remain in the
ignored local output directories and are not copied into the repository.

This is a post-observation inventory, not proof of a contemporaneously frozen
build or the exact bytes served at each event. The existing SDK manifest's
source/main-JS/build-log hashes do match the retained files. Full IAB exports and
browser identity can be attached later without turning unobserved cases into
results or replacing this compact transcription.

**Actual product follow-up.** The root task then operated a separate release
probe containing two actual `BeautifulSelectionActions` components, without a
probe-level shortcut map or custom selection action. Each was exercised once:
click, Meta+A, then one ArrowRight. Both DOM and Dart selection moved from
`[0,109]` after Meta+A to `[109,109]` after ArrowRight. Text stayed at 109 code
units, readonly remained true, and the document retained primary focus and its
state/controller identity.

| Product fixture | Text boundary | Stable state / controller | Reported result |
| --- | --- | --- | --- |
| Exact CI document | Original single-line text; no newline | `706662049` / `1013550805` | One plain ArrowRight collapsed to `[109,109]` |
| Explicit multiline variant | One separator space replaced by newline; still 109 code units | `87930328` / `972951705` | One plain ArrowRight collapsed to `[109,109]` |

The exact-CI product keydown observations were capture `22959`, animation frame
`22986`, and timer `22989` ms; all were trusted, default-prevented, and had all
modifier flags false. Keyup capture at `23014` ms was trusted and not
default-prevented. The multiline product keydown observations were capture
`43178`, animation frame `43206`, and timer `43210` ms, with the same trust,
default-prevention and modifier values. Its keyup at `43233` ms was trusted and
not default-prevented; a finer phase label was not supplied. These are
probe-relative times transcribed from root messages. No full trace export is
claimed. Shift-arrow checks remain headless-test coverage, not an observed
real-browser trial in this record.

The appended [product probe source](../diagnostics/readonly-selection-control/readonly_product_web_probe.dart),
[byte-identical build log](../diagnostics/readonly-selection-control/readonly-product-web-build.txt),
and [original product manifest](../diagnostics/readonly-selection-control/readonly-product-web-manifest.json)
are preserved separately from the initial three sources. The build log reports
38.5 seconds and successful output to `readonly-product-web`. The manifest's
five hashes—for probe source, main JS, build log, `selection_actions.dart`, and
`readonly_selection_shortcuts.dart`—match the retained files at append time.
The provenance inventory includes the output metadata and hashes; compiled
assets remain local. This local product observation does not replace the
original W3C suite or establish a broader browser, clipboard, or platform pass.
