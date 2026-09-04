# Interrupted controlled-baseline attempt at b2e0c2f1

**The complete run is invalid evidence, not a clean controlled baseline.** The
native driver and run both exited 1. The unchanged original assessor returns
exit 2, `invalid_evidence: report is not finalized complete`. Six workloads
finished; Records was invalidated by an actual lifecycle/frame-state change.
All **3,912 FrameTiming and 10,813 RSS samples** remain in the original raw files.

The [JSON companion](2026-09-04-b2e0c2f1-controlled-baseline.json) records the
original failures, exact sampling windows, all raw artifact hashes, and
independent recomputation. Its per-workload budget diagnostics use the original
`assess_scenario` function and unchanged engineering budget without changing any
input status. They do not override the invalid aggregate outcome.

| Workload | Frames / RSS | Build p95 / max (ms) | Raster p95 / max (ms) | Over interval | RSS peak (MiB) | Original-budget result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| `prompt_bar` | 659 / 91 | 8.578 / 84.097 | 17.172 / 85.595 | 122 / 659 | 183.969 | budget_fail |
| `diff_table` | 270 / 70 | 25.697 / 249.976 | 41.973 / 649.295 | 114 / 270 | 189.609 | budget_fail |
| `records_table` | 860 / 10368 | not assessed | not assessed | not assessed | not assessed | invalid environment |
| `sidebar_nav` | 687 / 64 | 1.404 / 14.367 | 4.578 / 35.432 | 12 / 687 | 196.734 | budget_fail |
| `flowchart` | 376 / 69 | 18.939 / 27.500 | 17.406 / 32.664 | 167 / 376 | 221.312 | budget_fail |
| `insight_cards` | 786 / 112 | 12.310 / 36.663 | 14.834 / 57.416 | 240 / 786 | 244.984 | budget_fail |
| `selection_actions` | 274 / 39 | 10.728 / 17.299 | 7.972 / 34.316 | 40 / 274 | 223.328 | budget_fail |

All six complete slices fail at least one frame gate. Their two measured-process
RSS gates pass, without establishing component memory cost or absence of leaks.
Records' raw distributions and 860 frames / 10,368 RSS samples are retained in
JSON and raw evidence, but are not treated as admissible budget results.

## Interruption and interventions

Times below are Asia/Shanghai, UTC+08:00; exact epochs and UTC are in JSON.
Records retains its entire sampling window **12:57:54.443–13:15:14.165**:

- **12:58:00.325:** native lifecycle became inactive.
- **12:58:00.794:** lifecycle became hidden and frames were disabled.
- During the stall, the root task inspected the VM and requested its timeline.
  `getStack` returned code 100, `Feature is disabled`, with `Debugger is disabled
  in AOT mode`; this is not a captured stack or a deadlock diagnosis. The original
  `getVMTimeline` response remains in `stalled-vm-timeline.json`.
- The operator reports CUA state inspection around **13:12**. Earlier AXRaise
  attempts did not restore frame progress. These CUA/AX observations are operator
  reports, not independently exported CUA traces in this directory.
- At **13:15:08**, the root task invoked the native Window menu's
  `makeKeyAndOrderFront`. Native callbacks at **13:15:08.908** recorded inactive
  and then resumed, with frames enabled. The remaining workloads then finished.

Sidebar, Flowchart, Insights and Selection were measured after reactivation.
Their own environment records are stable, but that does not make this interrupted
and actively diagnosed run a clean complete baseline. No interruption was cut
from the raw arrays, and no successful subset was relabeled as a complete pass.

## Source, host-side coverage and power setting

Both source inventories independently recompute to **305 files** at
`b2e0c2f1508bbf0e85eeb3b240a5c0dfa8f604da`, digest
`da3a8ead13884746abb0f6e283178d598969eb20cf82fdc570487bab76656aff`.
This verifies the recorded input scope; it is not a clean-worktree claim.

`host-top.log` contains **360 timestamp/CPU samples**, raw UTC
04:56:57–05:03:45, corresponding to **12:56:57–13:03:45** locally. It does not cover
the full Records interval or the post-13:15 workloads. No later CPU/GPU load or
contention is inferred from that sidecar. IINA was reported already paused, the
agent did not operate playback, and the global foreground query reported IINA;
no personal media filenames are reproduced or causal conclusion drawn.

A read-only `pmset -g custom` check confirms **AC `displaysleep = 10` minutes**.
No display-off event log corroborates what happened during this run. A configured
timeout alone is not evidence that display sleep caused the lifecycle transition.

Raw directory: `/tmp/beautiful-p3-baseline-b2e0c2f1/packages/beautiful_ai_ui_catalog/build/p3-profile/20260904-controlled-baseline`.
All 24 original files remain unchanged. Earlier failed runs, budgets and the
performance registry are untouched. The separate
[display-awake candidate](2026-09-04-f15f27eb-display-awake.md) is a new observation,
not a replacement for this invalid baseline.
