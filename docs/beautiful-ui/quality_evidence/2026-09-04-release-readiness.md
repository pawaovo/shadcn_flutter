# Release readiness — 2026-09-04

Date: 2026-09-04 (Asia/Shanghai). Toolchain: Flutter 3.47.0 / Dart 3.13.0.
Status: **not ready for stable-release sign-off**. The complete original
Android P1/P2/P3 journey now **passes at `f149ec29`**, with three actual LatinIME
candidate commits, all original actions/assertions, a successful full response
and verified stage/final cleanup. The actual driver finishes in **79.353 seconds**.
This is a separate source-bound execution of the same Android entry configured
in main. The most recent whole-main run remains the historical `75594991`
**11/12** result; its old Android failure is preserved, and no new 12/12 main run
is claimed. All its other main jobs, including iOS and the complete Edge
journey, passed. The separate input/AT checkpoint remains the
completed `5edbcab7` **4/9**, with four complete W3C suites and three native
framework input jobs passing, while retaining four framework composition
failures and the hosted Narrator limitation. It was not rerun at `75594991`.
Linux's original three
Catalog/Orca machine tasks now pass **3/3** at `79fbcdd1` with the explicitly
rebuilt SDK and patched native bridge. After desktop interaction became
available, a new complete native capture at `5edbcab7` passes **15/15 unchanged
engineering budgets and 120/120 gates**, with the new durable checkpoint success
path verified. Chinese OS IME pre-edit and full device/AT acceptance remain open. The older
locked `abd6293b` attempt remains a failed preparation with no measurements.

All 20 Gallery components and seven foundation/building-block items have
implementations. **All 27 registry entries remain `in_progress`; all six Flutter
platforms remain `Partial`.** This document adds current evidence without
changing those decisions or rewriting earlier records.

## Source and evidence boundaries

| Source snapshot | Evidence and meaning |
| --- | --- |
| Current Android `f149ec298a701d806661ab8ed4eb6085a037b70f` | Complete original P1/P2/P3 journey **passes**, three fixed native candidate commits and original actions pass, full response succeeds, and every helper/final cleanup is verified. The configured main and diagnostic Android entrypoints match; this does not rewrite the prior main run. |
| Most recent whole main `7559499112dcc5c5d9b0370ba1d6b0eb34743f45` | Main CI **11/12**; library 658, Catalog 147 and core 571 tests pass. Android's actual candidate commit and original Chat Send pass, then the complete response fails the P3 `/rest` command assertion. All other main jobs pass. Input/AT was not rerun. |
| Android observation `864ac59b523c278ef7ca99d7aad7d0c13015f377` | Native Chat commit/Send pass; slash Enter passes; actual Prompt composition changes to `[21,28]` during its original Send operation, with no host receipt. The complete original response fails. No P3 native candidate tree was inspected. |
| Runtime/performance `5edbcab7edc5c058cf9354c6109df917846fb4e8` | Main CI **11/12**, input/AT **4/9**; original Edge journey passes with explicit once-only executable preread; iOS passes; Android's composing-protected Send fails. All 15 native performance workloads and 120 original budget gates pass, with source/checkpoint integrity verified. Production runtime inputs are unchanged through `f149ec29`. |
| Historical `c2bde85dd5da7c33b0f7881234ae312f3be1826c` | The [September 3 CI record](./2026-09-03-final-ci-33748054504.json) preserves run `33748054504`, attempt 1, with 12/12 jobs passing. Its iOS driver, hosted consumer, build, visual and profile observations remain historical evidence for that source. They do not accept a later candidate. |
| Prior `36142500c9ad91dc307b6c8005e78add357f080b` | The earlier completed cloud checkpoint summarized below has main CI 10/12 and input/AT 1/9. Two complete native captures at this SHA have engineering-budget failures. Those results remain unchanged. |
| Earlier runtime `8729957220c011329022bafc7a0f7402434ce15e` | Main CI **12/12**, input/AT **4/9**, and clean publication dry-run **exit 0 / zero warnings**. The native P1/P2 budget is **8/8 pass**; P3 has **1 pass / 6 fail**. See its recorded runtime checkpoint below. |
| Local changes after `3614250`, now committed in `87299572` | P1 performance repairs, input/CI repairs and lossless timeline transport have completed local verification: 640 library tests, 59 Catalog tests, strict analysis and 141-file formatting. The exact committed source, clean dry-run and subsequent cloud/native observations are recorded in the current checkpoint. They do not accept future changes automatically. |

