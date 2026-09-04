# Android native candidate fixture and diagnostic

The fixture runs the **entire original Catalog journey** with three fixed native
candidate commits before the original actions. The regular main Android job and
the manual diagnostic use the same supervisor, helper, driver and target.
Earlier failures retain their original source/run. This English LatinIME fixture
does not constitute human Chinese-IME or physical-device acceptance.

| Stage | Exact original draft | Candidate and composing range | Original action retained |
|---|---|---|---|
| `chat_send` | `Check cone inventory` | `inventory`, [11,20], selection 20 | One Chat Send; original Stop response and subsequent Chat assertions |
| `prompt_command` | `/rest` | `rest`, [1,5], selection 5 | One Enter selecting `/restock ` |
| `prompt_send` | `Prepare the seasonal restock` | `restock`, [21,28], selection 28 | One Prompt Send with the original precise model and inventory attachment |

These stages and strings are compiled allowlists in Dart, Python and Java.
Callers cannot supply arbitrary drafts, candidate text, ranges, coordinates or
native operations. Missing composition or a missing/ambiguous candidate fails
the attempt. There is no fallback word, whitespace normalization, composing
clear, keyboard hide, focus move, mocked input peer or repeated click.

For an independent run, dispatch `beautiful_ai_ui_android_candidate.yml` with
an exact 40-character `source_sha` containing the fixture. The workflow checks
out and verifies that commit, uses Flutter 3.47.0 and a fresh API 35 x86_64
default Pixel 6 emulator, builds a fresh helper APK, and runs once. The main job
binds the same inputs to `github.sha`. Existing local emulators, physical devices,
or already installed Catalog/helper packages are not accepted by the supervisor.

The target is `integration_test/catalog_android_candidate_test.dart`. Its
`CATALOG_ANDROID_CANDIDATE` flag defaults to false in the shared journey.
The original input text, Enter/Send counts, disclosure operations, clipboard,
pump durations and assertions remain. Only this explicit fixture adds native
commit handoffs. The public VM extension is `ext.beautiful.androidCandidate`;
one original `requestData` response remains the full journey's authority.

Protocol v2 has a fixed ordered stage ledger. Each stage gets an independent
nonce, protocol, FIFO queue, helper instance and one-use candidate ticket.
The first helper retains its original lifetime before Flutter starts; the host
passes its preallocated chat nonce to the target. Later stage nonces are created
by the target. Preparing the first helper only acknowledges that same live
instance. Later preparation requires the previous original action/assertions
and complete helper retirement. Old-stage state, claim, result or drain requests
cannot authorize the current stage.

While a live widget observer is installed, VM requests queue until the test's
own awaited pump finishes. The test handles requests synchronously in its owning
zone and drains pending aborts immediately before activation. Claims and final
activation read current controller, focus and semantics. Frozen observations
cannot authorize another claim. The five-second action lease remains mandatory
until the actual action's activation check; the overall 600-second target and
driver deadlines do not restart between stages or disappear after the last
stage. A final target deadline check includes the rest of P3.

Preparation requires the exact original full text, selection, composing range,
primary focus, visible keyboard and disabled Send. Prompt Send also preserves
the selected model and attachment. The independent instrumentation targets its
own package, creates no Activity and never restarts Catalog. It inspects the
currently selected IME and requires exactly one visible, enabled, unobscured
candidate with the exact text/description. It independently rechecks the
focused Catalog window, IME identity, candidate and bounds before its single
touch.

The device's two-second monotonic ticket limits invocation. A checked DOWN/UP
is never retried; expiry before UP requests CANCEL. Public UiAutomation can
block inside injection, so invocation timestamps are not OS delivery deadlines
and HTTP timeout is not cancellation. A real native return or serial STOP
response establishes drain. Unverified drain fails the attempt and requires
teardown of the exclusively owned emulator before another run.

Each helper retires through serial STOP, verified helper PID absence, preservation
of its unique stage JSONL, removal and verification of its adb forward, and
owned host process-group/reader EOF cleanup. No new helper starts before these
conditions pass. Chat completion is reported after its original Stop response,
stopped-result and Suppliers assertions, preserving the Send-to-Stop timing.
The final helper remains alive through the full original response/test teardown
and is retired before the driver can report overall success. The Catalog process
and VM isolate remain bound throughout.

After each candidate the actual full text/selection must be unchanged,
composition empty, focus retained and Send enabled. Before command Enter the
actual Commands menu and enabled restock option must be present. Synchronous
activation guards recheck the real state after reveal/pump work. Three candidate
receipts alone cannot pass: all three original actions, the complete original
response, every native drain and resource cleanup are required.

The passive P3 observer records editing values, focus/controller identities,
rendered menus/Send, framework key delivery and visible host receipts in the
full response. It consumes no key and adds no input, focus change, frame, delay
or retry. Listener callbacks read held objects; only explicit test-owned
checkpoints query widgets/semantics. Observation failures do not replace the
original action/assertion failure.

The supervisor also preserves stock Android `atrace input` and owned-app
`InputConnection#...` dispatch slices. A slice alone is not acceptance or exact
causation. Native action records and actual editing/host results remain separate.
Relevant source inputs, package manifests/lockfile, resolved package configuration,
both workflow files and driver fixtures are hashed; unrelated generated workspace
files are recorded without being mistaken for Android source mutation.

Uploaded evidence includes the helper APK/JVM/compiler report, per-stage native
records and unique logs, VM snapshots, full original driver/response, raw
logcat/input trace, process identities, cleanup and a complete file/hash manifest.
GitHub ZIP digests are reported separately from independently verified extracted
file hashes.

Local checks exercise implementation and rejection paths, not native delivery:

```sh
python3 -B -m unittest discover -s .github/scripts -p test_android_candidate_diagnostic.py -v
python3 -B -m unittest discover -s tool/android_candidate_probe/tests -p test_build.py -v
cd packages/beautiful_ai_ui_catalog
flutter test test/android_candidate_protocol_test.dart test/android_candidate_sequence_test.dart test/catalog_chat_send_diagnostics_test.dart test/prompt_input_diagnostics_test.dart --no-pub
dart test_driver/android_candidate_http_fixture.dart
dart test_driver/android_candidate_stage_driver_fixture.dart
```

The [native helper contract](../tool/android_candidate_probe/README.md) documents
its strict public APIs and production-used gate tests. Both workflows compile
and execute the actual JVM checks before APK construction. Real candidate
existence and the full Android outcome must still come from a new source-bound
run; local fixtures never substitute for that evidence.
