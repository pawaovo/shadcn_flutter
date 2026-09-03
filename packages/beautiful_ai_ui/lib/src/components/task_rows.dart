import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/motion.dart';
import '../foundation/scope.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';

/// The host-owned execution state of a task.
enum BeautifulTaskStatus {
  /// Work has not started.
  pending,

  /// Work is in progress.
  running,

  /// Work finished successfully.
  completed,

  /// Work failed and may be retried by the host.
  failed,
}

/// Source-derived task-list presentations.
enum BeautifulTaskRowsVariant {
  /// Separate rounded rows with a small gap.
  capsules,

  /// Contiguous rows within one card.
  list,
}

/// One immutable detail shown when its task is expanded.
@immutable
final class BeautifulTaskDetail {
  /// Creates a detail with a stable, non-empty [id] and descriptive [label].
  /// [meta] contains caller-formatted supporting information, such as `3 files`.
  const BeautifulTaskDetail({
    required this.id,
    required this.label,
    required this.meta,
  }) : assert(id.length > 0),
       assert(label.length > 0);

  /// Stable identity, unique within one task.
  final String id;

  /// The action or result described by this detail.
  final String label;

  /// Caller-formatted supporting information.
  final String meta;
}

/// An immutable task snapshot; execution and progress belong to the host.
///
/// Details are defensively copied. Reuse [id] when updating or reordering the
/// same task so its disclosure and keyboard focus remain attached to that task.
@immutable
final class BeautifulTaskRow {
  /// Creates a task snapshot.
  ///
  /// [id] and [label] must be non-empty. [step], when supplied, is positive.
  /// [progress] is optional determinate progress between zero and one. A
  /// running task without progress displays a decorative indeterminate ring.
  /// [statusLabel] and [progressLabel] replace the default localized status and
  /// percentage text when the host needs more specific wording.
  BeautifulTaskRow({
    required this.id,
    required this.label,
    required this.amountLabel,
    required this.status,
    this.step,
    this.progress,
    this.statusLabel,
    this.progressLabel,
    List<BeautifulTaskDetail> details = const <BeautifulTaskDetail>[],
  }) : assert(id.isNotEmpty),
       assert(label.isNotEmpty),
       assert(step == null || step > 0),
       assert(
         progress == null ||
             (progress.isFinite && progress >= 0 && progress <= 1),
       ),
       assert(statusLabel == null || statusLabel.isNotEmpty),
       assert(progressLabel == null || progressLabel.isNotEmpty),
       assert(
         details.map((detail) => detail.id).toSet().length == details.length,
       ),
       details = List<BeautifulTaskDetail>.unmodifiable(details);

  /// Stable identity, unique within one task list.
  final String id;

  /// Human-readable task title.
  final String label;

  /// Caller-formatted extent or result, such as `12 suppliers`.
  final String amountLabel;

  /// Current host-owned execution state.
  final BeautifulTaskStatus status;

  /// Optional positive sequence number shown in the pending or running ring.
  final int? step;

  /// Optional determinate progress in the inclusive range zero to one.
  final double? progress;

  /// Optional localized replacement for the status text.
  final String? statusLabel;

  /// Optional localized replacement for the derived percentage text.
  final String? progressLabel;

  /// Immutable supporting details disclosed on activation.
  final List<BeautifulTaskDetail> details;
}

