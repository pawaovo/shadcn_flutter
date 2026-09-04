# Linux SDK accessibility boundaries at bff08825

This is a local upstream-report draft, not a submitted issue or an SDK patch.
It describes Flutter 3.47.0 / framework revision
`4cf24164269a5ebf0c16a028a00727d0e77bbb05` and the actual
[Catalog Orca run 33830848233](https://github.com/pawaovo/shadcn_flutter/actions/runs/33830848233)
at source `bff08825bf9bc48a074a261ec9f912a1058058a2`.

## Dynamic accessible names

The native parent repair passes all three real FlView initialization/lifetime
cases. In the actual Catalog, Theme's complete reverse parent chain reaches
the same-process frame and every parent/child inverse is verified. Orca now
keeps its locus on Theme instead of resetting to the enclosing panel.

One real Tab focuses `Theme: system`; Space changes the actual native name to
`Theme: light`. Both the after-action and after-reader-command AT-SPI trees
report `Theme: light`, with focus retained. However, a subsequently invoked
real Where Am I handler generates `Theme: system push button.`

This is not merely old speech left in the output queue. The observer establishes
actual silence and takes a new debug-stream byte offset before issuing the
reader command. The final 8,000 PCM frames before that command are all zero;
the recorded speech quiet interval is 0.607445 seconds. The new handler begins
at 02:49:42.245764 UTC and generates the old name at 02:49:42.254374 UTC.
The retained log has no corresponding accessible-name property-change event.

The pinned engine's `fl_accessible_node_set_name_impl`, in
`engine/src/flutter/shell/platform/linux/fl_accessible_node.cc:364`, frees and
duplicates its private name. It does not emit property notification or call
`atk_object_set_name`. The existing SetName engine test checks the getter only.
The observed fresh-getter/reader-name mismatch is consistent with this missing
notification contract. A proper SDK correction needs a real name-change signal
regression in addition to the getter check; clearing a reader cache or replacing
the application's semantic identity would not establish that contract.

## Expanded and expandable state

The same pinned implementation's complete `ref_state_set` and `set_flags`
paths omit `ATK_STATE_EXPANDED` and `ATK_STATE_EXPANDABLE`, including their
change notifications. Dart's expanded semantics therefore cannot establish
these native states through this SDK path. The actual Thinking disclosure's
native expanded/expandable state remains absent in the recorded run.

Thinking also omitted an explicit enabled flag in its own Dart semantics.
That is a separate application repair following this run; adding enabled does
not correct the SDK's expanded-state mapping. These two issues must not be
merged into a claim that every disclosure state was repaired.

## Evidence and next boundary

Original artifacts are retained under `/tmp/beautiful-ci-bff08825` and the
linked run. Relevant files are `theme-before-native-tree.json`,
`theme-after-native-tree.json`,
`theme-light-after-reader-command-native-tree.json`, `orca-debug.log`, and the
task's audio/quiet evidence. The CI archive preserves their exact source and
hashes when collected.

The application and reader assertions remain unchanged. No fake name/state
events, reader-cache reset, semantic-node replacement, local SDK mutation or
upstream message was used to accept this run. Full Linux screen-reader
acceptance remains open pending a verified SDK correction and another actual
reader run, followed by human speech review.
