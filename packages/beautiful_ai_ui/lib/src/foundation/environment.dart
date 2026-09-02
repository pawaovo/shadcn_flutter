import 'package:flutter/widgets.dart';

import 'layout.dart';
import 'motion.dart';

/// Internal environment shared by module implementations.
final class BeautifulUiEnvironment extends InheritedWidget {
  /// Creates the internal environment installed by [BeautifulUiScope].
  const BeautifulUiEnvironment({
    super.key,
    required this.breakpoints,
    required this.motionPolicy,
    required super.child,
  });

  /// Width thresholds shared by module implementations.
  final BeautifulUiBreakpoints breakpoints;

  /// Motion policy shared by module implementations.
  final BeautifulMotionPolicy motionPolicy;

  /// Returns the closest internal environment.
  static BeautifulUiEnvironment of(BuildContext context) {
    final environment = context
        .dependOnInheritedWidgetOfExactType<BeautifulUiEnvironment>();
    assert(environment != null, 'No BeautifulUiEnvironment found in context');
    return environment!;
  }

  /// Resolves a layout mode from local constraints with a MediaQuery fallback.
  BeautifulLayoutMode modeFor(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final mediaWidth = MediaQuery.maybeSizeOf(context)?.width;
    final width = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : mediaWidth;
    if (width == null || !width.isFinite || width < 0) {
      throw FlutterError(
        'Beautiful AI UI modules require finite local width constraints or a '
        'MediaQuery with a finite width.',
      );
    }
    return breakpoints.resolve(width);
  }

  /// Whether continuous decorative motion is allowed in the current context.
  bool continuousMotionEnabled(BuildContext context) {
    final platformDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (platformDisabled) {
      return false;
    }
    return motionPolicy == BeautifulMotionPolicy.system;
  }

  @override
  bool updateShouldNotify(BeautifulUiEnvironment oldWidget) {
    return oldWidget.breakpoints != breakpoints ||
        oldWidget.motionPolicy != motionPolicy;
  }
}