The [September 3 readiness document](./2026-09-03-release-readiness.md) and
`toolchain.json` retain their dated historical scope. This record is the current
entry point; an older heading containing “final” does not override a later
recorded failure.

## Completed original Android journey at f149ec29

[The actual Android evidence](../../../.github/evidence/android-candidate-f149ec29.md)
binds successful run `33869603924`, attempt 1, to exact source
`f149ec298a701d806661ab8ed4eb6085a037b70f`. The complete original integration
response succeeds with no failure details, and the driver reports
`all_tests_passed=true`. This includes the rest of P3 after Prompt Send.

| Fixed stage | Actual native commit and original result |
|---|---|
| Chat | One `inventory` candidate touch clears composition without changing `Check cone inventory`; the original Send creates its one host message and clears the editor, followed by the original Stop/Suppliers checks |
| Command | One `rest` candidate touch preserves `/rest`, clears composition and exposes one enabled restock option; the original Enter produces `/restock ` with caret 9 |
| Prompt Send | One `restock` candidate touch preserves the full original request and clears composition; the original Send reports the exact request with one file and the precise model, then clears the editor |

Catalog remains the same PID **2392** and process start identity throughout.
The three independently owned helper PIDs **2330, 2511 and 2570** each perform
one native DOWN/UP with no cancellation or repeat. Their nonces, tickets,
native results, original action ledger and cleanup all verify. Driver and
supervisor error/cleanup arrays are empty; all **232** runner-manifest files
match their recorded hashes and source inputs match before/after.

The [entrypoint/source comparison](../../../.github/evidence/android-entrypoint-equivalence-f149ec29.json)
verifies the same emulator action, settings and native build/runner commands in
main and the diagnostic, normalizing only their exact-source variable names.
Public/core/Catalog runtime, assets, manifests/lockfile and platform runners
remain unchanged from `5edbcab7`. This closes the original Android journey gap
for the verified fixture and source; it is not physical-device or human Chinese
IME acceptance and is not a new execution of the whole main workflow.

The failed [9e14317c wire run](../../../.github/evidence/android-candidate-9e14317c.md)
is retained with zero native touches. Its minimal flat-field repair has an
actual production-Dart-to-Python HTTP red/green regression covering preparation,
inspection, click and finish. The VM/native endpoints in that local regression
are explicitly fixtures. The current successful Android run supplies the real
native evidence, in addition to 50 Flutter, 35 stage-driver, 19 host and three
cross-language wire checks.

## Earlier completed main checkpoint at 75594991

[The exact-source main CI record](../../../.github/evidence/75594991-ci.md)
preserves run `33863483982`, attempt 1, with **11 successful jobs and one Android
failure**. Library **658/658**, Catalog **147/147**, core **571/571**, strict
analysis and all 170 checked Dart sources pass. The actual iOS driver exits 0
after **42.662 seconds**; its original discovery history and cleanup details are
preserved rather than reduced to a build-only success.

[The Android record](../../../.github/evidence/android-candidate-75594991.md)
contains the full failed integration response and the successful native Chat
portion. Actual candidate inspection and one DOWN/UP retain the full draft,
clear composition, preserve focus and enable Send. The original single Send
creates its expected host message, and the corrected final observer records
the normal Send-to-Stop transition without an observation error. Both driver
and supervisor cleanup succeed. P3 then fails at its original slash-command
expectation; no retry, alternate text or composition clear is used.

