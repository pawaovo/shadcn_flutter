# Multi-platform support matrix

Status: four-browser W3C input and P1/P2 engineering budgets pass; remaining journey, SDK, P3 and device/AT gates keep all six platforms Partial
Baseline: Flutter `>=3.47.0`, Dart `>=3.13.0 <4.0.0`, `shadcn_flutter` `0.0.54`

Current evidence: [September 4 release readiness](./quality_evidence/2026-09-04-release-readiness.md).
The completed `bff08825` checkpoint has main CI **10/12** and input/AT **4/9**,
including all three native input bridges. All four independent W3C suites pass
in full. The two main failures are Android's copy-feedback observation and
iOS VM-service discovery/cleanup before driver start. At the earlier `87299572`
runtime snapshot, P1/P2 budgets passed **8/8** and P3 **1/7**. Linux's native
parent/lifetime contract passes; full Orca tasks still expose SDK dynamic-name
notification and expanded-state limitations. The
`c2bde85` twelve-job pass retained below is historical, not current-candidate
acceptance. All 27 registry entries remain `in_progress`.

## Status vocabulary

| Status | Meaning |
|---|---|
| Planned | In release scope, but the required evidence is not complete. |
| Partial | Some evidence exists; documented gaps remain and support cannot yet be claimed without qualification. |
| Verified | The current release candidate passed the required automated and manual evidence. |
| Degraded | A documented alternative presentation preserves the core task because the full desktop interaction is inappropriate on that platform or input. |
| Out of scope | No compatibility commitment is made. |

All six Flutter platforms are currently **Partial**: build and selected interaction evidence exists, while the full release matrix remains incomplete. A configured CI step, successful compilation on another platform, or source-site behavior is not an executed verification.

## Release platform targets

| Platform | Window modes | Primary input | Required release evidence | Current status |
|---|---|---|---|---|
| Android | Compact, medium, expanded/split-screen | Touch; hardware keyboard where present | Build, emulator integration journeys, at least one physical-device smoke pass, TalkBack review | Partial |
| iOS | Compact, medium, expanded/iPad split view | Touch; hardware keyboard/trackpad where present | No-codesign/simulator build, simulator journeys, physical-device smoke pass, VoiceOver review | Partial |
| Web | All modes and live resize | Mouse/trackpad, keyboard, touch where present | JS and Wasm builds, Chrome journeys, browser compatibility pass, Web semantics review | Partial |
| macOS | Medium and expanded; compact windows remain usable | Mouse/trackpad and keyboard | Native build, desktop journeys, keyboard/focus/scroll review, VoiceOver review | Partial |
| Windows | Medium and expanded; compact windows remain usable | Mouse/trackpad and keyboard | Native build, desktop journeys, keyboard/focus/scroll review, Narrator review | Partial |
| Linux | Medium and expanded; compact windows remain usable | Mouse/trackpad and keyboard | Native build, desktop journeys, keyboard/focus/scroll review, Orca review | Partial |

Exact minimum OS versions are inherited from the pinned Flutter toolchain and generated platform projects until they are frozen before the first stable release. A future minimum-version decision must be explicit in package metadata and release notes.

## Web browser targets

| Browser | Evidence expectation | Current status | Automation/execution |
|---|---|---|---|
| Chrome stable | Release-blocking shared Web journey | Partial | Main journey and complete independent W3C input pass at bff08825; retained framework composition check fails |
| Edge stable | Release-candidate compatibility and shared journey | Partial | Main journey and complete independent W3C input pass at bff08825; separate framework driver navigation times out before a report |
| Firefox stable | Release-candidate compatibility and shared journey | Partial | Main journey and complete independent W3C input pass at bff08825; retained framework composition check fails |
| Safari stable | Release-candidate compatibility on macOS/iOS | Partial | Main journey and complete independent W3C input pass at bff08825; retained synthetic resize composition check fails; OS/device/AT acceptance remains open |

