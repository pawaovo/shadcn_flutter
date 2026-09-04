# Release readiness — 2026-09-04

Date: 2026-09-04 (Asia/Shanghai). Toolchain: Flutter 3.47.0 / Dart 3.13.0.
Status: **not ready for stable-release sign-off**. At the latest completed
`f5484b9f` checkpoint, all four browsers pass the complete trusted W3C input
journey, and all three native framework input jobs pass. Main CI is **11/12**:
Android and iOS complete their actual journeys, including the corrected input
synchronization and both numeric submission assertions. The only main failure
is Edge's initial browser navigation/window request before application code.
Linux's native parent
repair passes all three actual FlView cases; full Orca tasks now expose SDK
name-notification and expanded-state limitations. P1/P2 engineering budgets
passed at the earlier `87299572` runtime snapshot; P3 frames, OS IME and full
device/AT acceptance remain open.

All 20 Gallery components and seven foundation/building-block items have
implementations. **All 27 registry entries remain `in_progress`; all six Flutter
platforms remain `Partial`.** This document adds current evidence without
changing those decisions or rewriting earlier records.

## Source and evidence boundaries

| Source snapshot | Evidence and meaning |
| --- | --- |
| Historical `c2bde85dd5da7c33b0f7881234ae312f3be1826c` | The [September 3 CI record](./2026-09-03-final-ci-33748054504.json) preserves run `33748054504`, attempt 1, with 12/12 jobs passing. Its iOS driver, hosted consumer, build, visual and profile observations remain historical evidence for that source. They do not accept a later candidate. |
| Prior `36142500c9ad91dc307b6c8005e78add357f080b` | The earlier completed cloud checkpoint summarized below has main CI 10/12 and input/AT 1/9. Two complete native captures at this SHA have engineering-budget failures. Those results remain unchanged. |
| Earlier runtime `8729957220c011329022bafc7a0f7402434ce15e` | Main CI **12/12**, input/AT **4/9**, and clean publication dry-run **exit 0 / zero warnings**. The native P1/P2 budget is **8/8 pass**; P3 has **1 pass / 6 fail**. See its recorded runtime checkpoint below. |
| Local changes after `3614250`, now committed in `87299572` | P1 performance repairs, input/CI repairs and lossless timeline transport have completed local verification: 640 library tests, 59 Catalog tests, strict analysis and 141-file formatting. The exact committed source, clean dry-run and subsequent cloud/native observations are recorded in the current checkpoint. They do not accept future changes automatically. |

The [September 3 readiness document](./2026-09-03-release-readiness.md) and
`toolchain.json` retain their dated historical scope. This record is the current
entry point; an older heading containing “final” does not override a later
recorded failure.

## Latest completed checkpoint at f5484b9f

[The exact-source CI record](../../../.github/evidence/f5484b9f-ci.md) and its
[JSON manifest](../../../.github/evidence/f5484b9f-ci.json) bind the two new
runs and 21 job identities to `f5484b9ff80ebae9c728204c48387e3ef148bda8`.
Main CI is **11/12**, including successful actual Android and iOS journeys.
The iOS report has `passed=true`, required driver exit 0 in 57.405 seconds,
and `All tests passed.`. Both unconditional numeric checks execute: controller
text is `360` and the actual host Width setting is `360`. VM discovery, process
cleanup, stdout EOF and the final drain also succeed. The input protocol
correction therefore has an actual iOS result, not merely its local model.

Chrome, Edge, Firefox and Safari again pass all four independent trusted W3C
journeys; Safari's separate original journey passes as well. All three native
framework input/clipboard jobs pass. Combined input/AT remains **4/9** because
the retained framework composition checks and the Narrator environment do not
all pass. Edge's framework failure is startup rather than a composing assertion;
Chrome/Firefox fail the injected range check and Safari fails its synthetic
resize range check. Actual OS IME remains unaccepted.

The single main failure is Edge's startup before Catalog navigation.
[The startup comparison](./2026-09-04-edge-startup-boundary.md) finds identical
actual capabilities and versions within the input job, with the successful
suite executing the same SDK window-position request. Failed requests wait for
initial navigation after earlier child-process/network-service startup errors;
the actual bounds-setting command has not executed. The specific startup cause
is unresolved. Neither another suite's pass nor a configuration change accepts
the unexecuted Edge shared journey. Original failures were not retried or erased.

An independently verified empty diff covers the entire public package,
Catalog production Dart, web and all platform runners between `e3526d3f` and
this candidate. The e3526d3f Web/macOS release builds and zero-warning publication
dry-run retain that unchanged runtime/package boundary. The earlier native
FlView/Orca evidence is also retained with its original source and **0/3 full AT
tasks accepted**; it is not counted as a new run. All newer changes here are
test-harness and documentation changes. No package was published.

