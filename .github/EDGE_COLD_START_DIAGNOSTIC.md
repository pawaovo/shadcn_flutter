# Edge cold startup diagnostic

This manual diagnostic executes exactly three independent Edge sessions on one
Ubuntu 24.04 runner. Each starts the existing `flutter_edge_webdriver.py` adapter,
its real msedgedriver, and a fresh browser process and temporary profile. A failed
case is retained and makes the overall command fail even if subsequent cases
succeed. An unverified process cleanup stops further cases; they remain explicitly
`not_run`. The output directory must be new.

The initial baseline is **without Flutter compile load**. It isolates the five
startup requests captured from Flutter 3.47 before its Dart test driver starts.
It does not compile or navigate Catalog, recreate concurrent compiler activity,
reboot the runner, flush filesystem caches, or claim a full browser journey pass.
Three passing sessions mean only that this baseline did not reproduce the failure.
The optional preread condition below is the only additional experimental variable.
The workflow never automatically repeats until success or adds compiler/CPU load.

The older `codex/edge-152-diagnostic` experiment at `d97a2e12` used three separate
runners, explicitly installed distribution hashes for Edge 152, and ran complete
Catalog journeys. This baseline adds startup process/resource observation while
using the input runner's current installed-browser discovery. It neither modifies
nor supersedes those older artifacts (run `33761035001`).

## Execute

On an available Linux host with installed matching Edge/driver:

```sh
python3 -B .github/scripts/probe_edge_cold_start.py --output artifacts/edge-cold-start-new-run
```

`microsoft-edge` is discovered through PATH; `msedgedriver` first uses the existing
`EDGEWEBDRIVER` directory and otherwise PATH, exactly as the input runner does.
Optional `--binary` and `--driver` select explicit installed executables. There is
no installation, automatic browser update, Docker requirement, or SDK modification.
Ports 4444 and 4445 must be unused. The process supervisor owns its new process
group and verifies cleanup, including observed descendants that outlive the group.

The manual workflow is
[`beautiful_ai_ui_edge_cold_start.yml`](workflows/beautiful_ai_ui_edge_cold_start.yml).
Dispatch it at the branch containing that workflow, supplying the exact committed
source SHA. The workflow validates the 40-character SHA and verifies its checkout:

```sh
DIAGNOSTIC_SOURCE_SHA=$(git rev-parse HEAD)
gh workflow run beautiful_ai_ui_edge_cold_start.yml -R pawaovo/shadcn_flutter --ref product/main \
  -f source_sha="$DIAGNOSTIC_SOURCE_SHA"
```

The owner dispatches this only after review and commit. The workflow is manual
only and does not replace or relax any existing acceptance workflow. Its 50-minute
outer step bound leaves five minutes for artifact upload within the job bound.
Cancellation/outer timeout is failure or incomplete evidence, never a passing case.

## One-variable executable preread experiment

