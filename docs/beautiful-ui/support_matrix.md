# Multi-platform support matrix

Status: planned contract; no release support claim is implied until evidence is recorded
Baseline: Flutter `>=3.47.0`, Dart `>=3.13.0 <4.0.0`, `shadcn_flutter` `0.0.54`

## Status vocabulary

| Status | Meaning |
|---|---|
| Planned | In release scope, but the required evidence is not complete. |
| Partial | Some evidence exists; documented gaps remain and support cannot yet be claimed without qualification. |
| Verified | The current release candidate passed the required automated and manual evidence. |
| Degraded | A documented alternative presentation preserves the core task because the full desktop interaction is inappropriate on that platform or input. |
| Out of scope | No compatibility commitment is made. |

All six Flutter platforms begin as **Planned**. A roadmap entry, successful compilation on another platform, or source-site behavior is not verification.

## Release platform targets

| Platform | Window modes | Primary input | Required release evidence | Initial status |
|---|---|---|---|---|
| Android | Compact, medium, expanded/split-screen | Touch; hardware keyboard where present | Build, emulator integration journeys, at least one physical-device smoke pass, TalkBack review | Planned |
| iOS | Compact, medium, expanded/iPad split view | Touch; hardware keyboard/trackpad where present | No-codesign/simulator build, simulator journeys, physical-device smoke pass, VoiceOver review | Planned |
| Web | All modes and live resize | Mouse/trackpad, keyboard, touch where present | JS and Wasm builds, Chrome journeys, browser compatibility pass, Web semantics review | Planned |
| macOS | Medium and expanded; compact windows remain usable | Mouse/trackpad and keyboard | Native build, desktop journeys, keyboard/focus/scroll review, VoiceOver review | Planned |
| Windows | Medium and expanded; compact windows remain usable | Mouse/trackpad and keyboard | Native build, desktop journeys, keyboard/focus/scroll review, Narrator review | Planned |
| Linux | Medium and expanded; compact windows remain usable | Mouse/trackpad and keyboard | Native build, desktop journeys, keyboard/focus/scroll review, Orca review | Planned |

Exact minimum OS versions are inherited from the pinned Flutter toolchain and generated platform projects until they are frozen before the first stable release. A future minimum-version decision must be explicit in package metadata and release notes.

## Web browser targets

| Browser | Evidence expectation | Initial status |
|---|---|---|
| Chrome stable | Release-blocking automated journeys for the primary Web path | Planned |
| Edge stable | Release-candidate compatibility pass | Planned |
| Firefox stable | Release-candidate compatibility pass | Planned |
| Safari stable | Release-candidate compatibility pass on macOS/iOS | Planned |

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
| Records Table | List/card summary plus row detail; advanced column resizing/configuration may remain expanded-only |
| Sidebar Nav | Drawer or bottom navigation instead of a persistent sidebar |
| Flowchart | Read-only overview or ordered stepper; advanced graph editing may remain tablet/desktop-only |
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

## Current evidence snapshot

- CI run `33623501086` passed JavaScript and Wasm Web releases, Android debug
  APK, iOS release without signing, and macOS, Windows, and Linux release
  builds for the Loading vertical slice.
- The P1 shared Catalog journey passes locally through Flutter WebDriver on
  Chrome 152 with a matching ChromeDriver. The same test is wired for Ubuntu
  Chrome, Linux/Xvfb, and Android emulator execution in CI. Run
  [`33634769448`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33634769448)
  passed all ten jobs on commit `29dc443efe1bc4db67946024bf66f91d98f8128f`,
  including all three journeys and every P1 platform build. This verifies the
  explicit enabled Semantics and keyboard Search selection fixes on the
  committed tree. Canonical P1 Linux goldens retain their accepted origin in
  run `33632807691`.
- P2 implementation commit `92992e48ec0f361be9015e443bd15bff95b7b4d6`
  passed all six platform builds (including Web JS/Wasm) and the expanded
  Chrome, Linux/Xvfb, and Android emulator journeys in
  [run `33701530733`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33701530733).
  That run failed only at the missing P2 Linux golden baselines, exported
  candidates, and skipped the dependent publish check. Both Ubuntu candidates
  were visually accepted and registered for the follow-up strict comparison.
  Final [run `33707996401`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33707996401)
  passed all ten jobs on `bc6a72959dfa84543abc844fa8fef4fcd15e7629`, including
  strict Ubuntu golden comparison, publish dry-run, all platform builds, and
  all three journeys. The missing-baseline issue is resolved for P2.
  Local verification passed 257 package tests, 7 Catalog tests, 571 upstream
  tests, and publish dry-run with 0 warnings.
- All seven P3 implementation contracts are recorded in
  [`p3_contracts.md`](./p3_contracts.md), covering ownership, adaptive
  alternatives, input methods, bounded workloads, and source deviations.
  Their public implementations are present and remain `in_progress`.
  P3 execution evidence is recorded independently in
  [`quality_evidence/2026-09-03-p3-modules.md`](./quality_evidence/2026-09-03-p3-modules.md);
  passing P2 runs do not verify those later changes.
- P3 implementation commit `a27de98e909fe64a59d4d0f4f3c760f34501efa2` passed every
  platform build, Web JS/Wasm, and the full P1+P2+P3 Chrome, Linux/Xvfb, and
  Android emulator journeys in [run `33723609480`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33723609480).
  The four missing P3 Linux golden files were the only first-run failures.
  Their generated candidates were visually accepted and registered for
  ordinary comparison in the follow-up workflow. Local validation passed
  457 package tests, 9 Catalog tests, 571 upstream tests and a zero-warning
  publish dry-run. All 20 gallery components now have Flutter implementations.
- Widget and Semantics suites cover P1, P2 and P3 at adaptive boundaries,
  200% text scale, RTL, reduced motion, pointer, keyboard, and assistive action
  paths.
- Physical-device smoke passes and real TalkBack, VoiceOver, Narrator, and
  Orca reviews remain release gates, so no platform is yet marked Verified.
