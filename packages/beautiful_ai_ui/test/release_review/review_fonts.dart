import 'dart:io';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';

import '../test_fonts.dart';

var _loaded = false;

/// Explicit headless-review fallback; never downloaded by a Flutter test.
///
/// Run `python3 tool/release_review/prepare_review_fonts.py` first. The pinned
/// source, SHA-256, copyright, and OFL texts live beside the generated fonts.
Future<void> loadReviewFonts() async {
  if (_loaded) return;
  await loadBeautifulTestFonts();
  for (final (family, filename) in [
    ('ReviewNotoCJK', 'NotoSansCJKsc-Regular.otf'),
    ('ReviewNotoArabic', 'NotoSansArabic.ttf'),
  ]) {
    final file = File('build/release_review/fonts/$filename');
    if (!file.existsSync()) {
      throw StateError(
        'Missing review font $filename. Run '
        'python3 tool/release_review/prepare_review_fonts.py explicitly.',
      );
    }
    final bytes = ByteData.sublistView(await file.readAsBytes());
    // Default typography carries shadcn_flutter's package qualifier, which
    // Flutter also applies to fontFamilyFallback. Register that exact family.
    final loader = FontLoader('packages/shadcn_flutter/$family')
      ..addFont(Future.value(bytes));
    await loader.load();
  }
  _loaded = true;
}

/// Preserves the production styles while adding review-only glyph coverage.
BeautifulUiTypography reviewTypography([
  BeautifulUiTypography source = const BeautifulUiTypography(),
]) {
  const fallback = ['ReviewNotoArabic', 'ReviewNotoCJK'];
  return BeautifulUiTypography(
    body: source.body.copyWith(fontFamilyFallback: fallback),
    label: source.label.copyWith(fontFamilyFallback: fallback),
    caption: source.caption.copyWith(fontFamilyFallback: fallback),
    mono: source.mono.copyWith(fontFamilyFallback: fallback),
  );
}

/// Keeps every production token except the explicit test font fallbacks.
BeautifulUiThemeData reviewTheme(BeautifulUiThemeData source) =>
    BeautifulUiThemeData(
      colors: source.colors,
      radii: source.radii,
      spacing: source.spacing,
      typography: reviewTypography(source.typography),
      shadows: source.shadows,
      motion: source.motion,
    );
