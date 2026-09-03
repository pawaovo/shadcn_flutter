import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../../foundation/theme.dart';

/// Internal mapping from package-owned semantic tokens to shadcn_flutter.
abstract final class ShadcnThemeAdapter {
  /// Converts package-owned semantic theme data to the current shadcn theme.
  static shad.ThemeData fromBeautifulTheme(BeautifulUiThemeData theme) {
    final colors = theme.colors;
    final baseTypography = const shad.Typography.geist();
    return shad.ThemeData(
      colorScheme: shad.ColorScheme(
        brightness: colors.brightness,
        background: colors.page,
        foreground: colors.ink,
        card: colors.surface,
        cardForeground: colors.ink,
        popover: colors.surface,
        popoverForeground: colors.ink,
        primary: colors.accent,
        primaryForeground: colors.accentForeground,
        secondary: colors.inset,
        secondaryForeground: colors.ink,
        muted: colors.hover,
        mutedForeground: colors.inkMuted,
        accent: colors.accentTint,
        accentForeground: colors.foregroundOn(colors.accentTint),
        destructive: colors.destructive,
        destructiveForeground: colors.destructiveForeground,
        border: colors.line,
        input: colors.lineStrong,
        ring: colors.accent,
        chart1: colors.accent,
        chart2: colors.success,
        chart3: colors.warning,
        chart4: colors.destructive,
        chart5: colors.inkMuted,
      ),
      radius: theme.radii.card / 20,
      typography: baseTypography.copyWith(
        sans: () => theme.typography.body,
        mono: () => theme.typography.mono,
        small: () => theme.typography.body,
        base: () => theme.typography.body.copyWith(fontSize: 16),
        p: () => theme.typography.body.copyWith(fontSize: 16),
        inlineCode: () => theme.typography.mono,
        textSmall: () => theme.typography.label,
        textMuted: () => theme.typography.caption,
      ),
    );
  }
}

/// Internal host that installs shadcn infrastructure behind the package seam.
final class ShadcnLayerAdapter extends StatelessWidget {
  /// Creates the internal shadcn infrastructure host.
  const ShadcnLayerAdapter({
    super.key,
    required this.theme,
    required this.animateTheme,
    required this.child,
    required this.builder,
  });

  /// Package-owned semantic theme to map into shadcn.
  final BeautifulUiThemeData theme;

  /// Whether theme transitions are requested.
  final bool animateTheme;

  /// The subtree hosted by shadcn infrastructure.
  final Widget child;

  /// Installs package-owned environment scopes inside the shadcn layer.
  final Widget Function(BuildContext context, Widget? child) builder;

  @override
  Widget build(BuildContext context) {
    return shad.ShadcnLayer(
      theme: ShadcnThemeAdapter.fromBeautifulTheme(theme),
      scaling: shad.AdaptiveScaling.desktop,
      themeMode: shad.ThemeMode.light,
      enableThemeAnimation: animateTheme,
      builder: builder,
      child: child,
    );
  }
}
