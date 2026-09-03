# Final-source macOS profile capture — 2026-09-03

**Result: complete capture for revision `c2bde85dd5da7c33b0f7881234ae312f3be1826c`.**
Run `20260903T114308Z` completed seven workloads, test teardown, integration driver
and report finalization. Both driver and final script exited **0**. This is an
independent final-source capture, preserving the earlier successful baseline
and the failed window-preparation attempt.

The run saved **4,495 engine FrameTiming samples
and 478 process-RSS samples**, using the unchanged
protocol: one warmup round and three measured rounds per component. No new
workload, test, GUI action or runtime source change was added for this run.

## Observed configuration

- Apple M1 Pro, MacBookPro18,1, 10 logical processors, 32 GiB RAM.
- macOS 15.7.9, build 24G830; Flutter 3.47.0 stable; Dart 3.13.0.
- Native profile build, light theme, system motion, normal text scale,
  zh-Hans-CN; high-contrast and disable-animations platform flags off.
- **1728×1080 logical pixels / 3456×2160 physical pixels, DPR 2, 120Hz**.
  Each scenario's before/after measurements matched this actual native view.
  Its size was observed directly. The root had not issued AX zoom before
  VIEWPORT_READY; no restoration or external-adjustment cause is inferred.
- **Impeller with a Metal surface**, verified by
  `GPUSurfaceMetalImpeller::AcquireFrame` events in every raw VM timeline.
- The recorded **platform** semantics flag was false. The SDK's `testWidgets`
  default still requests framework semantics and holds its own handle. The
  platform flag therefore must not be read as disabling all framework semantics.

## Source integrity and working state

The working tree was **documentation/evidence dirty**, as recorded verbatim in
`summary.json`; it is not described as clean. All **50** files in
`source_hashes.json` were compared byte-for-byte with the successful CI revision:
library/Catalog Dart sources, targets/drivers, the official runner, toolchain and
dependency pins, and macOS window/DebugProfile configuration all matched.
The source manifest digest is `4c4cf5d6606596f8f7ce45f07d4e37a0309aad1d60f42ea7d50d0af850390dac`.
Built runner and AOT application hashes are in `artifact_manifest.json`.
No hostname or user/account identifier is included in this compact record.

## Measured values

Engine duration values below are milliseconds; percentiles use nearest rank.
The interaction wall column includes event injection, reveal/scroll and settling
and is deliberately separate from engine frame duration.

| Workload | Frames | Build p50 | Build p95 | Maximum build | Raster p95 | Total span p95 | Wall seconds | RSS samples |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| prompt_bar | 834 | 0.417 | 1.380 | 45.962 | 1.843 | 3.844 | 7.851 | 80 |
| diff_table | 497 | 0.832 | 3.265 | 17.205 | 1.952 | 5.576 | 5.224 | 54 |
| records_table | 1191 | 0.515 | 1.144 | 22.060 | 2.838 | 4.356 | 11.713 | 119 |
| sidebar_nav | 760 | 0.561 | 1.231 | 2.925 | 1.865 | 3.488 | 6.730 | 69 |
| flowchart | 366 | 0.274 | 4.985 | 8.910 | 4.513 | 8.022 | 5.537 | 57 |
| insight_cards | 544 | 1.575 | 3.818 | 45.395 | 1.774 | 5.740 | 5.967 | 61 |
| selection_actions | 303 | 0.877 | 4.219 | 5.189 | 1.844 | 6.073 | 3.668 | 38 |

Individual UI build peaks include **45.962ms for Prompt, 22.060ms for Records
and 45.395ms for Insights**. They remain visible in the evidence. This capture
introduces no arbitrary passing threshold and does not claim zero jank or that
an agreed product budget has been met.

All input/result assertions remained active: full expected Prompt text,
selection changes and host callbacks, actual list/grid scroll offsets,
intermediate Flowchart positions/callbacks/transforms, exact Insight index
changes, and Selection Actions replacement contents. This is programmatic
Flutter input, not OS IME, physical keyboard/touch or screen-reader acceptance.

RSS samples describe the **whole process**, including fixtures, engine, caches,
retained traces and instrumentation. They are not component-exclusive costs.
The 100ms sampler can miss shorter peaks; lifetime maxRss is separately named.
No garbage collection was forced and no leak claim is made.

## Artifacts and limits

- `summary.json` retains dataset sizes, all frame distributions, measured step
  wall durations, memory boundaries, callback outcomes and limitations.
- `p3_frame_samples.json.gz` and `p3_memory_samples.json.gz` are lossless copies
  of the complete captured arrays. Counts and every stored min/max/mean and
  p50/p90/p95/p99 were recomputed from raw samples and matched.
- `source_hashes.json` verifies final-source equality against the CI revision.
- `artifact_manifest.json` hashes every original output and compiled binary,
  as well as the preserved earlier runs.

The full raw output remains at
`packages/beautiful_ai_ui_catalog/build/p3-profile/20260903T114308Z/`.
Large timelines are retained there and referenced by hash rather than committed.
The VM recorder is a bounded ring buffer: **6 of seven returned timeline
extents are shorter than their interaction sequences**. These are partial
diagnostic traces; frame distributions use the independent complete FrameTiming
arrays, not timeline retention.

The earlier `20260903T080855Z` run used an older source, a 1728×963dp viewport
and a different platform semantics flag. Its original evidence remains intact;
these runs are not a controlled performance-regression comparison. Attempt
`20260903T113737Z` failed because window preparation was not completed before its
deadline; its original files are also preserved. See the parent
[`index.json`](../index.json) for explicit final/historical/failed roles.

The final-source **macOS capture requirement is now fulfilled**. Product frame
and memory budgets, repeat-run stability, other platforms and real assistive or
physical-input hardware remain separate acceptance work. Reproduction steps and
strict driver-exit finalization are in the
[protocol](../../../../../packages/beautiful_ai_ui_catalog/integration_test/P3_PERFORMANCE.md).