/// Accessible task progress with persistent local disclosure and host actions.
///
/// The host supplies status and progress snapshots. This module never advances
/// work on a timer or assumes retry success means the task has completed. Retry
/// activation is de-duplicated while the callback is pending. Callback errors
/// use the root [BeautifulUiScope.onFailure] seam; the host provides any visible
/// business error text through the next snapshot.
///
/// ```dart
/// BeautifulTaskRows(
///   rows: <BeautifulTaskRow>[
///     BeautifulTaskRow(
///       id: 'index',
///       label: 'Build task list',
///       amountLabel: '7 items',
///       status: BeautifulTaskStatus.running,
///       step: 2,
///       progress: 0.68,
///       details: const <BeautifulTaskDetail>[
///         BeautifulTaskDetail(id: 'read', label: 'Read export', meta: '3 files'),
///       ],
///     ),
///   ],
/// )
/// ```
final class BeautifulTaskRows extends StatelessWidget {
  /// Creates a task list from a defensively copied [rows] snapshot.
  ///
  /// Row ids must be unique. All labels are caller-replaceable. [onRetry], when
  /// provided, adds a real retry action for failed tasks. It receives the exact
  /// snapshot activated by the user. Updated data invalidates a pending retry
  /// result; stale completion or failure cannot affect a replacement task.
  BeautifulTaskRows({
    super.key,
    required List<BeautifulTaskRow> rows,
    this.variant = BeautifulTaskRowsVariant.capsules,
    this.pendingLabel = 'Pending',
    this.runningLabel = 'Running',
    this.completedLabel = 'Completed',
    this.failedLabel = 'Failed',
    this.retryLabel = 'Retry',
    this.retryingLabel = 'Retrying…',
    this.stepLabel = 'Step',
    this.emptyLabel = 'No tasks',
    this.onRetry,
  }) : assert(rows.map((row) => row.id).toSet().length == rows.length),
       assert(pendingLabel.isNotEmpty),
       assert(runningLabel.isNotEmpty),
       assert(completedLabel.isNotEmpty),
       assert(failedLabel.isNotEmpty),
       assert(retryLabel.isNotEmpty),
       assert(retryingLabel.isNotEmpty),
       assert(stepLabel.isNotEmpty),
       assert(emptyLabel.isNotEmpty),
       rows = List<BeautifulTaskRow>.unmodifiable(rows);

  /// Immutable task snapshots in reading and traversal order.
  final List<BeautifulTaskRow> rows;

  /// Separate capsules or a contiguous list card.
  final BeautifulTaskRowsVariant variant;

  /// Localized pending-state label.
  final String pendingLabel;

  /// Localized running-state label.
  final String runningLabel;

  /// Localized successful-state label.
  final String completedLabel;

  /// Localized failed-state label.
  final String failedLabel;

  /// Localized retry-action label.
  final String retryLabel;

  /// Localized pending retry label.
  final String retryingLabel;

  /// Localized prefix for the sequence number in assistive announcements.
  final String stepLabel;

  /// Localized empty-list text.
  final String emptyLabel;

  /// Optional host action for failed tasks; null hides the action.
  final FutureOr<void> Function(BeautifulTaskRow row)? onRetry;

