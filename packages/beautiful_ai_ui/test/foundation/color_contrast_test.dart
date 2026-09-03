import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui/src/implementation/shadcn/theme_adapter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final highContrast in <bool>[false, true]) {
      final base = brightness == Brightness.light
          ? const BeautifulUiThemeData.light()
          : const BeautifulUiThemeData.dark();
      final theme = highContrast ? base.highContrast() : base;
      final colors = theme.colors;
      final variant = '${brightness.name}, highContrast=$highContrast';

      test('semantic text stays readable on content surfaces for $variant', () {
        // Fixed and hovered surfaces used by Search, Context, Code Block,
        // Thinking, and Selection Actions; tint roles also host metadata and
        // citation/node-kind text in streaming answers and Flowchart.
        final backgrounds = <String, Color>{
          'page': colors.page,
          'surface': colors.surface,
          'inset': colors.inset,
          'canvas': colors.canvas,
          'field': colors.field,
          'hover': colors.hover,
          'hoverStrong': colors.hoverStrong,
          'accentTint': colors.accentTint,
          'successTint': colors.successTint,
          'warningTint': colors.warningTint,
          'destructiveTint': colors.destructiveTint,
        };
        final foregrounds = <String, Color>{
          'ink': colors.ink,
          'inkMuted': colors.inkMuted,
          'inkSubtle': colors.inkSubtle,
          'accentInk': colors.accentInk,
        };
        for (final background in backgrounds.entries) {
          for (final foreground in foregrounds.entries) {
            expect(
              _contrast(foreground.value, background.value, colors.surface),
              greaterThanOrEqualTo(4.5),
              reason: '${foreground.key} text on ${background.key}',
            );
          }
        }
        for (final foreground in <Color>[
          colors.tooltipForeground,
          colors.tooltipMuted,
        ]) {
          expect(
            _contrast(foreground, colors.tooltipBackground, colors.surface),
            greaterThanOrEqualTo(4.5),
            reason: 'Tooltip text on its declared floating background',
          );
        }

        final ink = colors.ink.computeLuminance();
        final muted = colors.inkMuted.computeLuminance();
        final subtle = colors.inkSubtle.computeLuminance();
        if (brightness == Brightness.light) {
          expect(ink, lessThan(muted));
          expect(muted, lessThan(subtle));
        } else {
          expect(ink, greaterThan(muted));
          expect(muted, greaterThan(subtle));
        }
      });

      test('filled action text meets 4.5:1 across $variant palettes', () {
        for (final (background, foreground) in <(Color, Color)>[
          (colors.accent, colors.accentForeground),
          (colors.success, colors.successForeground),
          (colors.destructive, colors.destructiveForeground),
        ]) {
          expect(
            _contrast(foreground, background, colors.surface),
            greaterThanOrEqualTo(4.5),
          );
        }
        // Accent/chart hue roles are preserved; this is a foreground fix.
        expect(colors.accent, base.colors.accent);
        expect(colors.accentInk, base.colors.accentInk);
        expect(colors.success, base.colors.success);
        expect(colors.destructive, base.colors.destructive);
      });

      test('accent hover stays readable throughout interpolation for $variant', () {
        for (var step = 0; step <= 100; step++) {
          final background = Color.lerp(
            colors.accent,
            colors.accentHover,
            step / 100,
          )!;
          expect(
            _contrast(colors.accentForeground, background, colors.surface),
            greaterThanOrEqualTo(4.5),
            reason:
                'The same text must remain readable at hover progress ${step / 100}.',
          );
        }
      });

      test(
        'shadcn adapter shares readable filled foregrounds for $variant',
        () {
          final adapted = ShadcnThemeAdapter.fromBeautifulTheme(theme)
              .colorScheme;
          expect(
            _contrast(
              adapted.primaryForeground,
              adapted.primary,
              colors.surface,
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(
              // The adapter also populates this legacy interoperability slot.
              // ignore: deprecated_member_use
              adapted.destructiveForeground,
              adapted.destructive,
              colors.surface,
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(adapted.accentForeground, adapted.accent, colors.surface),
            greaterThanOrEqualTo(4.5),
          );
          expect(adapted.chart1, base.colors.accent);
          expect(adapted.chart2, base.colors.success);
          expect(adapted.chart4, base.colors.destructive);
        },
      );

      test(
        'foreground derivation covers tinted and arbitrary fills for $variant',
        () {
          for (final alpha in <int>[64, 128, 255]) {
            for (final red in <int>[0, 51, 102, 153, 204, 255]) {
              for (final green in <int>[0, 51, 102, 153, 204, 255]) {
                for (final blue in <int>[0, 51, 102, 153, 204, 255]) {
                  final background = Color.fromARGB(alpha, red, green, blue);
                  expect(
                    _contrast(
                      colors.foregroundOn(background),
                      background,
                      colors.surface,
                    ),
                    greaterThanOrEqualTo(4.5),
                    reason: 'Foreground for ARGB($alpha, $red, $green, $blue)',
                  );
                }
              }
            }
          }
        },
      );
    }
  }
}

double _contrast(Color foreground, Color background, Color surface) {
  final paintedBackground = Color.alphaBlend(background, surface);
  final paintedForeground = Color.alphaBlend(foreground, paintedBackground);
  final a = paintedForeground.computeLuminance();
  final b = paintedBackground.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}
