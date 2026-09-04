# Main Android native candidate result — 75594991

The [main Android job](https://github.com/pawaovo/shadcn_flutter/actions/runs/33863483982/job/100993028063)
at exact source `7559499112dcc5c5d9b0370ba1d6b0eb34743f45` **failed in a later
P3 Prompt assertion**. The integrated native candidate step, unchanged Chat
draft commit, original single Send and corrected final observation all
succeeded. This time the complete integration `Response` was received and
explicitly contains failure, rather than the missing response in
[5a90dff9](android-candidate-5a90dff9.md).

The fresh API 35 emulator ran the actual LatinIME package
`com.android.inputmethod.latin/.LatinIME`. The host bound Catalog PID **2392**,
start ticks **27170**. One exact visible, enabled, clickable `inventory`
candidate was observed and revalidated in IME window 0, node 48, at bounds
`[380,1503,698,1604]`. The native helper invoked DOWN at device elapsed
**309369 ms** and UP at **309421 ms**, receiving successful returns at
**309415 ms** and **309477 ms**. There was no second tap or cancellation.

Actual controller observations retained exact `Check cone inventory` and
selection `[20,20]` throughout the native candidate step. Composition was
`[11,20]` before the native operation and `[-1,-1]` afterward. Send was enabled
and the editor still had primary focus at the final synchronous activation
guard. The original single Send then left the editor empty, host responding,
and exactly the expected new user text in host messages. The corrected
observer recorded `send_count=0`, `send_enabled_semantics=null`, and
`observation_error=null` after the normal Send-to-Stop transition.

The original journey continued through the remaining P2 checks and reached
P3. Its next Prompt command assertion failed at
`integration_test/catalog_journey_test.dart:304`:

```text
Expected: '/restock '
  Actual: '/rest'
```

The original actions immediately before this assertion are the `/rest` edit,
one Enter event and the existing pumps. This evidence establishes the actual
text mismatch; it does not by itself identify whether focus, composition,
menu readiness or another mechanism prevented command selection. The Chat
observer is scoped to its own composer and cannot stand in for a fresh P3
Prompt snapshot. No original input, timeout or assertion was relaxed.

The driver records `all_tests_passed=false` and the full original failure
details. Both driver and supervisor cleanup error lists are empty; supervisor
cleanup is verified and the actual serial native stop/drain acknowledgment is
true. One native candidate tap and one original Chat Send do not imply that
the complete journey passed. No real human IME or all-platform acceptance is
claimed.

The [JSON companion](android-candidate-75594991.json) preserves the actual
candidate identity, native timing, complete original candidate/Chat report,
final failure response, APK hashes, process identity and cleanup. All **102**
files in the runner artifact manifest were independently hash-verified after
one download. Original supervisor metadata still carries two manual-prototype
labels (`scope` and `original_android_gate_changed=false`); the JSON records
this caveat and binds the actual main workflow/job identity. Old failures
remain unchanged.

Raw evidence is retained under
`/tmp/beautiful-75594991-main-33863483982/artifacts/android-native-candidate-33863483982-1`.
