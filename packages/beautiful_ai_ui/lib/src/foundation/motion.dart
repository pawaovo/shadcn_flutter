import 'package:flutter/animation.dart';

/// Controls how decorative and continuous motion is presented.
enum BeautifulMotionPolicy {
  /// Follow the platform accessibility preference.
  system,

  /// Keep only short state transitions and remove continuous decoration.
  reduced,

  /// Disable non-essential motion.
  none,
}

/// Semantic motion tokens shared by Beautiful AI UI modules.
final class BeautifulUiMotion {
  /// Creates a motion token set.
  const BeautifulUiMotion({
    this.quick = const Duration(milliseconds: 120),
    this.standard = const Duration(milliseconds: 220),
    this.slow = const Duration(milliseconds: 420),
    this.loop = const Duration(milliseconds: 1400),
    this.outCurve = const Cubic(0.23, 1, 0.32, 1),
    this.inOutCurve = const Cubic(0.77, 0, 0.175, 1),
  });

  /// A quick feedback transition.
  final Duration quick;

  /// The default state transition duration.
  final Duration standard;

  /// A deliberate entrance or disclosure duration.
  final Duration slow;

  /// The default duration for continuous loading motion.
  final Duration loop;

  /// The standard emphasized exit curve.
  final Curve outCurve;

  /// The standard emphasized bidirectional curve.
  final Curve inOutCurve;
}
