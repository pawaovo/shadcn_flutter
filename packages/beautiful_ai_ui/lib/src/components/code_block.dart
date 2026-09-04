import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/failure.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';

/// A source run within a [BeautifulDiffLine].
///
/// [change] is null for unchanged text and may be [BeautifulDiffLineKind.added]
/// or [BeautifulDiffLineKind.removed] for a word-level highlight. Context is a
/// line kind, not a word-level change, and is rejected by the constructor.
///
/// ```dart
/// const piece = BeautifulCodePiece(
///   text: 'return nextValue;',
///   change: BeautifulDiffLineKind.added,
/// );
/// ```
@immutable
final class BeautifulCodePiece {
  /// Creates a source run.
  const BeautifulCodePiece({required this.text, this.change})
    : assert(
        change != BeautifulDiffLineKind.context,
        'A code-piece change must be added, removed, or null.',
      );

  /// The exact source text in this run.
  final String text;

  /// The optional word-level addition or removal treatment.
  final BeautifulDiffLineKind? change;
}

/// The semantic kind of a unified-diff line.
enum BeautifulDiffLineKind {
  /// Source that is unchanged between the old and new versions.
  context,

  /// Source that exists only in the new version.
  added,

  /// Source that exists only in the old version.
  removed,
}

/// One source row in a unified diff.
///
/// Context rows require both line numbers, additions require only a new line
/// number, and removals require only an old line number. The widget preserves
/// the caller's row and piece order.
@immutable
final class BeautifulDiffLine {
  /// Creates a validated unified-diff row.
  const BeautifulDiffLine({
    this.oldLineNumber,
    this.newLineNumber,
    required this.kind,
    required this.pieces,
  }) : assert(
         oldLineNumber == null || oldLineNumber > 0,
         'oldLineNumber must be positive when supplied.',
       ),
       assert(
         newLineNumber == null || newLineNumber > 0,
         'newLineNumber must be positive when supplied.',
       ),
       assert(
         (kind == BeautifulDiffLineKind.context &&
                 oldLineNumber != null &&
                 newLineNumber != null) ||
             (kind == BeautifulDiffLineKind.added &&
                 oldLineNumber == null &&
                 newLineNumber != null) ||
             (kind == BeautifulDiffLineKind.removed &&
                 oldLineNumber != null &&
                 newLineNumber == null),
         'Line numbers must agree with the diff-line kind.',
       );

  /// The one-based line number in the old version, when applicable.
  final int? oldLineNumber;

  /// The one-based line number in the new version, when applicable.
  final int? newLineNumber;

  /// Whether this row is context, added, or removed.
  final BeautifulDiffLineKind kind;

  /// Ordered source runs composing this row.
  ///
  /// Treat the list as an immutable snapshot after constructing the widget.
  final List<BeautifulCodePiece> pieces;
}

/// Displays a line-numbered source listing or a unified diff.
///
/// The two named constructors form a sealed caller-facing interface: source
/// mode accepts one canonical [String] that is both rendered and copied, while
/// diff mode accepts typed rows and has no copy action. The module owns syntax
/// coloring, horizontal overflow, copy ordering and feedback, keyboard input,
/// and Semantics.
///
/// Copy requests are de-duplicated while pending. Successful feedback remains
/// visible for 1.5 seconds. A supplied [onCopy] replaces the system clipboard
/// writer, which keeps tests and hosts with a custom clipboard policy
/// deterministic.
///
/// ```dart
/// const block = BeautifulCodeBlock.code(
///   filename: 'main.dart',
///   code: 'void main() {}',
/// );
/// ```
final class BeautifulCodeBlock extends StatefulWidget {
  /// Creates a line-numbered code listing.
  ///
  /// Parameters:
  /// - [filename] (`String`, required): Non-empty filename shown in the header.
  /// - [code] (`String`, required): Canonical rendered and copied source text.
  /// - [copyLabel] (`String`, default: `Copy`): Idle action label.
  /// - [copyingLabel] (`String`, default: `Copying`): Pending action label.
  /// - [copiedLabel] (`String`, default: `Copied`): Success feedback label.
  /// - [copyFailedLabel] (`String`, default: `Copy failed`): Failure feedback.
  /// - [onCopy] (`FutureOr<void> Function(String)?`, optional): Clipboard
  ///   replacement. When omitted, Flutter's system [Clipboard] is used.
  const BeautifulCodeBlock.code({
    super.key,
    required this.filename,
    required String code,
    this.copyLabel = 'Copy',
    this.copyingLabel = 'Copying',
    this.copiedLabel = 'Copied',
    this.copyFailedLabel = 'Copy failed',
    this.onCopy,
  }) : assert(filename.length > 0),
       assert(copyLabel.length > 0),
       assert(copyingLabel.length > 0),
       assert(copiedLabel.length > 0),
       assert(copyFailedLabel.length > 0),
       _mode = _BeautifulCodeBlockMode.code,
       // The public parameter deliberately stays `code`; exposing the private
       // backing-field name would make the named constructor unusable.
       // ignore: prefer_initializing_formals
       _code = code,
       _diffLines = const <BeautifulDiffLine>[];

