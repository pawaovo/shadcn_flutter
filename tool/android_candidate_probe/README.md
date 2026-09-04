# Android IME candidate probe

This independent instrumentation APK observes the catalog's existing Android
windows and permits one native touch on the exact candidate for one compiled
diagnostic stage. It targets its own package,
`dev.beautifulai.androidcandidateprobe`, and has no
Activity. Starting or finishing it does not start, restart, or finish the catalog.
It uses public SDK APIs and does not use AndroidX, an input connection, key events,
accessibility `ACTION_CLICK`, focus changes, or keyboard visibility controls.

The same APK supports only these fixed stage specifications:

| Stage | Required original draft | Exact native candidate | Required composing range | Selection |
| --- | --- | --- | --- | --- |
| `chat_send` | `Check cone inventory` | `inventory` | `[11,20]` | `20` |
| `prompt_command` | `/rest` | `rest` | `[1,5]` | `5` |
| `prompt_send` | `Prepare the seasonal restock` | `restock` | `[21,28]` | `28` |

These are strict experiment preconditions, not claims that a native candidate
has already been observed at every stage. A missing or ambiguous exact candidate
fails the stage. Host and Dart must validate the actual complete editing value,
focus, selection, composition, and original action before and after the native
touch. A different candidate, changed letter, or changed whitespace cannot be
accepted as equivalent. Native candidate presence alone does not prove the
actual Flutter draft matches the compiled specification.

The host enforces this stage order across fresh helper instances while preserving
the original Catalog PID and VM isolate. Each stage's live Dart hook generates a
new stage nonce; the host independently verifies that VM state before starting
the helper. Each instance still permits exactly one inspection attempt and one
tap attempt, with no reset API. The prior stage's native calls must be drained and
its original Enter/Send and assertions must finish before the next helper starts.

The deployment target is the existing API 35 emulator. The APK's minimum API is
34 because each inspection calls public `UiAutomation.clearCache()` before
reading all interactive windows.

## Build

Use an existing JDK and Android SDK; this script installs nothing:

```sh
python3 tool/android_candidate_probe/build.py \
  --sdk-root "$ANDROID_SDK_ROOT" \
  --source-sha "$SOURCE_SHA" \
  --output-dir "$NEW_OUTPUT_DIRECTORY"
```

`--build-tools-version 35.0.0` and `--java-home /path/to/jdk` are optional. The
output directory must not already exist. The build uses Android 35's `android.jar`,
`javac`, `aapt2`, `d8`, `zipalign`, and `apksigner`. Before compiling the Android
code, it compiles and runs the actual standalone `Protocol` and `StageSpec`
implementations with `tests/ProtocolTest.java` and `tests/StageSpecTest.java`.
Those tests cover HTTP framing, strict JSON and fields, the fixed stage table,
run/stage/source identity rejection, and the same monotonic gesture gate used by
the instrumentation.

Successful output contains `android-candidate-probe.apk`, `build-report.json`,
`build.log`, and intermediate files. The report is also printed as the only JSON
on stdout. It binds the APK hash, embedded source SHA, source file hashes, Android
jar hash, and tool paths/versions. A fresh debug signing key is created in a
temporary directory and deleted after signing or failure. Build diagnostics go
to stderr and `build.log`; failed builds retain their output directory.
Each build subprocess uses the repository acceptance runner's owned-process
launcher and verified process-group cleanup, even if its leader has already
exited. Version commands have a 30-second timeout; compilation, packaging,
signing, and protocol tests have a 120-second timeout each. Partial output,
original exit/error, and any cleanup failure remain in `build.log`. No command
is retried. The surrounding CI build step additionally bounds the whole build.

The process-ownership regression can run without Java or Android:

```sh
python3 -m unittest discover -s tool/android_candidate_probe/tests -p 'test_build.py'
```

## Start and connect

The host installs only the independent helper APK, then starts this component:

```sh
adb shell am instrument -w -r \
  -e nonce "$RUN_NONCE" \
  -e stage_nonce "$STAGE_NONCE" \
  -e stage_id "$STAGE_ID" \
  -e source_sha "$SOURCE_SHA" \
  dev.beautifulai.androidcandidateprobe/.ProbeInstrumentation
```

Run and stage nonces must contain 32–64 lowercase hexadecimal characters and
must differ. The stage ID must match the fixed table exactly. `source_sha` must
be the exact lowercase 40-character SHA compiled into the APK. Incorrect startup
arguments finish the helper before it obtains UI automation.

Instrumentation status `100` has these Bundle entries:

```text
ready=true
protocol_version=2
port=<random device loopback TCP port>
pid=<helper process PID>
nonce=<the supplied run nonce>
run_nonce=<the same run nonce, explicitly named in responses>
stage_nonce=<the fresh stage nonce>
stage_id=<the fixed stage ID>
source_sha=<compiled source SHA>
device_elapsed_ms=<SystemClock.elapsedRealtime()>
expected_text, candidate_text, composing_base, composing_extent, selection_offset
event_log=files/probe-events-<stage_id>-<stage_nonce>.jsonl
```

The host should verify the reported PID, both nonces, stage/specification,
source SHA, APK/report hash, and helper process identity before creating
`adb forward tcp:0 tcp:<device-port>`.
No helper Activity should be launched. The server binds only `127.0.0.1` and
accepts at most 16 requests during its maximum 600-second lifetime.

## HTTP contract

