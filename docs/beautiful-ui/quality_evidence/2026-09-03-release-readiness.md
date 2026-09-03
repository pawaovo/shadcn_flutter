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
| Library behavior and Semantics | 526 tests passed | Does not replace complete real screen-reader or physical-device workflows |
| Catalog | 19 tests passed; library and Catalog strict analyzers passed | Counts belong to this integrated pass; older P3 evidence retains its historical counts |
| macOS golden suite | 12 of 12 checks passed; ten current macOS image hashes recorded, including eight updated component images | Eight changed Linux component baselines await CI candidates and explicit review |
| Supplemental visual review | 49 images covering all 20 components individually reviewed | Two specific static profiles; the complete localization/state/motion matrix remains open |
| Dependency fonts/icons | 43 source files and all 37 runtime declarations checked; full notices verified | Applies to the pinned inventory and inspected artifacts |
| Other media | 266 transitive flag images and five original Web images verified in release artifacts | Original platform icons and media retain their separate source/hash inventory |
| Generated licenses | Real Flutter `LicenseRegistry` probe verified 13 complete labels | Does not assert an exhaustive legal guarantee for every dependency |
| Release builds and assets | Ordinary macOS, Web JavaScript, and Web Wasm builds and their strict asset/notice audits passed | New or independently generated artifacts require proportionate revalidation |
| Native macOS interaction | Complete shared Catalog journey passed; native AX comparison succeeded without a Web-only compile flag | AX inspection is not a completed VoiceOver user workflow |
| P3 native profile workloads | Historical baseline `20260903T080855Z` completed seven of seven scenarios, driver, and teardown | Final-source resampling after the palette/muted-ticker fixes is pending; product budgets remain open |
| Final frozen-source Web build | Latest Wasm release build passed after the final fixes | New remote twelve-job verification is pending |
| Expanded CI | Twelve jobs configured, including new native and browser journey coverage | The new remote workflow has not yet produced an accepted run for these changes |

The last completed implementation CI was
[run `33726848975`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33726848975)
on `74178098705aa83b5452857aece6a3b10bb3ce4f`, with all ten jobs passing.
It predates this engineering pass. Its success is retained as history and is
not substituted for the pending twelve-job verification of the current tree.

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
`31612099bcb0a461d0748007528bb71642221d2a11d57d1af70136bf6f04f686`;
the 249-entry source inventory fingerprint is
`936fc4800a23a18b044c0be7a3a5aa69fa16073e4bee3ef07e1e1a17ed65349c`.
The final ten macOS image hashes, including the eight changed component
images, are recorded in `toolchain.json`. Linux's eight changed component
baselines require CI candidates and explicit visual acceptance; they are not
updated automatically.

## Measured P3 workload evidence

The successful **historical native profile baseline** is
[`performance/2026-09-03-macos-profile/summary.json`](./performance/2026-09-03-macos-profile/summary.json),
run ID `20260903T080855Z`. It captured **4,524 independent `FrameTiming`
samples and 480 process RSS samples** across all seven scenarios. Both the
integration driver and finalized script exited 0 after teardown.
Its recorded source fingerprint predates the final normal-text palette and
muted-ticker fixes. A separate profile run of the final source is planned for
the next evidence commit. The statistics below describe the historical
baseline and are not presented as measurements of the final frozen source.

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

## Remote configuration awaiting execution

The [Beautiful AI UI workflow](../../../.github/workflows/beautiful_ai_ui.yml)
now has twelve jobs. Existing platform-build and Chrome/Linux/Android journey
coverage is extended with macOS, iOS simulator, and Windows native journeys
inside the corresponding native jobs. Firefox and Microsoft Edge each have
a dedicated browser journey job. Source and built-asset notice checks are
also wired into the appropriate quality/Web steps.

The new jobs and steps are **configured, pending remote execution**. No
Firefox, Edge, iOS simulator, Windows native journey, or refreshed Linux
golden result is claimed for this pass until its actual run is recorded.
The successful local macOS journey remains separate from its new CI step.

## Remaining stable-release gates

- Verify a consumer outside this workspace against the hosted dependency.
  Published `shadcn_flutter 0.0.54` exports the required APIs, but still
  ignores `enableThemeAnimation: false` and lacks the fork's package-root
  font/icon `NOTICES`. A sibling package's notices are not included when
  publishing `beautiful_ai_ui` alone. Independent consumption therefore
  still needs an internal compatibility/notice-delivery solution and an
  isolated test; workspace builds and publish dry-run do not establish it.
- Accept the current twelve-job remote run and resolve/review refreshed
  Ubuntu golden evidence, retaining the explicit baseline-acceptance policy.
- Capture and finalize a separate P3 profile run aligned to the final palette
  and muted-ticker source. Keep `20260903T080855Z` as historical evidence.
- Complete physical-device checks and actual TalkBack, VoiceOver, Narrator,
  and Orca workflows, including focus, selection, clipboard, IME, and core
  task completion. Native AX tree availability alone does not close this gate.
- Complete remaining browser coverage, including Safari and the actual
  configured Firefox/Edge runs, together with applicable native smoke checks.
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