## Earlier completed checkpoint at e3526d3f

[The exact-source CI record](../../../.github/evidence/e3526d3f-ci.md) binds the
results to `e3526d3fb6f9ce97706a3e28297d5e682ebce9e8`. Main CI is **11/12**;
Android's original full journey now passes. The iOS VM discovery query also
succeeds, verifies cleanup and connects its real Dart driver. The later
FineTune width failure is therefore an actual test assertion, not the earlier
environment failure: the test expects `360` and observes `324`.

All four independent W3C suites pass again, as do all three native framework
input targets. The combined input result remains **4/9**: Chrome/Edge/Firefox
retain the framework composition failure, Safari retains synthetic resize
composition failure, and Narrator lacks an audio endpoint. Native JSON output
and the three actual parent/lifetime cases pass. Thinking's native enabled
state is now true, while full AT remains **0/3**, including the documented
SDK name/expanded limitations and an uncompleted Search inspection.

Fresh Web and macOS release builds pass; the latter is 50.5 MB. Publication
dry-run passes with zero warnings and a 3 MB archive. No publication occurred.

## Framework text-input repair following e3526d3f

The [iOS fixture diagnosis](./2026-09-04-ios-framework-text-input-fixture.md)
confirms that `360` is within Width's `40..999` bounds and that responsive
layout does not alter the property value. `IntegrationTest` leaves
`TestTextInput` unregistered, while the old `tester.enterText` path pretends to
receive a native edit without updating the actual input peer. The pinned SDK
explicitly documents that synchronization risk.

The bounded protocol control shows Flutter at `360` while its last outbound
editing state remains `324`. An explicitly simulated echo reproduces the
reversion; the actual failed iOS echo sequence was not recorded. The replacement
uses the public `EditableTextState.userUpdateTextEditingValue` path once, with
primary-focus and complete-value checks. All six original journey text values
and subsequent key actions are retained. The original Width controller
assertion is retained and a new public host-settings assertion requires Width
to be accepted as `360`, so merely changing a draft cannot pass submission.

The new outbound protocol regression passes, the existing FineTune contract
suite passes **18/18**, and three existing Catalog interaction scenarios pass
with this helper in an explicitly labeled local compatibility copy. Targeted
analysis and formatting pass. The public library and native application source
remain unchanged; this is a fixture correction requiring the next actual iOS
run, not OS keyboard or IME acceptance. No new manual Orca run is needed for
this fixture-only change; the exact e3526d3f native evidence remains scoped to
its unchanged runtime sources.

## Earlier completed checkpoint at bff08825

