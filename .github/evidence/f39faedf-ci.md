# Exact-commit CI evidence: f39faedf

This record belongs to `f39faedfcb0e09f57e29fd8edbfab98b808164b9`.
Later native ATK parent repairs and observer diagnostics need their own runtime
verification. [The JSON record](./f39faedf-ci.json) retains run/job IDs and core
report hashes; downloaded evidence is under `/tmp/beautiful-ci-f39faedf`.

| Run | Result | Boundary |
| --- | --- | --- |
| [Main 33827337805](https://github.com/pawaovo/shadcn_flutter/actions/runs/33827337805) | **12/12 jobs passed** | Actual iOS simulator driver exit 0 was checked in its report. Builds, complete journeys and package checks passed. |
| [Input/AT 33827337737](https://github.com/pawaovo/shadcn_flutter/actions/runs/33827337737) | **4/9 jobs passed** | Three native framework targets and GTK Orca capability passed. Firefox's independent W3C suite passed, but its combined job still failed the retained framework composition check. |
| [Catalog Orca 33827344230](https://github.com/pawaovo/shadcn_flutter/actions/runs/33827344230) | **No full task accepted** | PTY/preflight and actual Theme keyboard focus/action worked; the reader spoke the enclosing panel instead of the expected Theme label. |

The retained Web framework composition checks also fail in the recorded stock
control and must not be presented as a Prompt-specific OS IME defect. Firefox
completed the full trusted W3C workflow. Chrome, Edge and Safari passed readonly
copy and Cut rejection, then did not produce the required collapsed caret after
ArrowRight. Paste was not issued. On Chrome/Edge the recorded DOM and Flutter
selections both remained `0:109`; Safari does not have an equivalent observed
post-ArrowRight DOM trace. No document deletion is inferred.

The actual Catalog pilot selected this exact source SHA in both runner and build
provenance. One Tab focused Theme and Space changed it to `Theme: light`, with
native `focused=true` and `enabled=true`. Orca received the Theme focus event,
but on Space its active-window check found an intermediate filler with no parent
and concluded the control was outside the frame. It reset its locus to the
frame/panel. The real Where Am I handler subsequently emitted `panel.`; nonzero
audio cannot replace the missing exact Theme utterance. Thinking and Search
inspection then hit their existing eight-second subprocess limits. Cleanup and
PTY EOF/reader completion were verified.

Narrator again lacked a default WASAPI render endpoint (`0x80070490`) despite a
working fixture, ordinary keyboard response and a running Narrator process.
Application-wide AT acceptance, human speech review, physical-device acceptance
and OS IME acceptance remain separate and unestablished by these runs.
