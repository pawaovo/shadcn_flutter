import 'package:flutter/services.dart';

var _loaded = false;

/// Loads the package's deterministic sans and mono fonts for golden tests.
Future<void> loadBeautifulTestFonts() async {
  if (_loaded) {
    return;
  }
  final sans = FontLoader('packages/shadcn_flutter/GeistSans')
    ..addFont(
      rootBundle.load('packages/shadcn_flutter/lib/fonts/Geist-Regular.otf'),
    );
  final mono = FontLoader('packages/shadcn_flutter/GeistMono')
    ..addFont(
      rootBundle.load(
        'packages/shadcn_flutter/lib/fonts/GeistMono-Regular.otf',
      ),
    );
  await Future.wait(<Future<void>>[sans.load(), mono.load()]);
  _loaded = true;
}
