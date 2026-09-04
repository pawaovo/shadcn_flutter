# Native all-15 performance at 5edbcab7

**One fresh native macOS profile completed all 15 workloads and passed all 15
unchanged engineering budgets.** The runner finalized with exit 0, the driver
exited 0, and the original all-suite assessor was invoked once and exited 0.
The capture contains **10,311 engine FrameTiming samples and 1,020 RSS samples**.
No capture retry, budget change, post-hoc frame trimming or replacement of older evidence
was used to obtain this result.

| Workload | Frames / RSS | Build p95 / max (ms) | Raster p95 / max (ms) | Over interval | RSS peak (MiB) | Original budget |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `prompt_bar` | 894 / 82 | 0.838 / 3.758 | 0.984 / 1.668 | 0 / 894 | 204.250 | pass |
| `diff_table` | 495 / 53 | 2.404 / 12.156 | 1.606 / 3.876 | 3 / 495 | 246.531 | pass |
| `records_table` | 1118 / 111 | 0.787 / 14.683 | 1.617 / 2.699 | 9 / 1118 | 249.906 | pass |
| `sidebar_nav` | 768 / 69 | 0.613 / 2.288 | 1.114 / 2.730 | 0 / 768 | 255.734 | pass |
| `flowchart` | 465 / 58 | 3.823 / 5.319 | 2.386 / 14.727 | 1 / 465 | 275.859 | pass |
| `insight_cards` | 1058 / 106 | 2.442 / 6.201 | 2.571 / 7.172 | 0 / 1058 | 278.766 | pass |
| `selection_actions` | 303 / 38 | 2.789 / 5.373 | 1.125 / 3.376 | 0 / 303 | 288.984 | pass |
| `search_long_catalog` | 1302 / 116 | 1.086 / 3.292 | 1.202 / 5.664 | 0 / 1302 | 263.750 | pass |
| `code_block_long_source` | 730 / 81 | 0.388 / 0.943 | 2.639 / 5.822 | 0 / 730 | 364.359 | pass |
| `thinking_long_trace` | 619 / 57 | 0.491 / 2.589 | 1.039 / 2.401 | 0 / 619 | 311.828 | pass |
| `streaming_long_answer` | 775 / 69 | 4.183 / 5.902 | 2.268 / 3.938 | 0 / 775 | 335.672 | pass |
| `tool_chips_large_output` | 538 / 51 | 2.880 / 5.221 | 1.230 / 10.481 | 1 / 538 | 353.359 | pass |
| `chat_long_transcript` | 314 / 35 | 0.478 / 1.812 | 0.777 / 6.368 | 0 / 314 | 370.125 | pass |
| `filter_table_large_dataset` | 363 / 40 | 3.497 / 6.717 | 1.532 / 3.334 | 0 / 363 | 382.641 | pass |
| `task_rows_large_workflow` | 569 / 54 | 2.290 / 2.976 | 1.216 / 4.660 | 0 / 569 | 386.547 | pass |

“Over interval” counts frames whose build or raster duration exceeds the observed
120 Hz interval (8.333… ms). All 14 such frames remain in the evidence: Diff has
3/495, Records 9/1,118, Flowchart 1/465 and Tool Chips 1/538. Each remains below
the unchanged 1% per-workload limit; every build/raster maximum is below two
intervals. Every build/raster p95 is below one interval and every total-span p95
is below two. Total span includes scheduling and is not an observed dropped-frame
count.

The highest measured whole-process RSS sample is **386.546875 MiB**, in Task
Rows, below the original 512 MiB limit. The largest positive measured-window
change is **8.6875 MiB**, in Search, below 64 MiB. The process-lifetime maximum
reported at the final RSS sample is **426 MiB**, a separate value. This was one
combined process in the table order, including earlier fixtures and capture
retention; RSS is not a per-component allocation or leak measurement.

The [JSON companion](2026-09-04-5edbcab7-all-performance.json) retains every gate,
dataset, sampling epoch, full environment record, RSS interpretation, source and
assessor identity, transport verification, and the hashes of **all 49 evidence files in the raw directory
(214,065,846 bytes)**. The full unchanged assessment is
`budget-assessment.json` in the raw directory. The policy remains
[`engineering_default_not_product_approved`](engineering_budget_v1.json).

## Native environment and source

