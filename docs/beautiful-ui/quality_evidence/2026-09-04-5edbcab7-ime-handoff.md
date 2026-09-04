# Exportable native input observation at 5edbcab7

The [current local observer](http://127.0.0.1:63120/) is ready for a real Chinese
candidate/pre-edit/commit workflow. Its Prompt is empty and focused. It now has
a **Save observed trace** button whose actual browser download has been verified.
This is an input-observation handoff, **not an OS IME acceptance result**.

The [new wrapper](../diagnostics/live-os-ime-observer/exportable_live_os_ime_probe.dart)
imports the byte-identical historical observer. It adds a DOM download button,
reads only the observer's deliberately published JSON, and serializes the full
current report into a file. It does not set editor values, change composition,
invoke submission callbacks, select an input source or change system settings.
Its pointer-down handler prevents normal DOM focus transfer on the export
button; it makes no claim about separate native IME commit behavior.

The wrapper was built with the source-5ed public library and current pinned
Flutter toolchain. It is separately hashed in the [provenance record](2026-09-04-5edbcab7-ime-handoff.json),
because the new diagnostic wrapper itself is not part of that library commit.
The original observer retains SHA-256
`3e00285fdde66ebf08f82ddd742f25eca474237ea1e8346dd4c996dabae0ae9b`.

## Actual observed result

One native Computer Use click focused the stock input, followed by one native
`n` key. The browser recorded trusted `beforeinput` and `input` events with
`inputType: insertText`, `isComposing: false`, text `n` and caret `[1,1]`.
Flutter also showed `n`, caret `[1,1]` and composing `[-1,-1]`. Prompt remained
empty and no submission occurred. These are ordinary keyboard-input results.

The actual **Save observed trace** click downloaded
`live-os-ime-observed-2026-09-04T08-14-59.634Z.json`. Chrome showed completion;
the local file was read, parsed and archived byte-for-byte. It contains **26
events**, including both trusted non-composing input events and **zero
composition events**. Native accessibility still reported the stock editor
focused after the export. The handoff then separately focused the empty Prompt.

- [Original exported JSON](../diagnostics/live-os-ime-observer/2026-09-04-5edbcab7-exported-trace.json)
- Original download: `/Users/zzz/Downloads/live-os-ime-observed-2026-09-04T08-14-59.634Z.json`
- File: **61,795 bytes**, SHA-256
  `ece542a26b8109a10e62089f054b513ce2a9c3d4067a4c5877c4432008ded88c`

A read-only current input-source query before this exportable run identified
WeType (`com.tencent.inputmethod.wetype.pinyin`, 微信输入法). Source identity does
not establish its language mode or participation in a given key. In the earlier
non-exportable observation, the native input tool rejected a modifier-only
`Shift_L` request before execution. No language-mode change followed, and no
synthetic composition or pasted Chinese text was used as an IME result.

## Remaining manual observation

Use the already configured input method in Chinese mode. In the empty Prompt,
type `ni`, choose the candidate `你`, then submit the committed text. Click
**Save observed trace** and retain that new file separately. A usable record
must actually contain the candidate/pre-edit/commit sequence and application
outcome; the presence of an input method, a Chinese character, a running
observer or this ordinary-key download does not satisfy that condition.

The user's older observer tab and its existing drafts were not edited. The
current page is a separate agent-created tab marked for handoff.
The earlier temporary port 63119 server was stopped; port 63120 remains active
for this handoff. No stable package or external service was published.
