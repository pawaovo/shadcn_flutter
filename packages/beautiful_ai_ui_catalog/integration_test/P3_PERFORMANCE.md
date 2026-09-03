# P3 native profile workload protocol

This target records real engine frame timings and process memory while the
seven P3 components execute their approved bounded workloads. It is separate
from the normal Catalog journey and does not modify the Catalog application.
A completed run is evidence for its recorded device, viewport, renderer
configuration, Flutter revision and profile build only. It does not by itself
approve every platform or define a performance budget.

## Run on the current Mac

From the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  packages/beautiful_ai_ui_catalog/tool/run_p3_profile.sh macos
```

The script uses `/opt/homebrew/bin/mise exec -- flutter` by default. Set
`P3_MISE_BIN` to another absolute `mise` executable when necessary. Set
`P3_PERF_OUTPUT_DIR` to choose the evidence directory; the default is a new UTC
run directory under `packages/beautiful_ai_ui_catalog/build/p3-profile/`.
No Git commit, push or CI configuration change is performed.

The native macOS runner initially opens an 800×600 window. **Resize the actual
window to at least 1120×720 logical pixels within two minutes of the waiting
screen.** The suite starts automatically when it observes that size. Keep the
window visible, keep the viewport fixed and stop interacting until completion.
The minimum ensures that Records Table renders its grid and Flowchart renders
its canvas. No `setSurfaceSize`, fake MediaQuery size, offscreen oversized
viewport or screenshot scaling is used in the native evidence target.
Window preparation runs in `setUpAll`, before the widget-test SemanticsHandle
baseline is established. Native accessibility inspection can enable a
platform-owned handle; doing that during a test would be reported as a leak.
The regular end-of-test handle and ticker verification remains enabled.
`P3_PROFILE_VIEWPORT_READY` marks the end of window preparation.

Coordinate this run with other desktop work and native builds. The normal
seven-workload suite takes a few minutes after the first build, including warmup
and engine timing flushes. Native preparation may take longer. Do not run it
concurrently with another performance suite.

The script forwards additional arguments without shell re-parsing. For example,
to request Impeller explicitly and identify that request in the report:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  packages/beautiful_ai_ui_catalog/tool/run_p3_profile.sh macos \
  --enable-impeller --dart-define=P3_RENDERER_REQUESTED=Impeller
```

A requested backend is not an observed backend. Flutter's public runtime API
does not report the active renderer. The driver preserves any exact
`Using the ... rendering backend` engine announcement from `launch.log`; when
none is present, renderer verification remains explicitly unavailable. Retain
and inspect the full launch command and engine log when accepting renderer
specific evidence.

For direct invocation from the Catalog directory:

```sh
p3_output="$PWD/build/p3-profile/direct-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$p3_output"
if P3_PERF_OUTPUT_DIR="$p3_output" \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /opt/homebrew/bin/mise exec -- flutter drive -d macos --profile --no-dds \
    --driver=test_driver/p3_performance_driver.dart \
    --target=integration_test/p3_performance_test.dart; then
  p3_driver_status=0
else
  p3_driver_status=$?
fi
printf '%s\n' "$p3_driver_status" > "$p3_output/driver_exit_code.txt"
/opt/homebrew/bin/mise exec -- dart run \
  test_driver/p3_performance_driver.dart --finalize \
  "$p3_output" "$p3_driver_status"
```

Direct invocation still writes the measured JSON files but does not supply the
script's `flutter_version.json`, `launch_command.txt`, `launch.log` or
`exit_code.txt`; save their equivalents before accepting a direct run as
reproducible release evidence. `--no-dds` lets `integration_test.traceAction`
connect to the application's local VM service for profiling. This harness
imports `dart:io` and is a native target, not a Web benchmark.
The explicit `--finalize` step above is required: without it, a
`workloads_complete` JSON report means only that workload bodies completed and
is **not a confirmed successful test run**. The finalizer preserves that phase
status and uses the captured driver exit code, including teardown failure, to
write final `complete` or `failed`; it exits nonzero for an invalid run.

The macOS Debug/Profile entitlement includes `com.apple.security.network.client`
so the profile process can connect to its own local VM-service websocket.
The Release entitlement is unchanged. The first attempted run exposed this
missing profile entitlement and was retained as failed evidence.

## Workloads and sampling

The dataset shapes come from `docs/beautiful-ui/p3_contracts.md`:

| Component | Dataset | Measured interactions |
| --- | --- | --- |
| Prompt Bar | 1,000 sources; 10,000 UTF-16 characters | Filter, keyboard wrap/accept, long edit, editor scroll, exact send callback |
| Diff Table | 500 records × 3 fields; 20 rows per page | Toggle inclusion, scroll, paginate, toggle another page and return |
| Records Table | 1,000 rows × 20 populated typed columns | Vertical/horizontal scrolling, numeric sort, filter, row selection |
| Sidebar Nav | 1,000 recent items; expanded 288dp lane | Lazy list scroll, unique query, recent activation, query clear |
| Flowchart | 24 nodes and 48 DAG edges | Accepted keyboard/drag edits, connector painting, pan and zoom |
| Insight Cards | 4 series × 512 observations | Pointer/keyboard inspection; disclose, scroll and hide 512 textual rows |
| Selection Actions | 20,000 UTF-16 characters | Native editor scroll, mouse selection, request, host acceptance of an equal-length replacement |

