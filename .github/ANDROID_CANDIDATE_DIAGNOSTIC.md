# Android native candidate diagnostic

This manual-only workflow investigates the retained Android journey failure
where composition appears over `inventory` before Send. The new native trace
is intended to identify the input-method calls behind that transition. The
original main Android job is unchanged. The independent target wraps and runs
the **entire original Catalog journey**, adding one explicitly enabled native
candidate step before its existing single Chat Send. It does not replace the
original failed result or constitute human Chinese-IME acceptance.

Dispatch `beautiful_ai_ui_android_candidate.yml` with an exact 40-character
`source_sha` containing these files. The workflow checks out and verifies that
commit, uses Flutter 3.47.0 and a freshly created API 35 x86_64 emulator, compiles
a fresh helper APK, and runs the target once. No physical device, existing local
emulator or already-installed Catalog/helper is accepted by the supervisor.
All build, driver and native failures remain failures; there is no retry path.

The target is `integration_test/catalog_android_candidate_test.dart`. Its
compile-time `CATALOG_ANDROID_CANDIDATE` flag defaults to false in the shared
test helper. The original journey's text, disclosure operations, clipboard,
single Send and host assertions remain present. The host driver uses the public
VM service extension `ext.beautiful.androidCandidate`; `requestData` remains the
authority for the original integration test's final result.

At the candidate stage the actual editor must contain exactly
`Check cone inventory`, with selection `[20,20]`, composing `[11,20]`, primary
focus, a visible keyboard and a disabled Send. The independent native helper
targets **its own instrumentation package**, creates no Activity, and does not
restart Catalog. It reads the current IME identity and all accessible windows,
then requires one visible, enabled, unobscured candidate whose text or accessible
description is exactly `inventory`. Only that candidate can receive one native
touch; no fallback key, alternate word, whitespace normalization, controller
write, composition clear, focus move or keyboard hide is used.

The host binds VM PID, app process start time, nonce, source SHA and the actual
candidate ticket. Immediately before requesting the native action it rechecks
the live VM stage and complete editor state. The helper independently rechecks
the current focused application, IME identity, candidate and bounds. Its earlier
two-second monotonic ticket prevents an expired **invocation**, and is consumed
before DOWN. If the guard expires before UP, the helper requests CANCEL instead
of a business UP; it never retries the touch.

Android's public injection API can wait inside the call. Invocation timestamps
are therefore not claimed as OS delivery deadlines, and an HTTP timeout is not
called cancellation. Dart keeps the fixture mounted while native drain is
unconfirmed, rejects Send after expiry/abort, and accepts a cleanup-only drain
acknowledgment without restoring success. The helper serves `/stop` serially
after any `/tap`; a completed stop response is a real drain barrier. If that
cannot be observed, the attempt fails with unverified drain and the workflow's
owned emulator is torn down before any later run. This isolation is required.

After the actual native candidate response, Dart must observe the unchanged
full text, empty composition, retained focus and enabled Send. It then reaches
the original send helper. A diagnostic-only synchronous activation guard checks
the live widget/controller/semantics again immediately before the existing
single tap, so reveal-time abort or re-composition cannot become Send. The
default helper has no extra wait or action. A final successful driver response
requires all original P1/P2/P3 assertions, one native tap and verified drain.

The supervisor captures stock Android `atrace` category `input`, preserving the
raw trace and owned-app `InputConnection#…` slices. Such a slice identifies an
Android dispatch attempt; it does not by itself prove an accepted callback or
exact causation. Native action records and the actual Dart editing/host results
remain separate required evidence. Ordinary `ime tracing` is not substituted
for these mutator dispatch slices.

Relevant tracked source files, package manifests, lockfile and resolved package
configuration are hashed before and after the run. Full workspace status is
also recorded; unrelated generated workspace targets are not mistaken for an
Android source mutation. The helper build binds its APK, Java sources, Android
jar and tool hashes. Reports include the exact source commit and all command
exits; generated artifacts must use a fresh output directory.

The uploaded artifact includes:

- `helper-build/`: signed helper APK, build report, actual JVM protocol test and
  compiler logs. The temporary signing key is removed after building.
- `run/summary.json`, source inventories and workspace status, device/IME/process
  identity records, original Flutter drive output and `driver/` reports.
- Complete native window/candidate responses, the helper's private JSONL event
  log, raw logcat and original input trace.
- Independent cleanup errors and a final file/hash manifest. Owned host process
  groups, helper/Catalog processes and the allocated adb forward are checked;
  the adb server and unrelated devices/processes are not stopped.

Local protocol checks do not prove Android delivery or IME acceptance:

```sh
python3 -B -m unittest discover -s .github/scripts -p test_android_candidate_diagnostic.py -v
python3 -B -m unittest discover -s tool/android_candidate_probe/tests -p test_build.py -v
cd packages/beautiful_ai_ui_catalog
flutter test test/android_candidate_protocol_test.dart test/catalog_chat_send_diagnostics_test.dart --no-pub
```

The [native helper documentation](../tool/android_candidate_probe/README.md)
describes its public APIs, exact HTTP contract, production-used gesture-gate
tests and bounded build command. The manual workflow compiles/runs those JVM
tests before APK compilation; no simulated input connection is accepted as a
successful native candidate run.
