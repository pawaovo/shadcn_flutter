# iOS journey framework text-input synchronization correction

Date: 2026-09-04. Examined candidate:
`e3526d3fb6f9ce97706a3e28297d5e682ebce9e8`.

The actual iOS driver connected and reached the P2 Fine-tune step. Its original
failure at `catalog_journey_test.dart:269` expected width text `360` and observed
`324`. The original driver log is under
`/tmp/beautiful-ci-e3526d3f/main/apple-native-journeys/shadcn_flutter/shadcn_flutter/packages/beautiful_ai_ui_catalog/artifacts/apple/native-flutter-driver.log`,
lines 5769–5795, SHA-256
`81ab93f7812f46d7c5564503dc2478c78297570d9bc2c211923b6fe32d05e6e2`.
The failure screenshot also shows the Width control and a real numeric keyboard.
Neither artifact records the input value immediately before Enter or the exact
native editing-state echo order, so that timing is not claimed as measured.

## Bounds and component behavior

The finder is scoped to the actual `catalog-fine-tune` component and stable
`beautiful-fine-tune-input-width` key. The host initializes Width to 324 with
inclusive bounds **40–999**, so 360 is a legal value. Responsive constraints
change the control's presentation, not these numeric bounds.

Fine-tune intentionally restores the accepted value while submitting a proposed
change, then displays the host's replacement snapshot. The ordinary headless
control path accepts 360 after Enter and the next build. This controlled-state
contract and `_NumericProperty._propose` are unchanged.

## Demonstrated fixture protocol gap

`IntegrationTestWidgetsFlutterBinding` sets `registerTestTextInput` to false.
The former `tester.enterText` calls still inject a
`TextInputClient.updateEditingState` message as though the real IME had already
changed its value. The SDK explicitly warns that this can confuse a real IME.
`EditableText.updateEditingValue` therefore treats the injected value as the
last known remote value and need not send it back to the real peer.

The existing framework-input suite already uses the appropriate public
`EditableTextState.userUpdateTextEditingValue` path. That path applies user
editing/formatting callbacks and sends a changed local value through
`TextInput.setEditingState` to synchronize its peer.

A Git-ignored diagnostic under
`packages/beautiful_ai_ui_catalog/build/fine_tune_input_probe/` exercised the
actual Catalog and captured its outbound method calls. The echo rows explicitly
simulate the peer returning its last outbound value; they are not recordings
of iOS events.

| Input path | Flutter draft before echo | Last outbound text | Explicit echo | Host value after Enter/build |
|---|---:|---:|---|---:|
| Old tester input | 360 | 324 | none | 360 |
| Old tester input | 360 | 324 | last outbound value | 324; exact 360 assertion fails |
| Public SDK user edit | 360 | 360 | none | 360 |
| Public SDK user edit | 360 | 360 | last outbound value | 360 |

The old no-echo control demonstrates that the numeric range, normalization and
ordinary submission work. The old echo case produces the exact 360-versus-324
failure while preserving actual primary focus. This is a reproducible protocol
gap; it does not prove the unrecorded echo ordering of the original iOS run.

## Fixture-only correction and verification

All six string-entry sites in the original journey now call the common
`enterCatalogText` helper in
[`interactions.dart`](../../../packages/beautiful_ai_ui_catalog/integration_test/support/interactions.dart).
It requests the intended editor's keyboard connection once, checks actual
primary focus, applies one public SDK user edit, and checks the complete text/
selection/composition value and primary focus afterward. Search, Chat, numeric
Width, both Prompt entries and Records search retain their original strings
and subsequent keyboard actions. W3C trusted-key flows are unchanged.

The original exact controller-text assertion `360` remains. An additional
assertion reads the public `BeautifulFineTuneCard.settings` snapshot and requires
the host's width value to be 360, so merely installing an uncommitted draft cannot
pass the submission step. No test writes the host model directly.

One permanent protocol regression observes the last actual outbound
`TextInput.setEditingState` as 360, explicitly echoes that value, then requires
both controller and host to accept Enter. It also requires the host to remain
324 before submission. This would distinguish the old wrong input API even
when ordinary no-echo widget tests pass.

Local checks completed:

- New outbound protocol regression: **1/1 passed**.
- Existing Fine-tune contract suite: **18/18 passed**.
- Three existing Catalog P1/P2/P3 scenarios, temporarily copied to a Git-ignored
  location and run through the new input helper: **3/3 passed**. Their assertions
  were unchanged; these are headless compatibility checks, not a native journey.
- Original journey, helper and new regression targeted analysis: no issues.
- Diff check: passed.

The product library, native bridge, numeric bounds, submission behavior,
timeouts, retries and original journey assertions were not weakened or changed.
This helper is controlled framework input and does not establish OS-IME
acceptance. No local iOS runtime was available, and no old candidate was retried;
the complete real iOS journey must be evaluated on the next source candidate.
