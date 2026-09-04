# Android candidate diagnostic — 5a90dff9

The [single manual run 33862137234](https://github.com/pawaovo/shadcn_flutter/actions/runs/33862137234)
used exact source `5a90dff9515deb7e421cfa2c9cc9bf9ebc67466a` and **remains
failed**. It nevertheless established the previously unverified native step:
one actual Android IME candidate tap committed the unchanged draft, followed
by one original Chat Send and the expected new host message. The complete
original integration `Response` was not received, so the full journey is not
accepted. The driver's `all_tests_passed` field is absent; this is not a
received response containing `allTestsPassed=false`.

Actual Android 35 helper/APK compilation, 36 JVM protocol checks, 41 Dart
regressions, the HTTP wire fixture and attachment succeeded. The host bound
Catalog PID **2386**, start ticks **23246**, and helper PID **2316**. The actual
IME was `com.android.inputmethod.latin/.LatinIME`. Its window 0 exposed one
visible, enabled, clickable `inventory` candidate: node 48, depth 9,
`android.widget.TextView`, bounds `[380,1503,698,1604]`. Fresh native inspection
immediately before the action again confirmed this candidate, IME and focused
Catalog window.

The native helper invoked DOWN at device elapsed **266965 ms** and received its
return at **267049 ms**; UP was invoked at **267050 ms** and returned at
**267245 ms**. Both injection results were true, with no cancellation or second
tap. The actual public VM result at target elapsed **30304 ms** retained exact
text `Check cone inventory` and selection `[20,20]`, while composition changed
from `[11,20]` to `[-1,-1]`. Composer focus remained true and Send changed from
disabled to enabled. The final fresh activation guard also passed.

The original Send helper then recorded pointer 23 DOWN at its elapsed
**574739 µs** and UP at **598408 µs**. Its `after_tap` record at **922275 µs**
(`utc_epoch_us=1788517138171762`) shows an empty editor, empty composition,
`send_count=0`, host `responding`, and the new user message `prompt-1` with the
unchanged text. The Android log truncates the end of that JSON line; the
evidence preserves its raw prefix and extracts only fields completely present
before truncation.

The stock input trace records actual Catalog PID 2386 dispatching
`InputConnection#setComposingRegion` at **264.724464 s**, then
`InputConnection#commitText` at **267.285969 s**. Its selected trace clock is
`boot`. These dispatch slices are supplementary evidence: the separate actual
VM snapshot establishes the unchanged text and cleared composition. No
cross-clock latency or universal OS delivery-deadline claim is made.

The remaining failure is a diagnostic observer defect:

```text
Final candidate observer failed: Bad state: Finder returned no matching elements.
```

The wrapper unconditionally queried Send semantics after successful submission
had replaced Send with Stop. The subsequent original-response collection
timed out after its existing 10 seconds. The proposed minimal fix reads Send
semantics only when its actual count is one and records null otherwise; all
preclaim and preactivation count/enabled/focus/composition conditions remain.
A real Catalog Send-to-Stop regression reproduced the old getter failure and
passes with the fix; the original 41 tests plus this regression pass **42/42**,
with strict analysis clean. These local results do not change this run's
failure conclusion.

Supervisor cleanup is **verified**, with no supervisor cleanup errors. Native
call drain and the serial native stop acknowledgment are true. The driver's
cleanup record retains the original-response timeout; it is not described as
fully error-free. There was exactly one native tap attempt and one original
Send pointer sequence. Earlier `920f1dd8`, `2e83a2e3` and `080697f2` failures
remain unchanged, and no run was retried.

The [JSON evidence](android-candidate-5a90dff9.json) binds run/job/artifact IDs,
actual APK hashes, original native and VM records, the truncated Send log,
cleanup and core file hashes. The artifact was downloaded once; all **101**
files in the runner manifest were independently hash-verified. Its ZIP digest
is GitHub-reported, not independently verified from a retained ZIP. Raw
evidence remains at
`/tmp/beautiful-android-candidate-5a90dff9-33862137234`.
