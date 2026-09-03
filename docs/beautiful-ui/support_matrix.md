# Multi-platform support matrix

Status: partial platform evidence accepted; stable-release gates remain open
Baseline: Flutter `>=3.47.0`, Dart `>=3.13.0 <4.0.0`, `shadcn_flutter` `0.0.54`

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
| Chrome stable | Release-blocking shared Web journey | Partial | Shared journey passed in run 33736546039; later portable-source verification remains separate |
| Edge stable | Release-candidate compatibility and shared journey | Partial | Dedicated journey passed in run 33736546039 |
| Firefox stable | Release-candidate compatibility and shared journey | Partial | Dedicated journey passed in run 33736546039 |
| Safari stable | Release-candidate compatibility on macOS/iOS | Planned | Post-TickerMode visual recheck awaits manual Mac unlock; remaining compatibility evidence required |

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

## Current evidence snapshot

The current engineering pass is recorded in
[`quality_evidence/2026-09-03-release-readiness.md`](./quality_evidence/2026-09-03-release-readiness.md).
It keeps completed evidence separate from the remaining release gates:

- All twenty Gallery components are implemented and exported. All 27 registry
  entries remain `in_progress`; implementation coverage is not full release
  acceptance.
- The integrated library suite passed 528 tests, the Catalog passed 19 tests,
  and both package scopes passed strict static analysis.
- The macOS golden suite passed 12 checks; ten current macOS image hashes are
  recorded. The final 49-image source inventory includes the hosted-adapter
  correction, with all image pixels unchanged. Eight Linux component
  candidates from run `33736546039` were explicitly reviewed and accepted;
  follow-up strict comparison is still required.
- Shared action foreground contrast and visible selected states were repaired;
  Approval uses drawn checks, Sidebar's compact trigger accommodates large
  text, and numeric/chart controls expose native slider flags. The accepted
  images cover specific profiles, not the entire temporal/localization matrix.
- The tested normal subtle-text combinations and light accent text on
  `accentTint` now meet 4.5:1; the latter measures 4.925:1. Muted ancestor
  tickers force immediate shared-action color changes, fixing unreadable
  Flowchart buttons after a reduced-motion theme switch. Four palette and
  three paint regressions cover these final corrections.
- Exact font/icon inventory and notices passed: 43 source files, 37 runtime
  font files, 266 flag images, five original Web images, and 13 full generated
  LicenseRegistry labels. JavaScript, Wasm, and ordinary macOS release builds
  and their actual asset audits passed. Verified inherited Geist is the
  current typography; no Inter or JetBrains Mono files are bundled. The
  isolated hosted-consumer test now also verifies atomic themes and portable
  13-label notice delivery without the fork's sibling package or overrides.
- The ordinary macOS shared Catalog journey passed. Native AX comparison also
  succeeded without the Web compile flag. Catalog forcing of Web semantics
  is now gated by `kIsWeb`; native applications use the platform lifecycle.
  The [native semantics evidence](./quality_evidence/2026-09-03-native-semantics.md)
  keeps AX inspection separate from a completed VoiceOver user workflow.
- All seven P3 workloads completed in historical macOS profile baseline
  `20260903T080855Z` on an
  M1 Pro/32 GiB machine: 4,524 independent frame samples and 480 process RSS
  samples at 1,728×963 logical pixels, DPR 2, 120 Hz. Driver, teardown and
  script completed successfully. Its source predates the last palette,
  muted-ticker and hosted-adapter fixes. Final profile run 4 has not started
  because the Mac is locked and Computer Use requires manual user unlock.
  Product budgets, repeatability,
  and representative other-platform/device measurements remain open; measured
  UI-build peaks include frames above 16ms.
- Latest portable-source Wasm and ordinary macOS release builds passed.
- The twelve-job [run `33736546039`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33736546039)
  on `19c80c17e5346f7415b52af9583ba6770cfbee50` passed Firefox/Edge,
  Chrome/Linux, Android, Windows native and macOS native journeys, builds and
  Web asset audits. Quality failed only the eight then-unaccepted Linux
  goldens; their candidates are now accepted. The run completed with nine
  successful jobs, two failed jobs, and one skipped job. Apple failed on the
  iOS simulator app-launch timeout after successful compilation, before the
  widget test began; its macOS journey passed. Publish validation was skipped
  due to quality. Launcher remediation and the portable changes await the
  next committed-tree verification.
- Safari's visual recheck after the TickerMode repair is unfinished and also
  requires the user to unlock the local Mac manually. Earlier Safari or
  profile observations are not promoted to final-source acceptance.

The earlier P3 implementation [run `33726848975`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33726848975)
passed all ten jobs on `74178098705aa83b5452857aece6a3b10bb3ce4f`, including
six-platform builds, Web JS/Wasm, Chrome/Linux/Android journeys, quality,
Ubuntu golden comparison and publish validation. Earlier P1/P2 evidence is
retained in their dated records. Those commits predate this engineering pass
and are retained separately from the partial twelve-job result above.

Actual TalkBack, VoiceOver, Narrator and Orca task flows, physical-device
input, remaining browsers and visual/motion combinations, agreed performance
budgets, and other-platform performance evidence remain release gates. No
platform is yet marked Verified.
