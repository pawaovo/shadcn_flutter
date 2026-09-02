import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/layout.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';

const _sourceMaxWidth = 380.0;
const _cardEntranceDuration = Duration(milliseconds: 400);
const _sourceRevealDelay = Duration(milliseconds: 700);
const _sourceRevealDuration = Duration(milliseconds: 300);
const _cardStagger = Duration(milliseconds: 100);
const _sourceStagger = Duration(milliseconds: 80);
const _compactBodyLines = 3;

/// Semantic color roles for a context chunk's compact source badge.
enum BeautifulContextTone {
  /// A quiet neutral badge for an unclassified source.
  neutral,

  /// The package accent color.
  accent,

  /// A positive or successfully verified source.
  success,

  /// A source that merits caution.
  warning,

  /// A destructive, error, or high-risk source.
  destructive,
}

/// An immutable retrieved knowledge chunk displayed by [BeautifulContextCards].
///
/// [id] is the stable identity used to retain disclosure and entrance state
/// while the host inserts, removes, or reorders chunks. It must be non-empty,
/// and every chunk in one [BeautifulContextCards] snapshot must have a unique
/// id.
///
/// ```dart
/// const chunk = BeautifulContextChunk(
///   id: 'policy',
///   title: 'Retention policy',
///   characterCountLabel: '120 characters',
///   body: 'Customer exports are retained for thirty days.',
///   sourceLabel: 'Policy.pdf',
///   sourceBadge: 'PDF',
/// );
/// ```
@immutable
final class BeautifulContextChunk {
  /// Creates a retrieved context chunk.
  ///
  /// Parameters:
  /// - [id] (`String`, required): Stable, non-empty identity.
  /// - [title] (`String`, required): Concise chunk title.
  /// - [characterCountLabel] (`String`, required): Caller-formatted extent,
  ///   such as `290 characters` or a localized equivalent.
  /// - [body] (`String`, required): Retrieved text presented to the user.
  /// - [sourceLabel] (`String`, required): Human-readable source name.
  /// - [sourceBadge] (`String`, required): Short source kind, such as `PDF`.
  /// - [tone] (`BeautifulContextTone`, default: `neutral`): Semantic badge
  ///   color.
  const BeautifulContextChunk({
    required this.id,
    required this.title,
    required this.characterCountLabel,
    required this.body,
    required this.sourceLabel,
    required this.sourceBadge,
    this.tone = BeautifulContextTone.neutral,
  }) : assert(id.length > 0),
       assert(title.length > 0),
       assert(characterCountLabel.length > 0),
       assert(body.length > 0),
       assert(sourceLabel.length > 0),
       assert(sourceBadge.length > 0);

  /// Stable identity for state retention and list reconciliation.
  final String id;

  /// Concise title for the retrieved chunk.
  final String title;

  /// Caller-formatted character or extent label.
  final String characterCountLabel;

  /// Retrieved body text.
  final String body;

  /// Human-readable source name.
  final String sourceLabel;

  /// Short source-kind badge text.
  final String sourceBadge;

  /// Semantic color role for [sourceBadge].
  final BeautifulContextTone tone;
}

