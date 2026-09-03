# P3 macOS profile capture — 2026-09-03

**Result: the final run completed all seven workloads, test teardown, the
integration driver and the evidence finalizer successfully.** The driver and
script both exited `0`. This records profile evidence for the configuration
below; it does not declare six-platform performance acceptance or invent a
product performance budget.

The run captured **4,524 engine FrameTiming samples and 480 process-RSS
samples**. Each component ran one warmup round followed by three measured rounds.
The fixed workload/input/result assertions are documented in the
[reproducible protocol](../../../../../packages/beautiful_ai_ui_catalog/integration_test/P3_PERFORMANCE.md).

## Recorded environment

- Hardware: Apple M1 Pro, MacBookPro18,1, 10 logical processors, 32 GiB RAM.
- OS: macOS 15.7.9, build 24G830.
- Flutter: 3.47.0 stable, framework `4cf24164269a5ebf0c16a028a00727d0e77bbb05`;
  engine `5f77625673248ee5846fbcaf5d3e1a3878386fd7`; Dart 3.13.0.
- Native profile build, light theme, system motion, 100% text scale,
  `zh-Hans-CN`, high contrast off and animation-disable preference off.
- Actual native view: **1728×963 logical pixels / 3456×1926 physical pixels**,
  DPR 2, 120 Hz display. Every scenario's before/after sampling view matched.
  The 1368×823 readiness log was the intermediate size while native zoom was
  crossing the preparation threshold; it is not the measured viewport.
- Flutter Semantics was enabled by native accessibility inspection during
  window preparation. No screen-reader operation was performed during sampling.
- Renderer: **Impeller using a Metal surface**, verified by exact
  `GPUSurfaceMetalImpeller::AcquireFrame` events in all seven native VM timelines.
  The framework's public renderer field is unavailable and the launch log did
  not include a renderer announcement; the raw runtime events supply the
  additional evidence. Event counts are retained in `summary.json`.

The source baseline was commit `37a56e0e28c5a3dcadd16678a02c92037932fec2`
with local implementation changes. `source_hashes.json` pins the actual library
sources, relevant dependency/toolchain files, harness and profile entitlement.
Its manifest digest is
`ed8f40f37ddb6e276683e1bfba622d17e13deee272dd5e84af57281e2cbd9637`.
The artifact manifest also hashes the built profile runner and AOT application
binary. No hostname, account identifier or unrelated worktree inventory is
included in this compact evidence.

## Measured values

Frame values below are **milliseconds from the engine**, with nearest-rank
percentiles. Wall duration is the elapsed measured interaction sequence,
including event injection, scrolling/reveal and settling. It is not a frame
measurement.

| Workload | Frames | Build p50 | Build p95 | Maximum build | Raster p95 | Total span p95 | Interaction wall seconds | RSS samples |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Prompt: 1,000 sources / 10,000-character draft | 830 | 0.213 | 0.502 | **43.082** | 0.606 | 1.418 | 7.850 | 80 |
| Diff: 500 records × 3 fields, page 20 | 493 | 0.875 | 1.052 | 10.917 | 0.800 | 2.071 | 5.135 | 53 |
| Records: 1,000 rows × 20 populated columns | 1,228 | 0.207 | 0.708 | **22.708** | 0.801 | 1.810 | 12.059 | 122 |
| Sidebar: 1,000 recent items | 769 | 0.228 | 0.468 | 2.487 | 0.534 | 1.188 | 6.760 | 69 |
| Flowchart: 24 nodes / 48 edges | 368 | 0.327 | 3.466 | 5.046 | 1.960 | 5.495 | 5.517 | 57 |
| Insights: 4 series × 512 observations | 533 | 1.451 | 1.993 | **37.153** | 1.257 | 6.958 | 5.991 | 61 |
| Selection: 20,000-character document | 303 | 0.972 | 1.228 | 5.012 | 0.924 | 2.243 | 3.643 | 38 |

The larger Prompt, Records and Insights maximum build frames remain visible in
the evidence. This run does not claim zero jank or establish that those maxima
meet an agreed product budget. Establish target-device budgets and repeat
representative measurements before making such a guarantee.

