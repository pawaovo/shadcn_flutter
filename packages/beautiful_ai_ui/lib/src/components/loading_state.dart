import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/layout.dart';
import '../foundation/theme.dart';

/// Formats caller-owned elapsed time for [BeautifulLoadingState].
///
/// Parameters:
/// - [elapsed] (`Duration`, required): Non-negative elapsed operation time.
///
/// Returns: `String` — localized visible and non-live semantic text.
typedef BeautifulElapsedFormatter = String Function(Duration elapsed);

/// Visual treatments supported by [BeautifulLoadingState].
enum BeautifulLoadingVariant {
  /// Square pixels with a chevron wavefront.
  drive,

  /// Circular pixels with a chevron wavefront.
  dots,

  /// A pixel comet that follows the grid perimeter.
  orbit,

  /// The drive loader paired with optional caller-owned media.
  surfer,
}

/// Displays accessible status for a long-running operation.
///
/// Elapsed time is declarative: the caller owns the clock and supplies updated
/// [elapsed] values. This keeps the module deterministic and prevents a demo
/// timer from becoming application behavior.
///
/// The module owns the four visual variants, constraint-based layout,
/// status/elapsed Semantics, reduced-motion substitutions, and animation
/// lifecycle. It never starts a network request or a wall-clock timer.
///
/// Example:
/// ```dart
/// const BeautifulLoadingState(
///   label: 'Preparing workspace',
///   variant: BeautifulLoadingVariant.orbit,
///   elapsed: Duration(seconds: 12),
/// )
/// ```
final class BeautifulLoadingState extends StatefulWidget {
  /// Creates a loading status module.
  ///
  /// Parameters:
  /// - [label] (`String`, required): Non-empty status description.
  /// - [variant] (`BeautifulLoadingVariant`, default: `drive`): Visual mode.
  /// - [elapsed] (`Duration?`, optional): Caller-owned non-negative time.
  /// - [elapsedFormatter] (`BeautifulElapsedFormatter?`, optional): Localized
  ///   formatting override.
  /// - [elapsedSemanticLabel] (`String`, default: `Elapsed time`): Localized
  ///   label for the separate, non-live elapsed node.
  /// - [surferMedia] (`Widget?`, optional): Licensed, non-interactive media.
  /// - [surferFallbackLabel] (`String`, default: `Media unavailable`):
  ///   Localizable fallback description.
  ///
  /// Assertions: [label] and [elapsedSemanticLabel] must be non-empty. A
  /// negative [elapsed] value asserts when the widget builds in debug mode.
  const BeautifulLoadingState({
    super.key,
    required this.label,
    this.variant = BeautifulLoadingVariant.drive,
    this.elapsed,
    this.elapsedFormatter,
    this.elapsedSemanticLabel = 'Elapsed time',
    this.surferMedia,
    this.surferFallbackLabel = 'Media unavailable',
  }) : assert(label.length > 0),
       assert(elapsedSemanticLabel.length > 0);

  /// Human-readable description of the work in progress.
  final String label;

  /// The visual loading treatment.
  final BeautifulLoadingVariant variant;

  /// Elapsed operation time supplied by the caller.
  final Duration? elapsed;

  /// Optional localized formatter for [elapsed].
  ///
  /// When omitted, the module uses compact English units such as `12.3s` and
  /// `1m 0.0s` without rounding across a minute boundary.
  final BeautifulElapsedFormatter? elapsedFormatter;

  /// Localizable semantics label for the non-live elapsed-time node.
  final String elapsedSemanticLabel;

  /// Optional, caller-owned media for the [BeautifulLoadingVariant.surfer]
  /// treatment.
  ///
  /// The package deliberately does not bundle or download the unlicensed video
  /// used by the web reference implementation. The subtree is preserved across
  /// motion-policy changes and wrapped in [TickerMode]; hosts that provide
  /// platform video must also honor Flutter's reduced-motion preference. The
  /// media may provide descriptive Semantics but must not contain interactive
  /// controls; actions belong outside this status module.
  final Widget? surferMedia;

  /// Text shown in the media frame when [surferMedia] is not supplied.
  final String surferFallbackLabel;

  @override
  State<BeautifulLoadingState> createState() => _BeautifulLoadingStateState();
}

