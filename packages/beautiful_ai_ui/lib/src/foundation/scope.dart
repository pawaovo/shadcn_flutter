import 'package:flutter/widgets.dart';

import '../implementation/shadcn/theme_adapter.dart';
import 'environment.dart';
import 'layout.dart';
import 'motion.dart';
import 'theme.dart';

/// Selects the light, dark, or platform theme.
enum BeautifulUiThemeMode {
  /// Follow the platform brightness.
  system,

  /// Always use the light theme.
  light,

  /// Always use the dark theme.
  dark,
}

/// Installs Beautiful AI UI theme, adaptive policy, and shadcn infrastructure.
///
/// Place this below a [WidgetsApp] or another widget that provides
/// [MediaQuery]. Public modules intentionally do not expose shadcn_flutter
/// theme or infrastructure types.
///
/// Theme changes are atomic so package-owned and internal shadcn colors never
/// show different interpolation phases. [motion] governs module motion and
/// still yields to the platform's disabled-animation preference.
///
/// Example:
/// ```dart
/// WidgetsApp(
///   color: const Color(0xff0285ff),
///   builder: (context, child) => BeautifulUiScope(
///     child: child ?? const SizedBox.shrink(),
///   ),
/// )
/// ```
final class BeautifulUiScope extends StatelessWidget {
  /// Creates a Beautiful AI UI scope.
  ///
  /// Parameters:
  /// - [child] (`Widget`, required): Subtree receiving the environment.
  /// - [theme] (`BeautifulUiThemeData`, default: light foundation): Light
  ///   semantic tokens.
  /// - [darkTheme] (`BeautifulUiThemeData`, default: dark foundation): Dark
  ///   semantic tokens.
  /// - [themeMode] (`BeautifulUiThemeMode`, default: `system`): Selection mode.
  /// - [breakpoints] (`BeautifulUiBreakpoints`, default: 600/1024): Nominal
  ///   layout thresholds.
  /// - [motion] (`BeautifulMotionPolicy`, default: `system`): Motion policy.
  ///
  /// A surrounding [MediaQuery] is required for platform brightness,
  /// high-contrast, text-scale, and reduced-motion behavior.
  const BeautifulUiScope({
    super.key,
    required this.child,
    this.theme = const BeautifulUiThemeData.light(),
    this.darkTheme = const BeautifulUiThemeData.dark(),
    this.themeMode = BeautifulUiThemeMode.system,
    this.breakpoints = const BeautifulUiBreakpoints(),
    this.motion = BeautifulMotionPolicy.system,
  });

  /// The subtree that receives the package environment.
  final Widget child;

  /// The light semantic theme.
  final BeautifulUiThemeData theme;

  /// The dark semantic theme.
  final BeautifulUiThemeData darkTheme;

  /// How the active theme is selected.
  final BeautifulUiThemeMode themeMode;

  /// Responsive layout thresholds.
  final BeautifulUiBreakpoints breakpoints;

  /// Motion accessibility policy.
  final BeautifulMotionPolicy motion;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final platformBrightness = media?.platformBrightness ?? Brightness.light;
    final selected = switch (themeMode) {
      BeautifulUiThemeMode.light => theme,
      BeautifulUiThemeMode.dark => darkTheme,
      BeautifulUiThemeMode.system =>
        platformBrightness == Brightness.dark ? darkTheme : theme,
    };
    final effectiveTheme = media?.highContrast ?? false
        ? selected.highContrast()
        : selected;

    return ShadcnLayerAdapter(
      theme: effectiveTheme,
      // Beautiful UI switches all semantic tokens atomically. Keep package
      // tokens and internal shadcn controls synchronized until both can share
      // one package-owned theme tween.
      animateTheme: false,
      child: child,
      builder: (context, child) {
        return DefaultTextStyle.merge(
          style: effectiveTheme.typography.body.copyWith(
            color: effectiveTheme.colors.ink,
          ),
          child: BeautifulUiEnvironment(
            breakpoints: breakpoints,
            motionPolicy: motion,
            child: BeautifulUiTheme(
              data: effectiveTheme,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}
