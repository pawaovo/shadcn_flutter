# Stable-release engineering readiness

Date: 2026-09-03 (Asia/Shanghai)
Toolchain: Flutter `3.47.0`, Dart `3.13.0`
Status: final CI, current-source macOS profile capture and targeted Safari
visual regression passed; remaining stable-release acceptance stays open

**Validated code: `c2bde85dd5da7c33b0f7881234ae312f3be1826c`.**
[Fifth CI `33748054504`, attempt 1](https://github.com/pawaovo/shadcn_flutter/actions/runs/33748054504)
completed successfully with **12 of 12 jobs passing**, including the actual
iOS native driver, all platform builds/journeys, quality, and publication
validation. The real iOS driver exited 0 and reported “All tests passed.”
The final macOS source-matched profile capture and independently reviewed
Safari Flowchart theme regression are also complete. This evidence may be
committed separately; the documentation commit does not replace the tested
code SHA above.

All twenty Gallery components and seven foundation/building-block items have
implementations. **All 27 entries remain `in_progress`, and all six platforms
remain `Partial`** because physical-device, full assistive-technology/visual
matrix and performance-budget acceptance are separate release gates.

## Current verification

| Area | Accepted evidence | Remaining boundary |
|---|---|---|
| CI and quality | 12/12 jobs; 528 library, 26 Catalog, 571 core tests; strict analysis and Linux goldens passed | Applies to the exact validated code/SDK |
| Native and browser journeys | Android, iOS simulator, macOS, Windows and Linux; Chrome, Edge and Firefox passed | Physical devices and complete real screen-reader flows remain separate |
| iOS native driver | Actual driver passed, exit 0, 50.234s; application terminated cleanly | One whole journey with suite setup/teardown, not three independent component tests |
| Visual review | 49 reviewed images; current macOS and accepted Linux baselines verified | Specific static profiles, not the complete localization/temporal matrix |
| Dependency assets and notices | 43 source/37 runtime font files, 266 flags, original artwork, 13 required complete notice labels | Pinned acquisition/artifact scope remains explicit |
| Independent publication surface | Cloud consumer matched 209 hosted files and passed 12 theme observations and all 13 notices | BAI is a tested publication-surface copy, not an actual pub.dev publication |
| Release builds | Six-platform builds, including Web JavaScript/Wasm, passed | Later source/dependency changes need proportionate validation |
| Final macOS profile | Run `20260903T114308Z`: 7/7 workloads, 4,495 frames, 478 RSS samples, teardown/driver/finalizer passed | One recorded platform/run; frame/memory budgets and repeatability remain unassessed |
| Targeted Safari regression | Three independently reviewed light/dark/light captures with reduced motion show correct Flowchart condition colors | Safari is Partial; complete browser/input/AT and temporal/performance matrices remain open |

The [compact final CI evidence](./2026-09-03-final-ci-33748054504.json) records
run/commit, native driver timings and artifact hashes, and the downloaded
hosted-consumer result without copying raw logs or service URLs.

## Verified iOS driver completion

Apple job `100625050615`, artifact `9890828917`, contains the actual
`ios-journey.json` with SHA256
`3f178a21ceb6f677f2679a2285cc5342d0fd3b1165590900fc4d4eed4a4d85bd`.
The bounded launch completed in 7.582s. VM discovery took 12.396s **including
launch**, validated PID 26615, and used one scoped history query. The original
native Flutter driver then ran for 50.234s, returned exit 0, and reported
success; termination also passed. The observed iOS semantics-baseline and
remaining driver-completion gates are closed for this recorded journey.

Cloud hosted artifact `9890573744` is `passed: true` at the same code SHA,
with 209 unchanged dependency files, 12 theme observations and all 13 required
complete notice/registry texts. Its result SHA256 is
`cfe7abbf71529b044e236fe93b53de05d36e0cfa9f82d3bd3cbd49ba4f28be45`.
Earlier attempts and the separate Edge retry are retained in history below
and in `toolchain.json`; they are not prerequisites for understanding the
current successful result.

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

## Final-source P3 workload capture

The [final macOS profile](./performance/2026-09-03-macos-profile-final/README.md),
run `20260903T114308Z`, completed **all seven workloads, strict teardown,
the integration driver and finalizer with exit 0**. It retained **4,495
independent FrameTiming samples and 478 process RSS samples**. All 50 runtime
and build-input files matched validated revision `c2bde85dd5da7c33b0f7881234ae312f3be1826c`
byte for byte. The source manifest digest is
`4c4cf5d6606596f8f7ce45f07d4e37a0309aad1d60f42ea7d50d0af850390dac`.
The working tree was documentation/evidence dirty, not clean; those changes
did not alter the measured runtime/build sources.

The observed machine was the M1 Pro MacBook Pro with 32 GiB memory and macOS
15.7.9, Flutter 3.47.0/Dart 3.13.0, using an Impeller/Metal surface. The actual
native viewport stayed **1,728×1,080 logical pixels, DPR 2, 120 Hz**. Its size
is an observation: no unrecorded zoom, restoration or external-adjustment
cause is inferred. The platform semantics flag was false, while the Flutter
test framework still requested semantics and retained its own handle; this
was not a semantics-free run.

The unchanged protocol exercises Prompt's 1,000 options/10,000-character
draft, Diff's 500×3 records and 20-row pages, Records' 1,000×20 grid,
1,000 Sidebar recents, a 24-node/48-edge Flowchart, four 512-point Insight
series, and a 20,000-character selected-text document. Individual UI-build
peaks remain visible: **45.962ms Prompt, 22.060ms Records, 45.395ms Insights**.
No product frame/memory threshold was invented to mark them acceptable.

RSS represents the instrumented whole process, including fixtures, engine,
caches and retained traces; it is not component-exclusive allocation or leak
evidence. Six raw VM timelines have ring-buffer-limited extents. Complete,
independently captured frame arrays supply the distributions. Programmatic
Flutter inputs do not replace OS IME, physical-input or screen-reader tests.

The [performance index](./performance/index.json) keeps three distinct roles:

| Record | Result and scope |
|---|---|
| Historical `20260903T080855Z` | Earlier-source success: 4,524 frames/480 RSS, 1,728×963dp and a different platform semantics flag. Retained unchanged; not a controlled regression comparison with the final capture. |
| Preparation attempt `20260903T113737Z` | Failed at 800×600dp after the 120s preparation deadline because the available zoom action was not completed in time. Zero workloads/frames/RSS samples. The finalizer correctly rejected this attempt despite driver exit 0. It does not prove the machine could not resize or was locked. |
| Final `20260903T114308Z` | Independent source-matched success at 1,728×1,080dp; seven workloads and strict finalization complete. |

## Targeted Safari visual regression

The [Safari review](./2026-09-03-safari-flowchart-theme-reduced.md) independently
checked exactly three real full-screen Safari 26.6.1 screenshots and paired
AX exports. The accepted captures show **light → dark → light**, with
**Motion: reduced** throughout and the same stock threshold. Canvas remains
visibly selected; condition buttons show readable dark text on a light
surface, then light text on a dark surface, then the correct light treatment
again. The stale dark-background mismatch is absent in this captured sequence.

The saved images are 1,229×768 pixels; that does not establish CSS viewport
size or DPR. The operator's intermediate `system (dark)` state is not part
of the three independently accepted captures. Runtime attribution and the
independently checked bootstrap hash are recorded in the review.

This closes the specific reduced-motion Flowchart color regression only.
Safari's overall status is **Partial**. Full component/input/AT coverage,
spoken screen-reader behavior, transition timing and performance remain open.
Earlier white frames and `noWindowsAvailable` ceased without application or
bootstrap changes; their cause remains unproven and is not attributed to the
library, renderer or capture tool. GUI testing is finished, and Safari was
restored to an ordinary window with light theme and reduced motion.

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

## Earlier CI history

| Run / code | Actual result | Evidence retained |
|---|---|---|
| [`33736546039`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33736546039) / `19c80c17…` | 9 success, 2 failure, 1 skipped | Eight then-unaccepted Linux goldens; iOS runner timed out without reporting test start/results. Actual app execution in that capture remains unconfirmed. |
| [`33741053163`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33741053163) / `896bcfe8…` | 11 success, 1 failure, 0 skipped | Strict goldens and publish/hosted checks passed. Two of four launcher self-tests failed on cleanup `EPERM`; simulator build/journey steps were skipped. |
| [`33742943774`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33742943774) / `57efe1a3…` | 11 success, 1 failure, 0 skipped | Unified logs confirmed actual VM/test execution, while driver discovery failed and strict teardown reported an active SemanticsHandle. No other body assertion failure was recorded; this is not inferred for the first run. |
| [`33745883748`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33745883748), attempt 1 / `26d908e0…` | 10 success, 2 failure, 0 skipped | Real whole iOS journey and strict teardown passed after platform semantics readiness, but delayed console PID output prevented the driver stage. Edge failed before tests at window positioning with a 300s renderer timeout. |

In the fourth iOS log, `+3: All tests passed!` counts suite setup, **one whole
journey**, and suite teardown; it does not mean three independent component
tests. Driver completion was still missing then and is established only by
the fifth run above.

The fourth run's same-SHA targeted Edge retry, attempt 2 / job
`100622856132`, passed with no Edge code/configuration change. The other jobs'
results were reused, not reexecuted. That retry did not prove the cause of the
original renderer timeout; the fifth full run now also passes Edge. The
relevant detailed metadata, earlier cloud artifact hashes, and exact prior
job counts remain in `toolchain.json`.

## Completed local follow-up and preserved history

The earlier locked session delayed local work, but a fresh check at 11:23 UTC
confirmed an unlocked Mac. The later preparation timeout is a separate
procedural failure, followed by the successful independent profile attempt.
Current-source profiling and the targeted Safari review are now complete;
no current locked/not-started/pending claim is retained for those checks.
The working tree remains documentation/evidence dirty for this evidence
commit, with runtime/build inputs verified against the CI code SHA.

## Remaining stable-release gates

- Complete physical-device checks and actual TalkBack, VoiceOver, Narrator,
  and Orca workflows, including focus, selection, clipboard, IME, and core
  task completion. Native AX tree availability alone does not close this gate.
- Complete remaining browser and applicable native smoke coverage beyond the
  successful recorded Firefox/Edge journeys and the targeted Safari visual
  regression, including the full Safari compatibility/input matrix.
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
macOS baseline, failed preparation attempt and final-source capture are
retained distinctly. Only the remaining manual, matrix and budget acceptance
is described as unfinished.
