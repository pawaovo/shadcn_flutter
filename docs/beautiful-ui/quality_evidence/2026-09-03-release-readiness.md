# Stable-release engineering readiness

Date: 2026-09-03 (Asia/Shanghai)
Toolchain: Flutter `3.47.0`, Dart `3.13.0`
Status: substantial local engineering evidence accepted; remote refresh and
manual release gates remain open

All twenty Gallery components and seven foundation/building-block registry
items have implementations. **All 27 manifest entries remain `in_progress`.**
This record adds measured performance, visual review, native interaction, and
distribution evidence to the implementation milestone; it does not declare a
stable release or mark any platform `Verified`.

## Current verification

| Area | Accepted evidence for this engineering pass | Limit of the result |
|---|---|---|
| Library behavior and Semantics | 528 passed: 410 behavior, 106 Semantics, 12 goldens | Does not replace complete real screen-reader or physical-device workflows |
| Catalog | Latest full local suite passed 26 tests, including the seven startup regressions; recorded strict analyzers passed | Third CI remains 19 historically; the enlarged suite has not yet been remotely verified |
| Golden baselines | macOS checks passed; eight accepted Linux candidates passed strict comparison in run `33741053163` | Future visual/source changes still require proportionate verification |
| Supplemental visual review | 49 images covering all 20 components individually reviewed | Two specific static profiles; the complete localization/state/motion matrix remains open |
| Dependency fonts/icons | 43 source files and all 37 runtime declarations checked; full notices verified | Applies to the pinned inventory and inspected artifacts |
| Other media | 266 transitive flag images and five original Web images verified in release artifacts | Original platform icons and media retain their separate source/hash inventory |
| Generated licenses | Workspace and independent hosted-consumer probes verified all 13 complete required labels; portable BAI notice delivery passed | BAI is still an unpublished publication-surface copy; dependency scope and artifact boundaries remain explicit |
| Release builds and assets | Ordinary macOS, Web JavaScript, and Web Wasm builds and their strict asset/notice audits passed | New or independently generated artifacts require proportionate revalidation |
| Native macOS interaction | Complete shared Catalog journey passed; native AX comparison succeeded without a Web-only compile flag | AX inspection is not a completed VoiceOver user workflow |
| P3 native profile workloads | Historical baseline `20260903T080855Z` completed seven of seven scenarios, driver, and teardown | Final-source resampling after the palette/muted-ticker fixes is pending; product budgets remain open |
| Latest portable-source builds | Wasm/macOS releases and the second run's platform builds passed | Actual iOS simulator journey remains unexecuted in the second run |
| Expanded CI | Run `33742943774` completed with 11 successful jobs, one Apple failure and no skips; quality and publish/hosted-consumer checks passed | App and Catalog test ran; driver VM discovery failed, and teardown reported an active SemanticsHandle |

The earlier fully successful implementation CI was
[run `33726848975`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33726848975)
on `74178098705aa83b5452857aece6a3b10bb3ce4f`, with all ten jobs passing.
It predates this engineering pass. The expanded twelve-job run
[`33736546039`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33736546039)
on `19c80c17e5346f7415b52af9583ba6770cfbee50` now provides the partial
results described below. The second expanded run
[`33741053163`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33741053163)
on `896bcfe8fd6419382f21ba6a311d37f5f017d875` completed with 11 successful
jobs and one Apple launcher-test failure. The third expanded run
[`33742943774`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33742943774)
on `57efe1a3f9bb72c1a7b8668dec127ad261eaedda` again has 11 successful jobs
and one Apple failure, with different evidence described below. No full-green
expanded run is claimed.

## Visual and interaction corrections

The [49-image review](./2026-09-03-accessibility-visual-review.md) covers compact
light at 200% text in RTL/high contrast and expanded dark in high contrast,
with documented motion inputs. Shared action controls now choose foregrounds
that contrast with their actual filled background. Accepted selections gain a
distinct fill and thicker border, making feedback, filters, metrics, and other
selected controls visible as well as semantic.

The final normal-palette review also corrected text that remained too faint:
`inkSubtle`, used by placeholders and metadata, changes to `#66696f` in light
mode and `#9c9fa5` in dark mode. The tested normal text combinations now meet
4.5:1. Light `accentInk` changes to `#0067cb`; its contrast on `accentTint`
rises from 4.294:1 to 4.925:1. The graphic accent color is unchanged. Four
palette regression cases cover these text combinations.

