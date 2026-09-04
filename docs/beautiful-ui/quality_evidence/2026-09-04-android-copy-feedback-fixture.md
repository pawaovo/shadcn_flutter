# Android journey copy-feedback observation correction

Date: 2026-09-04. Candidate examined:
`bff08825bf9bc48a074a261ec9f912a1058058a2`.

The reviewed raw job log is `/tmp/beautiful-ci-bff08825/android-job.log`,
lines 575–603, SHA-256
`831de1be6d2dcda0e2494378c4eece51ae4215380f5f9f6e2567d0c71fa0e140`.

The Android emulator booted, built and installed the APK, and reached resumed
application lifecycle. The original journey then failed at line 143 because
`find.text('Copied')` found zero widgets. This is an application-test failure,
not an emulator/build failure; the exact Android delay at the copy boundary
was not recorded and is not inferred from the job's total duration.

## What the existing code establishes

At this same candidate,
[`activateCatalogCopy`](../../../packages/beautiful_ai_ui_catalog/integration_test/support/trusted_clipboard_action.dart)
already waits until its scoped completion finder sees `Copied` before returning.
The real failure occurred after that helper returned, at the caller's assertion;
it did not fail at the helper's three-second completion timeout. Therefore the
journey had observed the success widget before the later failed observation.

[`BeautifulCodeBlock`](../../../packages/beautiful_ai_ui/lib/src/components/code_block.dart)
enters `Copied` only after its asynchronous copy callback succeeds. Catalog's
callback returns the real `Clipboard.setData` Future. The control retains success
for 1,500 ms and then returns to `Copy`. Its source is constant in this fixture;
callback closure replacement does not reset the state. The activation helper
taps only once and never retries the copy.

The original caller inserted an additional parameterless `tester.pump()` between
completion and its exact-one `Copied` assertion. Flutter's live test binding
waits for a subsequent engine frame even for parameterless pump; wall-clock
timers may expire while that frame is awaited. The same unnecessary boundary
existed at the other call site, with an extra 180 ms pump before the exact-one
`Response copied` assertion.

This establishes an observation race in the fixture. It does not establish that
the failed Android frame specifically took 1,500 ms, nor that native clipboard
read-back has been verified by this failure log.

## Minimal change

Both call sites in
[`catalog_journey_test.dart`](../../../packages/beautiful_ai_ui_catalog/integration_test/catalog_journey_test.dart)
now assert the already-observed success immediately after `activateCatalogCopy`
returns. Only the two intervening pump calls were removed. All exact feedback,
subsequent body/content and error assertions remain. There is no product change,
feedback-duration change, retry, duplicate copy, timeout increase, platform skip,
or native clipboard mock in the actual journey.

## Local evidence and its limits

A Git-ignored timing-boundary demonstration is retained under
`packages/beautiful_ai_ui_catalog/build/copy_feedback_probe/`. It uses the real
CodeBlock and unchanged completion helper with an asynchronous host callback,
then models a next frame arriving 1,500 ms later in a headless test clock. This
is an explicit counterexample, not an Android timing measurement or native
clipboard test.

| Diagnostic variant | Copied at helper return | Copied at assertion | Copy invocations |
|---|---:|---:|---:|
| Original extra-frame caller | 1 | 0; original exact-one assertion fails | 1 |
| Immediate assertion | 1 | 1; passes | 1 |

The second variant also advances that same next frame after its assertion and
verifies that feedback expires normally. The demonstration intentionally has
one failing negative control and one passing corrected variant; it is excluded
from permanent tests and CI and adds no mirrored release test.

Existing applicable headless checks passed: the two Catalog P1/P2 interaction
tests, and the two CodeBlock tests for exact clipboard payload/default transport
and pending de-duplication plus the existing 1,500 ms expiry. Those widget tests
use their documented host/transport fixtures and do not replace actual Android
execution. Targeted analysis of the original journey and completion helper
reported no issues; diff checks passed.

The exact Android journey has not been rerun locally or retried in CI by this
change. Its real native outcome must be established by the next candidate run.
