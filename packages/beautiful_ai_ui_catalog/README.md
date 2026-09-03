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

Run the shared device journey with Flutter Test on Android or Linux:

```bash
flutter test integration_test/catalog_journey_test.dart -d <device>
```

Web integration uses `flutter drive`, a matching ChromeDriver, and the
`test_driver/integration_test.dart` adapter because Flutter 3.47 does not run
`integration_test` through `flutter test -d chrome`.