The earlier diagnostic records preserve the separate
[helper compiler failure](../../../.github/evidence/android-candidate-920f1dd8.md),
[HTTP body-framing failure](../../../.github/evidence/android-candidate-2e83a2e3.md),
[cross-zone observer failure](../../../.github/evidence/android-candidate-080697f2.md)
and [successful candidate/Send with a post-Send observer failure](../../../.github/evidence/android-candidate-5a90dff9.md).
The last of those did not receive the final integration response; the current
`75594991` run did receive it, with the concrete P3 assertion failure.

An empty source diff verifies unchanged public library/core runtime, Catalog
production Dart and assets, package manifests/lockfile and generated platform
runners between `5edbcab7` and `75594991`. The earlier release artifacts and
native performance capture retain that runtime boundary. The new workflow and
integration fixtures are separately bound to their own tested source.

The [later passive Android observation at 864ac59b](../../../.github/evidence/android-candidate-864ac59b.md)
records the unchanged original P3 actions without additional input or frames.
Slash Enter sees empty composition, primary focus and one enabled restock
option; the actual key event produces `/restock `. A native composing update
arrives afterward. For Prompt Send, the initial full text and empty composition
change to composing `[21,28]` during the original Send operation. The final
state retains text and focus, with Send disabled and no host receipt. Controller
and focus identities are stable, both observers report zero errors, and the
complete original response fails. No exact P3 pointer-down timestamp was
captured, and this run does not retrospectively identify the earlier slash
failure's cause. The next fixed-stage native fixture retains all original
words/actions and requires actual candidate evidence at each declared edit.

## Earlier completed runtime checkpoint at 5edbcab7

[The exact-source CI record](../../../.github/evidence/5edbcab7-ci.md) preserves
the new main **11/12** and input/AT **4/9** results, both original attempt 1.
Library **658/658**, Catalog **110/110** and core **571/571** tests pass, as do
strict analysis, all platform builds, publication dry-run with zero warnings
and the isolated hosted-consumer check. No package was published.

The original full Edge journey now passes on actual Edge/driver **151.0.4129.101**.
Its explicit once-only 398,196,048-byte executable read takes **13.285643 seconds**;
the actual process identity and post-run hash match. The input job uses Edge
**152.0.4191.53** and independently verifies its preparation and cleanup, while
retaining its composing-assertion failure and complete W3C pass. The browser
flags, page-load deadline and journey assertions remain unchanged. This is a
verified prepared-run result, with old cold failures retained; it does not prove
a universal startup repair or a failure rate.

iOS completes its actual driver in **32.738 seconds**, with successful discovery,
EOF, cleanup, final drain and application termination. Android again records
`[-1,-1]` before Send and `[11,20]` by pointer down, so its original host message
assertion fails. The component's composition protection is preserved.

[The new complete native performance capture](./performance/2026-09-04-5edbcab7-all-performance.md)
passes **15/15 original engineering budgets and 120/120 gates** with **10,311
frames and 1,020 RSS samples**. Every scenario records a stable visible native
environment. Its 310 captured input files match before, after and at archival;
16 durable checkpoints and all 17 timeline-stop acknowledgements are verified.
The final checkpoint, integration response and independent raw response data
agree. The earlier locked preparation is preserved and no longer blocks this
successful path. Product-approved budgets and other-platform/human acceptance
remain separate from this single macOS engineering capture.

[Local delivery artifacts](./2026-09-04-5edbcab7-local-artifacts.md) include a
checked **21.2 MB macOS ZIP** for Intel and Apple Silicon, with 333 file/symlink
entries verified, and the source-equivalent local Web preview. The new release
app opens and switches Theme from system to light in a scoped native smoke
test. The Linux three-task reader evidence ZIP remains available separately.