A final reduced-motion regression was found in the real expanded Flowchart:
an ancestor `TickerMode(false)` froze action background tweens during a
dark-to-light theme change while the text updated, leaving an unreadable
button. Shared actions now read `TickerMode.valuesOf(context).enabled` and
use zero animation duration when it is false. Three paint regressions passed
after reproducing the fault, including a 1,200dp canvas case. Graph data and
the existing no-inertia behavior retain their contracts.

Approval's selected and submitted check marks now use native path drawing,
avoiding unavailable glyphs in the fixed fonts. Sidebar's compact closed
trigger grows with text instead of overflowing a fixed height. Fine-tune
numeric adjustment and Insight point inspection expose actual slider flags,
values, enabled state, and increase/decrease actions for native accessibility
bridges.

The Catalog's `ENABLE_WEB_SEMANTICS` handling is now restricted to
`kIsWeb && flag`. Normal macOS runs use the native platform's semantics
lifecycle. A no-flag A/B inspection verified native AX behavior, and the
ordinary macOS shared journey completed. These results preserve the
distinction between an available native accessibility tree and a complete
real screen-reader task flow. The [native semantics record](./2026-09-03-native-semantics.md)
preserves the A/B observations and raw evidence without claiming that the
framework's internal notification timing was instrumented.

The static review closes the specific clipping, missing-mark, and invisible
selection findings shown in its fixtures. Compact dark, expanded light,
medium constraints, real Arabic/Hebrew translations, full state combinations,
and transitions over time are still separate review dimensions. The final
49-image renderer manifest SHA256 is
`c0f46b73679b5ee81b2e920371f6310a6acd37ffd3a9a2916262221b7cdd91c6`;
the 249-entry source inventory fingerprint is
`27790be59b89b36743994b9cc141e7fd3ca922c9bd2c4218543b6151b1e14131`.
The final ten macOS image hashes, including the eight changed component
images, are recorded in `toolchain.json`. The private hosted-adapter correction
changed no pixels in any of the 49 review images or golden images. Linux's
eight changed component candidates from run `33736546039` have now been
[explicitly reviewed and accepted](./2026-09-03-linux-golden-acceptance-33736546039.json).
The accepted files preserve the reviewed CI bytes, and their strict Ubuntu
comparison passed in the second run `33741053163`.

## Measured P3 workload evidence

The successful **historical native profile baseline** is
[`performance/2026-09-03-macos-profile/summary.json`](./performance/2026-09-03-macos-profile/summary.json),
run ID `20260903T080855Z`. It captured **4,524 independent `FrameTiming`
samples and 480 process RSS samples** across all seven scenarios. Both the
integration driver and finalized script exited 0 after teardown.
Its recorded source fingerprint predates the final normal-text palette,
muted-ticker, and hosted-adapter corrections. Final profile run 4 has not
started: the local Mac session is locked, and Computer Use requires the user
to unlock it manually. The statistics below remain historical measurements,
not final-source results.

The machine was an Apple M1 Pro MacBook Pro with 32 GiB memory and macOS
15.7.9. Flutter 3.47.0 ran in profile mode with an Impeller/Metal surface,
verified by native timeline events. The measured native viewport stayed
**1,728 × 963 logical pixels, DPR 2, 120 Hz**; this is the sampled window,
not merely an intended fixture dimension.

The workloads exercise 1,000 Prompt suggestions and a 10,000-character draft;
a 500 × 3 Diff dataset with 20-row pages; 1,000 × 20 Records cells; 1,000
Sidebar recents; a 24-node/48-edge Flowchart; four 512-point Insight series;
and a 20,000-character selected-text document. Dataset details, independent
frame arrays, process samples, source hashes, and artifact hashes are preserved
with the profile record.

Successful workload completion is not a performance-budget pass. Peak UI
build frames reached **43.082ms for Prompt, 22.708ms for Records, and 37.153ms
for Insights**. Product frame/memory budgets remain to be set and evaluated,
and other platforms and representative physical devices remain unmeasured.
The inputs are programmatic Flutter actions and injected pointer gestures,
not OS IME, physical keyboard/touch, or assistive-technology acceptance.

