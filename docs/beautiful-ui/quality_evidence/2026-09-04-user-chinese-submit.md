# User Chinese-text submission — 2026-09-04

The user's new observation confirms **Chinese text insertion into both controls
and one actual Prompt submission of `你`, followed by draft clearing**. The
download has 54 records, including initialization, below the existing 300-record
retention cap. It contains no active composition session.

The [original downloaded trace](../diagnostics/live-os-ime-observer/2026-09-04-user-chinese-submit-trace.json)
is retained byte-for-byte: **121,252 bytes**, SHA-256
`1b8fd67bee48f2f0d5dda67682273fabda6327eecb26ef04bac237d1cc1305ac`.
The [compact analysis](2026-09-04-user-chinese-submit.json) preserves the exact
sequence, state identities, conclusions and live-page corroboration.

| Observation | Elapsed milliseconds | Result |
| --- | ---: | --- |
| Prompt keydown | 9,977 | `key=你`, `code=KeyA`, `keyCode=65`, trusted |
| Prompt beforeinput/input | 9,978–9,980 | `insertText`, `data=你`, trusted, not composing |
| Prompt controller update | 9,982 | Text `你`, caret `[1,1]` |
| Actual Prompt onSend | 14,426 | Exactly one callback with `你` |
| Prompt controller after callback | 14,427 | Draft cleared |
| Stock input and controller | 20,730–20,731 | Text `你`, caret `[1,1]`, text retained |

There are six actual capture records: keydown, beforeinput and input for each
control. Their post-dispatch copies are observations of the same events, not
additional input actions. All carry `isTrusted=true` and `isComposing=false`.
No `compositionstart`, `compositionupdate` or `compositionend` was recorded.
Both Flutter composing ranges remain `[-1,-1]` throughout, and each editor's
state/controller identity remains stable. The activation mechanism for Send
is not established by this observer's event list; only the real callback and
result are accepted.

The source page was independently identified as **Codex In-app Browser tab 7**,
at `http://127.0.0.1:63120/`. Its visible report has the same two state/controller
identities, the same submission timestamp and text, and the exact downloaded
filename. The separate Chrome tab still contains the earlier agent observation;
it is not the source of this user trace. This read did not reload or edit either
page. The browser surface identification does not, by itself, establish why
composition events were absent.

This closes the scoped Chinese committed-text insertion/submission observation.
It does not accept candidate/pre-edit behavior, Enter protection during active
composition, composition retention across resize or focus changes, a particular
OS input method, or Android behavior. The earlier WeType identity observation is
not transferred to this user run. No production change is justified solely by
the absence of composition events in a committed-text sequence.
