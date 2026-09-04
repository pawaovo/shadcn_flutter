# Live native input preparation — 2026-09-04

**Ordinary trusted native text input was observed; OS IME pre-edit remains
unverified and unaccepted.** The [compact record](2026-09-04-live-os-ime-observation.json)
transcribes the root task's observations. The complete original run trace was
not exported.

In the owned native Chrome tab, one native `n` key produced trusted beforeinput
and input captures at 26347 ms, both `insertText`, data `n`, and
`isComposing: false`. Keyup at 26387 ms was trusted `n` / `KeyN` / keyCode 78,
without modifiers. DOM and stock Flutter state both contained `n` with caret
`[1,1]`; Flutter composing was `[-1,-1]`. No compositionstart/update/end event
was observed. Prompt remained empty and unfocused, and no submission occurred.

The read-only `TISCopyCurrentKeyboardInputSource` result identified
`com.tencent.inputmethod.wetype.pinyin` / 微信输入法 / `com.tencent.inputmethod.wetype`.
That identifies an input source; it does not establish Chinese mode or IME
participation in this plain key insertion. Separately, `lsappinfo front` still
reported IINA while native AX reported the Chrome stock field focused. Both
facts are retained without inferring global foreground status from field focus.

A later clearing attempt was blocked by native CUA **before execution** when the
user switched applications. Further keys stopped. Clearing is not reported as
successful, and this interruption is not an IME pass or failure.

The [archived observer source and provenance](../diagnostics/live-os-ime-observer/README.md)
preserve the exact final source, raw build log and existing build manifest.
Source, compiled main JS/bootstrap and recorded dependency hashes were verified.
The observer uses enabled semantics, writable stock and actual Prompt controls,
passive native-event logging, and real Prompt submission logging; it has no
synthetic input buttons, automatic text/selection updates, or settings changes.
The historical manifest's `observed_events` list names **configured listeners**,
not events that were all observed in this run.

Native Chrome tab `1891840655` was claimed and handed off at
[the prepared local page](http://127.0.0.1:63118/); the initial background tab
`1891840652` was closed. Port 63118 remains available for manual input under the
root task's ownership. This local release observer is distinct from debug CI.
Products, framework gates and W3C assertions were not changed by this archival
step. Actual candidate/pre-edit/commit behavior still needs real IME validation.
