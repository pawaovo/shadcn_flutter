import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';

/// The operation represented by a tool-call row.
enum BeautifulToolKind {
  /// A reasoning or planning operation.
  think,

  /// A file write or edit.
  write,

  /// A command or external tool execution.
  run,

  /// A file or source read.
  read,
}

/// Caller-owned execution state; the module never starts or advances a tool.
enum BeautifulToolStatus {
  /// Waiting to start.
  pending,

  /// Currently running.
  running,

  /// Finished successfully.
  complete,

  /// Finished with an error.
  failed,
}

/// The meaning of a line in tool output or a file preview.
enum BeautifulToolLineTone {
  /// Unchanged or ordinary output.
  context,

  /// An added line, also identified by a visible plus sign.
  addition,

  /// A removed line, also identified by a visible minus sign.
  deletion,
}

/// Immutable output text, optionally carrying a file-change meaning.
@immutable
final class BeautifulToolDetailLine {
  /// Creates an output line. Empty text represents a blank line.
  const BeautifulToolDetailLine({
    required this.text,
    this.tone = BeautifulToolLineTone.context,
  });

  /// Full output; long lines wrap without truncation.
  final String text;

  /// Non-color and semantic meaning of this line.
  final BeautifulToolLineTone tone;
}

/// An immutable snapshot of one tool operation.
///
/// [id] must be nonblank and unique within [BeautifulToolChips.steps].
/// [details] is defensively copied. The host supplies changes to [status] and
/// output through a new snapshot; no execution or transport is created here.
@immutable
final class BeautifulToolStep {
  /// Creates a tool operation. [statusLabel] overrides the English status text
  /// for localization or a more specific host-owned progress message.
  BeautifulToolStep({
    required this.id,
    required this.label,
    required this.chip,
    this.kind = BeautifulToolKind.run,
    this.status = BeautifulToolStatus.complete,
    this.statusLabel,
    this.mono = true,
    this.detailMono = true,
    Iterable<BeautifulToolDetailLine> details = const [],
  }) : details = List<BeautifulToolDetailLine>.unmodifiable(details) {
    _requireText(id, 'id');
    _requireText(label, 'label');
    _requireText(chip, 'chip');
    if (statusLabel != null) _requireText(statusLabel!, 'statusLabel');
  }

  /// Stable identity retained across host updates and reordering.
  final String id;

  /// Primary operation label, such as `Read configuration`.
  final String label;

  /// File name, command, or short operation summary.
  final String chip;

  /// Operation category; expressed by a decorative glyph.
  final BeautifulToolKind kind;

  /// Execution state supplied by the host.
  final BeautifulToolStatus status;

  /// Localized execution-state text, or null for the English default.
  final String? statusLabel;

  /// Whether [chip] uses the theme's code typography.
  final bool mono;

  /// Whether output uses the theme's code typography.
  final bool detailMono;

  /// Defensively copied output shown when the row is expanded.
  final List<BeautifulToolDetailLine> details;
}

/// An immutable changed-file summary and its optional full preview.
@immutable
final class BeautifulToolDiff {
  /// Creates a changed-file summary. Counts must be nonnegative and [id] must
  /// be unique within [BeautifulToolChips.diffs]. [lines] is defensively copied.
  BeautifulToolDiff({
    required this.id,
    required this.file,
    required this.additions,
    this.deletions = 0,
    Iterable<BeautifulToolDetailLine> lines = const [],
  }) : lines = List<BeautifulToolDetailLine>.unmodifiable(lines) {
    _requireText(id, 'id');
    _requireText(file, 'file');
    if (additions < 0) {
      throw ArgumentError.value(additions, 'additions', 'must be nonnegative');
    }
    if (deletions < 0) {
      throw ArgumentError.value(deletions, 'deletions', 'must be nonnegative');
    }
  }

  /// Stable identity retained across host updates and reordering.
  final String id;

  /// File name or path.
  final String file;