RSS covers the instrumented process, including fixtures, engine caches and
accumulated trace data; it is not isolated component allocation or proof of a
leak. Six of seven raw VM timeline windows were limited by the ring buffer.
The independently collected frame arrays remain complete for the reported
percentiles, so the timeline limit is retained without discarding that frame
evidence.

## Distribution and typography

The [license audit](./2026-09-03-license-audit.md) and its source/build JSON
records verify the exact inherited Geist, Bootstrap, Lucide/Feather and Radix
assets, complete package-root notices, and generated registry coverage. The
37 runtime font files consist of 34 Geist files and three icon fonts; six
additional source OTF files are tracked but not declared into the runtime.

The current typography choice is the verified **Geist Sans / Geist Mono
dependency assets**. No Inter or JetBrains Mono files are bundled, and there
is no outstanding requirement to acquire those fonts for the current
implementation. Adding a different font later requires a new asset record.
The exact inherited Radix font is pinned by source commit and hash; its
earlier SVG conversion is not falsely presented as reproduced.

The flag/media inventory verifies the published `country_flags 4.1.2`
acquisition boundary and its upstream flag-icons notice. Original project
launcher/Web artwork replaces the previous Flutter template branding, with
its own inventory and repeatable generator. Source hashes, licenses and
release-bundle correspondence are recorded in `legal/assets.yaml` and the
referenced inventories; those concrete resource tasks are no longer pending.

Fresh macOS, JavaScript, and Wasm release checks are captured in
[`native-release-assets.json`](./native-release-assets.json),
[`web-js-release-assets.json`](./web-js-release-assets.json), and
[`web-wasm-release-assets.json`](./web-wasm-release-assets.json).
They do not provide brand rights or certify every unrelated third-party
package or future artifact.

## Independent publication boundary

The [isolated hosted-consumer record](./2026-09-03-hosted-consumer.md) closes
both observed publication-path gaps. The private adapter now provides atomic
inherited themes with unmodified hosted `shadcn_flutter 0.0.54`, retaining
consumer state, Search draft/selection, and focus through 12 immediate/75ms/
175ms observations. BAI's own `NOTICES` delivers all 13 required complete
texts without relying on the fork's sibling notice file.

The consumer runs outside the repository with no workspace or dependency
overrides and a fresh package cache. All 209 installed hosted runtime/source
files match the public archive. Resolution, strict analysis, two integration/
theme tests, and the real production-registry probe all passed. The BAI input
is an isolated publication-surface copy; this is not a pub.dev publication or
proof of every later version allowed by its dependency range.

## Remote CI results observed for this pass

The twelve-job [workflow](../../../.github/workflows/beautiful_ai_ui.yml)
ran as [run `33736546039`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33736546039)
on `19c80c17e5346f7415b52af9583ba6770cfbee50`. Recorded successes include
Firefox, Edge, the Chrome/Linux shared journeys, Android, Windows native and
macOS native journeys, platform builds and Web asset/notice audits.

GitHub's final API result is `completed/failure`: **nine successful jobs, two
failed jobs, and one skipped job**. Quality failed only the eight changed
Linux component goldens; their actual CI candidates were subsequently
reviewed and accepted. The Apple job failed when the iOS simulator application
launch step timed out after about 20 minutes after Xcode compilation. Its
runner did not report widget-test start/results; actual execution is
unconfirmed in that capture. Its iOS no-codesign build, macOS build, and macOS
journey steps had already passed. Publish validation was skipped after its
quality dependency failed.

The second [run `33741053163`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33741053163)
on `896bcfe8fd6419382f21ba6a311d37f5f017d875` is also `completed/failure`,
with **11 successful jobs, one failed job and no skipped jobs**. Quality now
passes the strict Linux golden comparison. Publish validation passes both
the real hosted-consumer gate and a 3 MB dry-run with zero warnings.

Apple's iOS release build, macOS release build/journey, and simulator boot
passed. Its bounded-launcher self-test ran four cases; two failed with
`EPERM` during process-group cleanup. Actual simulator build/journey steps
were skipped after that self-test, so this run does not verify simulator
execution or resolve the earlier launch result. The cleanup portability fix
is now implemented: six local regression checks and actionlint passed.
Remote simulator execution remains pending.