The new source is `bff08825bf9bc48a074a261ec9f912a1058058a2`.
[Main CI 33830801341](https://github.com/pawaovo/shadcn_flutter/actions/runs/33830801341)
finished naturally with **10/12** jobs passing.
[Input/AT 33830801244](https://github.com/pawaovo/shadcn_flutter/actions/runs/33830801244)
has **4/9** combined jobs passing, while **Chrome, Edge, Firefox and Safari all
pass their entire independent W3C suites**, including the original readonly
caret, rejected paste, actual paste and completion assertions. The Web readonly
selection repair therefore has the required four-browser runtime result.

The remaining framework results are distinct: Chrome/Firefox fail the retained
composition assertion; Safari gets through the earlier checks then fails
synthetic resize composition preservation. Edge's framework run times out in
WebDriver navigation before producing its framework report; it must not be
classified as a composing assertion failure. Its independent W3C suite passes.
Three native framework input targets and ordinary GTK Orca capability pass.
Narrator still lacks a default WASAPI render endpoint.

Android's emulator boots, builds and installs the app. The copy completion
helper observes `Copied`, but the caller's later assertion finds zero copies.
The [minimal fixture repair](./2026-09-04-android-copy-feedback-fixture.md)
removes only the redundant frames between completion and the original exact
feedback assertions; real execution at the next source remains required.
iOS builds, installs and launches, but its first unified-log query times out
after 15 seconds with zero bytes. The cleanup process-group check fails; the
driver never starts. The original report does not distinguish the underlying
`ps` timeout from nonzero exit. The next diagnostic retains that cause while
preserving every timeout and cleanup requirement.

[Catalog Orca pilot 33830848233](https://github.com/pawaovo/shadcn_flutter/actions/runs/33830848233)
verifies all three actual native parent/lifetime cases. Theme's reverse chain
now reaches the same-process frame with all inverse relations verified, and
Orca keeps its locus on Theme. Fresh native getters show the updated label,
but a new Where Am I handler still speaks the old name; expanded-state mapping
is also missing in this pinned SDK. The [SDK boundary report](./2026-09-04-linux-sdk-accessibility-boundaries.md)
separates these findings from Thinking's own missing enabled flag. That flag
now has a minimal repair with **15/15** targeted checks, without claiming it
fixes the SDK mappings. Native initialization noise in the probe's old stdout
report is retained; the next version writes JSON to an explicit file and keeps
stdout/stderr separately.

At bff08825, clean publication dry-run passes with zero warnings and a 3 MB
archive, and a fresh Web release build passes. The [live input-method observer](./2026-09-04-live-os-ime-observation.md)
is available for real human input. Native automation observed only a trusted
ordinary character insertion, with no composition session; actual OS IME
acceptance remains unestablished. No package was published.

## Earlier completed checkpoint at f39faedf

[The exact-source CI record](../../../.github/evidence/f39faedf-ci.md) and its
[JSON manifest](../../../.github/evidence/f39faedf-ci.json) bind all three runs,
22 job identities and 13 core report hashes to
`f39faedfcb0e09f57e29fd8edbfab98b808164b9`. Main CI passed **12/12**. Input/AT
passed **4/9** jobs: the three native framework targets and GTK Orca capability.
Firefox again passed its complete independent W3C suite, although its combined
job failed the retained framework composition check.

Chrome, Edge and Safari passed the actual readonly document's focus, full
selection, copy, Backspace protection and Cut rejection. Their next real
ArrowRight did not satisfy the required collapsed caret, and Paste was not
issued. Chrome/Edge observations show both DOM and Flutter still at `0:109`,
with text, readonly state, focus and controller identity preserved. Safari
provides the final Flutter selection but not the equivalent continuous DOM
trace. This is not evidence of document deletion or observed DOM/Dart divergence.

The real Linux Catalog pilot now reaches Theme with the first Tab and changes
system to light with Space. Native enabled/focused state and Orca's initial
Theme focus speech are observed. On the subsequent ancestor walk, an
intermediate filler reports no parent; Orca resets its locus to the frame/panel
and its real Where Am I handler says `panel.` instead of the required Theme
utterance. No complete task is accepted. The proposed bounded native ATK parent
repair has its own real FlView initialization/lifetime probe and requires a new
Linux execution; neither source review nor unrelated audio accepts that repair.

Local validation at this source remains **641/641 library tests, 66/66 Catalog
tests**, strict analysis and Git-source formatting. The clean publication
dry-run exited 0 with zero warnings, and fresh Web and macOS release builds
passed. No package was published. Narrator still lacks a default WASAPI render
endpoint; actual OS IME, physical devices and human speech review remain open.

A later [direct macOS observation](./2026-09-04-macos-direct-input.md) confirmed
native Tab traversal, Motion activation, and typing/filtering `waffle` in
Search after verifying the real foreground app. The subsequent system paste
operation timed out and produced inconsistent AX/rendered values, so clipboard
completion remains unaccepted. These bounded native observations do not accept
the complete input matrix or the later source changes.

## Repairs following f39faedf

The Web readonly document now routes plain and Shift Left/Right through
Flutter's own `ExtendSelectionByCharacterIntent` actions. This scope applies
only to that document on Web. Native widgets and Control/Alt/Meta shortcuts
retain their host policy; the component does not calculate character offsets
or manipulate DOM selection directly. Three red regressions became green,
covering full-selection collapse, grapheme movement and the SDK's RTL logical
selection contract; modifier/native-host protections also pass. All **648
library tests**, strict library/Catalog analysis, and **149 Git-source Dart
format checks** pass.

[The actual-browser controls](./2026-09-04-readonly-selection-control.md) compare
the earlier default paths with both a stock SDK-action variant and the actual
repaired product. On the product page, one real Meta+A followed by one
ArrowRight moves both DOM and Flutter from `0:109` to `109:109`, preserving
readonly state, focus, text and editor/controller identities. Both the exact
CI text and a separately labeled newline variant pass this bounded operation.
The observed host is Codex's in-app browser, release mode, with browser version
unknown. The four-browser CI and its complete clipboard journey remain their
own required verification; none of their assertions was relaxed.

The Linux Catalog runner repairs only a missing parent on its real direct
AtkSocket child. Its weak-reference destroy hook removes only the relation
it installed and still owns. The separate native probe covers actual SDK
initialization and explicitly constructed existing/replaced-parent conditions,
including real getter inverses and finalization. Independent source review,
55 Python checks (53 passed, two Windows-only skips), and workflow lint pass.
Actual native compilation, GTK lifetime results and full Orca tasks await the
new Linux execution. See the [native bridge contract](../../../packages/beautiful_ai_ui_catalog/linux/runner/ACCESSIBILITY_BRIDGE.md).

## Earlier checkpoint at 3612efd0

[The compact CI record](../../../.github/evidence/3612efd0-ci.md) and its
[JSON](../../../.github/evidence/3612efd0-ci.json) preserve the exact run/job
identity and report hashes. Main CI was **11/12**, with actual iOS driver
success and an Edge startup timeout before application navigation. Input/AT
jobs were **4/9**, while Firefox's independent W3C suite completed fully.
All four real-browser W3C runs passed Prompt typing, menu Escape, keyboard
copy/paste, five actual window widths, submission, and Code/Streaming clipboard
operations. The original Prompt semantics repair is therefore verified for
those browser flows.

Chrome's remaining readonly failure was an empty selected substring, after
its document-text-unchanged assertion had passed. Edge/Safari did not satisfy
the collapsed-caret condition after ArrowRight; Paste was not issued. The next
repair connects the readonly document's Semantics focus action to its real
FocusNode and uses document-specific Flutter/DOM readiness and selection
observations before the unchanged real-key operations. Its regression moves
focus from Prompt to the actual document and preserves text, selection,
controller identity and the readonly contract.

The Catalog content FocusScope and readonly-focus changes pass **641/641
library tests and 66/66 Catalog tests**, strict analysis, and formatting of
**146 package Dart sources plus the protocol test**. Real-browser and
X11/Orca outcomes still need the new source's CI run.

The remaining framework composition assertion is deliberately retained.
[Actual-browser stock controls](./2026-09-04-web-composition-control.md)
showed the same normalization in stock EditableText and Prompt: direct Dart
range injection was cleared, and synthetic DOM composition events did not
establish the expected active range under the enabled semantics strategy.
Text, selection and focus stayed correct. This establishes the tested channel's
limit, without accepting or rejecting real OS IME. No assertion is removed and
no synthetic event is relabelled as real input-method evidence.

## Earlier checkpoint at 351d7c4f and its following repair

[The compact 351d7c4f report](../../../.github/evidence/351d7c4f-ci.md) and
[its JSON](../../../.github/evidence/351d7c4f-ci.json) bind the following results
to `351d7c4f54b66d93749028c8053cc01840bd5328`:

- Main workflow **12/12 passed**, including the actual iOS driver again.
- Independent input/AT workflow **3/9 passed**: all three native framework
  input/clipboard jobs succeeded. Four Web jobs failed. The ordinary Orca
  capability probe timed out during the initial dependency import; Narrator
  again had no WASAPI render endpoint. Those are separate capability failures.
- The Catalog pilot's **5 PTY tests and actual GTK preflight passed**. Its live
  diagnostic stream captured 1,165,603 original bytes with verified EOF and
  reader shutdown. The real Catalog started and exposed 421 native nodes, but
  none of the three complete tasks was accepted. The observer's GI text getter
  collision and missing enabled semantics on Theme/Motion were then identified.

The browser diagnostics now expose the actual failure: opening/dismissing
Prompt menus clears the browser editor. An Edge terminal assertion expects the
full multiline draft after Escape and receives an empty string, before any
clipboard-copy action. A mechanism regression reproduces changing Prompt
semantic node IDs even while the EditableText state, controller, input client,
focus and selection stay stable. The next product repair gives the composer
container a stable key. Its semantic identity stays stable through command
and model menus, and all original input assertions remain.

The next candidate also explicitly marks the Catalog's always-enabled header
buttons as enabled. Flutter's Linux bridge maps the previous unspecified flag
to absent ATK ENABLED/SENSITIVE state; the existing focus tests reproduce that
flag and pass with the fix. This does not establish why Tab traversal was still
observed on the panel. The read-only observer now calls the explicit GI Text
interface, with two regression cases, and does not change focus requirements,
AT-SPI cache settings or task timeouts.

Local verification of these pending product repairs is **641/641 library tests,
61/61 Catalog tests, strict analysis clean, and 144 Git-source Dart files with
zero format changes**. The next real-browser run must verify that the original
draft-clearing symptom is gone. The new error recorder forwards the original
Flutter handler while preserving each error before aggregation; it does not
consume or suppress failures. The component and Catalog changes require their
new CI result; the older evidence remains scoped to its recorded source.

The subsequent Catalog cold-start regression also identified a missing content
focus scope in its builder-only app shell. A standard autofocus `FocusScope`
now wraps the actual Overlay content, without choosing any specific control.
Three initial-view-event orderings must reach Theme with the first Tab and
activate a real system-to-light transition with Space; an existing editor must
retain focus, value and selection during view recovery and theme changes.
The old pointer/keyboard fixture now mounts a fresh app before its keyboard
phase, so an already-light theme can no longer hide a missing key action.
The complete Catalog suite passes **65/65** with this repair; the library
remains **641/641**, strict analysis is clean and all **145 Git-source Dart
files** pass formatting. Real X11/Orca cold-start behavior remains pending the
new candidate run.

## Runtime checkpoint at 87299572

[Compact CI evidence](../../../.github/evidence/87299572-ci.md) and its
[JSON manifest](../../../.github/evidence/87299572-ci.json) preserve job IDs,
uploaded artifact hashes and the actual driver results.

| Verification | Actual result | Boundary |
| --- | --- | --- |
| [Main CI 33820302952](https://github.com/pawaovo/shadcn_flutter/actions/runs/33820302952) | **12/12 jobs passed**, including the actual iOS simulator driver, six platform builds and browser/native journeys | Exact recorded source and toolchain; physical devices and full AT are separate. |
| [Input/AT 33820302929](https://github.com/pawaovo/shadcn_flutter/actions/runs/33820302929) | **4 passed, 5 failed**. Linux/macOS/Windows framework input, including actual native clipboard, and GTK Orca capability passed | Four Web jobs and the Narrator capability job failed. Native framework injection is not physical keyboard or OS IME proof. |
| [Catalog Orca pilot 33820333356](https://github.com/pawaovo/shadcn_flutter/actions/runs/33820333356) | Release build bound to the exact source; GTK preflight observation timed out | Catalog never started and all three tasks remain `not_observed`. Actual audio existed, but the required live handler/utterance correlation was not complete. |
| Local publication dry-run after commit | **Exit 0, zero warnings**, reported archive 3 MB, clean working tree | Validation only; no pub.dev publication. The earlier dirty-tree warning remains historical. |
| [Native performance](./performance/2026-09-04-87299572-native-profile.md) | P1/P2 **8/8 pass**, 5,212 frames / 504 RSS samples; P3 **1 pass / 6 fail**, 4,543 frames / 569 RSS samples | Both are valid complete captures; all sampled RSS budgets pass. P3 frame failures remain accepted evidence of this run. |

The four Web framework reports show that the initial view-focus transition
redirected focus to `Hide steps thinking details` after the editor request.
The subsequent test-only repair prepares actual view focus before requesting
editor focus. Its minimized loop reproduces the old ordering and verifies the
new ordering, including an existing primary scope and an already focused view.

In the independent W3C suites, Chrome and Edge lost the initial `b` before the
exact first-text assertion; **Shift+Enter was never sent**. Firefox terminated
after Escape, before copy, and Safari terminated after copy, before clear.
Their old driver did not capture the original early target failure. The next
candidate waits for actual Flutter/DOM editor readiness before typing once,
observes exact selection and reads the original terminal test result alongside
every stage. The original action payloads and text assertions remain intact.
These repairs have local protocol/DOM regressions; their real-browser result
still needs the next CI run.

Narrator's fixture now compiles, exposes UIA and responds to Tab/Space, but the
hosted runner has no WASAPI render endpoint. Narrator navigation, utterance and
audio remain unaccepted. The Catalog Orca pilot has a separate pending fix for
live debug transport: a raw owned PTY makes producer lines observable without
changing their bytes or substituting audio for the required utterance evidence.

P1/P2 build peaks improved from 28.981 to 2.089 ms (Code), 77.294 to 6.923 ms
(Tool), 11.279 to 1.104 ms (Chat) and 38.296 to 5.306 ms (Filter). Whole-suite
peak sampled RSS is 387.96875 MiB; individual Search/Code RSS increases remain
in the data. No component-exclusive memory or leak claim is made.

P3's IINA and video-decoder process starts overlap the Records sampling window;
later scenarios also slowed. This is a timing association, not established
causality. Diff's 5/495 over-interval frames already exceeded the 1% budget
before those processes started. A same-source playback-paused comparison has
been requested but has not been executed. The separate failed P3 preparation
attempt measured zero workloads and is not a comparison or a budget pass.

A later local macOS release-input attempt built successfully but could not
establish native editor focus through the current UI-control surface; no text
was observed after typing. It is recorded as unaccepted, with no product cause
inferred. The owned app was closed. This does not weaken the passing cloud
native-clipboard evidence or establish OS keyboard/IME acceptance.

## Earlier completed cloud checkpoint at 3614250

| Workflow | Actual result | Failed jobs / surviving evidence |
| --- | --- | --- |
| [Main CI `33816718251`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33816718251) | **10 success, 2 failure; completed failure** | `Build Apple catalogs` and `Run Edge journey` failed. Builds, quality/package checks, Chrome/Firefox journeys, and Android/Linux/macOS/Windows journeys retain their successful results. |
| [Input/AT CI `33816718252`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33816718252) | **1 success, 8 failure; completed failure** | Only `Real Orca capability probe (not app acceptance)` passed. The full original Safari journey passed as a sub-suite, but the later framework input failure leaves its job failed. |

The downloaded result snapshots are `/tmp/beautiful-ci-36142500/main-final.json`
and `input-final.json`; `triage.md` in the same directory indexes the original
logs and diagnostic artifacts. The run links above preserve the portable source
and job-result identity.

The observed failure boundaries are specific:

- **iOS simulator:** installation passed, then `simctl launch` exceeded its
  30-second limit, exit 124, before VM discovery or the native Flutter driver.
  Cleanup termination also exceeded 15 seconds. The Apple job name does not
  mean compilation failed. The passing macOS journey and older successful iOS
  drivers cannot substitute for this candidate's missing iOS execution.
- **Main Edge:** matching Edge/driver 152.0.4191.53 timed out after 300 seconds
  in the SDK's initial `SetWindowRect {x: 0, y: 0}`, before the custom journey
  driver. A network-service crash is recorded, but its causality is unproven.
  Input Edge used a different 151 build, so that session is not a same-binary
  startup comparison.
- **Four browser framework targets:** Chrome, Edge, Firefox and Safari failed
  the initial Prompt primary-focus precondition before text injection. These
  jobs did not reach the later W3C input suite; unexecuted checks are not counted
  as either passing or executed failures. Safari 26.6.2's earlier original
  journey, including its two trusted clipboard gestures, did pass.
- **Three native framework targets:** Linux, macOS and Windows passed their
  first five scenarios, then failed the sixth clipboard scenario because the
  empty Prompt semantics node did not expose `SemanticsAction.paste`. The
  preceding CodeBlock copy succeeded. These framework tests inject Flutter
  input and synthetic constraints; they are not OS IME or physical-input proof.
- **Narrator capability:** compilation is now observed with exit 0 and a
  12,288-byte fixture, and UIA found the controls. The probe then failed on
  PowerShell 5.1's unsupported `[ushort]` type before the first Tab. The later
  `System.UInt16` correction still needs a new Windows execution.
- **Orca capability:** the native GTK fixture observed four machine layers,
  including synthesized PCM. Its application and human-review fields remain
  `not_accepted`; it did not accept the Flutter Catalog or a human task flow.

The [input contract](../../../.github/INPUT_ACCEPTANCE.md) now allows later
independent suites to run after an ordinary failure only when owned-process
cleanup is verified. Any suite failure still makes the invocation fail;
cleanup failure prevents continuation. This does not retry failed actions,
weaken assertions, or grant browser clipboard permissions. The changed runner
itself still needs execution at the next frozen source.

## Local candidate verification after 3614250

The following are local observations, pending final candidate attribution and
the corresponding runtime checks. The [final local-validation record](./2026-09-04-local-validation.json)
retains the exact results and runtime source hashes:

| Area | Latest confirmed local result | Remaining boundary |
| --- | --- | --- |
| Component library | **640/640 tests passed**, strict analysis clean; logs `/tmp/beautiful-candidate3-library-{tests,analysis}.log` | Does not replace Catalog, cloud, native performance or real AT execution. |
| Catalog | **59/59 tests passed**, strict analysis clean, including the final focus repair | Logs `/tmp/beautiful-candidate3-catalog-{tests,analysis}.log`; actual browser/native input still needs its cloud run. |
| Formatting | **141 files checked, zero changes** | Recorded in `/tmp/beautiful-candidate3-format.log`; formatting is not runtime evidence. |
| CI/input tooling | **43 Python cases: 41 passed, 2 real-Windows-only skips**; 4 Node checks passed; Dart HTTP protocol passed; 3 workflows passed actionlint; 11 Python files passed AST checks | `/tmp/beautiful-ci-current-validation.json` records the working-tree hashes. Native/browser/AT execution was not launched by those checks. |
| Lossless timeline transport | 7 focused tests and 3 real Dart finalizer tests passed; targeted analysis clean; independent review found no defect | No new native frame/RSS result exists for the compressed transport. |
| Assets and media | Current source asset audit reports no errors; media audit passed; icon checks cover 47 hashes, 40 PNGs, an ICO and two manifests | Final publication/artifact correspondence remains tied to the candidate checks. |
| Web release and local preview | Release build exited **0 in 37.4 seconds**; source and built-bundle asset/media audits passed. The local preview on port 8096 served `index.html`, `main.dart.js` and `flutter_bootstrap.js` byte-identical to the new build | This establishes the recorded build/HTTP preview correspondence, not a new GUI visual inspection or browser-input pass. |
| Publication dry-run | Dirty-tree precheck exited **65**; the subsequent clean `87299572` check exited **0 with zero warnings** | Both outcomes are preserved. No package publication is claimed. |

The CI tooling manifest's documentation hashes precede this readiness/README
update. Its validation applies to the recorded scripts and workflows; it does
not claim that these later Markdown edits were present during those checks.

Search virtualization and measurement invalidation, Records row/header reuse,
and the Prompt editor's shared tap-region group have their recorded behavioral
and visual evidence. Subsequent P1 long-content fixes and the input focus/paste
repairs are included in `87299572`; the older `3614250` captures do not measure
them, while the current checkpoint records the later observations. Tool output retention keeps the first-open layout cost and its
memory tradeoff explicit instead of deleting content from the workload.

The new timeline transport compresses the complete returned JSON only after
the sampling window, trailing timing flush and raw frame/RSS evidence assembly.
The driver validates lengths, SHA-256 and event count, restores ordinary
`.timeline.json`, and preserves independent evidence before failing on a bad
payload. The [read-only replay record](./performance/2026-09-04-timeline-transport-roundtrip.json)
restores all 15 existing driver files byte for byte: 481,371 retained events,
85,225,947 bytes of compact JSON and 5,030,142 bytes of transport envelopes.
This proves serialization fidelity and size reduction, not reduced native RSS,
absence of leaks, or recovery of VM events already evicted from a ring buffer.

## Visual, localization and temporal evidence added since the older readiness

| Evidence | Accepted scope | Limits retained |
| --- | --- | --- |
| [P1/P2 complementary review](./2026-09-03-p1-p2-complementary-review.md) | 13 modules × 6 complementary profiles; **78 individually inspected images**, plus targeted bidi/temporal regressions | Not the full Cartesian product of every dimension/state. Arabic/CJK rendering uses explicitly pinned review fonts, not proof of automatic native fallback. |
| [P3 review](./2026-09-03-p3-visual-localization-temporal-review.md) | **1,008 declared cases** across seven modules; **127 individually inspected PNGs**, including focus/held-pointer/disclosure states | Full within its declared finite fixture matrix; not universal platform, OS input, AT or performance acceptance. |
| [Search addendum](./2026-09-04-search-visual-regression-addendum.md) | Six fresh PNGs byte-identical to accepted images; 43/43 behavioral tests in its recorded run | The visual fixture has a localized nonempty query and two title-only results. Long lazy-list behavior is established separately by tests. |
| [Records addendum](./2026-09-04-records-cache-visual-addendum.md) | Three selected cases, seven byte-identical PNGs; focused cache and existing behavioral checks | Not a fresh full 1,008-case run or reinspection of all 127 images. |
| [Prompt addendum](./2026-09-04-prompt-focus-visual-addendum.md) | Three selected cases, seven byte-identical PNGs after the shared tap-group fix | Focus/held-pointer pictures exercise Send; model-menu/Escape behavior has separate regression evidence. |
| [P1/P2 performance-fix visual addendum](./2026-09-04-performance-visual-regression-addendum.md) | All **78/78** complementary-fixture PNGs remain byte-identical after the latest performance fixes | Carries forward the recorded visual observations by byte identity; no new GUI inspection, full Cartesian matrix or native-performance pass is claimed. |

Byte-identical addenda carry forward the original visual observations; they do
not claim newly viewed images. The [older 49-image review](./2026-09-03-accessibility-visual-review.md)
and [targeted Safari Flowchart review](./2026-09-03-safari-flowchart-theme-reduced.md)
remain dated, bounded evidence. The latter is a three-capture visual regression,
not the complete Safari input or screen-reader matrix.

## Earlier native performance at 3614250: complete captures, failed budgets

The [3614250 baseline](./performance/2026-09-04-3614250-native-baseline.md) and
[machine-readable data](./performance/2026-09-04-3614250-native-baseline.json)
preserve the two complete, independently recomputed captures:

| Capture | Workloads | Frames / RSS samples | Observed engineering-budget result |
| --- | ---: | ---: | --- |
| `20260903T231449Z-p1p2` | 8/8 | 5,125 / 504 | 3 pass, **5 fail**: Code, Tool Chips, Chat, Filter Table and Task Rows |
| `20260903T231943Z-p3` | 7/7 | 4,547 / 560 | 1 pass, **6 fail**; Sidebar alone passed |
| `20260903T233401Z-p3-isolated` | 0 | 0 / 0 | Failed preparation because the Mac was locked; **no isolated comparison was executed** |

The complete captures have one warmup and three measured rounds per workload,
driver/script exit 0, and assessor exit 1. All four 302-file source manifests
match `3614250` and digest
`9a42d11bfc2cc808a4b85143963757d362c578afbd7e5b7836d7637c42281945`.
Their observed sampling environment stayed at 1728 × 1080 dp, DPR 2, 120 Hz,
resumed lifecycle, with both platform and framework semantics enabled.

The [fixed engineering defaults](./performance/engineering_acceptance.md)
**exist and are being applied**. They remain explicitly unapproved as product
budgets, and no thresholds were relaxed. The P1/P2 failures include build peaks
of 28.981 ms in Code, 77.294 ms in Tool Chips and 38.296 ms in Filter Table;
later measured whole-process RSS peaks exceed 512 MiB. P3 showed broadly
higher build/raster durations. Short concurrent read-only parsing was recorded,
but no cause was established. Those valid failures are not discarded.

Thirteen VM timelines demonstrate bounded suffix retention; Chat and Selection
have no evident capacity loss with boundary caveats. The independent engine
FrameTiming arrays remain complete and determine the budgets. Whole-process
RSS includes fixtures, the engine and retained traces; component allocation,
leaks and repeated-run stability remain unassessed.

The locked attempt expired at the unchanged 120-second preparation deadline,
with driver/script exit 1 and no measurement. It does not prove the cause of the
earlier P3 slowdown. The desktop later became available and the separate
`87299572` captures above completed. Lock/sleep settings were not changed and
no simulated activity was used to bypass the lock.

## Physical devices, assistive technology and distribution

The [device/AT acceptance package](../device-acceptance/README.md) provides
repeatable preparation, actual-device journey and manual recording entry points.
The September 3 local inventory found no eligible Android/iOS physical device;
that dated observation is not a fresh inventory or a simulator substitute.
The [VoiceOver capability attempt](./2026-09-03-local-at-capability.md) could start
VoiceOver but could not observe its output reliably, so it accepted no spoken
task flow. Native AX/UIA/AT-SPI trees, synthetic composition, Unicode WebDriver
insertion and native GTK fixture speech do not complete actual OS IME, physical
input or Flutter screen-reader acceptance.

The [Linux Catalog/Orca pilot](../../../.github/REAL_AT_CATALOG_PILOT.md) is an
additional scoped workflow, not a result merely because its code or workflow
exists. Actual Catalog tasks, utterance/audio association and human review must
be recorded independently. The [real AT contract](../../../.github/REAL_AT_ACCEPTANCE.md)
keeps those layers separate.

Font/icon/media provenance, the inherited Geist assets, complete notices and
the isolated hosted-consumer checks retain their [license](./2026-09-03-license-audit.md)
and [publication-surface](./2026-09-03-hosted-consumer.md) evidence. There is no
new requirement to acquire Inter or JetBrains Mono. A historical hosted
consumer pass is not an actual publication or automatic validation of every
later source/artifact. Real file selection, microphone/dictation, external
sources and backend behavior keep their explicit host-integration boundaries;
default Catalog samples do not accept those capabilities.

## Remaining sign-off work

- Resolve and verify the remaining Edge startup boundary before accepting its
  unexecuted shared journey. Android/iOS complete journeys and all four W3C
  suites now have actual results at `f5484b9f`. Full Linux reader tasks still
  need the verified SDK corrections and remaining task observation described
  above; actual OS IME remains a separate open boundary.
- Complete the requested same-source P3 comparison with video playback paused,
  investigate remaining frame-budget failures, and keep both prior observations.
  Product budget approval, repeatability and other-device measurements remain
  separate from the engineering defaults used here. A [read-only trace diagnosis](./performance/2026-09-04-p3-trace-diagnosis.md)
  identifies expensive phases but does not provide sufficient attribution for
  an additional product patch.
- Complete actual physical-device, OS IME, direct keyboard/clipboard and full
  screen-reader task-flow review for the advertised platforms and applicable
  host integrations. Narrator needs a host with an available audio endpoint;
  a capability probe or prepared script is insufficient.
- Reconcile future runtime changes with the bounded visual/localization,
  performance, asset, notice and publication evidence. The latest readonly focus bridge and Catalog content scope have corresponding
  new local regressions; their new real-platform observations must remain explicit.

The [support matrix](../support_matrix.md) and [parity manifest](../parity_manifest.yaml)
therefore retain six `Partial` platforms and 27 `in_progress` entries. No later
cloud success, new native budget pass, package publication or complete release
acceptance is inferred from local implementation work.
