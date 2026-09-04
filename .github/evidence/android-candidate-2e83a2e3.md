# Android candidate diagnostic — 2e83a2e3

The [single manual run 33858867632](https://github.com/pawaovo/shadcn_flutter/actions/runs/33858867632)
at exact source `2e83a2e3bda5d0ebdfaf8f72caf682d949f4cd49` **passed actual
Android 35 helper compilation and signing**, then failed at the Dart driver's
initial HTTP attachment to the host supervisor. It did not inspect or tap an
IME candidate. No run was retried.

Cloud verification passed 10 host protocol tests, three build-process cleanup
tests, 36 Dart tests and analysis, and 36 actual JVM `ProtocolTest` checks.
The helper APK SHA-256 is
`9055846a9592c2a4f9a5709be98d17ad7b489181493743912d0e6e404a755ac3`.
The original Catalog test APK also built and installed; its SHA-256 is
`025f2c480a4d67929748ae53af4ba4c59041dad54cc6f4a45f76cbbde5d5b95c`.

The helper started as PID 2314. Android's configured IME component was
`com.android.inputmethod.latin/.LatinIME`. The public VM extension returned the
correct source/nonce in `preparing` state. The driver then failed with:

```text
Native supervisor /attach failed (400):
{ok: false, error: Invalid protocol Content-Length}
```

`catalog_android_candidate_driver.dart:391-392` set JSON content type and called
`HttpClientRequest.write(jsonEncode(body))` without setting an explicit body
length. The strict host requires positive `Content-Length`; the client must send
the UTF-8 byte length and bytes explicitly. The proposed repair belongs at this
HTTP boundary, without relaxing native input or Send requirements.

The root-authorized fix extracts that same client into a pure Dart module and
encodes the JSON once as UTF-8, sets `contentLength` to the byte count, then adds
those bytes. A real loopback HTTP server reproduced the old client's **400**:
length `-1`, transfer encoding `chunked`, and an otherwise complete 87-byte body
containing `你`. The fixed client passed four real requests covering POST, GET,
exact authentication and routes, nested Unicode (`你🙂`) and ASCII bodies. POST
lengths were exactly 87, 100 and 48 received bytes, with no chunked encoding.
The same regression is now in the manual workflow. This local wire test does
not turn the failed Android attempt into a pass; a new source/run is required.

The original full journey started but did not complete; no final integration
response was accepted. The driver recorded zero native clicks. The helper's
private event log contains only stop/finish, confirming that candidate inspection
and touch never occurred. There is no inventory candidate or draft-commit proof.

Stock Android input tracing did work: the raw trace contains 11
`InputConnection#…` dispatch slices for Catalog PID 2385, including
`finishComposingText` and `setComposingRegion`. PID 2385 is observed in the
process-tagged Flutter launch log; host attachment/PID validation did not run.
Two launcher PID 1293 slices are kept separate. These early journey events must
not be attributed to the candidate action that never happened.

Supervisor cleanup was verified with no cleanup errors. The native helper
returned a serial stop response and finished, owned processes/forward were
checked, and the emulator finalizer received `OK: killing emulator, bye bye`.
All **84 run artifact hashes and sizes** matched the original manifest. The
artifact was downloaded once; original metadata and raw files remain at
`/tmp/beautiful-android-candidate-2e83a2e3-33858867632`.

The [JSON evidence](android-candidate-2e83a2e3.json) retains exact run/job/artifact
identities, APK hashes, the driver error, actual input trace lines, cleanup and
the complete run-file hash manifest. The prior `920f1dd8` build failure remains
unchanged and separately archived.