Embedded WebViews, obsolete browser versions, and browser extensions that alter layout or semantics are out of scope unless a consuming product adds a separate requirement.

## Adaptive layout contract

| Mode | Default constraint | Required behavior |
|---|---:|---|
| Compact | `< 600dp` | Single-column flow; primary actions remain reachable above SafeArea/keyboard; wide data becomes summaries and detail; no hover-only action |
| Medium | `600–1023dp` | Optional two-pane flow; navigation rail where appropriate; only essential data columns; overlay may become sheet based on available space |
| Expanded | `>= 1024dp` | Full sidebar/multi-column/data/editor affordances; pointer and keyboard acceleration; anchored overlays when space permits |

Every reusable component is also tested at 599, 600, 1023, and 1024dp. Layout selection uses parent constraints; it does not assume that a platform always has one mode.

## Input and interaction matrix

| Capability | Touch | Mouse/trackpad | Keyboard | Accessibility requirement |
|---|---|---|---|---|
| Primary action | Tap | Click | Enter/Space | Named control with enabled/disabled state |
| Secondary/context action | Visible action, long-press, or sheet | Click/right-click as conventional | Menu key/shortcut where conventional | Equivalent path cannot rely on hover |
| Disclosure | Tap | Click | Enter/Space; arrows when conventional | Expanded/collapsed state exposed |
| Scrolling | Drag/fling | Wheel/trackpad; visible scrollbar for data surfaces | Page/arrow navigation where useful | Focus does not become trapped |
| Drag or resize | Enlarged handle with scroll-conflict policy | Pointer drag | Discrete keyboard adjustment | Current value and bounds exposed |
| Selection | System selection behavior or touch-safe sheet | Pointer selection and contextual overlay | Shift/navigation shortcuts | Selected range/action labels exposed |
| Dismissal | Back gesture/button or explicit close | Outside click/close | Escape | Focus returns to the logical invoker |

## Cross-platform quality requirements

Every verified public component must demonstrate:

- light, dark, and high-contrast behavior;
- 200% text scaling without loss of the core task;
- long English and Chinese text plus Arabic/RTL coverage;
- reduced-motion behavior using the current Flutter accessibility setting;
- no state loss during resize, rotation, split view, or software-keyboard changes;
- status and errors conveyed with text/semantics, not color alone;
- stable focus order and visible focus indication;
- platform-appropriate overlay placement, back/dismiss behavior, scrolling, and text selection.

## Component-specific degraded presentations

`Degraded` is an intentional, documented experience rather than an accidental omission:

| Component | Compact/touch presentation allowed for initial release |
|---|---|
| Records Table | Lazy cards with complete row detail and accessible property/column controls; expanded mode adds the horizontal grid |
| Sidebar Nav | Drawer or bottom navigation instead of a persistent sidebar |
| Flowchart | Editable ordered steps preserve conditions and movement actions; expanded mode offers the spatial canvas |
| Selection Actions | System selection toolbar or bottom sheet instead of a pointer-anchored floating panel |
| Prompt Bar | Core compose/send controls visible; secondary tools move to an accessible menu/sheet |
| Insight Cards | Single-card flow and textual chart summary when a dense multi-card chart would be unusable |

The parity manifest records the approved presentation per component before implementation can be marked complete.

## Evidence gates

| Gate | Minimum platform evidence |
|---|---|
| G1: vertical slice | Loading State builds on all six targets; Android, Chrome, and one desktop target run the key journey; semantics and golden checks pass in the pinned environment |
| G2: six-component MVP | Six P1 components run in a real consumer; Android, iOS, Web, macOS, and Windows receive smoke coverage; Linux builds and receives targeted desktop coverage |
| G3: complex components | Each P3 spike defines supported/degraded modes, workload, performance budget, and platform-specific interaction before implementation approval |
| G4: stable release | All advertised platforms meet the table above; real assistive-technology review, browser pass, performance evidence, license audit, and publish dry-run are complete |