  /// Creates a unified diff without a copy action.
  ///
  /// [filename] must be non-empty. [lines] are displayed in caller order and
  /// treated as an immutable snapshot.
  const BeautifulCodeBlock.diff({
    super.key,
    required this.filename,
    required List<BeautifulDiffLine> lines,
  }) : assert(filename.length > 0),
       _mode = _BeautifulCodeBlockMode.diff,
       _code = null,
       _diffLines = lines,
       copyLabel = 'Copy',
       copyingLabel = 'Copying',
       copiedLabel = 'Copied',
       copyFailedLabel = 'Copy failed',
       onCopy = null;

  /// The filename displayed in the header.
  final String filename;

  /// The localized idle copy-action label.
  final String copyLabel;

  /// The localized pending copy-action label.
  final String copyingLabel;

  /// The localized successful copy-action label.
  final String copiedLabel;

  /// The localized failed copy-action label.
  final String copyFailedLabel;

  /// Optional clipboard replacement for code mode.
  ///
  /// Returning normally means the write succeeded. Throwing reports a
  /// [BeautifulUiOperation.clipboard] failure through [BeautifulUiScope].
  final FutureOr<void> Function(String code)? onCopy;

  final _BeautifulCodeBlockMode _mode;
  final String? _code;
  final List<BeautifulDiffLine> _diffLines;

  @override
  State<BeautifulCodeBlock> createState() => _BeautifulCodeBlockState();
}

enum _BeautifulCodeBlockMode { code, diff }

enum _CopyFeedback { idle, copying, copied, failed }

