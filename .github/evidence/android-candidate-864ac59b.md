# Android P3 observation — 864ac59b

The [single manual run 33865319762](https://github.com/pawaovo/shadcn_flutter/actions/runs/33865319762)
at exact source `864ac59b523c278ef7ca99d7aad7d0c13015f377` completed with
**failure**. APK build, native Chat candidate commit, unchanged Chat text,
single original Chat Send and its corrected observer succeeded. The complete
original Response was received with `all_tests_passed=false`; the later Prompt
Send host-receipt assertion failed at `catalog_journey_test.dart:356`.

The new passive P3 evidence is complete in
`reportData.prompt_input_diagnostics`, with no observer errors:

| Original action/checkpoint | Actual state |
|---|---|
| Slash before Enter, 1044933 µs | `/rest`, selection 5, empty composition, primary focus; Commands and enabled restock option each present once |
| Enter Down, 1161191 µs | Same input and focus |
| Controller change, 1164523 µs | `/restock `, selection 9, empty composition |
| Enter Up / returned result | Same new text; `key_down_handled_by_framework=true` |
| Later controller change, 1231136 µs | Same `/restock ` text; composition changed to `[1,5]` |
| Prompt before Send, 403733 µs | `Prepare the seasonal restock`, selection 28, empty composition, primary focus, Send enabled |
| Controller change during original Send operation, 776664 µs | Same full text/selection/focus; composition changed to `[21,28]` |
| After original Send and pump, 1480600 µs | Same text and focus, composition `[21,28]`, Send disabled, Sending count 0, no host receipt |

Times are relative to each action's observer. Controller identity `198723207`
and focus identity `608540670` remain stable. This run demonstrates the actual
composition transition between the Prompt Send checkpoints; it does not have
an exact P3 pointer-down timestamp. Slash succeeded here, so its observations
do not retrospectively determine why the [755 slash assertion](android-candidate-75594991.md)
failed. No P3 native candidate tree was inspected, and no candidate existence
or successful P3 native commit is inferred.

The actual native Chat operation bound Catalog PID **2395**, start ticks
**25676**, and helper PID **2333**. One LatinIME `inventory` candidate received
DOWN at device elapsed **290633 ms** and UP at **290736 ms**, with successful
returns at **290736 ms** and **290757 ms**, no cancellation and no second tap.
Actual VM input subsequently retained the original text with empty composition
and passed the final activation guard. Both driver and supervisor cleanup
error arrays are empty, owned cleanup is verified, and native drain is true.

The [JSON companion](android-candidate-864ac59b.json) preserves the complete
original Response, both P3 reports, native timing, process/APK identity,
cleanup and source-bound file hashes. All **102** runner-manifest files were
independently verified after one artifact download. The GitHub ZIP digest is
retained as reported, separately from those verified file hashes. Raw evidence
remains under `/tmp/beautiful-android-candidate-864ac59b-33865319762`.

No assertion, composition protection, original input or wait was relaxed. This
failed source is preserved while a separately reviewed, explicitly limited
multi-stage native candidate diagnostic is prepared. No workflow was retried.