  /// Host-supplied count of added lines.
  final int additions;

  /// Host-supplied count of removed lines.
  final int deletions;

  /// Defensively copied preview; an empty preview produces a descriptive chip.
  final List<BeautifulToolDetailLine> lines;
}

/// Compact tool-call rows followed by expandable changed-file chips.
///
/// The host owns execution, networking, errors, output, and file navigation.
/// This module owns only disclosure. Tool and file details are inline panels
/// activated by tap, Enter, or Space, so they remain reachable on touch screens
/// and during resizing. Escape closes the focused disclosure and returns focus
/// to its trigger. Closed panels leave the focus and Semantics trees.
///
/// Source Tool Chips has one presentation and no visual variants. Its scripted
/// reveal timer is replaced by the host's immutable snapshots. Stable IDs keep
/// open details attached to the correct operation when snapshots are reordered.
/// The run starts expanded; all individual details start collapsed. Changing
/// [initiallyExpanded] or [initiallyVisibleDiffCount] after mounting does not
/// reset the user's disclosure choices.
///
/// ```dart
/// final tools = BeautifulToolChips(
///   headerLabel: '1 tool call',
///   steps: [
///     BeautifulToolStep(
///       id: 'verify',
///       label: 'Verify project',
///       chip: 'flutter test',
///       details: const [BeautifulToolDetailLine(text: 'All tests passed')],
///     ),
///   ],
/// );
/// ```
final class BeautifulToolChips extends StatefulWidget {
  /// Creates a tool-call trace from defensively copied snapshots.
  ///
  /// IDs must be unique within their collection. Blank labels and negative
  /// [initiallyVisibleDiffCount] values throw [ArgumentError]. Disclosure
  /// callbacks report user changes and do not control the local state.
  BeautifulToolChips({
    super.key,
    required Iterable<BeautifulToolStep> steps,
    Iterable<BeautifulToolDiff> diffs = const [],
    this.headerLabel = 'Tool activity',
    this.initiallyExpanded = true,
    this.initiallyVisibleDiffCount = 3,
    this.showMoreLabel = 'Show more files',
    this.showLessLabel = 'Show fewer files',
    this.onExpandedChanged,
    this.onStepExpandedChanged,
    this.onDiffExpandedChanged,
  }) : steps = List<BeautifulToolStep>.unmodifiable(steps),
       diffs = List<BeautifulToolDiff>.unmodifiable(diffs) {
    _requireText(headerLabel, 'headerLabel');
    _requireText(showMoreLabel, 'showMoreLabel');
    _requireText(showLessLabel, 'showLessLabel');
    _requireUniqueIds(this.steps.map((step) => step.id), 'steps');
    _requireUniqueIds(this.diffs.map((diff) => diff.id), 'diffs');
    if (initiallyVisibleDiffCount < 0) {
      throw ArgumentError.value(
        initiallyVisibleDiffCount,
        'initiallyVisibleDiffCount',
        'must be nonnegative',
      );
    }
  }

  /// Immutable tool-operation snapshot.
  final List<BeautifulToolStep> steps;

  /// Immutable changed-file snapshot.
  final List<BeautifulToolDiff> diffs;

  /// Localized run summary; the host may include counts or progress here.
  final String headerLabel;

  /// Run disclosure on first mount only.
  final bool initiallyExpanded;

  /// Number of file chips shown before the local show-more action.
  final int initiallyVisibleDiffCount;

  /// Localized action to reveal the remaining file chips.
  final String showMoreLabel;

  /// Localized action to restore the initial file-chip count.
  final String showLessLabel;

  /// Reports a user change to the run's disclosure.
  final ValueChanged<bool>? onExpandedChanged;

  /// Reports a user change to one tool row's disclosure by stable ID.
  final void Function(String id, bool expanded)? onStepExpandedChanged;

  /// Reports a user change to one file preview's disclosure by stable ID.
  final void Function(String id, bool expanded)? onDiffExpandedChanged;