/// Displays a compact, accessible list of retrieved knowledge chunks.
///
/// The host owns retrieval, persistence, source routing, and the immutable
/// [chunks] snapshot. This module owns adaptive layout, one-time entrances,
/// source hover/focus/keyboard behavior, compact disclosure state, Semantics,
/// and reduced-motion substitutions.
///
/// The source chip is descriptive text when [onSourcePressed] is null. When a
/// callback is supplied it becomes a focusable Semantics button activated by
/// pointer, Enter, or Space. No URL launcher or navigation dependency is
/// created inside the module.
///
/// ```dart
/// const cards = BeautifulContextCards(
///   chunks: <BeautifulContextChunk>[
///     BeautifulContextChunk(
///       id: 'policy',
///       title: 'Retention policy',
///       characterCountLabel: '120 characters',
///       body: 'Customer exports are retained for thirty days.',
///       sourceLabel: 'Policy.pdf',
///       sourceBadge: 'PDF',
///     ),
///   ],
/// );
/// ```
final class BeautifulContextCards extends StatefulWidget {
  /// Creates a context-card list.
  ///
  /// Parameters:
  /// - [chunks] (`List<BeautifulContextChunk>`, required): Immutable snapshot
  ///   with unique, non-empty ids.
  /// - [headerLabel] (`String`, default: `All chunks`): Localized heading.
  /// - [countLabel] (`String?`, optional): Localized visible total. When null,
  ///   the number of supplied chunks is shown.
  /// - [expandLabel] (`String`, default: `Show more`): Localized compact
  ///   disclosure label.
  /// - [collapseLabel] (`String`, default: `Show less`): Localized compact
  ///   collapse label.
  /// - [openSourceLabel] (`String`, default: `Open source`): Localized prefix
  ///   for an interactive source's Semantics label.
  /// - [onSourcePressed] (`ValueChanged<BeautifulContextChunk>?`, optional):
  ///   Host-owned source action.
  const BeautifulContextCards({
    super.key,
    required this.chunks,
    this.headerLabel = 'All chunks',
    this.countLabel,
    this.expandLabel = 'Show more',
    this.collapseLabel = 'Show less',
    this.openSourceLabel = 'Open source',
    this.onSourcePressed,
  }) : assert(headerLabel.length > 0),
       assert(countLabel == null || countLabel.length > 0),
       assert(expandLabel.length > 0),
       assert(collapseLabel.length > 0),
       assert(openSourceLabel.length > 0);

  /// Immutable retrieved-chunk snapshot.
  final List<BeautifulContextChunk> chunks;

  /// Localized list heading.
  final String headerLabel;

  /// Localized total label, or null to derive it from [chunks].
  final String? countLabel;

  /// Localized label for expanding a long compact body.
  final String expandLabel;

  /// Localized label for collapsing a long compact body.
  final String collapseLabel;

  /// Localized Semantics prefix for an interactive source.
  final String openSourceLabel;

  /// Invoked with the selected chunk when its source action is activated.
  final ValueChanged<BeautifulContextChunk>? onSourcePressed;

  @override
  State<BeautifulContextCards> createState() => _BeautifulContextCardsState();
}

