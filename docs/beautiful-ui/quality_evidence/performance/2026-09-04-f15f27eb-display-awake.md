# Display-awake P3 profile at f15f27eb

**This complete native macOS capture passes all seven unchanged engineering-budget
workloads.** Driver and run exit codes are 0, failure count is 0, and independent
recomputation matches the saved `budget_assessment.json` exactly. The capture
contains **5,163 FrameTiming and 525 RSS samples**; no bad frames were removed.

| Workload | Frames / RSS | Build p95 / max (ms) | Raster p95 / max (ms) | Over interval | RSS peak (MiB) | Original-budget result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `prompt_bar` | 897 / 83 | 1.032 / 4.661 | 1.338 / 9.032 | 1 / 897 | 180.281 | pass |
| `diff_table` | 492 / 53 | 2.404 / 9.504 | 1.418 / 2.866 | 3 / 492 | 221.094 | pass |
| `records_table` | 1157 / 115 | 0.803 / 14.078 | 1.481 / 3.166 | 9 / 1157 | 252.141 | pass |
| `sidebar_nav` | 803 / 72 | 0.607 / 2.048 | 1.151 / 3.277 | 0 / 803 | 223.516 | pass |
| `flowchart` | 457 / 58 | 3.890 / 6.475 | 2.510 / 7.222 | 0 / 457 | 235.891 | pass |
| `insight_cards` | 1055 / 106 | 2.052 / 5.635 | 2.163 / 3.932 | 0 / 1055 | 201.516 | pass |
| `selection_actions` | 302 / 38 | 1.593 / 3.815 | 0.950 / 2.343 | 0 / 302 | 213.359 | pass |

The [JSON companion](2026-09-04-f15f27eb-display-awake.json) retains every gate,
original sampling interval, source/assessor/budget identity, raw artifact hash,
and measured-process RSS details. The original budget remains
`engineering_default_not_product_approved`: at 120 Hz its p95 build/raster limit
is one 8.333 ms interval, maxima and total-span p95 allow two intervals, and the
per-workload build-or-raster over-interval fraction is at most 1%. RSS limits
remain 512 MiB sampled peak and 64 MiB positive measured-window growth.

## Capture controls and source integrity

Every workload used one warmup and three measured rounds. All seven environment
records are `verified_stable` with zero changes: **1728 × 1080 dp, DPR 2, 120 Hz,
resumed, frames enabled, platform and framework semantics enabled**, light theme
and system motion. The renderer remains the requested platform default; the
captured log does not independently identify its backend.

The root task reports wrapping the driver with temporary `caffeinate -di`.
`power-assertions-before.txt`, timestamped **13:20:43 +0800**, records both
PreventUserIdleDisplaySleep and PreventUserIdleSystemSleep as active, owned by
caffeinate PID 20330 on behalf of the driver shell. This is a temporary assertion,
not a changed power policy or a waiver of the actual lifecycle/frame gates.

CUA Window `makeKeyAndOrderFront`, observed resumed state, then explicit Start
preceded sampling. Recorded Start was **13:20:48.371**, followed by stable READY
at **13:20:49.445**. The root reports no UI actions or ad-hoc local CLI work after
Start until completion, only the existing wait; other agents paused. The recorder
and declared sidecar continued their intended observation. `host-top.log` has
**127 samples**, not 84, from raw UTC 05:20:45–05:23:06, or local
**13:20:45–13:23:06**, covering all measured workload windows. Coverage itself is
not evidence of a particular CPU/GPU cause.

Both before/after source inventories independently recompute to **305 files** at
`f15f27eb671086444f137475f1cf4e9de3eb6328`, digest
`e2ab84eb64e7ef55b246cc3bed78d7bdc955346b056c644f4304c4d6f9077f91`.
Only `diff_table.dart` and `flowchart.dart` differ from the b2e0c2f1 input manifest;
datasets match. The original assessor and budget are byte-identical across the
frozen copies/current repository. Root also reports **655 combined library tests
passed**, including the component mechanism regressions; that is separate from
this native timing result.

## Interpretation and retained history

The [preceding baseline attempt](2026-09-04-b2e0c2f1-controlled-baseline.md) is
invalid: it contains a long hidden/no-frame interval and diagnostic/reactivation
interventions. The display-awake handling and run continuity differ too. Five
components with unchanged source also changed timing. **The large overall
before/after difference is not an isolated causal measurement of the two code
optimizations.** This record accepts only this observed run under the original
engineering defaults; repeated-run stability, component-exclusive memory/leaks,
and other platforms/devices remain unassessed.

The older [P1/P2 8/8 pass at 87299572](2026-09-04-87299572-native-profile.md)
remains historical evidence; P1/P2 was not rerun in this capture. Earlier failures,
original budgets and the performance registry are unchanged. No combined
all-platform release acceptance is granted here.

Raw directory: `/tmp/beautiful-p3-candidate-f15f27eb/packages/beautiful_ai_ui_catalog/build/p3-profile/20260904-f15f27eb-display-awake`.
All 24 original files remain intact and hashed in the JSON companion.
