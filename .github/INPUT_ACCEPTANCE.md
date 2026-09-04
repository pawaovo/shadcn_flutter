# Catalog input acceptance layers

The original complete Catalog journey remains an independent gate. The added
input workflow runs separate targets and retains a failing operation as failure;
it does not retry inputs, grant browser clipboard permissions, or replace a
browser with a different engine.

Each suite starts a fresh Flutter process and, for web targets, a fresh owned
WebDriver. A failing framework or journey suite does not suppress the independent
browser suite after all owned processes have been verified clean. Reports retain
every suite's original failure and the invocation still exits nonzero if any
suite fails. A cleanup failure stops later suites to prevent shared process or
browser state from contaminating their evidence. This is independent execution,
not a retry of any failed operation.

The original Web journey now uses `catalog_trusted_journey_driver.dart` and
`CATALOG_TRUSTED_BROWSER_COPY=true` for exactly two clipboard activations. Its
CodeBlock and StreamingText copy controls are clicked with actual W3C pointer
events, while every original business assertion and completion check remains.
The helper waits for the existing success state after the real async write;
failure still fails the journey. Native runs retain Flutter-injected taps.
The global test handshake and live pointer-propagation setting are cleared or
restored in `finally`.

## What the two targets prove

| Target | Actual execution boundary | Evidence limit |
| --- | --- | --- |
| `catalog_platform_input_test.dart` | Full Catalog, real platform renderer, public Flutter editing/keyboard/pointer input, synthetic render constraints; native platforms also use the real Clipboard bridge | Injected composing ranges and keys are not an operating-system IME or physical keyboard. Synthetic constraints are not a real window resize. |
| `catalog_browser_input_test.dart` with its W3C driver | Real browser pointer/key actions; CJK text; Shift+Enter/send; model Escape/focus; keyboard copy/paste; CodeBlock and StreamingText copy pasted into Prompt; read-only Cut/Paste/Backspace; actual window widths 599/600/1023/1024/1440 | Unicode key insertion is not a native IME candidate workflow. No result represents a screen-reader or physical-device review. |

The browser target reports actual Flutter control coordinates and state. Its
bridge cannot set editor values or invoke business callbacks. The host-side
driver sends W3C actions and window commands to the original session created by
`flutter drive`, then requires the original integration-test completion result.
Live device pointer propagation is enabled only for this test and restored.

Before its single initial text action, the driver waits after the single pointer
click for both the published Prompt focus and an actual active Flutter editing
element. The DOM check follows active elements through shadow roots and rejects
unrelated, disabled, or read-only fields; it reads state without focusing an
element or inserting text through JavaScript. Prompt paste targets use the same
readiness boundary. Select-all before keyboard copy waits for the exact full
selection, with no repeated key action.

Read-only document stages publish their own text, focus, selection, read-only
flag, and editor/controller identities separately from Prompt. After one document
click, the driver waits for that document's Flutter focus and the matching active
read-only DOM editor. Its single select-all must be reflected in both document
and DOM selection before copy and Backspace proceed. The original unchanged-text
and selected-text assertions remain the acceptance conditions.

Every stage/readiness wait also reads the original `$flutterDriverResult`.
An early target assertion is saved and propagated immediately, together with the
last non-null application state and acknowledgement. Post-Escape and post-copy
snapshots preserve the observed application and DOM selection state. A `stages`
entry means the driver observed that stage before sending its actions; it is not
a claim that the target completed the stage.

The framework target separately prepares web view focus through the public
platform request and waits for the binding's actual focused-view event state
before requesting editor input. An already focused view needs no second event.
This setup remains framework input, not W3C pointer acceptance.

The Catalog's CodeBlock and StreamingText host callbacks now await real
`Clipboard.setData`; success feedback follows that completion. Acceptance checks
the exact text pasted into the actual Prompt editor, including code newlines
and streaming citation numbers. Clipboard failures therefore fail the suite
instead of being accepted from a `Copied` label alone.

## Repeatable execution

Resolve the existing lockfile first:

```sh
flutter pub get --enforce-lockfile
python3 .github/scripts/run_catalog_input_acceptance.py --platform chrome --artifacts artifacts/input-chrome
python3 .github/scripts/run_catalog_input_acceptance.py --platform edge --artifacts artifacts/input-edge
python3 .github/scripts/run_catalog_input_acceptance.py --platform firefox --artifacts artifacts/input-firefox
python3 .github/scripts/run_catalog_input_acceptance.py --platform safari --include-journey --artifacts artifacts/input-safari
python3 .github/scripts/run_catalog_input_acceptance.py --platform macos --artifacts artifacts/input-macos
python3 .github/scripts/run_catalog_input_acceptance.py --platform windows --artifacts artifacts/input-windows
python3 .github/scripts/run_catalog_input_acceptance.py --platform linux --artifacts artifacts/input-linux
```

Browser WebDriver executables must be installed and match their browser. Edge
uses the existing real Edge adapter and verbose/failure diagnostics. Safari uses
Apple's installed `safaridriver`; its workflow enables automation only on the
temporary macOS runner with a bounded command and records Safari/macOS/driver
versions. It does not change the local user's Safari permissions. Any inability
to enable automation or execute the session is retained as a failing job.

Mobile entry points require an explicit currently connected device or simulator:

```sh
python3 .github/scripts/run_catalog_input_acceptance.py --platform android --device DEVICE_ID --artifacts artifacts/input-android
python3 .github/scripts/run_catalog_input_acceptance.py --platform ios --device DEVICE_UDID --artifacts artifacts/input-ios
```

These commands do not provision, authorize, unlock, or pretend to attach a
physical device. iOS device signing and Flutter's debug-service connection must
already be configured; a simulator result must be labeled as simulator evidence.

Artifacts retain each suite's exact command, process exit status, logs and
structured result. Browser results include actual session capabilities and
actual window responses. Native results include the `CATALOG_INPUT_REPORT`
marker and test-runner event JSON. Missing runtime evidence remains pending;
static analysis or protocol fixtures alone cannot complete the runtime matrix.

Choose a fresh artifact directory for each invocation. Existing suite evidence
or an existing run-owner file is rejected, including an old successful report;
the runner never accepts a report left by a previous invocation. Browser and
Flutter subprocesses are owned as POSIX process groups or Windows Job Objects.
Cleanup verifies no live group/job members remain even after the leader exits,
and a cleanup error prevents the suite from being reported as passed.

## Real assistive technology

The separate Windows/Linux capability jobs do not replace a real Narrator or
Orca task-flow acceptance. They report executable/session/input/speech/audio
capability and explicit missing layers. A UIA/AT-SPI tree, a running AT process,
or an Orca speech debug line is insufficient to mark spoken interaction passed.
Actual OS IME, understandable announcements, and physical-device operation
retain their own evidence requirements.
