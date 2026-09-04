# Android IME candidate probe

This independent instrumentation APK observes the catalog's existing Android
windows and permits one native touch on the exact `inventory` IME candidate. It
targets its own package, `dev.beautifulai.androidcandidateprobe`, and has no
Activity. Starting or finishing it does not start, restart, or finish the catalog.
It uses public SDK APIs and does not use AndroidX, an input connection, key events,
accessibility `ACTION_CLICK`, focus changes, or keyboard visibility controls.

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
code, it compiles and runs the actual standalone `Protocol` implementation with
`tests/ProtocolTest.java`. Those tests cover HTTP framing, strict JSON, and the
same monotonic gesture gate used by the instrumentation.

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
  -e nonce "$NONCE" \
  -e source_sha "$SOURCE_SHA" \
  dev.beautifulai.androidcandidateprobe/.ProbeInstrumentation
```

The nonce must contain 32–128 hexadecimal characters. `source_sha` must be the
exact lowercase 40-character SHA compiled into the APK. Incorrect startup
arguments finish the helper before it obtains UI automation.

Instrumentation status `100` has these Bundle entries:

```text
ready=true
protocol_version=1
port=<random device loopback TCP port>
pid=<helper process PID>
nonce=<the supplied nonce>
source_sha=<compiled source SHA>
device_elapsed_ms=<SystemClock.elapsedRealtime()>
event_log=files/probe-events.jsonl
```

The host should verify the reported PID, nonce, source SHA, APK/report hash, and
helper process identity before creating `adb forward tcp:0 tcp:<device-port>`.
No helper Activity should be launched. The server binds only `127.0.0.1` and
accepts at most 16 requests during its maximum 600-second lifetime.

## HTTP contract

All endpoints accept a single HTTP/1.1 `POST`, `Content-Type: application/json`,
and an explicit `Content-Length`. The body is a flat JSON object of unescaped
ASCII strings. Duplicate headers/JSON keys, transfer/content encodings, comments,
single quotes, trailing data, queries, and unknown fields are rejected. Header
bytes are limited to 8192, lines to 2048, headers to 32, and body bytes to 4096.
Sockets have a one-second read timeout; the overall lifetime also bounds reads.

Every response includes `ok`, `operation`, `protocol_version`, `source_sha`, and
`device_elapsed_ms`. Errors add `error: {code, message}` and bounded `diagnostics`.
Full response and final JSON records are retained in the helper's private
`files/probe-events.jsonl`, retrievable with `adb exec-out run-as
dev.beautifulai.androidcandidateprobe cat files/probe-events.jsonl`. Logcat also
receives records, but large node dumps may exceed logcat's line limit; preserve
the private JSONL file and HTTP responses as the complete artifacts.

`POST /inspect`:

```json
{"nonce":"<hexadecimal nonce>"}
```

Only one inspection attempt is permitted. It verifies exactly one focused
application window from `dev.beautifulai.beautiful_ai_ui_catalog`, exactly one
visible IME window matching `Settings.Secure.DEFAULT_INPUT_METHOD`, and exactly
one visible, enabled candidate whose text or content description is exactly
`inventory`. The matching node must be clickable or have a visible, enabled
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
{"nonce":"<hexadecimal nonce>","candidate_id":"<ticket from inspect>"}
```

Only one tap attempt is permitted, including failed attempts. The helper clears
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
cleared composing region, enabled Send button, and single submission. Framework
`InputConnection#commitText` trace slices provide dispatch-attempt evidence only.

`POST /stop` accepts only the nonce. It acknowledges the request, closes the
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