  @override
  State<BeautifulToolChips> createState() => _BeautifulToolChipsState();
}

final class _BeautifulToolChipsState extends State<BeautifulToolChips> {
  late bool _expanded;
  late final int _visibleDiffCount;
  var _showAllDiffs = false;
  final _openSteps = <String>{};
  final _openDiffs = <String>{};

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _visibleDiffCount = widget.initiallyVisibleDiffCount;
  }

  @override
  void didUpdateWidget(BeautifulToolChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stepIds = widget.steps.map((step) => step.id).toSet();
    final diffIds = widget.diffs.map((diff) => diff.id).toSet();
    _openSteps.removeWhere((id) => !stepIds.contains(id));
    _openDiffs.removeWhere((id) => !diffIds.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SizedBox(
        width: double.infinity,
        child: FocusTraversalGroup(
          child: _ToolDisclosure(
            controlKey: const ValueKey('beautiful-tool-chips-header'),
            label: widget.headerLabel,
            semanticLabel: widget.headerLabel,
            expanded: _expanded,
            tone: BeautifulActionTone.quiet,
            onChanged: (expanded) {
              setState(() => _expanded = expanded);
              widget.onExpandedChanged?.call(expanded);
            },
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              role: SemanticsRole.list,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final step in widget.steps)
                    _buildStep(context, theme, step),
                  if (widget.diffs.isNotEmpty) ...[
                    SizedBox(height: theme.spacing.sm),
                    Container(height: 1, color: theme.colors.line),
                    SizedBox(height: theme.spacing.sm),
                    for (final diff
                        in _showAllDiffs
                            ? widget.diffs
                            : widget.diffs.take(_visibleDiffCount))
                      _buildDiff(context, theme, diff),
                    if (widget.diffs.length > _visibleDiffCount)
                      BeautifulActionControl(
                        key: const ValueKey('beautiful-tool-chips-more'),
                        label: _showAllDiffs
                            ? widget.showLessLabel
                            : widget.showMoreLabel,
                        fullWidth: true,
                        minHeight: 48,
                        tone: BeautifulActionTone.quiet,
                        expanded: _showAllDiffs,
                        onPressed: () {
                          setState(() => _showAllDiffs = !_showAllDiffs);
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    BeautifulUiThemeData theme,
    BeautifulToolStep step,
  ) {
    final statusLabel = step.statusLabel ?? _statusLabel(step.status);
    final color = switch (step.status) {
      BeautifulToolStatus.pending => theme.colors.inkMuted,
      BeautifulToolStatus.running => _readableTone(
        theme,
        theme.colors.accentInk,
      ),
      BeautifulToolStatus.complete => _readableTone(
        theme,
        theme.colors.success,
      ),
      BeautifulToolStatus.failed => _readableTone(
        theme,
        theme.colors.destructive,
      ),
    };
    return Semantics(
      key: ValueKey('beautiful-tool-step-${step.id}'),
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.listItem,
      child: Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.xs),
        child: _ToolDisclosure(
          controlKey: ValueKey('beautiful-tool-step-control-${step.id}'),
          label: step.label,
          semanticLabel: '${step.label}, ${step.chip}',
          expanded: _openSteps.contains(step.id) && step.details.isNotEmpty,
          leading: _ToolIcon(
            shape: switch (step.kind) {
              BeautifulToolKind.think => _ToolIconShape.think,
              BeautifulToolKind.write => _ToolIconShape.write,
              BeautifulToolKind.run => _ToolIconShape.run,
              BeautifulToolKind.read => _ToolIconShape.read,
            },
            color: theme.colors.inkMuted,
          ),
          summary: Container(
            width: double.infinity,
            margin: EdgeInsetsDirectional.fromSTEB(
              theme.spacing.md,
              0,
              theme.spacing.md,
              theme.spacing.xs,
            ),
            padding: EdgeInsets.all(theme.spacing.sm),
            decoration: BoxDecoration(
              color: theme.colors.field,
              borderRadius: BorderRadius.circular(theme.radii.chip),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Text(
                    step.chip,
                    style:
                        (step.mono
                                ? theme.typography.mono
                                : theme.typography.body)
                            .copyWith(
                              color: theme.colors.inkMuted,
                              fontSize: 12,
                            ),
                  ),
                ),
                Semantics(
                  identifier: 'beautiful-tool-status-${step.id}',
                  liveRegion: true,
                  label: '${step.label}: $statusLabel',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToolIcon(
                        shape: switch (step.status) {
                          BeautifulToolStatus.pending => _ToolIconShape.pending,
                          BeautifulToolStatus.running => _ToolIconShape.running,
                          BeautifulToolStatus.complete =>
                            _ToolIconShape.complete,
                          BeautifulToolStatus.failed => _ToolIconShape.failed,
                        },
                        color: color,
                      ),
                      SizedBox(width: theme.spacing.xs),
                      Flexible(
                        child: Text(
                          statusLabel,
                          style: theme.typography.caption.copyWith(
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          onChanged: step.details.isEmpty
              ? null
              : (expanded) {
                  setState(() {
                    expanded
                        ? _openSteps.add(step.id)
                        : _openSteps.remove(step.id);
                  });
                  widget.onStepExpandedChanged?.call(step.id, expanded);
                },
          child: _ToolLines(lines: step.details, mono: step.detailMono),
        ),
      ),
    );
  }

  Widget _buildDiff(
    BuildContext context,
    BeautifulUiThemeData theme,
    BeautifulToolDiff diff,
  ) {
    final countLabel = '+${diff.additions}  −${diff.deletions}';
    return Semantics(
      key: ValueKey('beautiful-tool-diff-${diff.id}'),
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.listItem,
      child: Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.xs),
        child: _ToolDisclosure(
          controlKey: ValueKey('beautiful-tool-diff-control-${diff.id}'),
          label: diff.file,
          semanticLabel: '${diff.file}, $countLabel',
          expanded: _openDiffs.contains(diff.id) && diff.lines.isNotEmpty,
          summary: ExcludeSemantics(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: theme.spacing.md,
                end: theme.spacing.md,
                bottom: theme.spacing.xs,
              ),
              child: Wrap(
                spacing: theme.spacing.sm,
                children: [
                  Text(
                    '+${diff.additions}',
                    style: theme.typography.mono.copyWith(
                      color: _readableTone(theme, theme.colors.success),
                    ),
                  ),
                  Text(
                    '−${diff.deletions}',
                    style: theme.typography.mono.copyWith(
                      color: _readableTone(theme, theme.colors.destructive),
                    ),
                  ),
                ],
              ),
            ),
          ),
          onChanged: diff.lines.isEmpty
              ? null
              : (expanded) {
                  setState(() {
                    expanded
                        ? _openDiffs.add(diff.id)
                        : _openDiffs.remove(diff.id);
                  });
                  widget.onDiffExpandedChanged?.call(diff.id, expanded);
                },
          child: _ToolLines(lines: diff.lines, mono: true),
        ),
      ),
    );
  }
}

final class _ToolDisclosure extends StatefulWidget {
  const _ToolDisclosure({
    required this.controlKey,
    required this.label,
    required this.semanticLabel,
    required this.expanded,
    required this.onChanged,
    required this.child,
    this.leading,
    this.summary,
    this.tone = BeautifulActionTone.secondary,
  });

  final Key controlKey;
  final String label;
  final String semanticLabel;
  final bool expanded;
  final ValueChanged<bool>? onChanged;
  final Widget child;
  final Widget? leading;
  final Widget? summary;
  final BeautifulActionTone tone;

  @override
  State<_ToolDisclosure> createState() => _ToolDisclosureState();
}

final class _ToolDisclosureState extends State<_ToolDisclosure> {
  final _headerFocus = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _headerFocus.dispose();
    super.dispose();
  }

  void _change(bool expanded) {
    if (!expanded) {
      for (final node in _headerFocus.descendants) {
        if (node.canRequestFocus && !node.skipTraversal) {
          node.requestFocus();
          break;
        }
      }
    }
    widget.onChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final environment = BeautifulUiEnvironment.of(context);
    final animate =
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
        environment.motionPolicy != BeautifulMotionPolicy.none &&
        environment.motionPolicy != BeautifulMotionPolicy.reduced;
    final enabled = widget.onChanged != null;
    return Focus(
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            widget.expanded &&
            enabled) {
          _change(false);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            focusNode: _headerFocus,
            skipTraversal: true,
            includeSemantics: false,
            child: enabled
                ? BeautifulActionControl(
                    key: widget.controlKey,
                    label: widget.label,
                    semanticLabel: widget.semanticLabel,
                    fullWidth: true,
                    minHeight: 48,
                    maxLines: null,
                    leading: widget.leading,
                    trailing: _ToolIcon(
                      shape: widget.expanded
                          ? _ToolIconShape.chevronDown
                          : _ToolIconShape.chevronEnd,
                      color: theme.colors.inkMuted,
                    ),
                    expanded: widget.expanded,
                    tone: widget.tone,
                    onPressed: () => _change(!widget.expanded),
                  )
                : Semantics(
                    key: widget.controlKey,
                    label: widget.semanticLabel,
                    excludeSemantics: true,
                    child: Padding(
                      padding: EdgeInsets.all(theme.spacing.md),
                      child: Text(
                        widget.label,
                        style: theme.typography.label.copyWith(
                          color: theme.colors.ink,
                        ),
                      ),
                    ),
                  ),
          ),
          if (widget.summary != null) widget.summary!,
          if (animate)
            AnimatedSize(
              duration: theme.motion.standard,
              curve: theme.motion.outCurve,
              alignment: AlignmentDirectional.topStart,
              child: widget.expanded ? widget.child : const SizedBox.shrink(),
            )
          else if (widget.expanded)
            widget.child,
        ],
      ),
    );
  }
}