  String _statusLabel(BeautifulTaskRow row) {
    return row.statusLabel ??
        switch (row.status) {
          BeautifulTaskStatus.pending => pendingLabel,
          BeautifulTaskStatus.running => runningLabel,
          BeautifulTaskStatus.completed => completedLabel,
          BeautifulTaskStatus.failed => failedLabel,
        };
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final list = variant == BeautifulTaskRowsVariant.list;
    return Align(
      alignment: AlignmentDirectional.topStart,
      widthFactor: 1,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: list ? theme.colors.surface : null,
            borderRadius: BorderRadius.circular(theme.radii.window),
            boxShadow: list ? theme.shadows.card : null,
          ),
          child: rows.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(theme.spacing.md),
                  child: Text(emptyLabel, style: theme.typography.body),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(
                    list ? theme.radii.window : 0,
                  ),
                  clipBehavior: list ? Clip.hardEdge : Clip.none,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var index = 0; index < rows.length; index++)
                        _TaskRowView(
                          key: ValueKey<String>(rows[index].id),
                          row: rows[index],
                          list: list,
                          last: index == rows.length - 1,
                          statusLabel: _statusLabel(rows[index]),
                          retryLabel: retryLabel,
                          retryingLabel: retryingLabel,
                          stepLabel: stepLabel,
                          onRetry: onRetry,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

final class _TaskRowView extends StatefulWidget {
  const _TaskRowView({
    super.key,
    required this.row,
    required this.list,
    required this.last,
    required this.statusLabel,
    required this.retryLabel,
    required this.retryingLabel,
    required this.stepLabel,
    required this.onRetry,
  });

  final BeautifulTaskRow row;
  final bool list;
  final bool last;
  final String statusLabel;
  final String retryLabel;
  final String retryingLabel;
  final String stepLabel;
  final FutureOr<void> Function(BeautifulTaskRow row)? onRetry;

  @override
  State<_TaskRowView> createState() => _TaskRowViewState();
}

final class _TaskRowViewState extends State<_TaskRowView> {
  final _focusNode = FocusNode();
  var _expanded = false;
  var _focused = false;
  var _hovered = false;
  var _retryPending = false;
  var _retryGeneration = 0;

  @override
  void didUpdateWidget(_TaskRowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTask(oldWidget.row, widget.row) || widget.onRetry == null) {
      _retryGeneration++;
      _retryPending = false;
    }
    if (widget.row.details.isEmpty) {
      _expanded = false;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    if (widget.row.details.isNotEmpty) {
      setState(() => _expanded = !_expanded);
    }
  }

  Future<void> _retry() async {
    final callback = widget.onRetry;
    if (_retryPending || callback == null) return;
    final row = widget.row;
    final generation = ++_retryGeneration;
    setState(() => _retryPending = true);
    try {
      await callback(row);
    } catch (error, stackTrace) {
      if (!mounted || generation != _retryGeneration) return;
      setState(() => _retryPending = false);
      BeautifulUiEnvironment.of(context).reportFailure(
        BeautifulUiFailure(
          operation: BeautifulUiOperation.taskRetry,
          message: 'Task retry failed for task "${row.id}".',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      return;
    }
    if (mounted && generation == _retryGeneration) {
      setState(() => _retryPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final colors = theme.colors;
    final canExpand = widget.row.details.isNotEmpty;
    final progress = widget.row.progress;
    final progressLabel =
        widget.row.progressLabel ??
        (progress == null ? null : '${(progress * 100).round()}%');
    final statusValue = <String>[widget.statusLabel, ?progressLabel].join(', ');
    final semanticStatus = <String>[
      statusValue,
      if (widget.row.step != null &&
          (widget.row.status == BeautifulTaskStatus.running ||
              widget.row.status == BeautifulTaskStatus.pending))
        '${widget.stepLabel} ${widget.row.step}',
    ].join(', ');
    final duration = _transitionDuration(context, theme);
    final radius = widget.list
        ? 0.0
        : _expanded
        ? theme.radii.window
        : 24.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.list || widget.last ? 0 : theme.spacing.sm,
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: widget.list && !_focused
              ? Border(
                  bottom: widget.last
                      ? BorderSide.none
                      : BorderSide(color: colors.line),
                )
              : Border.all(
                  color: _focused ? colors.accent : colors.line,
                  width: _focused ? 2 : 1,
                ),
        ),
        child: AnimatedContainer(
          duration: duration,
          curve: theme.motion.outCurve,
          decoration: BoxDecoration(
            color: _hovered ? colors.hover : colors.surface,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: widget.list ? null : theme.shadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                identifier: 'beautiful-task-${widget.row.id}',
                container: true,
                button: canExpand,
                enabled: canExpand ? true : null,
                expanded: canExpand ? _expanded : null,
                liveRegion: true,
                label: <String>[
                  widget.row.label,
                  if (widget.row.amountLabel.isNotEmpty) widget.row.amountLabel,
                ].join(', '),
                value: semanticStatus,
                onTap: canExpand ? _toggle : null,
                excludeSemantics: true,
                child: FocusableActionDetector(
                  focusNode: _focusNode,
                  enabled: canExpand,
                  mouseCursor: canExpand
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  onShowFocusHighlight: (focused) {
                    setState(() => _focused = focused);
                  },
                  onShowHoverHighlight: (hovered) {
                    setState(() => _hovered = hovered);
                  },
                  shortcuts: const <ShortcutActivator, Intent>{
                    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                    SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                  },
                  actions: <Type, Action<Intent>>{
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) {
                        _toggle();
                        return null;
                      },
                    ),
                    DismissIntent: CallbackAction<DismissIntent>(
                      onInvoke: (_) {
                        if (_expanded) setState(() => _expanded = false);
                        return null;
                      },
                    ),
                  },
                  child: GestureDetector(
                    key: ValueKey<String>('task-toggle-${widget.row.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: canExpand
                        ? () {
                            _focusNode.requestFocus();
                            _toggle();
                          }
                        : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: EdgeInsets.all(theme.spacing.sm),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final largeText =
                                MediaQuery.textScalerOf(context).scale(13) > 18;
                            final compact =
                                constraints.maxWidth < 390 || largeText;
                            return Row(
                              children: <Widget>[
                                _TaskStatusGlyph(row: widget.row),
                                SizedBox(width: theme.spacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        widget.row.label,
                                        style: theme.typography.label.copyWith(
                                          color: colors.ink,
                                        ),
                                      ),
                                      if (compact) ...<Widget>[
                                        SizedBox(height: theme.spacing.xs),
                                        _metadata(theme, statusValue),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!compact) ...<Widget>[
                                  SizedBox(width: theme.spacing.sm),
                                  Flexible(
                                    child: _metadata(theme, statusValue),
                                  ),
                                ],
                                if (canExpand) ...<Widget>[
                                  SizedBox(width: theme.spacing.xs),
                                  AnimatedRotation(
                                    turns: _expanded ? 0.5 : 0,
                                    duration: duration,
                                    child: CustomPaint(
                                      size: const Size.square(16),
                                      painter: _TaskChevronPainter(
                                        colors.inkMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _TaskDisclosure(
                duration: duration,
                curve: theme.motion.outCurve,
                child: _expanded
                    ? Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                          20,
                          0,
                          theme.spacing.md,
                          theme.spacing.md,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: BorderDirectional(
                              start: BorderSide(color: colors.lineStrong),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              start: theme.spacing.xl,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                for (final detail in widget.row.details)
                                  Padding(
                                    key: ValueKey<String>(detail.id),
                                    padding: EdgeInsets.symmetric(
                                      vertical: theme.spacing.xs,
                                    ),
                                    child: Semantics(
                                      label: [detail.label, detail.meta]
                                          .where((value) => value.isNotEmpty)
                                          .join(', '),
                                      excludeSemantics: true,
                                      child: Wrap(
                                        spacing: theme.spacing.md,
                                        runSpacing: theme.spacing.xs,
                                        alignment: WrapAlignment.spaceBetween,
                                        children: <Widget>[
                                          Text(
                                            detail.label,
                                            style: theme.typography.caption
                                                .copyWith(
                                                  color: colors.inkMuted,
                                                ),
                                          ),
                                          Text(
                                            detail.meta,
                                            style: theme.typography.mono
                                                .copyWith(
                                                  color: colors.inkMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (widget.row.status == BeautifulTaskStatus.failed &&
                  widget.onRetry != null)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    theme.spacing.md,
                    0,
                    theme.spacing.md,
                    theme.spacing.sm,
                  ),
                  child: BeautifulActionControl(
                    key: ValueKey<String>('task-retry-${widget.row.id}'),
                    label: _retryPending
                        ? widget.retryingLabel
                        : widget.retryLabel,
                    semanticLabel:
                        '${_retryPending ? widget.retryingLabel : widget.retryLabel}: ${widget.row.label}',
                    tone: BeautifulActionTone.secondary,
                    fullWidth: true,
                    minHeight: 48,
                    onPressed: _retryPending ? null : () => unawaited(_retry()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metadata(BeautifulUiThemeData theme, String status) {
    final colors = theme.colors;
    final tint = switch (widget.row.status) {
      BeautifulTaskStatus.completed => colors.successTint,
      BeautifulTaskStatus.failed => colors.destructiveTint,
      BeautifulTaskStatus.pending ||
      BeautifulTaskStatus.running => colors.inset,
    };
    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (widget.row.amountLabel.isNotEmpty)
          Text(
            widget.row.amountLabel,
            style: theme.typography.caption.copyWith(color: colors.inkMuted),
          ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status,
            style: theme.typography.caption.copyWith(color: colors.ink),
          ),
        ),
      ],
    );
  }
}

final class _TaskDisclosure extends StatelessWidget {
  const _TaskDisclosure({
    required this.duration,
    required this.curve,
    required this.child,
  });

  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A zero-duration AnimatedSize mutates layout synchronously in the pinned
    // SDK. Removing the transition also implements disabled motion literally.
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: AlignmentDirectional.topStart,
      child: child,
    );
  }
}

final class _TaskStatusGlyph extends StatefulWidget {
  const _TaskStatusGlyph({required this.row});

  final BeautifulTaskRow row;

  @override
  State<_TaskStatusGlyph> createState() => _TaskStatusGlyphState();
}

final class _TaskStatusGlyphState extends State<_TaskStatusGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(_TaskStatusGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final animate =
        widget.row.status == BeautifulTaskStatus.running &&
        widget.row.progress == null &&
        BeautifulUiEnvironment.of(context).continuousMotionEnabled(context);
    if (animate && !_rotation.isAnimating) {
      _rotation.repeat();
    } else if (!animate) {
      _rotation.stop();
      _rotation.value = 0;
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 24,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            RotationTransition(
              turns: _rotation,
              child: CustomPaint(
                size: const Size.square(24),
                painter: _TaskStatusPainter(widget.row, theme.colors),
              ),
            ),
            if ((widget.row.status == BeautifulTaskStatus.running ||
                    widget.row.status == BeautifulTaskStatus.pending) &&
                widget.row.step != null)
              Padding(
                padding: const EdgeInsets.all(5),
                child: FittedBox(
                  child: Text(
                    '${widget.row.step}',
                    style: theme.typography.label.copyWith(
                      fontSize: 10.5,
                      color: theme.colors.ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _TaskStatusPainter extends CustomPainter {
  const _TaskStatusPainter(this.row, this.colors);

  final BeautifulTaskRow row;
  final BeautifulUiColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 1;
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (row.status) {
      case BeautifulTaskStatus.pending:
      case BeautifulTaskStatus.running:
        canvas.drawCircle(center, radius, paint..color = colors.lineStrong);
        if (row.progress != null || row.status == BeautifulTaskStatus.running) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            -math.pi / 2,
            math.pi * 2 * (row.progress ?? 0.28),
            false,
            paint..color = colors.inkMuted,
          );
        }
      case BeautifulTaskStatus.completed:
      case BeautifulTaskStatus.failed:
        final completed = row.status == BeautifulTaskStatus.completed;
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = completed ? colors.successTint : colors.destructiveTint,
        );
        paint.color = colors.ink;
        canvas.drawCircle(center, radius, paint);
        if (completed) {
          canvas.drawPath(
            Path()
              ..moveTo(size.width * 0.26, size.height * 0.5)
              ..lineTo(size.width * 0.44, size.height * 0.68)
              ..lineTo(size.width * 0.76, size.height * 0.32),
            paint,
          );
        } else {
          canvas
            ..drawLine(
              Offset(size.width * 0.34, size.height * 0.34),
              Offset(size.width * 0.66, size.height * 0.66),
              paint,
            )
            ..drawLine(
              Offset(size.width * 0.66, size.height * 0.34),
              Offset(size.width * 0.34, size.height * 0.66),
              paint,
            );
        }
    }
  }

  @override
  bool shouldRepaint(_TaskStatusPainter oldDelegate) {
    return oldDelegate.row.status != row.status ||
        oldDelegate.row.progress != row.progress ||
        oldDelegate.colors != colors;
  }
}

final class _TaskChevronPainter extends CustomPainter {
  const _TaskChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.25, size.height * 0.38)
        ..lineTo(size.width * 0.5, size.height * 0.63)
        ..lineTo(size.width * 0.75, size.height * 0.38),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TaskChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}

Duration _transitionDuration(BuildContext context, BeautifulUiThemeData theme) {
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return switch (BeautifulUiEnvironment.of(context).motionPolicy) {
    BeautifulMotionPolicy.none => Duration.zero,
    BeautifulMotionPolicy.reduced => theme.motion.quick,
    BeautifulMotionPolicy.system => theme.motion.standard,
  };
}

bool _sameTask(BeautifulTaskRow first, BeautifulTaskRow second) {
  if (identical(first, second)) return true;
  if (first.id != second.id ||
      first.label != second.label ||
      first.amountLabel != second.amountLabel ||
      first.status != second.status ||
      first.step != second.step ||
      first.progress != second.progress ||
      first.statusLabel != second.statusLabel ||
      first.progressLabel != second.progressLabel ||
      first.details.length != second.details.length) {
    return false;
  }
  for (var index = 0; index < first.details.length; index++) {
    final a = first.details[index];
    final b = second.details[index];
    if (a.id != b.id || a.label != b.label || a.meta != b.meta) return false;
  }
  return true;
}