All endpoints accept a single HTTP/1.1 `POST`, `Content-Type: application/json`,
and an explicit `Content-Length`. The body is a flat JSON object of at most five
unescaped ASCII string fields. Duplicate headers/JSON keys, transfer/content
encodings, comments,
single quotes, trailing data, queries, and unknown fields are rejected. Header
bytes are limited to 8192, lines to 2048, headers to 32, and body bytes to 4096.
Sockets have a one-second read timeout; the overall lifetime also bounds reads.

Every request requires `nonce`, `stage_nonce`, `stage_id`, and `source_sha`.
Every response includes `ok`, `operation`, `protocol_version`, `source_sha`,
`nonce`, `run_nonce`, `stage_nonce`, `stage_id`, `device_elapsed_ms`, and the fixed
stage specification fields from readiness. `run_nonce` is a response alias of
`nonce`, not an extra request field. The text/range fields are compiled stage
metadata, not observations of the Flutter editor. Errors add
`error: {code, message}` and bounded `diagnostics`.
Full response and final JSON records are retained in the helper's private
readiness-reported `event_log` path, retrievable with `adb exec-out run-as
dev.beautifulai.androidcandidateprobe cat "$EVENT_LOG"`. Each stage's file is
distinct so a later helper cannot overwrite its evidence. Logcat also
receives records, but large node dumps may exceed logcat's line limit; preserve
the private JSONL file and HTTP responses as the complete artifacts.

`POST /inspect`:

```json
{"nonce":"<run nonce>","stage_nonce":"<stage nonce>","stage_id":"chat_send","source_sha":"<compiled SHA>"}
```

Only one inspection attempt is permitted. It verifies exactly one focused
application window from `dev.beautifulai.beautiful_ai_ui_catalog`, exactly one
visible IME window matching `Settings.Secure.DEFAULT_INPUT_METHOD`, and exactly
one visible, enabled candidate whose text or content description exactly matches
the selected stage's candidate. The matching node must be clickable or have a
visible, enabled
clickable ancestor in the same IME window/package. The target rectangle must be
inside the IME window and unobscured by a higher-layer window. Breadth-first tree
inspection is bounded to 4096 nodes and depth 32; incomplete traversal fails.

Success adds:

```text
candidate_id=<random 32-character lowercase hexadecimal ticket>
inspect_started_device_ms=<monotonic time before inspection>
expires_at_device_ms=<inspection start + 2000, capped by helper lifetime>
ime_package, ime_component, ime_window_id, focused_app_package
bounds={left,top,right,bottom}
windows=[bounded window summaries]
nodes=[bounded raw node summaries]
```

`POST /tap`:

```json
{"nonce":"<run nonce>","stage_nonce":"<stage nonce>","stage_id":"chat_send","source_sha":"<compiled SHA>","candidate_id":"<ticket from inspect>"}
```

Only one tap attempt is permitted per helper instance, including failed attempts.
The ticket stores the exact stage specification, stage/run nonces, and compiled
source SHA in addition to its random ID and deadline. The helper clears
the accessibility cache and re-inspects everything. The IME component, window
ID, unique exact candidate, and target rectangle must still match. At least
150 ms must remain before DOWN. The shared `Protocol.GestureGate` consumes the
ticket before submitting DOWN; it cannot authorize another DOWN.

The helper submits one touchscreen `MotionEvent.ACTION_DOWN`, then targets UP
50 ms after the recorded DOWN invocation time. If the deadline is reached before
UP, only CANCEL is submitted. A rejected or throwing partially submitted gesture
also gets CANCEL. A pre-DOWN rejection submits no input event. There is no tap
retry. Success adds `used_candidate_id`, `expires_at_device_ms`, `injected_down`,
`injected_up`, `cancelled`, `down_dispatch_attempted`, and these device times:

```text
down_device_elapsed_ms
down_injection_returned_device_elapsed_ms
up_device_elapsed_ms
up_injection_returned_device_elapsed_ms
cancel_device_elapsed_ms  # present only when cancellation was attempted
cancel_injection_returned_device_elapsed_ms
```

The first pair for each event brackets the public `UiAutomation.injectInputEvent`
call. These are invocation/return timestamps, not proof of the precise Android
delivery time. Public Android injection can synchronize window transactions
internally, so the monotonic gate proves when the helper authorizes submission;
it cannot impose an atomic deadline on Android's downstream dispatch. The host
must retain the independent Dart lease and verify the actual unchanged text,
cleared composing region, original action readiness, and single original
Enter/Send with its complete host assertions. Framework
`InputConnection#commitText` trace slices provide dispatch-attempt evidence only.

`POST /stop` accepts only the four request identity fields. It acknowledges the
request, closes the
listener, and calls `Instrumentation.finish` for the helper's own process. The
server handles requests serially: it cannot acknowledge `/stop` until the
current `/tap` call, including any cancellation, has returned. If native injection
never returns, `/stop` cannot return success; the outer owner must treat drain as
unverified and tear down its disposable emulator. The helper does not invent an
Android input-cancellation API to release a blocked call. The
final instrumentation Bundle contains a compact summary and the JSONL artifact
path; large node diagnostics remain in the JSONL file.

## Validation limits

The standalone tests exercise production parser and gesture decisions without
an emulator. They do not emulate an IME or demonstrate native candidate delivery.
Build, actual window discovery, candidate touch, input-connection traces, and the
Flutter state transition still require the pinned Android CI job.
