# Complete Android journey with three native commits — f149ec29

The [single independent diagnostic run 33869603924](https://github.com/pawaovo/shadcn_flutter/actions/runs/33869603924)
at exact source `f149ec298a701d806661ab8ed4eb6085a037b70f` **passed the complete
original Android Catalog P1/P2/P3 journey**, with all three fixed native IME
candidate commits and all original assertions retained. The actual integration
Response contains `result: "true"` and `failureDetails: []`; the driver reports
`all_tests_passed=true`, three native clicks and no cleanup errors.

This was the independent diagnostic workflow, not a new main workflow run.
The historical [75594991 main result](75594991-ci.md) remains **11/12**, with
its original Android failure preserved. The separate
[entrypoint comparison](android-entrypoint-equivalence-f149ec29.json) records
matching main/manual Android emulator configuration and normalized build/run
commands, and unchanged runtime inputs; that comparison is not another CI
execution. No other platform or input/AT run is attributed to this source.

The job took **7 minutes 55 seconds**, including setup, compilation and
validation. The driver took **79.353 seconds**, and its final target snapshot
records `journey_status=passed` at **78.817 seconds**, within the unchanged
600-second overall deadline. Catalog remained the same actual process:
**PID 2392, start ticks 24739**.

| Fixed stage | Actual candidate | Composing range before native commit | Helper PID / start ticks | Native touches |
|---|---|---|---|---:|
| `chat_send` | `inventory` | `[11,20]` | 2330 / 6178 | 1 DOWN/UP pair |
| `prompt_command` | `rest` | `[1,5]` | 2511 / 29300 | 1 DOWN/UP pair |
| `prompt_send` | `restock` | `[21,28]` | 2570 / 30308 | 1 DOWN/UP pair |

All three candidates were actually observed as unique, visible, enabled,
clickable nodes in `com.android.inputmethod.latin/.LatinIME`. Their respective
IME window IDs were **3, 11 and 27**. Each helper used its own nonce, ticket,
process and JSONL event log. No stage had a second inspection or touch, and no
fallback text, key or focus action was used.

The raw native invocation and return times are retained separately:

| Stage | DOWN invoked / returned, device ms | UP invoked / returned, device ms |
|---|---|---|
| Chat | 281879 / 281983 | 281983 / 282158 |
| Prompt command | 295407 / 295515 | 295515 / 295722 |
| Prompt Send | 305618 / 305732 | 305732 / 305925 |

Both injection results are true for each pair, with `cancelled=false`. These
timestamps describe public API invocation/return, not a universal OS delivery
deadline. Stock atrace separately records three `InputConnection#commitText`
dispatches for actual Catalog PID 2392; the live Dart snapshots establish the
actual editing outcomes rather than treating those dispatches alone as proof.

The original actions completed as follows:

- **Chat:** native commit preserved exact `Check cone inventory`, selection
  `[20,20]` and primary focus while clearing composition. The final activation
  guard saw enabled Send. The original single Send produced the correct host
  user message, responding state and empty editor. The original Stop response,
  stopped-result and Suppliers-context assertions passed before this stage
  was marked done.
- **Prompt command:** native commit preserved exact `/rest`, selection `[5,5]`
  and primary focus with empty composition. At the actual Enter guard,
  Commands and the enabled restock option were each present once. The passive
  observer recorded one original KeyDown/KeyUp pair, framework handled=true,
  and resulting `/restock ` with selection `[9,9]` and empty composition.
- **Prompt Send:** native commit preserved exact `Prepare the seasonal
  restock`, selection `[28,28]` and primary focus with empty composition. The
  final activation snapshot also recorded model `precise` and one inventory
  attachment; the host checked those values before the native touch. The
  original Send produced exact host receipt `Prompt received: Prepare the
  seasonal restock · 1 files · precise`, and the editor became empty.

Both P3 passive observer reports have empty error lists. Each completed stage
records `original_action_passed`, `native_click_acknowledged`, `native_drained`
and `send_activation_checked` as true. Original draft insertion, Enter and
application-button taps retain their Flutter framework injection scope; the
three explicitly enumerated IME candidate touches are the native operations.

Completion extends beyond these three editing points. The source-bound
original journey sequentially awaits the remaining P3 Diff, Records, sidebar,
Flow, Insights and document-edit assertions. Its tail checks calculated and
saved supplier data, threshold 60, the allocation follow-up, accepted document
edit and final improved document prefix. The actual Flutter log then reaches
`(tearDownAll)` and `All tests passed!`, followed by the complete successful
Response. The [JSON evidence](android-candidate-f149ec29.json) links the exact
source and assertion lines; no separate per-card telemetry is invented.

Every stage's native event log contains successful `inspect`, `tap`, `stop`
and `finish`. Each helper was serially drained, retired and recorded as
`cleanup_verified=true` before the next helper could start. The last helper
remained until the complete original Response and was then retired. The
supervisor's final owned cleanup is verified, and both driver and supervisor
error/cleanup lists are empty. Platform semantics at each recorded original
activation was true; no semantics handle or verification hook was changed.

Cloud validation also passed the 50 headless regressions, 35 driver fixture
checks, three real Dart-to-Python wire cases, 19 host regressions, and actual
JVM checks (**46 ProtocolTest + 27 StageSpecTest**) before the real APK run.
Those checks remain distinct from the native observations above.

All **232** runner-manifest files were independently hash-verified after one
artifact download. All **325** recorded source inputs match before and after
execution. The JSON companion binds the original run/job/artifact, APK hashes,
candidate identities, before/after values, native returns, original Response,
retirement and core evidence hashes. The ZIP digest is GitHub-reported,
separate from the verified extracted-file hashes. Raw evidence remains at
`/tmp/beautiful-android-candidate-f149ec29-33869603924`.

This is representative machine evidence for the fixed API 35 LatinIME
emulator and the complete original Android journey. It does not establish
human IME acceptance, other languages/IMEs/devices, native performance or
all-platform acceptance. All earlier source-specific failures remain intact;
no UI action or CI run was retried.
