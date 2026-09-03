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

The catalog exposes all six P1 modules and all seven P2 modules, theme cycling,
motion policy cycling, and responsive one/two/three-column layouts. Drafts,
filters, disclosure, and inspector values survive layout and theme changes.

P2 examples include complete/live/failed Streaming Text with citations,
copy/feedback/follow-up actions and retry; a three-question Approval Card;
Tool Chips with output and changed-file disclosure; both Task Rows variants;
Chat with context tabs, send, and stop; a status Filter Table; and a controlled
Fine-tune Card with numeric entry, layout, and type selection. The **Run stream
demo** action and Chat replies use finite local timers owned by the catalog.
Submission and retry examples resolve locally. No AI backend is connected,
and the excluded Surfer demonstration video is never requested.

Run catalog widget tests:

```bash
flutter test
```

Tests cover P1 and P2 interactions, compact layouts, and state preservation when
resizing from a desktop grid to a phone viewport. The shared device journey
exercises P1 actions followed by all seven P2 modules with scoped controls, so
repeated labels such as Copy, Retry, and Send remain unambiguous.

Run the shared device journey with Flutter Test on Android or Linux:

```bash
flutter test integration_test/catalog_journey_test.dart -d <device>
```

Web integration uses `flutter drive`, a matching ChromeDriver, and the
`test_driver/integration_test.dart` adapter because Flutter 3.47 does not run
`integration_test` through `flutter test -d chrome`.
