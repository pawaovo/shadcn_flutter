# Android Chat send composition race — 2026-09-04

The original Android journey at source
`153412b3014192b2d6c4c15e377161a5a862a968` **failed** its real Chat host
acceptance check: one user message was expected, but none was accepted and the
host stayed idle. The earlier Android journey at `abd6293b` passed; that earlier
pass does not resolve this source's failure. Both results remain retained.

The [original failing job](https://github.com/pawaovo/shadcn_flutter/actions/runs/33847999343/job/100944201351)
and [four exact diagnostic records](./2026-09-04-android-chat-composition-race.json)
show the relevant transition:

| Phase | Elapsed | Composing | Send enabled | Host |
| --- | ---: | --- | --- | --- |
| Before tap preparation | 0.352 ms | `[-1,-1]` | Yes | Idle; no new message |
| Pointer down | 683.027 ms | `[11,20]` | No | Idle; no new message |
| Pointer up | 798.546 ms | `[11,20]` | No | Idle; no new message |
| After tap | 1,322.312 ms | `[11,20]` | No | Idle; no new message |

Text remains `Check cone inventory`, the caret remains `[20,20]`, the editor
retains primary focus, and the native bottom inset remains 901 physical pixels.
The target moves during reveal, but both pointer coordinates are inside its
then-current rectangle. The button is already disabled when the pointer arrives.
This is sufficient to explain the rejected send without attributing it to a
missed target or a response-completion timer.

The [Chat contract](../parity_manifest.yaml) forbids submission during active
composition. The existing component obeys that contract. The observed failure
therefore does not justify enabling Send during composition or changing Enter.
Native IME re-composition after a framework edit is a plausible explanation for
the range change; these snapshots do not identify the originating native
callback or prove a human OS IME session.

## A regression at the actual Catalog call site

The existing
[`catalog_chat_send_diagnostics_test.dart`](../../../packages/beautiful_ai_ui_catalog/test/catalog_chat_send_diagnostics_test.dart)
now includes a delayed platform-value replay. It uses the real Catalog, the
public framework edit helper, the unchanged target-reveal helper, and exactly
one tap. The initial diagnostic must see Send enabled. On the next reveal frame,
an injected platform update changes only composition to `[11,20]`; pointer-down
must then see Send disabled. The host remains idle, no sent message or Stop
response appears, and the composing range survives unchanged. The previous
already-composing and successful non-composing controls remain.

This is a deterministic replay of the observed ordering, not native IME proof.
Allowing the delayed replay to expect successful host acceptance produced the
same red result as CI: expected one message, actual zero, at
`sendCatalogChatOnce`'s original host assertion. Restoring the regression's
required rejection passed all **5/5** tests in about two seconds. Targeted
analysis reported no issues. Only the diagnostic regression changed; production
Chat, the original integration journey and its assertions remain unchanged.

Local verification logs are
`/tmp/beautiful-android-delayed-composition-red.log`,
`/tmp/beautiful-android-delayed-composition-green.log`, and
`/tmp/beautiful-android-delayed-composition-analysis.log`.

## Input-boundary alternatives checked

Flutter's pinned source (`4cf24164269a5ebf0c16a028a00727d0e77bbb05`) explains why
the two apparent fixture shortcuts do not repair this gate:

- `TextInput.setInputControl` retains the platform control in its control set,
  still forwards valid native editing updates to the client, and changes new
  native input configuration to `TextInputType.none`. Switching while focused
  also asks the old control to hide. It neither preserves the original keyboard
  behavior nor isolates native peer updates. See `text_input.dart` lines
  1989–2044, 2260–2263 and 2630–2640, and `editable_text.dart` lines 4196–4200.
- `TestTextInput.register` installs an outbound mock method-channel handler;
  the integration binding deliberately leaves that stub unregistered. A
  separately named controlled-framework test could use that boundary, but its
  success would not replace the existing native-peer journey or validate its
  keyboard geometry. See `test_text_input.dart` lines 66–83 and
  `integration_test.dart` lines 98–99.

A user can finish an OS candidate/composition before sending. This automated
journey has no evidence that such a native commit occurred and must not infer
one. No forced composing clear, keyboard hiding, extra tap, retry, timeout
change, disabled assertion, or green replacement gate was introduced. The
original Android result remains failed; no new cloud run is warranted solely
by this diagnostic regression.
