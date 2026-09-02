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

The current catalog exposes the Loading State variants, theme cycling, motion
policy cycling, and responsive one/two-column layouts. It contains no AI
backend and makes no request for the excluded Surfer demonstration video.
