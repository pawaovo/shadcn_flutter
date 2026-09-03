# Beautiful AI UI Catalog

Multi-platform visual, interaction, accessibility, and integration harness for
`beautiful_ai_ui`.

Run on the Web:

```bash
flutter run -d chrome
```

Build both Web render targets:

```bash
flutter build web --release --dart-define=ENABLE_WEB_SEMANTICS=true
flutter build web --release --wasm --dart-define=ENABLE_WEB_SEMANTICS=true
```

`ENABLE_WEB_SEMANTICS` applies only on Web (`kIsWeb && flag`). Ordinary native
runs use the operating system's accessibility lifecycle. Forcing the Web
semantics handle on macOS previously prevented the expected native AX tree
from being exposed; the current scoped behavior was checked with a no-flag
native A/B run. The [native semantics evidence](../../docs/beautiful-ui/quality_evidence/2026-09-03-native-semantics.md)
keeps this tree inspection separate from a complete VoiceOver workflow.

The catalog exposes all 20 P1, P2, and P3 modules, theme cycling, and motion
policy cycling. P1/P2 use a responsive one/two/three-column grid. The seven P3
sections use the full available width so Records Table and Flowchart can expose
their desktop grid and canvas; narrow windows use cards and ordered steps.
Drafts, filters, disclosure, and inspector values survive layout and theme changes.

P2 examples include complete/live/failed Streaming Text with citations,
copy/feedback/follow-up actions and retry; a three-question Approval Card;
Tool Chips with output and changed-file disclosure; both Task Rows variants;
Chat with context tabs, send, and stop; a status Filter Table; and a controlled
Fine-tune Card with numeric entry, layout, and type selection. The **Run stream
demo** action uses a finite local timer owned by the catalog. Chat replies stay
pending until **Complete demonstration response** or **Stop response** is
selected, allowing either state to be inspected without a time limit.
Submission and retry examples resolve locally. No AI backend is connected,
and the excluded Surfer demonstration video is never requested.

P3 examples are complete local host integrations:

- **Prompt Bar** accepts `/` commands and `@` sources, switches models, attaches
  sample files, inserts a sample dictation transcript, and receives submissions.
  Rounded/pill and compact/tall variants retain the same draft. The sample
  dictation control does not request a microphone.
- **Diff Table** reviews added, changed, removed, and unchanged records, keeps
  inclusion across pages, and applies exactly the chosen change IDs. Reset
  starts a fresh proposal.
- **Records Table** searches and sorts supplier records, selects rows, edits
  accepted property settings, adds properties, and calculates visible rows using
  deterministic local sample rules. Configuration and results are supplied back
  by the catalog host, making acceptance visible in the table.
- **Sidebar Nav** switches workspaces and destinations, searches recent chats,
  creates local sample chats/workspaces, and exposes workspace action previews.
  Its explicit expanded/drawer presentation follows the surrounding layout.
- **Flowchart** edits a stock threshold in ordered steps or the desktop canvas,
  where node movement and viewport controls are available. Changes update the
  host workflow snapshot.
- **Insight Cards** includes comparison, anomaly, and allocation charts with
  exact observations, chart-data disclosure, metric/segment selection, and
  follow-up actions.
- **Selection Actions** starts with a real selected document range, prepares
  local sample rewrites/explanations, and updates the document only when the
  user keeps a proposed edit. Reset restores the original passage.

Run catalog widget tests:

```bash
flutter test
```

Tests cover P1, P2, and P3 interactions, compact layouts, and state preservation
when resizing from a desktop grid/canvas to a phone viewport. The shared device
journey exercises all 20 modules with scoped controls, so
repeated labels such as Copy, Retry, and Send remain unambiguous.

Run the shared device journey with Flutter Test on an available native target
such as Android, Linux, macOS, Windows, or an iOS simulator:

```bash
flutter test integration_test/catalog_journey_test.dart -d <device>
```

Web integration uses `flutter drive`, a matching ChromeDriver, and the
`test_driver/integration_test.dart` adapter because Flutter 3.47 does not run
`integration_test` through `flutter test -d chrome`.

The current local suite passed **19 Catalog tests** and strict Catalog
analysis; the library passed 528 tests and its strict analyzer. The complete
ordinary macOS journey also passed. The second twelve-job
[run `33741053163`](https://github.com/pawaovo/shadcn_flutter/actions/runs/33741053163)
finished with 11 successful jobs, one failure and no skips. Strict Linux
goldens and publish validation passed, including the isolated hosted consumer
and a zero-warning 3 MB dry-run. Apple release builds, macOS journey and
simulator boot passed. Two of four launcher self-tests failed with cleanup
`EPERM`, so the actual simulator build/journey did not begin. The implemented
cleanup fix passes six local regression checks and actionlint; actual remote
simulator execution remains pending. Earlier CI history stays in readiness.

The Catalog now uses independently drawn launcher/Web artwork. The exact
source and generated files are recorded in
[`legal/assets.yaml`](../../legal/assets.yaml). Fresh JavaScript, Wasm, and
macOS release artifact audits verified the registered font/media hashes and
complete notices, including 266 flag images and five original Web images.
The real Flutter `LicenseRegistry` probe verified 13 complete labels.

For native workload measurement, the opt-in
[`tool/run_p3_profile.sh`](tool/run_p3_profile.sh) runner creates a separate
profile fixture and saves raw artifacts under `build/p3-profile/`. The historical
[macOS profile record](../../docs/beautiful-ui/quality_evidence/performance/2026-09-03-macos-profile/README.md)
completed all seven P3 workloads with 4,524 frame samples and 480 RSS samples
on an M1 Pro/32 GiB machine at 1,728×963 logical pixels, DPR 2, 120 Hz. It
records measured spikes and process-memory limitations. Run `20260903T080855Z`
predates the final palette, muted-ticker and hosted-adapter changes. Final
profile run 4 has not started: the local Mac is locked and Computer Use
requires manual user unlock. Product budgets, repeatability and other
platforms remain separate acceptance work.

The final 49-image source capture includes the hosted-adapter correction,
which changed no reviewed image or golden pixels. Eight Linux component
candidates from run `33736546039` were accepted. Latest portable-source Wasm
and ordinary macOS release builds passed. Safari's visual recheck after the
TickerMode fix is unfinished and also requires manual Mac unlock; the next
CI run must verify the launcher self-test fix and actual iOS simulator journey.

The [49-image review](../../docs/beautiful-ui/quality_evidence/2026-09-03-accessibility-visual-review.md)
and [release-readiness record](../../docs/beautiful-ui/quality_evidence/2026-09-03-release-readiness.md)
track specific visual/input corrections and remaining gates. All twenty
modules are implemented, all 27 registry entries remain `in_progress`, and
all six platform support states are `Partial`.