final class _BeautifulLoadingStateState extends State<BeautifulLoadingState>
    with TickerProviderStateMixin {
  late final AnimationController _gridController;
  late final AnimationController _shimmerController;
  bool? _motionEnabled;

  @override
  void initState() {
    super.initState();
    _gridController = AnimationController(
      vsync: this,
      duration: _gridDuration(widget.variant),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final environment = BeautifulUiEnvironment.of(context);
    final theme = BeautifulUiTheme.of(context);
    final enabled = environment.continuousMotionEnabled(context);
    if (_shimmerController.duration != theme.motion.loop) {
      _shimmerController.duration = theme.motion.loop;
    }
    if (_motionEnabled != enabled) {
      _motionEnabled = enabled;
      if (enabled) {
        _gridController.repeat();
        _shimmerController.repeat();
      } else {
        _gridController.stop();
        _shimmerController.stop();
        _gridController.value = 0;
        _shimmerController.value = 0;
      }
    }
  }

  @override
  void didUpdateWidget(BeautifulLoadingState oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant != widget.variant) {
      _gridController.duration = _gridDuration(widget.variant);
      _gridController.value = 0;
      if (_motionEnabled ?? false) {
        _gridController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _gridController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.elapsed == null || !widget.elapsed!.isNegative,
      'elapsed must not be negative',
    );
    final theme = BeautifulUiTheme.of(context);
    final elapsedLabel = widget.elapsed == null
        ? null
        : (widget.elapsedFormatter?.call(widget.elapsed!) ??
              _defaultElapsedLabel(widget.elapsed!));
    final motionEnabled = _motionEnabled ?? false;
    return LayoutBuilder(
      builder: (context, constraints) {
        final environment = BeautifulUiEnvironment.of(context);
        final mode = environment.modeFor(context, constraints);
        return _buildLayout(
          context,
          theme,
          mode,
          constraints,
          elapsedLabel,
          motionEnabled,
        );
      },
    );
  }

  Widget _buildLayout(
    BuildContext context,
    BeautifulUiThemeData theme,
    BeautifulLayoutMode mode,
    BoxConstraints constraints,
    String? elapsedLabel,
    bool motionEnabled,
  ) {
    final colors = theme.colors;
    final spacing = theme.spacing;
    final gap = mode == BeautifulLayoutMode.compact ? spacing.sm : 10.0;
    final statusVisual = Semantics(
      container: true,
      role: SemanticsRole.status,
      label: widget.label,
      hint:
          widget.variant == BeautifulLoadingVariant.surfer &&
              widget.surferMedia == null
          ? widget.surferFallbackLabel
          : null,
      child: Wrap(
        spacing: gap,
        runSpacing: spacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _PixelGrid(
            variant: widget.variant == BeautifulLoadingVariant.surfer
                ? BeautifulLoadingVariant.drive
                : widget.variant,
            animation: _gridController,
            color: colors.ink,
            motionEnabled: motionEnabled,
          ),
          _ShimmerLabel(
            label: widget.label,
            animation: _shimmerController,
            motionEnabled: motionEnabled,
            style: theme.typography.label,
            colors: colors,
          ),
        ],
      ),
    );
    final header = Wrap(
      spacing: gap,
      runSpacing: spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        statusVisual,
        if (elapsedLabel != null)
          Semantics(
            container: true,
            label: widget.elapsedSemanticLabel,
            value: elapsedLabel,
            child: ExcludeSemantics(
              child: Text(
                elapsedLabel,
                style: theme.typography.mono.copyWith(color: colors.inkMuted),
              ),
            ),
          ),
      ],
    );

    if (widget.variant != BeautifulLoadingVariant.surfer) {
      return header;
    }

    final availableWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : 224.0;
    final mediaWidth = math.min(224.0, availableWidth);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        header,
        SizedBox(height: spacing.sm),
        _SurferEntrance(
          motionEnabled: motionEnabled,
          child: Container(
            width: mediaWidth,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.tooltipBackground,
              borderRadius: BorderRadius.circular(theme.radii.card),
              border: Border.all(color: theme.shadows.overlayOutline),
              boxShadow: theme.shadows.overlay,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: widget.surferMedia != null
                  ? TickerMode(
                      enabled: motionEnabled,
                      child: widget.surferMedia!,
                    )
                  : ExcludeSemantics(
                      child: _SurferFallback(
                        animation: _gridController,
                        motionEnabled: motionEnabled,
                        label: widget.surferFallbackLabel,
                        color: colors.tooltipMuted,
                        accent: colors.accent,
                        style: theme.typography.mono,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

Duration _gridDuration(BeautifulLoadingVariant variant) {
  return Duration(
    milliseconds: variant == BeautifulLoadingVariant.orbit ? 950 : 650,
  );
}

String _defaultElapsedLabel(Duration elapsed) {
  final totalDeciseconds = math.max(0, elapsed.inMilliseconds ~/ 100);
  if (totalDeciseconds < 600) {
    return '${(totalDeciseconds / 10).toStringAsFixed(1)}s';
  }
  final minutes = totalDeciseconds ~/ 600;
  final remainingDeciseconds = totalDeciseconds % 600;
  return '${minutes}m ${(remainingDeciseconds / 10).toStringAsFixed(1)}s';
}

final class _SurferEntrance extends StatelessWidget {
  const _SurferEntrance({required this.motionEnabled, required this.child});

  final bool motionEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: motionEnabled
          ? const Duration(milliseconds: 200)
          : Duration.zero,
      curve: const Cubic(0.16, 1, 0.3, 1),
      child: child,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.95 + value * 0.05,
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }
}

final class _ShimmerLabel extends StatelessWidget {
  const _ShimmerLabel({
    required this.label,
    required this.animation,
    required this.motionEnabled,
    required this.style,
    required this.colors,
  });

  final String label;
  final Animation<double> animation;
  final bool motionEnabled;
  final TextStyle style;
  final BeautifulUiColors colors;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: style.copyWith(color: colors.inkMuted));
    if (!motionEnabled) {
      return ExcludeSemantics(child: text);
    }
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: animation,
        child: text,
        builder: (context, child) {
          final center = -2.5 + animation.value * 5;
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(center - 1.2, 0),
                end: Alignment(center + 1.2, 0),
                colors: <Color>[colors.inkMuted, colors.ink, colors.inkMuted],
                stops: const <double>[0.35, 0.5, 0.65],
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

final class _PixelGrid extends StatelessWidget {
  const _PixelGrid({
    required this.variant,
    required this.animation,
    required this.color,
    required this.motionEnabled,
  });

  final BeautifulLoadingVariant variant;
  final Animation<double> animation;
  final Color color;
  final bool motionEnabled;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 15,
        child: CustomPaint(
          painter: _PixelGridPainter(
            variant: variant,
            animation: animation,
            color: color,
            motionEnabled: motionEnabled,
          ),
        ),
      ),
    );
  }
}

final class _PixelGridPainter extends CustomPainter {
  _PixelGridPainter({
    required this.variant,
    required this.animation,
    required this.color,
    required this.motionEnabled,
  }) : super(repaint: motionEnabled ? animation : null);

  static const List<int> _orbitOrder = <int>[0, 1, 2, 5, 8, 7, 6, 3];

  final BeautifulLoadingVariant variant;
  final Animation<double> animation;
  final Color color;
  final bool motionEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 4.0;
    const gap = 1.5;
    final paint = Paint()..color = color;
    final durationMs = _gridDuration(variant).inMilliseconds;
    final loopMs = animation.value * durationMs;

    for (var index = 0; index < 9; index++) {
      final row = index ~/ 3;
      final column = index % 3;
      final delay = _delayFor(index, row, column);
      final baseOpacity = delay == null ? 0.07 : 0.15;
      final opacity = !motionEnabled || delay == null
          ? baseOpacity
          : _pixelOpacity((loopMs - delay) % durationMs / durationMs);
      paint.color = color.withValues(alpha: opacity);
      final rect = Rect.fromLTWH(
        column * (cellSize + gap),
        row * (cellSize + gap),
        cellSize,
        cellSize,
      );
      if (variant == BeautifulLoadingVariant.dots) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1)),
          paint,
        );
      }
    }
  }

  double? _delayFor(int index, int row, int column) {
    if (variant == BeautifulLoadingVariant.orbit) {
      final order = _orbitOrder.indexOf(index);
      return order < 0 ? null : order * 110.0;
    }
    return (column + (row - 1).abs()) * 90.0;
  }

  double _pixelOpacity(double normalized) {
    final value = normalized < 0 ? normalized + 1 : normalized;
    if (value < 0.18) {
      return 0.15 + Curves.easeInOut.transform(value / 0.18) * 0.85;
    }
    if (value <= 0.42) {
      return 1;
    }
    if (value < 0.62) {
      return 1 - Curves.easeInOut.transform((value - 0.42) / 0.20) * 0.85;
    }
    return 0.15;
  }

  @override
  bool shouldRepaint(_PixelGridPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        oldDelegate.animation != animation ||
        oldDelegate.color != color ||
        oldDelegate.motionEnabled != motionEnabled;
  }
}