The [exportable input-method handoff](./2026-09-04-5edbcab7-ime-handoff.md)
provides a verified JSON download button at `http://127.0.0.1:63120/`.
The [user's subsequent Chinese-input record](./2026-09-04-user-chinese-submit.md)
contains 54 events, trusted `你` insertion in both controls and one actual Prompt
submission followed by draft clearing. Its state identities and exact download
filename match the live in-app browser page. No composition lifecycle is present;
candidate/pre-edit protection remains distinct from this accepted committed-text
path. The earlier 26-event ordinary `n` record is preserved.

## Completed Linux runtime repair and earlier source-153 validation

The complete public library passes **658/658 tests** after
[Thinking's named focus-owner repair](./2026-09-04-thinking-focus-owner.md).
The [original three-task Linux run](../diagnostics/linux-sdk-runtime-build/evidence/catalog-79fbcdd1-orca.md)
finishes naturally in **112.819 seconds**, exit 0, with no inspector tracing or
debugger. Theme, Thinking collapse/restore and Search query/selection/commit pass
every original native-state, reader-handler, exact-utterance, PCM and quiet-window
condition. All five reader checkpoints pass; source, bundle and runtime binding
remain unchanged and process cleanup is verified.

This result uses two source-level native repairs: the pinned Flutter GTK
name/expanded-state patch, and the independently built same-process geometry
repair in AT-SPI 2.52. Actual process mappings verify the generated engine, the
canonical bridge and all **26 dependencies**. The bridge's real GTK fixtures pass
**155 checks**, including direct/recursive coordinates, remote IPC and invalid or
destroyed parents. The old original 0/3 and diagnostic 1/3 runs are retained.
The result is scoped to this Linux debug runtime; ordinary stock SDK/release,
all-component and human review acceptance remain separate.

[The completed source-153 CI record](./2026-09-04-153412b3-ci.md) is main
**10/12**, input/AT **4/9**. The raw PTY repair passes the original Linux
capability fixture in actual CI. The iOS driver now passes in **70.256 seconds**,
with actual VM discovery, stdout EOF, process-group cleanup, final drain and
application termination verified. The kernel-only absent-group path preserves
present/unknown-group inspection, the original one-second `ps` limit,
15-second query limit and 120-second discovery deadline. The earlier
`abd6293b` failed discovery remains a failure in its original record.

[Android's exact delayed-composition replay](./2026-09-04-android-chat-composition-race.md)
confirms that a composing update arriving during target reveal correctly disables
the later Send tap. All **5 diagnostic tests** pass, including the successful
non-composing control, but the original cloud journey is still failed. The
[single matched Edge pair](../diagnostics/edge-startup/2026-09-04-153412b3-pair.md)
preserves baseline failure and preread success on Edge 152 with different
hosted runners/regions. Main CI used Edge 151; the pair's version match does not
extend to that main job. The explicit CI preread has 11 passing checks and valid
workflow syntax; its new actual source-5ed result is recorded above. The old
source-153 failure remains unaccepted.

The native profile recovery changes pass **68 headless checks**. Their first
[actual VM connection at abd6293b](./performance/2026-09-04-abd6293b-native-preparation.md)
correctly saves a failed response and exits 1 after the original preparation
deadline while the Mac is locked. No Start action, checkpoint or measured
workload occurs. That attempt did not validate a successful checkpoint path;
the new source-5ed capture above completes it with an actual stable visible
window.

[Narrator's 30 guard checks](../../../.github/evidence/narrator-b179fbf2.md)
compile and pass on Windows PowerShell 5.1. The latest real probe finds an owned
native HWND exposed as a Pane, but no WindowPattern. It sends no minimization or
reader commands and retains the preparation failure. Its independent inventory
also finds zero render endpoints; speech is unaccepted. Actual fixture focus
remains mandatory before any reader input. Real OS IME pre-edit is also
unaccepted.

## Earlier completed checkpoint at f15f27eb

[The exact-source CI record](../../../.github/evidence/f15f27eb-ci.md) preserves
main run `33839986027` (**10/12**) and input/AT run `33839985973` (**3/9**), both
attempt 1. The actual iOS driver passes in **56.534 seconds**, all platform builds
and package validation pass, and all four trusted W3C suites pass. Android's new
Chat failure is separate from its earlier successful journey: the old text finder
also matches an unsent draft, so a new one-tap diagnostic records public host
messages/status, composing state, pointer phases and native insets without
clearing composition, retrying Send or weakening the original Stop assertion.

The component changes retain Diff totals during pagination and the Flowchart
scene during viewport transformations. Combined library tests pass **655/655**.
The [new native P3 record](./performance/2026-09-04-f15f27eb-display-awake.md)
contains **5,163 frames and 525 RSS samples**, with seven stable native
environment records and all original engineering gates passing. Its 305-file
source manifests match before and after. The interrupted preceding baseline and
all older budget failures remain preserved; the comparison does not isolate the
two optimizations from environment and display-awake differences. P1/P2 was not
rerun in this capture, and engineering defaults do not grant product sign-off.

The new Linux capability failure exposed a
[buffered Orca debug-file transport](./2026-09-04-orca-capability-log-transport.md).
The real Where Am I handler and generated text are present, but the expected new
utterance was not visible in the file within its deadline. A deterministic
unflushed-writer regression supports reusing the existing raw PTY transport; the
next actual run must verify capability, and this old failure stays unaccepted.

The [separate Narrator diagnostic at 70e3d149](../../../.github/evidence/narrator-70e3d149.md)
passes real Windows PowerShell/C# compilation and seven diagnostic regressions.
It confirms **zero render endpoints across all device states**, with all three
default roles returning `0x80070490`. It also records fixture focus leaving during
the reader command and a copied `Welcome to Narrator` heading. That is distinct
from a fixture utterance; neither reader task nor synthesized audio is accepted.
The [Edge preread experiment](../../../.github/evidence/edge-preread-16906e5e.md)
records its full setup cost and actual version/image drift and does not resolve
the original 300-second startup failure.

The [pinned GTK source patch](../diagnostics/linux-sdk-accessibility-patch/README.md)
has actual native source-unit red/green evidence (**2/10 to 10/10**). Its complete
isolated engine build and unchanged real Catalog/Orca tasks remain a separate
runtime verification; the unit link stubs never enter an application build.

## Earlier completed checkpoint at f5484b9f

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
The [September 4 discovery refresh](./2026-09-04-local-device-inventory.md)
successfully queries CoreDevice and finds zero known devices. No current ADB
query was possible through the probed shell/project/default SDK paths; this is
not a claim that Android hardware is absent. The earlier September 3 inventory
retains its own dated scope, and no simulator result replaces a physical smoke.
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

- Extend the actual Android English candidate evidence to Chinese OS IME
  pre-edit and cross-platform candidate/commit observation. Four-browser
  W3C input passes, but those Unicode key events are not an IME workflow. The
  retained synthetic composing checks still fail in web framework suites, and
  the stock Flutter control reproduces that channel limitation. The user's
  in-app browser trace now verifies committed Chinese insertion and submission;
  no active composition or input-method identity is recorded in that run.
- Complete actual physical-device, direct keyboard/clipboard and full reader
  task-flow review for advertised platforms and applicable host integrations.
  Linux's three original representative reader tasks are complete at `79fbcdd1`
  in the explicitly rebuilt SDK/AT-SPI debug runtime; stock SDK/release,
  all-component and human listening review remain separate. The Windows hosted
  runner has zero audio render endpoints and its owned Narrator window lacks
  the required WindowPattern, so no reader commands are accepted there.
- The complete 15-workload macOS engineering budget and durable checkpoint
  success path are now verified at `5edbcab7`. Product budget approval and
  representative other-platform/device evidence remain separate from this
  single native capture. Repeatability or leak claims are not inferred.

The current local Web preview and macOS release artifact retain unchanged
runtime inputs relative to the completed source-5ed verification. Visual,
localization, asset, notice and publication evidence keeps its recorded scope;
later runtime changes require a proportionate refresh. No stable package
publication occurred.

The [support matrix](../support_matrix.md) and [parity manifest](../parity_manifest.yaml)
therefore retain six `Partial` platforms and 27 `in_progress` entries. No later
cloud success, new native budget pass, package publication or complete release
acceptance is inferred from local implementation work.