Observed whole-process RSS sample peaks in workload order were 182.47, 239.53,
291.06, 321.47, 369.34, 434.67 and 461.84 MiB. These values include the harness,
fixture snapshots, engine, caches and previously retained VM traces. They are
**not component-exclusive memory costs**. The 100ms sampler can miss shorter
peaks; `ProcessInfo.maxRss` is separately labeled as the peak since process
launch. Post-unmount observations retain the fixture object until the workload
runner returns, and no garbage collection was forced. No leak conclusion is
supported by the rising process RSS alone.

## What was verified

- All declared data sizes were mounted; lazy realization remained bounded
  (five Prompt suggestion controls, 20 Diff rows, nine Records rows and eight
  Sidebar recent rows at their observed maxima).
- Prompt submission matched the complete expected trimmed draft (9,999 sent
  UTF-16 units from the 10,000-unit input), not merely an equal length.
- Diff selection flipped on both pages. Records selection changed its visible
  state and invoked the host; horizontal and vertical scrolling changed real
  offsets. Sidebar scrolling and recent activation were likewise checked.
- Flowchart keyboard and drag operations changed intermediate node positions
  and invoked accepted-snapshot callbacks. Pan and zoom changed the actual
  viewport transform. Warmup plus measurement produced 120 accepted graph edits.
- Insight pointer inspection changed the inspected index; eight Right events
  advanced it by exactly eight; dragging moved it back. Full textual data was
  realized only while requested.
- Selection used injected pointer gestures through the native Flutter editor,
  then requested and accepted four equal-length replacements over warmup plus
  measurement, retaining a 20,000-unit document.
- End-of-test SemanticsHandle and ticker checks remained enabled and passed.
  Window preparation was moved into `setUpAll`, so native accessibility setup
  preceded the widget-test handle baseline.

Text entry uses the public `EditableTextState.userUpdateTextEditingValue` path,
and key events use explicit Flutter physical-key mappings. This is a
**programmatic Flutter interaction workload**, not OS IME, real physical-keyboard,
physical-touch or screen-reader acceptance.

## Artifacts and trace coverage

- `summary.json` contains exact values, dataset sizes, callback outcomes,
  measurement configuration, process-memory boundaries and limitations.
- `p3_frame_samples.json.gz` and `p3_memory_samples.json.gz` preserve the complete
  original engine/RSS sample arrays, losslessly compressed. Frame counts and all
  stored p50/p90/p95/p99/max summaries were recomputed from the original arrays
  and matched before creating this evidence.
- `source_hashes.json` identifies the measured code and dependencies.
- `artifact_manifest.json` records raw-file byte sizes and SHA-256 checksums,
  compressed-copy checksums, profile-binary hashes and the two failed attempts.

The full raw output, including seven VM timelines, remains locally in
`packages/beautiful_ai_ui_catalog/build/p3-profile/20260903T080855Z/`.
Raw timelines are intentionally not committed. Their hashes let a reviewer
verify supplied raw copies against this compact evidence.

The VM timeline recorder is a bounded ring buffer. Six of the seven returned
traces retain roughly 32,000 events and a shorter time span than their complete
interaction sequences; only the Selection trace spans the full measured
sequence in this run. Treat those traces as **partial diagnostic traces**.
The 4,524 independent FrameTiming samples were captured via the engine callback
and are the source of all reported distributions; they do not rely on the
retention length of the VM timeline.

Two earlier attempts remain preserved as failed runs: `20260903T074846Z`
exposed profile-only test-helper and local VM-service entitlement issues;
`20260903T075336Z` completed workload bodies but failed the native AX-related
SemanticsHandle teardown check. Neither is accepted as a complete run.
`artifact_manifest.json` records their original report/log hashes and failures.

## Remaining acceptance limits

This is one successful run on one Mac. Other target platforms, physical touch
hardware, OS input methods and assistive technology retain their separate
acceptance requirements. Product frame/memory budgets and repeat-run stability
are still separate decisions. The native profile process has a
Debug/Profile-only network-client entitlement for its own local VM service;
Release entitlements are unchanged.