final class _ToolLines extends StatelessWidget {
  const _ToolLines({required this.lines, required this.mono});

  final List<BeautifulToolDetailLine> lines;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Container(
      width: double.infinity,
      margin: EdgeInsetsDirectional.only(
        start: theme.spacing.md,
        top: theme.spacing.xs,
        bottom: theme.spacing.sm,
      ),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: theme.colors.lineStrong, width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in lines)
            Container(
              color: switch (line.tone) {
                BeautifulToolLineTone.context => null,
                BeautifulToolLineTone.addition => theme.colors.successTint,
                BeautifulToolLineTone.deletion => theme.colors.destructiveTint,
              },
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.sm,
                vertical: theme.spacing.xs,
              ),
              child: Text(
                switch (line.tone) {
                  BeautifulToolLineTone.context => line.text,
                  BeautifulToolLineTone.addition => '+ ${line.text}',
                  BeautifulToolLineTone.deletion => '− ${line.text}',
                },
                style: (mono ? theme.typography.mono : theme.typography.body)
                    .copyWith(
                      color: theme.colors.ink,
                      fontSize: 12,
                      height: 1.6,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

String _statusLabel(BeautifulToolStatus status) => switch (status) {
  BeautifulToolStatus.pending => 'Pending',
  BeautifulToolStatus.running => 'Running',
  BeautifulToolStatus.complete => 'Complete',
  BeautifulToolStatus.failed => 'Failed',
};

// These decorative shapes are drawn rather than sourced from a font so their
// rendering remains deterministic with the package's pinned Latin font files.
enum _ToolIconShape {
  chevronDown,
  chevronEnd,
  pending,
  running,
  complete,
  failed,
  think,
  write,
  run,
  read,
}

final class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.shape, required this.color});

