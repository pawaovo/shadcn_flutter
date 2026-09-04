# Android candidate diagnostic — 080697f2

The [single manual run 33860651421](https://github.com/pawaovo/shadcn_flutter/actions/runs/33860651421)
used exact source `080697f20272fa69055a300e52afbe673d9d165d`. Actual Android 35
APK compilation and the previously failing HTTP attachment passed. The run then
**failed while reading a live widget snapshot through the public VM extension**,
before any native candidate inspection, claim or touch.

Cloud gates passed 10 host tests, three build-cleanup tests, 36 Dart tests,
analysis, four real Dart HTTP wire requests and 36 actual JVM protocol checks.
The driver attached successfully and the host independently bound Catalog PID
**2380**, start ticks **19583**; the helper was PID **2316**. The configured IME
was `com.android.inputmethod.latin/.LatinIME`.

At Chat, the target had an outstanding `await tester.pump` at
`catalog_android_candidate_test.dart:182`. A VM callback, after its existing
zero-duration event-loop defer, called `tester.widget` through `readSnapshot`
at line 93 in another async zone. Flutter rejected the overlapping guarded
calls:

```text
Guarded function conflict.
The first method (WidgetTester.pump) had not yet finished executing
at the time that the second method (WidgetController.widget) was called.
```

This is an observation/RPC serialization defect. It does not justify changing
`TestAsyncUtils`, accepting a cached snapshot as live, or weakening any input or
Send condition. The intended next fix queues live requests and processes them
in the test's own zone after the awaited pump completes, with pending aborts
also processed immediately before the existing activation guard.

The real controller trace independently recorded the unchanged
`Check cone inventory` text and `[20,20]` selection, with composition changing
from `[-1,-1]` at elapsed 22511 ms to `[11,20]` at 22715 ms. The RPC failure and
abort prevented the target from offering a candidate. No `inventory` candidate
was inspected or clicked, and no candidate-commit result was observed. The
original integration response correctly reported failure.

The native event log contains only stop/finish. The driver received a real
serial stop/drain acknowledgment; supervisor and driver cleanup completed with
no cleanup errors. The previous `920f1dd8` compilation failure and `2e83a2e3`
attachment failure remain separately retained. No run was retried.

The [JSON evidence](android-candidate-080697f2.json) contains the exact run/job
and artifact identities, APK hashes, bound process identities, complete original
guard error, actual controller trace, app-PID dispatch summary, cleanup and the
verified run-file hash manifest. The artifact was downloaded once; raw evidence
remains at `/tmp/beautiful-android-candidate-080697f2-33860651421`.
