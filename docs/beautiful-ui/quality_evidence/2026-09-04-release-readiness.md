# Release readiness — 2026-09-04

Date: 2026-09-04 (Asia/Shanghai). Toolchain: Flutter 3.47.0 / Dart 3.13.0.
Status: **not ready for stable-release sign-off**. Completed cloud and native
performance runs contain real failures; subsequent local fixes still need a
frozen-source cloud run and new native performance evidence.

All 20 Gallery components and seven foundation/building-block items have
implementations. **All 27 registry entries remain `in_progress`; all six Flutter
platforms remain `Partial`.** This document adds current evidence without
changing those decisions or rewriting earlier records.

## Source and evidence boundaries

| Source snapshot | Evidence and meaning |
| --- | --- |
| Historical `c2bde85dd5da7c33b0f7881234ae312f3be1826c` | The [September 3 CI record](./2026-09-03-final-ci-33748054504.json) preserves run `33748054504`, attempt 1, with 12/12 jobs passing. Its iOS driver, hosted consumer, build, visual and profile observations remain historical evidence for that source. They do not accept a later candidate. |
| `36142500c9ad91dc307b6c8005e78add357f080b` | The latest completed cloud checkpoint summarized below has main CI 10/12 and input/AT 1/9. Two complete native captures at this SHA have engineering-budget failures. Those results remain unchanged. |
| Local changes after `3614250` | P1 performance repairs, input/CI repairs and lossless timeline transport have completed local verification: 640 library tests, 59 Catalog tests, strict analysis and 141-file formatting. Final commit identity, publication dry-run after commit and subsequent cloud/native results are pending. Local passes are not promoted to later-SHA runtime acceptance. |

The [September 3 readiness document](./2026-09-03-release-readiness.md) and
`toolchain.json` retain their dated historical scope. This record is the current
entry point; an older heading containing “final” does not override a later
recorded failure.

## Completed cloud checkpoint at 3614250

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
| Publication dry-run | Current attempt exited **65** with the dirty-tracked-files warning | It is not a pass. Re-run after the source commit and retain the actual result. No package publication is claimed. |

The CI tooling manifest's documentation hashes precede this readiness/README
update. Its validation applies to the recorded scripts and workflows; it does
not claim that these later Markdown edits were present during those checks.

Search virtualization and measurement invalidation, Records row/header reuse,
and the Prompt editor's shared tap-region group have their recorded behavioral
and visual evidence. Subsequent P1 long-content fixes and the input focus/paste
repairs are local candidate work; the earlier captures do not measure their
final result. Tool output retention keeps the first-open layout cost and its
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

## Native performance: complete captures, failed budgets

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
earlier P3 slowdown. Further native work requires the user to unlock the Mac,
then a newly frozen source and a fresh result directory. Lock/sleep settings
were not changed and no simulated activity was used to bypass the lock.

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

- Commit the locally verified candidate, complete its post-commit publication dry-run,
  then record the actual main and independent input/AT cloud outcomes. Retain
  iOS, Edge and input failures until a corresponding run supplies new evidence.
- After user unlock, capture the unchanged representative workloads on the
  new source, keep prior failures, and assess the fixed engineering defaults.
  Agree product budgets separately and retain the repeated-run/device limits.
- Complete actual physical-device, OS IME, clipboard, screen-reader task-flow
  and human-review evidence for the advertised platforms and applicable host
  integrations. A capability probe or prepared script is insufficient.
- Reconcile the final candidate with the bounded visual/localization/temporal,
  asset, notice and publication evidence, adding proportionate checks wherever
  later changes invalidate the prior source scope.

The [support matrix](../support_matrix.md) and [parity manifest](../parity_manifest.yaml)
therefore retain six `Partial` platforms and 27 `in_progress` entries. No later
cloud success, new native budget pass, package publication or complete release
acceptance is inferred from local implementation work.