  final _ToolIconShape shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 16,
        child: CustomPaint(
          painter: _ToolIconPainter(
            shape: shape,
            color: color,
            rtl: Directionality.of(context) == TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

final class _ToolIconPainter extends CustomPainter {
  const _ToolIconPainter({
    required this.shape,
    required this.color,
    required this.rtl,
  });

  final _ToolIconShape shape;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    if (rtl && shape == _ToolIconShape.chevronEnd) {
      canvas.translate(24, 0);
      canvas.scale(-1, 1);
    }
    switch (shape) {
      case _ToolIconShape.chevronDown:
        canvas.drawPath(
          Path()
            ..moveTo(6, 9)
            ..lineTo(12, 15)
            ..lineTo(18, 9),
          stroke,
        );
      case _ToolIconShape.chevronEnd:
        canvas.drawPath(
          Path()
            ..moveTo(9, 6)
            ..lineTo(15, 12)
            ..lineTo(9, 18),
          stroke,
        );
      case _ToolIconShape.pending:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
      case _ToolIconShape.running:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(12, 6)
            ..lineTo(12, 12)
            ..lineTo(17, 12),
          stroke,
        );
      case _ToolIconShape.complete:
        canvas.drawPath(
          Path()
            ..moveTo(4, 12)
            ..lineTo(9, 17)
            ..lineTo(20, 6),
          stroke,
        );
      case _ToolIconShape.failed:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawLine(const Offset(12, 7), const Offset(12, 12), stroke);
        canvas.drawCircle(const Offset(12, 16.5), 1, fill);
      case _ToolIconShape.think:
        canvas.drawPath(
          Path()
            ..moveTo(12, 2)
            ..lineTo(14.8, 9.2)
            ..lineTo(22, 12)
            ..lineTo(14.8, 14.8)
            ..lineTo(12, 22)
            ..lineTo(9.2, 14.8)
            ..lineTo(2, 12)
            ..lineTo(9.2, 9.2)
            ..close(),
          fill,
        );
      case _ToolIconShape.write:
        canvas.drawPath(
          Path()
            ..moveTo(5, 16)
            ..lineTo(16, 5)
            ..lineTo(20, 9)
            ..lineTo(9, 20)
            ..lineTo(4, 21)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(14, 7), const Offset(18, 11), stroke);
      case _ToolIconShape.run:
        canvas.drawPath(
          Path()
            ..moveTo(4, 5)
            ..lineTo(10, 11)
            ..lineTo(4, 17),
          stroke,
        );
        canvas.drawLine(const Offset(13, 18), const Offset(21, 18), stroke);
      case _ToolIconShape.read:
        canvas.drawPath(
          Path()
            ..moveTo(5, 3)
            ..lineTo(14, 3)
            ..lineTo(20, 9)
            ..lineTo(20, 21)
            ..lineTo(5, 21)
            ..close()
            ..moveTo(14, 3)
            ..lineTo(14, 9)
            ..lineTo(20, 9),
          stroke,
        );
        canvas.drawLine(const Offset(8, 13), const Offset(17, 13), stroke);
        canvas.drawLine(const Offset(8, 17), const Offset(15, 17), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ToolIconPainter oldDelegate) =>
      shape != oldDelegate.shape ||
      color != oldDelegate.color ||
      rtl != oldDelegate.rtl;
}

void _requireText(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
}

void _requireUniqueIds(Iterable<String> ids, String name) {
  final seen = <String>{};
  for (final id in ids) {
    if (!seen.add(id)) {
      throw ArgumentError.value(id, name, 'IDs must be unique');
    }
  }
}

// Preserve the semantic hue while giving small status/count text enough ink
// contrast on both light and dark field surfaces.
Color _readableTone(BeautifulUiThemeData theme, Color tone) =>
    Color.lerp(tone, theme.colors.ink, 0.35)!;
