# Reproducible native performance assessment

The performance runner now covers seven P3 workloads and eight representative
P1/P2 long-content workloads. An independent Python evaluator scores the raw
engine frame and process-memory samples against a versioned **engineering
default**. These defaults have not been approved as product budgets by the
user. A passing result is limited to the measured run and environment; it does
not grant all-platform release acceptance.

## Measurement basis and engineering defaults

Flutter recommends profile builds for performance inspection; debug-mode costs
are not representative. It describes the UI and raster threads as separate
stages of a rendering pipeline. Our frame interval is derived from the actual
recorded display refresh rate: `1,000,000 / Hz` microseconds (8.333… ms at the
observed 120 Hz). [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)

The raw `FrameTiming` arrays retain build, raster, total-span and vsync-overhead
durations independently. `totalSpan` runs from vsync start to raster finish;
it is neither the sum of the two execution costs nor proof of when a frame was
actually displayed. We report scheduling-inclusive total span separately and
never label its threshold crossings as observed dropped frames.
[Flutter FrameTiming API](https://api.flutter.dev/flutter/dart-ui/FrameTiming-class.html)

The exact machine-readable policy is
[`engineering_budget_v1.json`](engineering_budget_v1.json). The non-official
engineering choices below are fixed for this acceptance pass:

| Gate | Engineering default |
| --- | --- |
| Build p95 / raster p95 | Each at most one observed display interval |
| Frames with build **or** raster above one interval | At most 1% of captured frames |
| Maximum build / raster duration | Each at most two intervals |
| Total-span p95 | At most two intervals, assessed separately from throughput |
| Measured whole-process RSS sampled peak | At most 512 MiB |
| Positive measured last-minus-first RSS growth | At most 64 MiB per scenario |
| Minimum evidence | One warmup round, three measured rounds, 100 engine frames and 10 RSS samples per scenario |

Thresholds are inclusive, tested without rounding a fractional frame interval
upward. Percentiles use nearest rank. The maximum-duration gates intentionally
retain visible outlier risk even when p95 looks good; no warmup or mount frame
is relabeled after looking at the results.

RSS includes fixtures, Flutter, the engine and capture overhead. Trace results
are retained by `integration_test` across scenarios; later scenarios can inherit
this evidence cost. RSS sampled during interactions is kept separate from
post-trace lifecycle snapshots and the process-lifetime `maxRss` counter. The
tool always leaves component-memory and leak assessment `unassessed`. Retaining
paths and heap snapshots would be needed to distinguish a leak from expected
retention; a two-second unmount observation does not establish either.
[Flutter DevTools memory guidance](https://docs.flutter.dev/tools/devtools/memory)

## Workload scope

All sizes below are finite representative fixtures, not universal supported
maximums. Caller-owned data and public host callbacks are deterministic; no
network/model latency, physical keyboard or OS IME input is represented.

| Suite | Scenario | Dataset and verified work |
| --- | --- | --- |
| P3 | Prompt | 1,000 sources, keyboard wrap to the last source, exact 10,000-character edit/scroll/send |
| P3 | Diff | 500 records × 3 fields, 20-row pagination, inclusion toggles |
| P3 | Records | 1,000 records × 20 typed columns, two-axis scrolling, sorting, filtering and selection |
| P3 | Sidebar | 1,000 recents, scrolling, unique filtering and activation |
| P3 | Flowchart | Original node/edge dataset and real drag, keyboard move, pan and zoom |
| P3 | Insights | Four × 512-point series, pointer/keyboard inspection and complete text data access |
| P3 | Selection | 20,000-character native editor, actual pointer selection, host replacement and acceptance |
| P1 | Search | 1,000 entries; 12 unique queries plus a broad match, ten keyboard moves, last-result selection |
| P1 | Code | 1,000 lines, real host scrolling, exact full-source copy callback |
| P1 | Thinking | 200 completed steps, disclosure, scrolling and collapse |
| P2 | Streaming Text | 50 snapshots building an exact 20,000-character answer, scrolling and full-answer copy |
| P2 | Tool Chips | 1,000 output lines, disclosure, scrolling and collapse |
| P2 | Chat | 500 messages, transcript scrolling/latest, composer editing and send |
| P2 | Filter Table | 200 non-virtualized rows, scrolling, 66 completed results, restore all |
| P2 | Task Rows | 100 completed tasks × 10 details, scrolling and disclosure |

The eight P1/P2 additions were functionally exercised twice per fixture in
debug widget tests. Those tests validate the input scripts; their durations
are explicitly not profile-performance evidence. Loading, Recommendation,
Context, Approval and Fine Tune remain covered by behavioral/visual suites,
without a new isolated native performance claim for each static composite.

## Existing P3 capture assessment

The immutable `20260903T114308Z` capture remains attributed to source revision
`c2bde85dd5da7c33b0f7881234ae312f3be1826c`. Its 4,495 complete engine frames and
478 RSS samples were independently recomputed; every stored percentile and
sample count matched. Six of its seven VM traces have bounded retention, so
none of the following gates use the traces as if they were complete.

[`2026-09-03-engineering-budget-existing-p3.json`](2026-09-03-engineering-budget-existing-p3.json)
is a new assessment of that old capture, not a replacement or alteration of it.
All seven build and raster p95 values are below the 120 Hz interval, while four
scenarios fail a maximum or tail-frequency gate:

| Scenario | Failed engineering gate |
| --- | --- |
| Prompt | Build maximum 45.962 ms exceeds 16.667 ms |
| Diff | Build maximum 17.205 ms; build-or-raster over-interval fraction 7/497 = 1.40845% |
| Records | Build maximum 22.060 ms |
| Insights | Build maximum 45.395 ms |
| Sidebar, Flowchart, Selection | No failure under these engineering defaults |

All measured-process RSS gates pass for that capture; the highest sampled RSS
is 474.0625 MiB in Selection. The later process-lifetime maximum is 522.875 MiB,
after trace retrieval/retention. Both are retained, with different meanings.

The old step records have elapsed durations but no per-step epoch. Reconstructing
consecutive intervals leaves only 214 µs unassigned for Prompt, 127 µs for
Records, and 280 µs for Insights across each complete scenario. This narrowly
bounded inference associates the long Prompt builds with source filtering and
keyboard selection, Records with sorting, and Insights with text-data disclosure.
It does not alone prove which function consumed CPU. The current recorder adds
explicit step and round epoch boundaries so subsequent captures can establish
the operation association directly. The evaluator reports the ten slowest
frames by the larger of build/raster duration, with every actual step/round
interval overlapping each frame. Interval overlap identifies the exercised
operation; it still does not substitute for CPU stack attribution. Historical
captures without step epochs are marked `unavailable_pre_epoch_capture`.

A concrete defect exposed by the new Thinking fixture was fixed: hidden entry
animations previously kept ticking, and duration grew as `320 + 120 × index`
milliseconds, reaching 24.2 seconds at 200 entries. Hidden disclosure content
now mutes its tickers and the stagger is capped after the first three intervals.
The first three rows preserve their previous timing. A focused regression
checks a 200-item trace, two-second settle limits, access and keyboard activation
of the final row, and correct collapse state. This is a behavioral performance
repair; a native frame-budget result requires the new frozen-source capture.

## Run and assess

Run from the repository root. The runner keeps historical `p3_*` artifact names
for compatibility; `performance_suite` and exact expected scenario IDs
distinguish each suite. Default behavior remains the seven-scenario P3 suite.

```bash
P3_PERF_SUITE=p3 \
  packages/beautiful_ai_ui_catalog/tool/run_p3_profile.sh macos

P3_PERF_SUITE=p1p2 \
  packages/beautiful_ai_ui_catalog/tool/run_p3_profile.sh macos

# Optional single-process combined suite; RSS includes prior trace retention.
P3_PERF_SUITE=all \
  packages/beautiful_ai_ui_catalog/tool/run_p3_profile.sh macos
```

Keep the actual native window at least 1120 × 720 logical pixels, visible and
unchanged once measurement begins. Close unrelated benchmarks; freeze the
source and capture its hashes. Separate fresh processes for P3 and P1/P2 make
cross-suite trace retention explicit and keep both complete suites measurable.
During the preparation screen, activate the app, resize it if needed, and click
**Start native measurements**. The entire preparation has a 120-second limit,
including the one-second post-click stability interval. The gate requires the
actual `resumed` lifecycle, enabled frame scheduling, at least two completed
framework frames, and unchanged native size, DPR, and platform/framework
semantics flags. A click alone does not establish foreground or visibility.
The preparation record describes these observations; its frames are not timed
workload samples. Once the ready log appears, stop all native UI inspection and
interaction until the runner exits.

The recorder observes lifecycle and metrics callbacks throughout each sampling
window, and checks both semantics flags at the boundaries and with each 100ms
RSS sample. An observed change invalidates that workload even if the original
state later returns; affected frame and memory samples remain in the evidence.
Flutter exposes no separate public platform-semantics listener while the test
already holds a framework semantics handle, so platform flag changes between
those polling points are not claimed to be exhaustively observed.

Each runner invocation requires a new or empty output directory. It records
preflight failures in `runner_status.json` and `exit_code.txt`, so a failed
dependency step cannot inherit a previous run's success. The checked-in
`profile_source_snapshot.py` captures the listed runtime/build inputs after
dependency preparation and before the profile build, then repeats the capture
after the driver exits. `source_before.json`, `source_after.json`, and
`source_integrity.json` identify the exact input bytes; any change in their
manifest or git revision makes the runner fail without overwriting historical
evidence. External dependency source contents are represented by the lockfile;
this source manifest is not a hash of the entire developer machine.

Use the output directory printed by the runner:

```bash
python3 packages/beautiful_ai_ui_catalog/tool/assess_profile_budget.py \
  /absolute/path/to/run-directory --suite p1p2 \
  --output /absolute/path/to/assessment.json

python3 -B -W error::ResourceWarning -m unittest discover \
  -s packages/beautiful_ai_ui_catalog/tool -p 'test_profile_*.py'
```

Exit `0` means the observed-run engineering gates passed, `1` means a budget
failed, and `2` means the evidence is missing, inconsistent or insufficient.
Failures do not erase partial evidence. The real Dart finalizer requires the
correct target suite, every exact unique scenario ID, completed workload phase
and successful driver; duplicated IDs cannot pass by preserving a row count.
Its `complete` status describes capture completion only. Always run the
independent assessor afterward: it additionally validates the profile metadata,
raw artifacts, frame/RSS counts, summaries, epochs and evidence minima before
applying any budget.

Mobile physical devices, other desktop machines, browser profiling, real input,
assistive technology during profiling, heap retention and repeated-run stability
remain separate dimensions. This evaluator must not turn missing observations
into a release pass.