final class _SurferFallback extends StatelessWidget {
  const _SurferFallback({
    required this.animation,
    required this.motionEnabled,
    required this.label,
    required this.color,
    required this.accent,
    required this.style,
  });

  final Animation<double> animation;
  final bool motionEnabled;
  final String label;
  final Color color;
  final Color accent;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        CustomPaint(
          painter: _SurferFallbackPainter(
            animation: animation,
            motionEnabled: motionEnabled,
            color: color,
            accent: accent,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: style.copyWith(color: color, fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

final class _SurferFallbackPainter extends CustomPainter {
  _SurferFallbackPainter({
    required this.animation,
    required this.motionEnabled,
    required this.color,
    required this.accent,
  }) : super(repaint: motionEnabled ? animation : null);

  final Animation<double> animation;
  final bool motionEnabled;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final lanePaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    for (var lane = 1; lane < 4; lane++) {
      final x = size.width * lane / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), lanePaint);
    }
    final progress = motionEnabled ? animation.value : 0.35;
    final runnerPaint = Paint()..color = accent;
    final runner = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          size.width * (0.15 + progress * 0.7),
          size.height * (0.35 + math.sin(progress * math.pi * 2) * 0.08),
        ),
        width: 12,
        height: 18,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(runner, runnerPaint);
  }

  @override
  bool shouldRepaint(_SurferFallbackPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.motionEnabled != motionEnabled ||
        oldDelegate.color != color ||
        oldDelegate.accent != accent;
  }
}