Each workload is prepared and mounted separately. Preparation and mount wall
time and RSS snapshots are recorded separately from interaction frames. One
complete interaction round warms the mounted component. Three rounds are then
measured by default; `--dart-define=P3_MEASURED_ROUNDS=N` permits 1–20 rounds.
The selected count is recorded in each result. The same stateful workload must
complete repeated rounds, so warmup cannot silently consume a one-shot action.

During measured rounds:

- `SchedulerBinding.addTimingsCallback` captures actual engine `FrameTiming`.
  Raw build, raster, total-span and vsync-overhead microseconds, frame numbers,
  raster-finish wall timestamps and engine raster-cache byte counters are saved.
- `IntegrationTestWidgetsFlutterBinding.traceAction` records Dart, Embedder and
  GC timeline streams. Each workload gets its own raw timeline file.
  VM timeline storage is a bounded ring buffer; long/high-event workloads can
  overwrite earlier events. Retain event counts and the returned timeline time
  extent when assessing trace coverage. The independent FrameTiming arrays
  remain the source of the reported frame distributions, including when the
  diagnostic VM trace covers only part of the action interval.
- Two-second idle periods flush batched engine timing callbacks before and
  after recording. Only frames whose `rasterFinishWallTime` lies inside the
  recorded wall-clock interval enter the summary. Received, selected and
  excluded frame counts are all reported. A zero-frame workload fails.
- `ProcessInfo.currentRss` and `ProcessInfo.maxRss` are sampled before, after and
  every 100ms during interactions. `rss_observed_peak_bytes` is the largest
  sampled current RSS. Sampling can miss shorter peaks. `maxRss` is the peak
  since process launch, not a resettable component-level peak.
- Each scripted interaction has its own wall duration, including input,
  scrolling/reveal and settling. These durations are never called frame times.
  Summary frame percentiles use the nearest-rank method; raw samples allow
  independent recalculation.

The protocol uses actual native view dimensions, normal text scale and platform
accessibility settings, a light theme and system motion. It records those values
rather than claiming a universal device configuration. The native integration
binding uses fully-live frames. Host-generated fixture values and synchronous
callbacks do not represent network, model, disk or business service latency.

Input is explicitly a **programmatic Flutter workload**: text changes go through
the public `EditableTextState.userUpdateTextEditingValue` path, including input
formatting and change callbacks. Arrow/Enter events use Flutter's simulator
with explicit physical-key mappings because debug-name key inference is absent
in profile builds. Pointer drags exercise the rendered selection/scroll/drag
surfaces. This is not an OS IME, physical keyboard, screen-reader, or physical
touch-device acceptance test. The first failed native run also exposed the
debug-only unregistered text-client shortcut used by `tester.enterText`; that
shortcut is not used in the corrected profile target.

RSS includes the entire process: harness, fixture snapshots, Flutter engine,
VM, traces, caches and rendered UI. The fixture object is retained while the
post-unmount snapshot is taken; no GC is forced. These samples cannot establish
a per-component allocation cost or memory leak. Instrumentation and RSS
sampling also add overhead. Compare runs only when device, workload, mode,
viewport, toolchain and instrumentation match.

## Output and acceptance

The driver writes partial evidence even if an interaction fails. Check
`status` and every scenario before interpreting timings.
The script then finalizes the report with the actual integration-driver exit
code. All seven workloads plus test teardown must succeed for the top-level
status to become `complete`. Direct invocation leaves `workloads_complete`
until the caller also verifies the final driver result; it does not silently
promote body-only completion past a failing teardown.

| File | Contents |
| --- | --- |
| `p3_performance.json` | Status, dataset shapes, observed configuration, preparation/mount wall time, frame percentiles, interaction step durations, memory snapshots, callback outcomes and failure details |
| `p3_frame_samples.json` | Every included engine frame sample, grouped by workload |
| `p3_memory_samples.json` | Periodic and boundary process-memory observations |
| `p3_trace_*.timeline.json` | Original VM timelines, suitable for a trace viewer |
| `launcher_metadata.json` | Flutter machine version when captured, exact command, host hardware/OS context, local Xcode selection and any renderer announcement evidence |
| `flutter_version.json` | `flutter --version --machine`, captured before the run |
| `launch_command.txt`, `launch.log`, `driver_exit_code.txt`, `exit_code.txt` | Exact launch, complete native build/runtime log, driver exit status and final script exit status |

A successful run requires the real interactions and data checks to complete and
at least one native engine frame for every workload. No arbitrary millisecond,
FPS or memory limit is introduced. Agree on product budgets separately, inspect
the distributions and traces, and repeat representative runs before asserting a
platform performance guarantee. A failed or partial run must remain labeled as
such; its timings are not accepted evidence for the omitted interactions.

Retain the full output directory locally. When adding compact evidence to the
repository, include the summary, selected raw data or their checksums, toolchain
and device context, source revision/worktree status, and any unresolved gates.
Do not silently replace an earlier accepted measurement with a later run.

## Functional validation of the harness

These checks do not launch a native app or generate performance evidence:

```sh
cd packages/beautiful_ai_ui_catalog
/opt/homebrew/bin/mise exec -- flutter test --no-pub \
  test/p3_performance_workloads_smoke_test.dart
/opt/homebrew/bin/mise exec -- dart analyze \
  integration_test/p3_performance_test.dart \
  integration_test/support/p3_performance_measurement.dart \
  integration_test/support/p3_performance_workloads.dart \
  test_driver/p3_performance_driver.dart \
  test/p3_performance_workloads_smoke_test.dart
```

The smoke test runs two functional rounds per fixture under the widget-test
binding to catch broken finders, lost state and invalid callback assumptions.
Its synthetic debug viewport and timings are deliberately excluded from the
native profile report.