The unmodified baseline at source `d1c44cce0bede4355bb4456a1280af34dce00ec5`,
[run 33838225726](https://github.com/pawaovo/shadcn_flutter/actions/runs/33838225726),
completed all three sessions. Session creation took 32.634 s, 0.262 s and 0.278 s;
all original geometry commands and cleanup passed. In session 1, the actual
browser PID was sampled 32 times: 26 observations had state `D` and wait channel
`folio_wait_bit_common`. I/O pressure cumulative `some` increased about 25.15 s,
while its main-thread scheduler queue delay was about 1.53 ms. These observations
support investigating executable page/I/O waits in that slow successful startup.
They do not establish the cause of the earlier 300-second navigation timeout.
The baseline artifacts and every earlier failure remain unchanged.

The experimental command adds one sequential read of the actual browser ELF,
**once before all three startups**:

```sh
python3 -B .github/scripts/probe_edge_cold_start.py \
  --output artifacts/edge-preread-new-run \
  --preread-browser-executable /opt/microsoft/msedge/msedge
```

This path was observed through the baseline browser's `/proc/{pid}/exe`; it is not
the `/usr/bin/microsoft-edge` shell launcher. The diagnostic rejects a shell/non-ELF
target and records elapsed time, bytes and SHA-256 from the same single sequential
pass in `preread.json`. Each later session must bind that path to its actual
`goog:processID` in the post-startup `/proc` snapshot. A different or unavailable
actual browser identity makes the experiment fail. Normal post-session executable
hashing must also match the bytes read before startup. No executable is modified.

To explicitly select this condition for one manual run, append
`-f preread_browser=true` to the dispatch command above. The default is false:
omitting it preserves the baseline with no preread. Installed-version checks,
three independent profiles, request sequence/options, 300-second navigation
deadline, 900-second transport watchdog, observations and cleanup remain the same.
There is no automatic control rerun or retry of a failed case.

Compare the first session's page/I/O waiting and startup time, plus all failures,
against the retained baseline; report preread cost separately and alongside total
elapsed time rather than hiding it as setup. The pre-read intentionally changes
file-cache residency, not browser settings or the actual startup command. The
read is a diagnostic intervention, not a proposed production repair. Differences
between fresh CI runners and a potentially updated browser distribution limit
causal conclusions; compare recorded versions and executable hashes first. Three
successful preread sessions still do not resolve the original 300-second failure.

The pinned Flutter 3.47 source also rules out invented initial compile concurrency:
`DriveCommand` awaits `driverService.start` before `startTest`; the web runner
awaits `_updateDevFS`, synchronously caches the dill, then completes its app-started
signal. Only then is the Edge session created. The resident Flutter tool/server
can remain alive, but this does not mean the initial compile overlaps startup.

## Preserved protocol and evidence

The ordinary Edge shared journey and input suites also enable the adapter's
optional `--resources` observer. This captures the actual full Flutter-drive
startup, rather than substituting the standalone replay. It reads Linux `/proc`,
pressure, memory and shared-memory metadata at 1 Hz; it does not issue browser
commands, pre-read executables, change options/deadlines or retry an action.

The observer binds the real driver PID **and its start time**, then follows its
descendants. The adapter can share its shell's process group, so group membership
alone would wrongly include Flutter or sibling processes. Only the bound tree's
command lines are read. The original standalone experiment retains its existing
dedicated-group scope and cleanup verification. Stopping the adapter observer
only stops observation; process ownership and cleanup remain with the original
supervisor. Each flushed `resources.jsonl` sample survives an interrupted run;
`observation.json` records collection status when shutdown permits. An unavailable
observer is recorded separately and cannot overwrite a browser's result.

This additional evidence is prepared for the next full journey execution. The
PID-reuse/sibling boundary and a real Linux child were verified in two focused
tests; that is neither an Edge reproduction nor a repair of the 300-second error.

The harness sends `GET /status`, the captured legacy `POST /session`,
`GET /session/{id}/window`, `POST /window/rect {x:0,y:0}`, then
`POST /window/rect {width:1440,height:900}` in that order. The unchanged adapter
normalizes the exact Flutter legacy capability shape to the existing Edge options.
No extra browser observation is inserted between these commands. The returned
`pageLoadStrategy` must be `normal` and `timeouts.pageLoad` must be `300000`.
No `setTimeouts` request is made. The request transport watchdog remains 900 seconds;
the EdgeDriver navigation deadline remains 300 seconds. Original HTTP errors and
response bodies are written verbatim and fail the case. Returned geometry is also
checked; failed actions are never retried.

Each session directory retains:

- `report.json`: outcome, phase, real session identity, original failure and cleanup.
- `requests.jsonl`: exact request bodies, response status/body and elapsed time.
- `adapter.log`, `msedgedriver.log`, `browser-identity.json`, and adapter failure
  diagnostics using the existing unmodified adapter behavior.
- `resources.jsonl`: 1 Hz process identities, parent/group relationships, CPU ticks,
  RSS, scheduler counters/wait channel, observed appearance/disappearance,
  load/memory/pressure, process cgroup paths and visible root cgroup counters,
  and `/dev/shm` capacity. Sampling is bounded to 3000 records per case. Missing
  kernel metrics are explicit; process disappearance does not establish an exit
  code. Short-lived processes between samples may be missed. Original driver logs
  remain the source for reported child startup termination and service crashes.
- `post-startup-processes.json`: an additional `/proc` observation after the five
  startup requests (or their failure), before browser quit, so fast successful
  sessions do not escape executable identity collection between 1 Hz samples.

`provenance.json` binds source, relevant scripts, runner image, configured executable
paths and versions. It also hashes actual executable paths observed through
`/proc/{pid}/exe`, after the sessions finish so hashing does not add startup load.
In preread mode the one intentional earlier pass is timed and hashed separately;
the baseline never performs that pass.
Missing executable files are recorded, not replaced with guessed identities.
`summary.json` retains all three planned cases and every observed failure.

After an original failure is persisted, the harness may request a read-only CDP
`Runtime.evaluate` through EdgeDriver's vendor endpoint, bounded to eight seconds,
to record `document.readyState`, URL and time origin. This happens **after** the
driver may have called `Page.stopLoading`; it cannot establish the page state
before the timeout. A diagnostic failure never changes the original result.
Session deletion has its own eight-second cleanup observation bound, followed by
owned process group termination and verification.

The report extracts counts and original log lines for initial loading events,
pending-navigation polling and actual window-bound commands. Resource pressure
or child service failure correlated with a stalled initial document supports a
startup-health hypothesis; a responsive document with a stuck navigation tracker
supports investigating driver event tracking. Neither is automatically labelled
the cause by the script. Exact timing and complete logs remain reviewable.

## Local regression boundary

```sh
python3 -B -m unittest discover -s .github/scripts -p 'test_probe_edge_cold_start.py' -v
```

These tests use the real adapter and HTTP client with a clearly synthetic upstream.
They verify exact order/options, preservation of a 300-second renderer timeout
error, absence of later size requests after that error, rejection of changed
deadlines, failure retention across three cases, and stopping on unverified
cleanup. They do not reproduce a real Edge startup failure. Actual Linux runs are
required before claiming the cold-start bug is reproduced or repaired.
Additional preread regressions verify one sequential pass before all three cases,
shell rejection, binding to the browser PID rather than another process, and no
preread in baseline mode. They use a synthetic ELF-header file that is never run.