final class _BeautifulCodeBlockState extends State<BeautifulCodeBlock> {
  late final ScrollController _horizontalController;
  late final FocusNode _selectionFocusNode;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _selectionFocusNode = FocusNode(debugLabel: 'BeautifulCodeBlock selection');
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _selectionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final radius = BorderRadius.circular(theme.radii.card);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colors.surface,
              border: Border.all(color: theme.colors.line),
              borderRadius: radius,
              boxShadow: theme.shadows.card,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: theme.colors.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[_buildHeader(theme), _buildBody(theme)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BeautifulUiThemeData theme) {
    final trailing = widget._mode == _BeautifulCodeBlockMode.diff
        ? _buildDiffStatistics(theme)
        : _CodeCopyControl(
            code: widget._code!,
            copyLabel: widget.copyLabel,
            copyingLabel: widget.copyingLabel,
            copiedLabel: widget.copiedLabel,
            copyFailedLabel: widget.copyFailedLabel,
            onCopy: widget.onCopy,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colors.line)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: theme.spacing.lg,
            end: theme.spacing.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  container: true,
                  label: widget.filename,
                  child: ExcludeSemantics(
                    child: Row(
                      children: <Widget>[
                        _FileGlyph(color: theme.colors.inkSubtle),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            widget.filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.ltr,
                            style: theme.typography.mono.copyWith(
                              color: theme.colors.ink,
                              fontSize: 12.5,
                              height: 1,
                              letterSpacing: -0.125,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiffStatistics(BeautifulUiThemeData theme) {
    final additions = widget._diffLines
        .where((line) => line.kind == BeautifulDiffLineKind.added)
        .length;
    final deletions = widget._diffLines
        .where((line) => line.kind == BeautifulDiffLineKind.removed)
        .length;
    final semanticLabel =
        '$additions ${additions == 1 ? 'addition' : 'additions'}, '
        '$deletions ${deletions == 1 ? 'deletion' : 'deletions'}';
    final style = theme.typography.mono.copyWith(
      fontSize: 12,
      height: 1,
      letterSpacing: -0.12,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '+$additions',
                style: style.copyWith(color: theme.colors.success),
              ),
              SizedBox(width: theme.spacing.sm),
              Text(
                '-$deletions',
                style: style.copyWith(color: theme.colors.destructive),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BeautifulUiThemeData theme) {
    final codeStyle = theme.typography.mono.copyWith(
      color: theme.colors.inkMuted,
      fontSize: 12.5,
      height: 1.65,
      letterSpacing: -0.125,
    );
    final numberStyle = codeStyle.copyWith(
      color: theme.colors.inkSubtle,
      fontSize: 11,
    );
    final rows = widget._mode == _BeautifulCodeBlockMode.code
        ? _buildCodeRows(theme, codeStyle, numberStyle)
        : _buildDiffRows(theme, codeStyle, numberStyle);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minimumWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 420.0;
            final content = Stack(
              children: <Widget>[
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minimumWidth),
                  child: IntrinsicWidth(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: rows,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 20,
                  width: 1,
                  child: ColoredBox(color: theme.colors.line),
                ),
              ],
            );
            final selectable = Overlay.maybeOf(context) == null
                ? content
                : SelectableRegion(
                    focusNode: _selectionFocusNode,
                    selectionControls: emptyTextSelectionControls,
                    child: content,
                  );
            return RawScrollbar(
              controller: _horizontalController,
              thumbColor: theme.colors.lineStrong,
              thickness: 4,
              radius: const Radius.circular(2),
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: selectable,
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCodeRows(
    BeautifulUiThemeData theme,
    TextStyle codeStyle,
    TextStyle numberStyle,
  ) {
    final lines = widget._code!.split('\n');
    return <Widget>[
      for (var index = 0; index < lines.length; index++)
        _CodeLineRow(
          lineNumber: index + 1,
          semanticLabel: 'Line ${index + 1}: ${_displayLine(lines[index])}',
          numberStyle: numberStyle,
          codeStyle: codeStyle,
          spans: _highlight(_displayLine(lines[index]), theme),
        ),
    ];
  }

  List<Widget> _buildDiffRows(
    BeautifulUiThemeData theme,
    TextStyle codeStyle,
    TextStyle numberStyle,
  ) {
    return <Widget>[
      for (final line in widget._diffLines)
        _DiffLineRow(
          line: line,
          semanticLabel: _diffSemanticLabel(line),
          numberStyle: numberStyle,
          codeStyle: codeStyle,
          spans: <InlineSpan>[
            for (final piece in line.pieces)
              TextSpan(
                style: _pieceStyle(piece, theme),
                children: _highlight(piece.text, theme),
              ),
          ],
          theme: theme,
        ),
    ];
  }
}

// Copy feedback is independent of the source listing: a timer, pointer hover,
// or focus change must not rebuild/re-tokenize every unchanged source line.
final class _CodeCopyControl extends StatefulWidget {
  const _CodeCopyControl({
    required this.code,
    required this.copyLabel,
    required this.copyingLabel,
    required this.copiedLabel,
    required this.copyFailedLabel,
    required this.onCopy,
  });

  final String code;
  final String copyLabel;
  final String copyingLabel;
  final String copiedLabel;
  final String copyFailedLabel;
  final FutureOr<void> Function(String code)? onCopy;

  @override
  State<_CodeCopyControl> createState() => _CodeCopyControlState();
}

final class _CodeCopyControlState extends State<_CodeCopyControl> {
  static const _feedbackDuration = Duration(milliseconds: 1500);
  final FocusNode _copyFocusNode = FocusNode(
    debugLabel: 'BeautifulCodeBlock copy',
  );
  Timer? _feedbackTimer;
  _CopyFeedback _copyFeedback = _CopyFeedback.idle;
  var _copyGeneration = 0;
  var _copyHovered = false;
  var _copyFocused = false;

  @override
  void didUpdateWidget(_CodeCopyControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _feedbackTimer?.cancel();
      _copyGeneration += 1;
      _copyFeedback = _CopyFeedback.idle;
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _copyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final enabled = _copyFeedback != _CopyFeedback.copying;
    final isLive =
        _copyFeedback == _CopyFeedback.copied ||
        _copyFeedback == _CopyFeedback.failed;
    final label = switch (_copyFeedback) {
      _CopyFeedback.idle => widget.copyLabel,
      _CopyFeedback.copying => widget.copyingLabel,
      _CopyFeedback.copied => widget.copiedLabel,
      _CopyFeedback.failed => widget.copyFailedLabel,
    };
    final foreground = switch (_copyFeedback) {
      _CopyFeedback.idle =>
        _copyHovered ? theme.colors.ink : theme.colors.inkSubtle,
      _CopyFeedback.copying => theme.colors.accentInk,
      _CopyFeedback.copied => theme.colors.success,
      _CopyFeedback.failed => theme.colors.destructive,
    };
    final environment = BeautifulUiEnvironment.of(context);
    final mediaDisablesMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        mediaDisablesMotion ||
            environment.motionPolicy == BeautifulMotionPolicy.none
        ? Duration.zero
        : theme.motion.quick;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      liveRegion: isLive,
      excludeSemantics: true,
      label: label,
      onTap: enabled ? _copy : null,
      child: FocusableActionDetector(
        focusNode: _copyFocusNode,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowHoverHighlight: (value) {
          if (_copyHovered != value) {
            setState(() => _copyHovered = value);
          }
        },
        onShowFocusHighlight: (value) {
          if (_copyFocused != value) {
            setState(() => _copyFocused = value);
          }
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (enabled) {
                _copy();
              }
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _copy : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 48,
              maxWidth: 160,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: theme.motion.outCurve,
                constraints: const BoxConstraints(minHeight: 24),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _copyHovered && enabled
                      ? theme.colors.hover
                      : const Color(0x00000000),
                  border: _copyFocused
                      ? Border.all(color: theme.colors.accent, width: 2)
                      : null,
                  borderRadius: BorderRadius.circular(theme.radii.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _CopyGlyph(feedback: _copyFeedback, color: foreground),
                    SizedBox(width: theme.spacing.xs),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.label.copyWith(
                          color: foreground,
                          fontSize: 12,
                          height: 1.25,
                          letterSpacing: -0.12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copy() async {
    if (_copyFeedback == _CopyFeedback.copying) {
      return;
    }

    _feedbackTimer?.cancel();
    final generation = ++_copyGeneration;
    final source = widget.code;
    final environment = BeautifulUiEnvironment.of(context);
    setState(() => _copyFeedback = _CopyFeedback.copying);

    try {
      final callback = widget.onCopy;
      if (callback == null) {
        await Clipboard.setData(ClipboardData(text: source));
      } else {
        await callback(source);
      }
    } catch (error, stackTrace) {
      environment.reportFailure(
        BeautifulUiFailure(
          operation: BeautifulUiOperation.clipboard,
          message: 'Unable to copy code to the clipboard.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
      if (!mounted || generation != _copyGeneration) {
        return;
      }
      setState(() => _copyFeedback = _CopyFeedback.failed);
      _scheduleFeedbackReset(generation);
      return;
    }

    if (!mounted || generation != _copyGeneration) {
      return;
    }
    setState(() => _copyFeedback = _CopyFeedback.copied);
    _scheduleFeedbackReset(generation);
  }

  void _scheduleFeedbackReset(int generation) {
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(_feedbackDuration, () {
      if (!mounted || generation != _copyGeneration) {
        return;
      }
      setState(() => _copyFeedback = _CopyFeedback.idle);
    });
  }
}

final class _CodeLineRow extends StatelessWidget {
  const _CodeLineRow({
    required this.lineNumber,
    required this.semanticLabel,
    required this.numberStyle,
    required this.codeStyle,
    required this.spans,
  });

  final int lineNumber;
  final String semanticLabel;
  final TextStyle numberStyle;
  final TextStyle codeStyle;
  final List<InlineSpan> spans;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectionContainer.disabled(
              child: SizedBox(
                width: 20,
                child: Text(
                  '$lineNumber',
                  textAlign: TextAlign.center,
                  style: numberStyle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 12),
              child: Text.rich(
                TextSpan(children: spans),
                softWrap: false,
                overflow: TextOverflow.visible,
                style: codeStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({
    required this.line,
    required this.semanticLabel,
    required this.numberStyle,
    required this.codeStyle,
    required this.spans,
    required this.theme,
  });

  final BeautifulDiffLine line;
  final String semanticLabel;
  final TextStyle numberStyle;
  final TextStyle codeStyle;
  final List<InlineSpan> spans;
  final BeautifulUiThemeData theme;

  @override
  Widget build(BuildContext context) {
    final lineNumber = line.kind == BeautifulDiffLineKind.removed
        ? line.oldLineNumber
        : line.newLineNumber;
    final foreground = switch (line.kind) {
      BeautifulDiffLineKind.context => theme.colors.inkSubtle,
      BeautifulDiffLineKind.added => theme.colors.success,
      BeautifulDiffLineKind.removed => theme.colors.destructive,
    };
    final background = switch (line.kind) {
      BeautifulDiffLineKind.context => const Color(0x00000000),
      BeautifulDiffLineKind.added => theme.colors.successTint,
      BeautifulDiffLineKind.removed => theme.colors.destructiveTint,
    };

    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: background,
          child: Stack(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectionContainer.disabled(
                    child: SizedBox(
                      width: 20,
                      child: Text(
                        '${lineNumber ?? ''}',
                        textAlign: TextAlign.center,
                        style: numberStyle.copyWith(color: foreground),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 12),
                    child: Text.rich(
                      TextSpan(children: spans),
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: codeStyle,
                    ),
                  ),
                ],
              ),
              if (line.kind != BeautifulDiffLineKind.context)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: 3,
                  child: line.kind == BeautifulDiffLineKind.added
                      ? ColoredBox(color: theme.colors.success)
                      : CustomPaint(
                          painter: _HatchPainter(
                            color: theme.colors.destructive,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _FileGlyph extends StatelessWidget {
  const _FileGlyph({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(15),
      painter: _FileGlyphPainter(color),
    );
  }
}

final class _CopyGlyph extends StatelessWidget {
  const _CopyGlyph({required this.feedback, required this.color});

  final _CopyFeedback feedback;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(11),
      painter: _CopyGlyphPainter(feedback, color),
    );
  }
}

final class _FileGlyphPainter extends CustomPainter {
  const _FileGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(scale, scale);
    final path = Path()
      ..moveTo(17.25, 6.75)
      ..lineTo(22.5, 12)
      ..lineTo(17.25, 17.25)
      ..moveTo(6.75, 17.25)
      ..lineTo(1.5, 12)
      ..lineTo(6.75, 6.75)
      ..moveTo(14.25, 3.75)
      ..lineTo(9.75, 20.25);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FileGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

final class _CopyGlyphPainter extends CustomPainter {
  const _CopyGlyphPainter(this.feedback, this.color);

  final _CopyFeedback feedback;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = feedback == _CopyFeedback.copied ? 3 : 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(scale, scale);
    switch (feedback) {
      case _CopyFeedback.copied:
        canvas.drawPath(
          Path()
            ..moveTo(20, 6)
            ..lineTo(9, 17)
            ..lineTo(4, 12),
          paint,
        );
      case _CopyFeedback.failed:
        canvas.drawCircle(const Offset(12, 12), 9, paint);
        canvas.drawLine(const Offset(12, 7), const Offset(12, 13), paint);
        canvas.drawCircle(
          const Offset(12, 17),
          0.7,
          paint..style = PaintingStyle.fill,
        );
      case _CopyFeedback.copying:
      case _CopyFeedback.idle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(9, 9, 12, 12),
            const Radius.circular(2.5),
          ),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(5, 15)
            ..lineTo(4, 15)
            ..quadraticBezierTo(2, 15, 2, 13)
            ..lineTo(2, 4)
            ..quadraticBezierTo(2, 2, 4, 2)
            ..lineTo(13, 2)
            ..quadraticBezierTo(15, 2, 15, 4)
            ..lineTo(15, 5),
          paint,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CopyGlyphPainter oldDelegate) {
    return oldDelegate.feedback != feedback || oldDelegate.color != color;
  }
}

final class _HatchPainter extends CustomPainter {
  const _HatchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    for (var y = -size.width; y < size.height + size.width; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + size.width), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.color != color;
}

String _displayLine(String line) {
  return line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
}

String _diffSemanticLabel(BeautifulDiffLine line) {
  final lineNumber = line.kind == BeautifulDiffLineKind.removed
      ? line.oldLineNumber
      : line.newLineNumber;
  final kind = switch (line.kind) {
    BeautifulDiffLineKind.context => 'Context',
    BeautifulDiffLineKind.added => 'Added',
    BeautifulDiffLineKind.removed => 'Removed',
  };
  final text = line.pieces.map((piece) => piece.text).join();
  return '$kind line $lineNumber: $text';
}

TextStyle? _pieceStyle(BeautifulCodePiece piece, BeautifulUiThemeData theme) {
  return switch (piece.change) {
    null => null,
    BeautifulDiffLineKind.added => TextStyle(
      backgroundColor: theme.colors.success.withValues(alpha: 0.18),
    ),
    BeautifulDiffLineKind.removed => TextStyle(
      backgroundColor: theme.colors.destructive.withValues(alpha: 0.18),
    ),
    BeautifulDiffLineKind.context => null,
  };
}

const Set<String> _keywords = <String>{
  'import',
  'from',
  'export',
  'default',
  'async',
  'function',
  'const',
  'let',
  'var',
  'await',
  'return',
  'if',
  'else',
  'for',
  'while',
  'new',
  'throw',
  'try',
  'catch',
  'null',
  'true',
  'false',
  'undefined',
};

final RegExp _syntaxTokens = RegExp(
  r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`[^`]*`|\b\d+(?:\.\d+)?\b|\b(?:import|from|export|default|async|function|const|let|var|await|return|if|else|for|while|new|throw|try|catch|null|true|false|undefined)\b|[A-Za-z_$][\w$]*(?=\s*\())''',
);

final RegExp _numberToken = RegExp(r'^\d');

List<InlineSpan> _highlight(String text, BeautifulUiThemeData theme) {
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in _syntaxTokens.allMatches(text)) {
    if (match.start > last) {
      spans.add(TextSpan(text: text.substring(last, match.start)));
    }
    final token = match.group(0)!;
    final first = token[0];
    final style =
        first == '"' ||
            first == "'" ||
            first == '`' ||
            _numberToken.hasMatch(token)
        ? TextStyle(color: theme.colors.warning)
        : _keywords.contains(token)
        ? TextStyle(color: theme.colors.accentInk)
        : TextStyle(color: theme.colors.ink, fontWeight: FontWeight.w500);
    spans.add(TextSpan(text: token, style: style));
    last = match.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last)));
  }
  return spans;
}
