# Thinking focus ownership repair

The actual Linux diagnostic with the rebuilt GTK engine reached Thinking's
collapsed state, then Orca's Where Am I returned `panel grayed.`. The named
button was enabled and unfocused; its empty child panel was focused and had no
enabled flag. This is preserved in the original
`/tmp/beautiful-linux-runtime-build-20260904/work/validation/catalog-orca-trace-1`
artifacts. That diagnostic accepts only its Theme task; the Thinking failure
remains part of the record.

`_ThinkingControl` kept independent status semantics and also retained the
default FocusableActionDetector focus wrapper and GestureDetector tap wrapper.
The focus flag therefore belonged to an unnamed semantic child. The repair
moves real focus state and the existing non-iOS focus action onto the named
control, and disables only the two redundant semantic wrappers. Status remains
an independent child. Enabled, expanded, expand/collapse, activation callbacks
and the separate visual focus-highlight state are retained.

The new keyboard regression starts at a host autofocus control and uses Tab to
enter Thinking. The original component has one focused node in its subtree but
fails the requirement that the named button owns it. The repaired component
passes Tab, Space collapse and Space expand, retaining the same named focus
owner and independent status, without an empty focusable/actionable child.
Additional Linux/iOS checks preserve the SDK's focus-action platform contract.
The test also uses touch highlight mode so a painted focus indicator cannot
stand in for actual keyboard focus.

Targeted Thinking widget, semantics, long-trace and temporal coverage passes
**28/28**. The complete library suite then passes **658/658**; its expanded log
is `/tmp/beautiful-thinking-final-library-tests.log`. Targeted strict analysis
and formatting pass. These are component tests; a new full native Catalog/Orca
run with the repaired component and the independently patched ATK bridge still
has to validate the real reader outcome.