final class _BeautifulContextCardsState extends State<BeautifulContextCards>
    with SingleTickerProviderStateMixin {
  late final AnimationController _headerController;
  late List<BeautifulContextChunk> _chunks;
  var _headerInitialized = false;
  var _headerMotionEnabled = false;

  @override
  void initState() {
    super.initState();
    _takeChunksSnapshot();
    _headerController = AnimationController(
      vsync: this,
      duration: _cardEntranceDuration,
    );
  }

  @override
  void didUpdateWidget(BeautifulContextCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    _takeChunksSnapshot();
  }

  void _takeChunksSnapshot() {
    _chunks = List<BeautifulContextChunk>.unmodifiable(widget.chunks);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = _entranceMotionEnabled(context);
    if (!_headerInitialized) {
      _headerInitialized = true;
      _headerMotionEnabled = enabled;
      if (enabled) {
        _headerController.forward();
      } else {
        _headerController.value = 1;
      }
      return;
    }

    if (_headerMotionEnabled && !enabled) {
      _headerMotionEnabled = false;
      _headerController.value = 1;
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _debugValidateUniqueIds(_chunks);
    final theme = BeautifulUiTheme.of(context);
    final countLabel = widget.countLabel ?? '${_chunks.length}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final environment = BeautifulUiEnvironment.of(context);
        final mode = environment.modeFor(context, constraints);
        final compact = mode == BeautifulLayoutMode.compact;

        return Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _sourceMaxWidth),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeader(context, theme, countLabel),
                  SizedBox(height: theme.spacing.sm),
                  Semantics(
                    container: true,
                    explicitChildNodes: true,
                    role: SemanticsRole.list,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (
                          var index = 0;
                          index < _chunks.length;
                          index++
                        ) ...<Widget>[
                          if (index > 0) SizedBox(height: theme.spacing.sm),
                          _ContextCard(
                            key: ValueKey<String>(_chunks[index].id),
                            chunk: _chunks[index],
                            index: index,
                            compact: compact,
                            expandLabel: widget.expandLabel,
                            collapseLabel: widget.collapseLabel,
                            openSourceLabel: widget.openSourceLabel,
                            onSourcePressed: widget.onSourcePressed,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    BeautifulUiThemeData theme,
    String countLabel,
  ) {
    final colors = theme.colors;
    return Semantics(
      container: true,
      header: true,
      label: '${widget.headerLabel}, $countLabel',
      excludeSemantics: true,
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _headerController,
          curve: Curves.easeOut,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
          child: Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                widget.headerLabel,
                style: theme.typography.label.copyWith(
                  color: colors.ink,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.13,
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 20),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.inset,
                  borderRadius: BorderRadius.circular(theme.radii.chip),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: colors.line, spreadRadius: 1),
                  ],
                ),
                child: Text(
                  countLabel,
                  style: theme.typography.caption.copyWith(
                    color: colors.inkMuted,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.115,
                    fontFeatures: const <ui.FontFeature>[
                      ui.FontFeature.tabularFigures(),
                    ],
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

final class _ContextCard extends StatefulWidget {
  const _ContextCard({
    super.key,
    required this.chunk,
    required this.index,
    required this.compact,
    required this.expandLabel,
    required this.collapseLabel,
    required this.openSourceLabel,
    required this.onSourcePressed,
  });

  final BeautifulContextChunk chunk;
  final int index;
  final bool compact;
  final String expandLabel;
  final String collapseLabel;
  final String openSourceLabel;
  final ValueChanged<BeautifulContextChunk>? onSourcePressed;

  @override
  State<_ContextCard> createState() => _ContextCardState();
}

final class _ContextCardState extends State<_ContextCard>
    with TickerProviderStateMixin {
  late final AnimationController _cardController;
  late final AnimationController _sourceController;
  Timer? _cardTimer;
  Timer? _sourceTimer;
  var _motionInitialized = false;
  var _motionEnabled = false;
  var _expanded = false;

  @override
  void initState() {
    super.initState();
    _cardController = AnimationController(
      vsync: this,
      duration: _cardEntranceDuration,
    );
    _sourceController = AnimationController(
      vsync: this,
      duration: _sourceRevealDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = _entranceMotionEnabled(context);
    if (!_motionInitialized) {
      _motionInitialized = true;
      _motionEnabled = enabled;
      if (enabled) {
        _scheduleEntrances();
      } else {
        _settleEntrances();
      }
      return;
    }

    if (_motionEnabled && !enabled) {
      _motionEnabled = false;
      _settleEntrances();
    }
  }

  @override
  void didUpdateWidget(_ContextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_motionEnabled && oldWidget.index != widget.index) {
      if (_cardController.value == 0) {
        _cardTimer?.cancel();
        _cardTimer = Timer(_cardStagger * widget.index, _startCardEntrance);
      }
      if (_sourceController.value == 0) {
        _sourceTimer?.cancel();
        _sourceTimer = Timer(
          _sourceRevealDelay + (_sourceStagger * widget.index),
          _startSourceReveal,
        );
      }
    }
  }

  @override
  void dispose() {
    _cardTimer?.cancel();
    _sourceTimer?.cancel();
    _cardController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  void _scheduleEntrances() {
    _cardTimer = Timer(_cardStagger * widget.index, _startCardEntrance);
    _sourceTimer = Timer(
      _sourceRevealDelay + (_sourceStagger * widget.index),
      _startSourceReveal,
    );
  }

  void _startCardEntrance() {
    if (mounted) {
      _cardController.forward();
    }
  }

  void _startSourceReveal() {
    if (mounted) {
      _sourceController.forward();
    }
  }

  void _settleEntrances() {
    _cardTimer?.cancel();
    _sourceTimer?.cancel();
    _cardController.value = 1;
    _sourceController.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final cardCurve = CurvedAnimation(
      parent: _cardController,
      curve: theme.motion.outCurve,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.listItem,
      child: AnimatedBuilder(
        animation: cardCurve,
        child: _buildCard(context, theme),
        builder: (context, child) {
          final progress = cardCurve.value;
          return Opacity(
            opacity: progress,
            alwaysIncludeSemantics: true,
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - progress)),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, BeautifulUiThemeData theme) {
    final colors = theme.colors;
    return Container(
      key: ValueKey<String>('context-card-${widget.chunk.id}'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        boxShadow: <BoxShadow>[
          BoxShadow(color: colors.line, spreadRadius: 1),
          ...theme.shadows.card,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radii.card),
        child: ColoredBox(
          color: colors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildCardHeader(context, theme),
              _buildBody(context, theme),
              _buildSource(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(BuildContext context, BeautifulUiThemeData theme) {
    final colors = theme.colors;
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: CustomPaint(
            size: const Size.square(11),
            painter: _ListGlyphPainter(colors.ink),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              widget.chunk.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.label.copyWith(
                color: colors.ink,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.13,
              ),
            ),
          ),
        ),
      ],
    );
    final extent = Text(
      widget.chunk.characterCountLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.end,
      style: theme.typography.caption.copyWith(
        color: colors.inkSubtle,
        fontSize: 12,
        height: 1.35,
        letterSpacing: -0.12,
        fontFeatures: const <ui.FontFeature>[ui.FontFeature.tabularFigures()],
      ),
    );
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 230 || textScale > 1.4) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                title,
                SizedBox(height: theme.spacing.xs),
                Align(alignment: AlignmentDirectional.centerEnd, child: extent),
              ],
            );
          }
          return Row(
            children: <Widget>[
              Expanded(child: title),
              const SizedBox(width: 10),
              Flexible(child: extent),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, BeautifulUiThemeData theme) {
    final style = theme.typography.body.copyWith(
      color: theme.colors.inkMuted,
      fontSize: 12.5,
      height: 1.625,
      letterSpacing: -0.125,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final overflows =
              widget.compact &&
              _textExceedsLines(
                context,
                widget.chunk.body,
                style,
                constraints.maxWidth,
                _compactBodyLines,
              );
          final collapsed = overflows && !_expanded;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                identifier: 'beautiful-context-body-${widget.chunk.id}',
                label: collapsed
                    ? _collapsedBodySummary(widget.chunk.body)
                    : widget.chunk.body,
                excludeSemantics: true,
                child: Text(
                  widget.chunk.body,
                  maxLines: collapsed ? _compactBodyLines : null,
                  overflow: collapsed ? TextOverflow.ellipsis : null,
                  style: style,
                ),
              ),
              if (overflows) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                BeautifulActionControl(
                  key: ValueKey<String>(
                    'context-disclosure-${widget.chunk.id}',
                  ),
                  label: _expanded ? widget.collapseLabel : widget.expandLabel,
                  semanticLabel:
                      '${_expanded ? widget.collapseLabel : widget.expandLabel}: ${widget.chunk.title}',
                  tone: BeautifulActionTone.quiet,
                  expanded: _expanded,
                  minHeight: _minimumInteractiveExtent(),
                  trailing: ExcludeSemantics(
                    child: CustomPaint(
                      size: const Size.square(13),
                      painter: _ChevronGlyphPainter(
                        color: theme.colors.inkMuted,
                        pointsUp: _expanded,
                      ),
                    ),
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  String _collapsedBodySummary(String body) {
    final runes = body.runes.toList(growable: false);
    if (runes.length <= 1) {
      return '…';
    }
    final end = runes.length > 120 ? 120 : runes.length - 1;
    return '${String.fromCharCodes(runes.take(end)).trimRight()}…';
  }

  Widget _buildSource(BuildContext context, BeautifulUiThemeData theme) {
    final sourceCurve = CurvedAnimation(
      parent: _sourceController,
      curve: theme.motion.outCurve,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12),
      child: AnimatedBuilder(
        animation: sourceCurve,
        child: _SourceChip(
          chunk: widget.chunk,
          openSourceLabel: widget.openSourceLabel,
          onPressed: widget.onSourcePressed == null
              ? null
              : () => widget.onSourcePressed!(widget.chunk),
        ),
        builder: (context, child) {
          final progress = sourceCurve.value;
          return Opacity(
            opacity: progress,
            alwaysIncludeSemantics: true,
            child: Transform.scale(
              alignment: AlignmentDirectional.centerStart.resolve(
                Directionality.of(context),
              ),
              scale: 0.95 + (0.05 * progress),
              child: IgnorePointer(ignoring: progress == 0, child: child),
            ),
          );
        },
      ),
    );
  }
}

final class _SourceChip extends StatefulWidget {
  const _SourceChip({
    required this.chunk,
    required this.openSourceLabel,
    required this.onPressed,
  });

  final BeautifulContextChunk chunk;
  final String openSourceLabel;
  final VoidCallback? onPressed;

  @override
  State<_SourceChip> createState() => _SourceChipState();
}

final class _SourceChipState extends State<_SourceChip> {
  late final FocusNode _focusNode;
  var _hovered = false;
  var _focused = false;
  var _pressed = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'Context source ${widget.chunk.id}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final interactive = widget.onPressed != null;
    final visual = _buildVisual(context, theme, interactive);

    if (!interactive) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          container: true,
          label: '${widget.chunk.sourceBadge}, ${widget.chunk.sourceLabel}',
          excludeSemantics: true,
          child: visual,
        ),
      );
    }

    final semanticLabel =
        '${widget.openSourceLabel}: ${widget.chunk.sourceLabel}';
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        container: true,
        button: true,
        enabled: true,
        label: semanticLabel,
        excludeSemantics: true,
        onTap: widget.onPressed,
        child: FocusableActionDetector(
          enabled: true,
          focusNode: _focusNode,
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (value) {
            if (_hovered != value) {
              setState(() => _hovered = value);
            }
          },
          onShowFocusHighlight: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
            }
          },
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            onTapDown: (_) {
              _focusNode.requestFocus();
              setState(() => _pressed = true);
            },
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: ConstrainedBox(
              key: ValueKey<String>('context-source-${widget.chunk.id}'),
              constraints: BoxConstraints(
                minWidth: _minimumInteractiveExtent(),
                minHeight: _minimumInteractiveExtent(),
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: visual,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisual(
    BuildContext context,
    BeautifulUiThemeData theme,
    bool interactive,
  ) {
    final colors = theme.colors;
    final environment = BeautifulUiEnvironment.of(context);
    final mediaDisablesMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration =
        mediaDisablesMotion ||
            environment.motionPolicy == BeautifulMotionPolicy.none
        ? Duration.zero
        : environment.motionPolicy == BeautifulMotionPolicy.reduced
        ? theme.motion.quick
        : _sourceRevealDuration;
    final background = interactive && (_hovered || _pressed)
        ? (_pressed ? colors.hoverStrong : colors.hover)
        : colors.inset;
    final shadows = <BoxShadow>[
      if (_focused)
        BoxShadow(color: colors.accent, spreadRadius: 2)
      else
        BoxShadow(
          color: colors.brightness == Brightness.dark
              ? const Color(0x1affffff)
              : colors.lineStrong,
          spreadRadius: 1,
        ),
      if (colors.brightness == Brightness.dark)
        const BoxShadow(
          color: Color(0x4d000000),
          blurRadius: 2,
          offset: Offset(0, 1),
        )
      else
        const BoxShadow(color: Color(0x0a000000), blurRadius: 4),
    ];

    return AnimatedScale(
      duration: duration,
      curve: theme.motion.outCurve,
      scale: _pressed ? 0.98 : 1,
      child: AnimatedContainer(
        duration: duration,
        curve: theme.motion.outCurve,
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          boxShadow: shadows,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _badgeColor(colors, widget.chunk.tone),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.chunk.sourceBadge,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: theme.typography.caption.copyWith(
                  color: const Color(0xffffffff),
                  fontSize: 7,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.chunk.sourceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(
                  color: colors.inkMuted,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.12,
                ),
              ),
            ),
            if (interactive) ...<Widget>[
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: CustomPaint(
                  size: const Size.square(9),
                  painter: _ExternalLinkGlyphPainter(colors.inkMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _badgeColor(BeautifulUiColors colors, BeautifulContextTone tone) {
  return switch (tone) {
    BeautifulContextTone.neutral => colors.inkSubtle,
    BeautifulContextTone.accent => colors.accent,
    BeautifulContextTone.success => colors.success,
    BeautifulContextTone.warning => colors.warning,
    BeautifulContextTone.destructive => colors.destructive,
  };
}

bool _entranceMotionEnabled(BuildContext context) {
  final environment = BeautifulUiEnvironment.of(context);
  final platformDisabled =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return !platformDisabled &&
      environment.motionPolicy == BeautifulMotionPolicy.system;
}

double _minimumInteractiveExtent() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 48,
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.linux ||
    TargetPlatform.windows ||
    TargetPlatform.fuchsia => 44,
  };
}

bool _textExceedsLines(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
  int maxLines,
) {
  if (!maxWidth.isFinite || maxWidth <= 0) {
    return false;
  }
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
  )..layout(maxWidth: maxWidth);
  final exceeds = painter.didExceedMaxLines;
  painter.dispose();
  return exceeds;
}

void _debugValidateUniqueIds(List<BeautifulContextChunk> chunks) {
  assert(() {
    final ids = <String>{};
    for (final chunk in chunks) {
      if (!ids.add(chunk.id)) {
        throw FlutterError(
          'BeautifulContextCards requires unique chunk ids; '
          '`${chunk.id}` appears more than once.',
        );
      }
    }
    return true;
  }());
}

final class _ListGlyphPainter extends CustomPainter {
  const _ListGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(4 * scale, 6 * scale),
        Offset(20 * scale, 6 * scale),
        paint,
      )
      ..drawLine(
        Offset(4 * scale, 12 * scale),
        Offset(20 * scale, 12 * scale),
        paint,
      )
      ..drawLine(
        Offset(4 * scale, 18 * scale),
        Offset(14 * scale, 18 * scale),
        paint,
      );
  }

  @override
  bool shouldRepaint(_ListGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

final class _ExternalLinkGlyphPainter extends CustomPainter {
  const _ExternalLinkGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawLine(
        Offset(7 * scale, 17 * scale),
        Offset(17 * scale, 7 * scale),
        paint,
      )
      ..drawLine(
        Offset(7 * scale, 7 * scale),
        Offset(17 * scale, 7 * scale),
        paint,
      )
      ..drawLine(
        Offset(17 * scale, 7 * scale),
        Offset(17 * scale, 17 * scale),
        paint,
      );
  }

  @override
  bool shouldRepaint(_ExternalLinkGlyphPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

final class _ChevronGlyphPainter extends CustomPainter {
  const _ChevronGlyphPainter({required this.color, required this.pointsUp});

  final Color color;
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * (2 / 13)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final middleY = pointsUp ? size.height * 0.38 : size.height * 0.62;
    final edgeY = pointsUp ? size.height * 0.62 : size.height * 0.38;
    final path = Path()
      ..moveTo(size.width * 0.22, edgeY)
      ..lineTo(size.width * 0.5, middleY)
      ..lineTo(size.width * 0.78, edgeY);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronGlyphPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pointsUp != pointsUp;
  }
}