The downloaded cloud hosted-consumer artifact `9887907974` was independently
checked: 209 public dependency files match, all 12 theme observations pass,
and all 13 complete notice/registry texts are present. Its result SHA256 is
`ff2e38c34a3eb304567c1e40ee0692bddc0f3d0a5d0fcc2191f524281b00ef40`;
compact cloud metadata is retained in `toolchain.json` alongside the local
before/after evidence.

The third [run `33742943774`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33742943774)
on `57efe1a3f9bb72c1a7b8668dec127ad261eaedda` completed with **11 successful
jobs, one Apple failure and no skips**. All six launcher self-tests passed;
the simulator build succeeded in about five minutes and installation took
about 22 seconds. The launcher console did not expose the VM announcement,
so URI discovery reported a 120-second timeout and the driver did not attach.

Downloaded unified logs nevertheless show the real VM announcement at
10:27:01 and Catalog test start at 10:27:02. About 46 seconds later,
`_endOfTestVerifications` reported an active `SemanticsHandle`; no other test
body assertion failure was recorded, and `failure.png` displayed “Test
finished”. Thus the app/test did run, while result attachment and teardown
failed. The earlier run's actual execution remains unconfirmed; this third-run
Semantics finding is not applied retrospectively to it.

The next fixes target PID/launch-time-scoped unified-log discovery and the
race between iOS's platform semantics handle from `viewDidAppear` and the
test's baseline. Leak checks remain strict, with no exemption. Apple artifact
`9889094131` and job `100608850829` identify this raw evidence.
The latest complete local Catalog rerun passed 26 tests, including all seven
new startup regressions (`/tmp/release-fourth-catalog-tests.log`, exit 0).
Formatting checked three touched files with no changes, and the diff check
passed. The third CI count below remains 19; remote verification of the
enlarged suite is still pending.

Third-run quality passed 410 behavior, 106 Semantics and 12 golden checks
(528 library total), plus 19 Catalog and 571 core tests. The downloaded hosted
artifact `9888622880` again verifies 209 unchanged dependency files, 12 theme
observations and all 13 required notice/registry texts. Its result SHA256 is
`96fc50d78e61c89136129333e7547eb57e6f7b6bd6f7600a2e7f1b1b63b4cb76`.
Compact metadata and the first two run records remain in `toolchain.json`.

## External execution condition

The current local Mac session is locked. Computer Use explicitly requires
manual user unlock before desktop interaction can resume. Final profile run
4 has not started, and Safari's visual recheck after the TickerMode repair has
not completed. These two tasks remain open because their desktop execution
condition is unavailable; no historical profile or earlier Safari observation
is substituted for the missing final-source evidence.

## Remaining stable-release gates

- Verify scoped VM discovery/driver attachment and a stable iOS semantics
  baseline, then complete strict teardown without a leak exemption. The third
  run already demonstrates real app/test execution; quality and hosted-consumer
  checks remain completed evidence.
- After manual unlock of the local Mac, start and finalize profile run 4
  against the final source and complete the post-TickerMode Safari visual
  recheck. Keep `20260903T080855Z` as historical evidence.
- Complete physical-device checks and actual TalkBack, VoiceOver, Narrator,
  and Orca workflows, including focus, selection, clipboard, IME, and core
  task completion. Native AX tree availability alone does not close this gate.
- Complete remaining browser and applicable native smoke coverage beyond the
  successful recorded Firefox/Edge journeys, including the outstanding Safari
  final visual check and compatibility matrix.
- Review remaining visual/localization combinations and temporal hover,
  focus, pressed, normal-motion, and reduced-motion behavior.
- Define product frame and memory budgets, assess measured peaks against
  them, and collect representative platform/device performance evidence.
  Outstanding P1/P2 long-content workloads also retain their own scope.
- Keep final publication metadata, source/asset pins, notice coverage, and
  artifact-specific checks consistent with the actual release candidate.

The support matrix therefore records all six advertised platforms as
`Partial`. The remaining gates describe real missing evidence; completed
font inventories, accepted static images, and the successful historical
macOS profile baseline are retained, while the final-source resample is
explicitly distinguished as unfinished.
