# Original Catalog/Orca task verification — 79fbcdd1

The original three-task pilot completed successfully on source
`79fbcdd14fb7e1022def265df30c880cab9b4c21`: **3/3 tasks observed, exit 0**, with
no task or supervisor errors. It used an independently cloned Catalog, the full
official Linux arm64 debug/unoptimized engine and the separately rebuilt native
ATK bridge. Inspector tracing and debugger attachment were disabled. The original
240-second probe deadline, eight-second inspector timeout, task assertions,
WhereAmI handler, exact text, post-key PCM, quiet boundaries and cleanup checks
remained in force.

| Task | Actual keyboard/result evidence | Reader evidence |
|---|---|---|
| Theme | Tab focuses the named button; Space changes system to light | WhereAmI says “Theme: light push button.” |
| Thinking | Space collapses exactly one trace; a second Space restores it | WhereAmI says “Show steps thinking details collapsed push button.” and “Hide steps thinking details expanded push button.” |
| Search | Real keyboard query, result focus and Return commit select Find waffle cone suppliers | WhereAmI identifies the result, then the search field and its committed selected text |

Five independent reader checkpoints passed. Each observed the actual Orca
handler, the expected utterance after that command, real espeak-ng PCM, a single
speech-dispatcher audio client, silent PCM boundaries and unchanged application
state during the reader command.

| Checkpoint | PCM frames at 16 kHz | RMS |
|---|---:|---:|
| Theme light | 39,948 | 4,116.56 |
| Thinking collapsed | 68,118 | 4,260.40 |
| Thinking restored | 67,016 | 4,585.59 |
| Search result | 65,532 | 4,506.94 |
| Search committed | 95,551 | 4,231.72 |

The actual Catalog process mapped engine SHA-256
`763654ee12d84c51fb4c6a9937d18aa95b691f576df861ee6c1af51eaa14acab` and canonical
bridge SHA-256 `dcb5f71fdad78b45021ee162836218eb7069c0d75a220b6a0c466b605e457f74`.
The GTK preflight and Catalog each verified all 26 selected bridge dependency
mappings and file hashes. The engine source remains pinned to Flutter
`4cf24164269a5ebf0c16a028a00727d0e77bbb05`; the bridge source is GNOME
`46c8de80022d28eef2da58f1054b5bff745ed7e0` with reviewed patch
`2315f3fbb206a85af9baefedca8030751e26f01c629e9d20d003bfcf3941da7d`.

Execution took 112.819 seconds. Source, bundle and runtime binding remained
unchanged. Owned-process cleanup passed; the Orca PTY reached EOF, its reader
stopped, and its 1,257,157 original diagnostic bytes had no capture error. A
post-run process check found only the container's original `sleep infinity`.
All **56 raw artifact file hashes and sizes** were checked against the original
artifact manifest.

The [machine-readable evidence](catalog-79fbcdd1-orca.json) contains command
records, utterances, PCM statistics, actual mapped dependencies and exact
source/build/runtime/artifact hashes. Raw reports, native trees, logs and audio
remain at
`/tmp/beautiful-linux-runtime-build-20260904/work/validation/catalog-79fbcdd1-orca`.
The original 049 source attempt remains failed at 0/3; the two separately scoped
diagnostic attempts remain 1/3. None was overwritten.

This is representative machine evidence for the explicitly rebuilt Linux debug
runtime. It does not convert the stock SDK/release workflow, other platforms,
all components, performance results or human listening review into acceptance.
The ordinary release build and default CI environment were not modified.