This is Flutter **3.47.0 / Dart 3.13.0**, macOS **15.7.9 (24G830)** on an **Apple
M1 Pro / MacBookPro18,1**, with 32 GiB physical memory. All 15 native environment
records are `verified_stable`, with zero recorded changes: **1728 × 1080 logical
pixels, DPR 2, 120 Hz, resumed lifecycle, frame scheduling enabled, platform and
framework semantics enabled**, light theme and system motion. Platform locale
is `zh-Hans-CN`; widget locale is `en-US`. The captured launch log does not identify
the renderer backend independently, so it remains the unverified platform default.

The root task activated the actual native window through Window
`makeKeyAndOrderFront`, observed the native size and resumed lifecycle, and clicked
Start. The native preparation record shows Start at **15:56:03.856836 +08:00**,
READY at **15:56:04.857089 +08:00**, **nine completed framework frames**, and
**1,000,268 µs** of stable post-click state. The complete preparation took
59.402683 seconds within its original 120-second limit. The application report
started at **15:55:05.454314** and finished at **15:59:56.388464** local time.

The unchanged runner was invoked under temporary **`caffeinate -di`** to prevent
idle display/system sleep for its lifetime; no OS power or lock setting changed.
After Start, the root stopped GUI interaction, other agents paused local work,
and the capture agent only waited on the existing capture session. No ad-hoc
process/CPU sidecar was added. Root reported no IINA in the pre-capture CUA
inventory and did not change playback. These are operator observations, not a
continuous inventory of other user applications or proof of zero external load.

Both source manifests identify exact revision
`5edbcab7edc5c058cf9354c6109df917846fb4e8` and **310 identical build/runtime input
files**, digest:

```text
5519a41a224b9fdb77fea770213aa29f9b65e9cede05b19d18e0f96d6d838804
```

The archive pass independently recomputed both inventory digests and rehashed
all 310 actual files in the frozen worktree; each matched. The fresh detached
checkout started clean. Dependency preparation generated out-of-scope
`packages/docs` native xcconfig changes and Podfiles before the first inventory;
that worktree status was identical before and after capture. This is an unchanged
scoped-input claim, not a clean-whole-worktree claim.

## Actual checkpoint and timeline proof

The new harness's normal path is now exercised on the real native VM:

- **16 durable checkpoint files**, schema 1, consecutive sequences 1–16, all
  nonterminal. Checkpoints 1–15 contain respectively 1–15 completed scenarios;
  checkpoint 16 contains all 15 and `workloads_complete`.
- Checkpoint 16's `report_data` is semantically identical to both the final
  `integration_response.raw.json.data` and `p3_response_data.raw.json`. The actual
  response is `result: "true"` with `failureDetails: []`.
- All **17 timeline-stop RPCs**—16 checkpoint boundaries and final close—are
  `acknowledged`, taking 472–901 µs. No primary or secondary transport failure
  occurred. The first 15 stops follow their sampling windows, and the first 14
  precede the next window.
- Existing completed scenario data and trace envelopes remain stable across
  checkpoints 1–15. At checkpoint 16 only Task Rows' latest-await diagnostic
  changes to `suite.cleanup`; its recorded samples and outcomes are retained.
- All **15 compressed trace payloads** passed an independent base64/gzip streaming
  check of byte lengths and compact-JSON SHA-256: **3,676,710 compressed bytes →
  85,781,527 JSON bytes**. The real driver also checked decoded event-array counts
  before writing the timelines; its decode/evidence failure maps are empty.
  Reported retained events total **485,358**. The reviewer did not independently
  recount the large event arrays, and bounded VM retention is still not a complete
  execution history.

The launch log retains the integration_test-plugin warning emitted during
tearDownAll. Actual VM request-data, all checkpoints, final response and persisted
artifacts succeeded as recorded above. This does not claim Android
instrumentation or XCTest reporting was exercised.

## Scope and retained history

This is one observed native macOS all-suite pass on the frozen source. Repeated-run
stability, other devices/platforms, physical input, assistive-technology use during
measurement, isolated component memory and leaks remain unassessed. It is not a
causal comparison with earlier separate suites or differently controlled runs.

The [locked abd6293b attempt](2026-09-04-abd6293b-native-preparation.md) remains a
120-second preparation failure with no Start, no measured workload and no budget
result. The [earlier f15f27eb P3 pass](2026-09-04-f15f27eb-display-awake.md),
[87299572 outcomes and failures](2026-09-04-87299572-native-profile.md), and all
original raw artifacts and budgets are unchanged. This new result does not turn
any earlier failure into a pass or grant all-platform release acceptance.

Raw directory:
`/tmp/beautiful-native-all-5edbcab7/packages/beautiful_ai_ui_catalog/build/p3-profile/20260904-5edbcab7-all-awake`.
