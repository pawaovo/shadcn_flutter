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

The current catalog exposes the complete P1 module set, theme cycling, motion
policy cycling, and responsive one/two/three-column layouts. It contains no AI
backend and makes no request for the excluded Surfer demonstration video.

Run the shared device journey with Flutter Test on Android or Linux:

```bash
flutter test integration_test/catalog_journey_test.dart -d <device>
```

Web integration uses `flutter drive`, a matching ChromeDriver, and the
`test_driver/integration_test.dart` adapter because Flutter 3.47 does not run
`integration_test` through `flutter test -d chrome`.