Evidence is dated and release-specific. A platform returns to Partial when a toolchain, renderer, or major interaction dependency changes until proportionate regression evidence is restored.

## Historical evidence snapshot — September 3, c2bde85

**Historically validated code: `c2bde85dd5da7c33b0f7881234ae312f3be1826c`.**
[Fifth CI `33748054504`, attempt 1](https://github.com/pawaovo/shadcn_flutter/actions/runs/33748054504)
completed with **12 successful jobs, zero failures and zero skips**. The
[compact final evidence](./quality_evidence/2026-09-03-final-ci-33748054504.json)
records exact native-driver and hosted-consumer artifact hashes. A later
standalone documentation/evidence commit does not replace this tested code SHA.

- Quality passed 528 library tests, 26 Catalog tests and 571 core regressions,
  together with strict analysis and Ubuntu golden comparison. Ten macOS
  golden hashes and the eight accepted Linux component baselines are recorded;
  49 supplemental static images were individually reviewed.
- All platform builds passed, including Web JavaScript and Wasm. The shared
  journeys passed on Android, iOS simulator, macOS, Windows and Linux, with
  Chrome, Edge and Firefox browser jobs also passing.
- The actual iOS driver ran and passed: exit 0 in 50.234s. Launch took 7.582s;
  VM discovery took 12.396s including launch and used one scoped history query.
  One whole Catalog journey with suite setup/teardown passed, and termination
  completed. This closes the observed native semantics and driver-completion
  gates for the recorded simulator run.
- The independent hosted-consumer artifact at the same code SHA passed all
  209 public-dependency file checks, 12 atomic theme/state/focus observations
  and 13 complete notice/registry texts. Source/built-asset audits cover the
  registered fonts, flags and original artwork. This is validation/preflight,
  not an actual package publication.
- The current typography is verified inherited Geist Sans/Mono, with no
  bundled Inter or JetBrains Mono. Shared contrast, selected-state, glyph,
  large-text and slider-semantics corrections retain their focused evidence.
- The [final macOS profile](./quality_evidence/performance/2026-09-03-macos-profile-final/README.md)
  completed 7/7 workloads, strict teardown, driver and finalization: 4,495
  frame samples and 478 process RSS samples at 1,728×1,080dp, DPR 2, 120 Hz.
  All 50 runtime/build inputs match the validated code despite documentation/
  evidence changes in the working tree. Platform semantics was false while
  framework test semantics remained enabled. Product budgets, repeatability
  and other-platform performance acceptance remain open.
- The [Safari review](./quality_evidence/2026-09-03-safari-flowchart-theme-reduced.md)
  independently accepted three full-screen light/dark/light captures with
  reduced motion and correctly restored Flowchart condition colors. This
  closes only that visual regression. The 1,229×768 saved pixels do not imply
  a CSS viewport/DPR, and the operator-reported system-dark intermediate is
  not independently accepted. Earlier white/no-window capture symptoms ceased
  without a code change; their cause remains unproven.

The [historical readiness record](./quality_evidence/2026-09-03-release-readiness.md) and
`toolchain.json` retain the first four failed attempts and the fourth run's
successful same-SHA targeted Edge retry. The fourth runner's `+3` counts
setup, one journey and teardown, not three independent journey tests. Those
historical failures and the unknown cause of the original Edge timeout are
kept distinct from the fifth run's successful actual driver execution. The
performance index separately preserves the old `080855Z` success and the
`113737Z` preparation timeout with zero samples; neither is substituted for
the final `114308Z` source-matched capture.

Actual TalkBack, VoiceOver, Narrator and Orca task flows, physical-device
input, remaining Safari/browser and full visual/localization/motion coverage,
agreed product budgets and representative performance evidence remain release
gates. All 27 registry entries stay `in_progress`; no platform is marked Verified.
