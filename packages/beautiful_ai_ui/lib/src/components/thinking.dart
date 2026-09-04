import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';

/// The source-derived presentation used by [BeautifulThinking].
enum BeautifulThinkingVariant {
  /// A sequence of completed steps followed by the current working step.
  steps,

  /// A naturally wrapping reasoning trace.
  reasoning,

  /// A search query followed by actionable results.
  search,

  /// A selectable trace of files, edits, and commands.
  coding,
}

/// Whether a [BeautifulThinking] trace is still working or has completed.
enum BeautifulThinkingStatus {
  /// Work is in progress.
  working,

  /// Work has completed.
  complete,
}

/// Immutable caller-owned content displayed by [BeautifulThinking].
///
/// [id] is the stable identity used to retain item presentation state when the
/// caller replaces [BeautifulThinking.items] with a newer immutable snapshot.
/// [detail] is source metadata, a count, or a file/command target. [additions]
/// and [deletions] are rendered only by [BeautifulThinkingVariant.coding].
///
/// ```dart
/// const item = BeautifulThinkingItem(
///   id: 'sources',
///   label: 'Reading sources',
///   detail: '3 documents',
/// );
/// ```
@immutable
final class BeautifulThinkingItem {
  /// Creates one thinking-trace item.
  const BeautifulThinkingItem({
    required this.id,
    required this.label,
    this.detail,
    this.additions,
    this.deletions,
  }) : assert(id.length > 0),
       assert(label.length > 0),
       assert(additions == null || additions >= 0),
       assert(deletions == null || deletions >= 0);

  /// Stable, non-empty identity unique within one [BeautifulThinking].
  final String id;

  /// Primary visible text.
  final String label;

  /// Optional supporting text.
  final String? detail;

  /// Optional number of added lines for a coding item.
  final int? additions;

  /// Optional number of deleted lines for a coding item.
  final int? deletions;
}

/// Displays an accessible, expandable agent trace.
///
/// The host owns [status] and the immutable [items] snapshot. This module does
/// not run a demo timer or infer business progress. It owns only transient
/// disclosure and coding-row selection, so those states survive responsive
/// constraint changes while the widget keeps the same identity.
///
/// Search and coding rows invoke [onItemPressed]. Search rows are non-actionable
/// when no callback is supplied; coding rows remain locally selectable.
///
/// ```dart
/// final thinking = BeautifulThinking(
///   variant: BeautifulThinkingVariant.steps,
///   status: BeautifulThinkingStatus.working,
///   workingLabel: 'Thinking',
///   completedLabel: 'Thought for 4 seconds',
///   items: const <BeautifulThinkingItem>[
///     BeautifulThinkingItem(id: 'sources', label: 'Reading sources'),
///   ],
/// );
/// ```
final class BeautifulThinking extends StatefulWidget {
  /// Creates a thinking trace.
  ///
  /// Parameters:
  /// - [variant] (`BeautifulThinkingVariant`, required): Trace presentation.
  /// - [status] (`BeautifulThinkingStatus`, required): Caller-owned progress.
  /// - [workingLabel] (`String`, required): Localized working status.
  /// - [completedLabel] (`String`, required): Localized completed status.
  /// - [items] (`Iterable<BeautifulThinkingItem>`, required): Immutable content
  ///   snapshot. IDs must be non-empty and unique.
  /// - [query] (`String?`, optional): Search query shown by the search variant.
  /// - [initiallyExpanded] (`bool`, default: `false`): Initial disclosure only.
  /// - [expandLabel] (`String`, default: `Show thinking details`): Localized
  ///   disclosure-button label while the trace is collapsed.
  /// - [collapseLabel] (`String`, default: `Hide thinking details`): Localized
  ///   disclosure-button label while the trace is expanded.
  /// - [onExpandedChanged] (`ValueChanged<bool>?`, optional): Disclosure event.
  /// - [onItemPressed] (`ValueChanged<BeautifulThinkingItem>?`, optional): Host
  ///   action for search and coding rows.
  ///
  /// Throws [ArgumentError] when either status label is blank or when an item
  /// ID is blank or duplicated. The iterable is defensively copied.
  BeautifulThinking({
    super.key,
    required this.variant,
    required this.status,
    required this.workingLabel,
    required this.completedLabel,
    required Iterable<BeautifulThinkingItem> items,
    this.query,
    this.initiallyExpanded = false,
    this.expandLabel = 'Show thinking details',
    this.collapseLabel = 'Hide thinking details',
    this.onExpandedChanged,
    this.onItemPressed,
  }) : items = _validatedItems(items) {
    if (workingLabel.trim().isEmpty) {
      throw ArgumentError.value(
        workingLabel,
        'workingLabel',
        'must not be blank',
      );
    }
    if (completedLabel.trim().isEmpty) {
      throw ArgumentError.value(
        completedLabel,
        'completedLabel',
        'must not be blank',
      );
    }
    if (expandLabel.trim().isEmpty) {
      throw ArgumentError.value(
        expandLabel,
        'expandLabel',
        'must not be blank',
      );
    }
    if (collapseLabel.trim().isEmpty) {
      throw ArgumentError.value(
        collapseLabel,
        'collapseLabel',
        'must not be blank',
      );
    }
  }

  /// The trace presentation.
  final BeautifulThinkingVariant variant;

  /// Caller-owned work status.
  final BeautifulThinkingStatus status;

  /// Localized label shown while [status] is working.
  final String workingLabel;

  /// Localized label shown when [status] is complete.
  final String completedLabel;

  /// Defensively copied immutable trace snapshot.
  final List<BeautifulThinkingItem> items;

  /// Optional query shown above search results.
  final String? query;

  /// Initial disclosure state. Later widget updates do not reset local state.
  final bool initiallyExpanded;

  /// Localized disclosure-button label while the trace is collapsed.
  final String expandLabel;

  /// Localized disclosure-button label while the trace is expanded.
  final String collapseLabel;

  /// Called after the user changes disclosure state.
  final ValueChanged<bool>? onExpandedChanged;

  /// Called when the user activates an actionable search or coding item.
  final ValueChanged<BeautifulThinkingItem>? onItemPressed;

  static List<BeautifulThinkingItem> _validatedItems(
    Iterable<BeautifulThinkingItem> source,
  ) {
    final items = List<BeautifulThinkingItem>.unmodifiable(source);
    final ids = <String>{};
    for (final item in items) {
      final id = item.id.trim();
      if (id.isEmpty) {
        throw ArgumentError.value(
          item.id,
          'items',
          'item IDs must not be blank',
        );
      }
      if (!ids.add(id)) {
        throw ArgumentError.value(item.id, 'items', 'item IDs must be unique');
      }
    }
    return items;
  }

  @override
  State<BeautifulThinking> createState() => _BeautifulThinkingState();
}

final class _BeautifulThinkingState extends State<BeautifulThinking>
    with SingleTickerProviderStateMixin {
  static const _maxWidth = 380.0;
  static const _sourceMinHeight = 176.0;

  late final AnimationController _loopController;
  late bool _expanded;
  String? _selectedItemId;
  bool _continuousMotionEnabled = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final environment = BeautifulUiEnvironment.of(context);
    final theme = BeautifulUiTheme.of(context);
    _continuousMotionEnabled = environment.continuousMotionEnabled(context);
    if (_loopController.duration != theme.motion.loop) {
      _loopController.duration = theme.motion.loop;
    }
    _syncContinuousMotion();
  }

  @override
  void didUpdateWidget(BeautifulThinking oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant != widget.variant ||
        !widget.items.any((item) => item.id == _selectedItemId)) {
      _selectedItemId = null;
    }
    _syncContinuousMotion();
  }

  void _syncContinuousMotion() {
    final shouldRun =
        _continuousMotionEnabled &&
        widget.status == BeautifulThinkingStatus.working;
    if (shouldRun) {
      if (!_loopController.isAnimating) {
        _loopController.repeat();
      }
      return;
    }
    _loopController
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final environment = BeautifulUiEnvironment.of(context);
    final motion = _ThinkingMotion.resolve(context, environment, theme);
    final minHeight =
        widget.status == BeautifulThinkingStatus.working || _expanded
        ? _sourceMinHeight
        : 0.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxWidth),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedContainer(
          duration: motion.disclosure,
          curve: theme.motion.outCurve,
          constraints: BoxConstraints(minHeight: minHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildHeader(theme, motion),
              _buildDisclosure(theme, motion),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BeautifulUiThemeData theme, _ThinkingMotion motion) {
    final label = widget.status == BeautifulThinkingStatus.working
        ? widget.workingLabel
        : widget.completedLabel;
    final disclosureLabel = _expanded
        ? widget.collapseLabel
        : widget.expandLabel;
    return _ThinkingControl(
      key: const ValueKey<String>('beautiful-thinking-header'),
      identifier: 'beautiful-thinking-header',
      semanticLabel: disclosureLabel,
      preserveChildSemantics: true,
      expanded: _expanded,
      onPressed: _toggleExpanded,
      minHeight: 48,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 6,
        vertical: 4,
      ),
      borderRadius: theme.radii.control,
      hoverColor: theme.colors.hoverStrong,
      focusColor: theme.colors.accent,
      transitionDuration: motion.feedback,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(
            child: _ThinkingSparkle(
              color: widget.status == BeautifulThinkingStatus.working
                  ? theme.colors.inkMuted
                  : theme.colors.inkSubtle,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Flexible(
            child: Semantics(
              identifier: 'beautiful-thinking-status',
              role: SemanticsRole.status,
              label: label,
              child: ExcludeSemantics(
                child: widget.status == BeautifulThinkingStatus.working
                    ? _ThinkingShimmerLabel(
                        label: label,
                        animation: _loopController,
                        enabled: _continuousMotionEnabled,
                        theme: theme,
                      )
                    : _ThinkingStatusEntrance(
                        duration: motion.status,
                        curve: theme.motion.outCurve,
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.label.copyWith(
                            color: theme.colors.inkMuted,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          ExcludeSemantics(
            child: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: motion.chevron,
              curve: theme.motion.outCurve,
              child: _ThinkingChevron(color: theme.colors.inkSubtle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclosure(BeautifulUiThemeData theme, _ThinkingMotion motion) {
    return TweenAnimationBuilder<double>(
      key: const ValueKey<String>('beautiful-thinking-disclosure'),
      tween: Tween<double>(begin: 0, end: _expanded ? 1 : 0),
      duration: motion.disclosure,
      curve: theme.motion.outCurve,
      builder: (context, value, child) {
        return ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            heightFactor: value,
            child: Opacity(opacity: value, child: child),
          ),
        );
      },
      child: TickerMode(
        enabled: _expanded,
        child: IgnorePointer(
          ignoring: !_expanded,
          child: ExcludeFocus(
            excluding: !_expanded,
            child: ExcludeSemantics(
              excluding: !_expanded,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 4, start: 5),
                child: Stack(
                  children: <Widget>[
                    PositionedDirectional(
                      top: 0,
                      bottom: 2,
                      start: 3,
                      child: ColoredBox(
                        color: theme.colors.line,
                        child: const SizedBox(width: 1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 16),
                      child: _buildTrace(theme, motion),
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

  Widget _buildTrace(BeautifulUiThemeData theme, _ThinkingMotion motion) {
    final children = <Widget>[];
    final query = widget.query?.trim();
    if (widget.variant == BeautifulThinkingVariant.search &&
        query != null &&
        query.isNotEmpty) {
      children.add(
        _ThinkingItemEntrance(
          duration: motion.itemDuration(0),
          curve: theme.motion.outCurve,
          translate: motion.translateItems,
          child: Semantics(
            container: true,
            label: query,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 28),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
                  child: Row(
                    children: <Widget>[
                      _ThinkingSearchIcon(color: theme.colors.inkSubtle),
                      SizedBox(width: theme.spacing.sm),
                      Expanded(
                        child: Text(
                          query,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(
                            color: theme.colors.inkMuted,
                            fontSize: 12.5,
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

    for (var index = 0; index < widget.items.length; index++) {
      children.add(
        _ThinkingItemEntrance(
          key: ValueKey<String>(
            'beautiful-thinking-entrance-${widget.items[index].id}',
          ),
          duration: motion.itemDuration(index),
          curve: theme.motion.outCurve,
          translate: motion.translateItems,
          child: _buildItem(theme, motion, widget.items[index], index),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _withGaps(children, theme.spacing.xs),
      ),
    );
  }

  Widget _buildItem(
    BeautifulUiThemeData theme,
    _ThinkingMotion motion,
    BeautifulThinkingItem item,
    int index,
  ) {
    return switch (widget.variant) {
      BeautifulThinkingVariant.steps => _buildStep(theme, item, index),
      BeautifulThinkingVariant.reasoning => _buildReasoning(theme, item),
      BeautifulThinkingVariant.search => _buildSearchResult(
        theme,
        motion,
        item,
        index,
      ),
      BeautifulThinkingVariant.coding => _buildCodingItem(theme, motion, item),
    };
  }

  Widget _buildStep(
    BeautifulUiThemeData theme,
    BeautifulThinkingItem item,
    int index,
  ) {
    final isCurrent =
        widget.status == BeautifulThinkingStatus.working &&
        index == widget.items.length - 1;
    final semanticValue = isCurrent
        ? widget.workingLabel
        : widget.completedLabel;
    return Semantics(
      key: ValueKey<String>('beautiful-thinking-item-${item.id}'),
      container: true,
      label: _semanticLabel(item),
      value: semanticValue,
      child: ExcludeSemantics(
        child: _ThinkingStaticRow(
          leading: isCurrent
              ? _ThinkingSpinner(
                  animation: _loopController,
                  enabled: _continuousMotionEnabled,
                  lineColor: theme.colors.lineStrong,
                  activeColor: theme.colors.inkMuted,
                )
              : _ThinkingCheck(color: theme.colors.inkSubtle),
          child: _ThinkingItemCopy(item: item, theme: theme),
        ),
      ),
    );
  }

  Widget _buildReasoning(
    BeautifulUiThemeData theme,
    BeautifulThinkingItem item,
  ) {
    return Semantics(
      key: ValueKey<String>('beautiful-thinking-item-${item.id}'),
      container: true,
      label: _semanticLabel(item),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 28),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            child: Text(
              item.label,
              style: theme.typography.body.copyWith(
                color: theme.colors.inkMuted,
                fontSize: 12.5,
                height: 1.625,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResult(
    BeautifulUiThemeData theme,
    _ThinkingMotion motion,
    BeautifulThinkingItem item,
    int index,
  ) {
    final callback = widget.onItemPressed;
    final content = _ThinkingStaticRow(
      minHeight: 48,
      leading: _ThinkingGlobe(
        background: switch (index % 3) {
          0 => theme.colors.accent,
          1 => theme.colors.warning,
          _ => theme.colors.success,
        },
      ),
      child: _ThinkingItemCopy(item: item, theme: theme),
    );
    if (callback == null) {
      return Semantics(
        key: ValueKey<String>('beautiful-thinking-item-${item.id}'),
        container: true,
        label: _semanticLabel(item),
        child: ExcludeSemantics(child: content),
      );
    }
    return _ThinkingControl(
      key: ValueKey<String>('beautiful-thinking-item-${item.id}'),
      semanticLabel: _semanticLabel(item),
      link: true,
      onPressed: () => callback(item),
      minHeight: 48,
      padding: EdgeInsets.zero,
      borderRadius: theme.radii.chip,
      hoverColor: theme.colors.hover,
      focusColor: theme.colors.accent,
      transitionDuration: motion.feedback,
      fullWidth: true,
      child: content,
    );
  }

  Widget _buildCodingItem(
    BeautifulUiThemeData theme,
    _ThinkingMotion motion,
    BeautifulThinkingItem item,
  ) {
    final selected = _selectedItemId == item.id;
    return _ThinkingControl(
      key: ValueKey<String>('beautiful-thinking-item-${item.id}'),
      semanticLabel: _semanticLabel(item),
      selected: selected,
      onPressed: () {
        setState(() {
          _selectedItemId = selected ? null : item.id;
        });
        widget.onItemPressed?.call(item);
      },
      minHeight: 48,
      padding: EdgeInsets.zero,
      borderRadius: theme.radii.chip,
      hoverColor: theme.colors.hover,
      selectedColor: theme.colors.inset,
      focusColor: theme.colors.accent,
      transitionDuration: motion.feedback,
      fullWidth: true,
      child: _ThinkingStaticRow(
        minHeight: 48,
        child: _ThinkingItemCopy(item: item, theme: theme, coding: true),
      ),
    );
  }

  void _toggleExpanded() {
    final next = !_expanded;
    setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  String _semanticLabel(BeautifulThinkingItem item) {
    final parts = <String>[item.label];
    final detail = item.detail?.trim();
    if (detail != null && detail.isNotEmpty) {
      parts.add(detail);
    }
    if (item.additions case final additions?) {
      parts.add('+$additions');
    }
    if (item.deletions case final deletions?) {
      parts.add('−$deletions');
    }
    return parts.join(', ');
  }
}

List<Widget> _withGaps(List<Widget> children, double gap) {
  if (children.length < 2) {
    return children;
  }
  return <Widget>[
    for (var index = 0; index < children.length; index++) ...<Widget>[
      if (index > 0) SizedBox(height: gap),
      children[index],
    ],
  ];
}

final class _ThinkingMotion {
  const _ThinkingMotion({
    required this.feedback,
    required this.chevron,
    required this.status,
    required this.disclosure,
    required this.itemBase,
    required this.itemStagger,
    required this.translateItems,
  });

  factory _ThinkingMotion.resolve(
    BuildContext context,
    BeautifulUiEnvironment environment,
    BeautifulUiThemeData theme,
  ) {
    final platformDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (platformDisabled ||
        environment.motionPolicy == BeautifulMotionPolicy.none) {
      return const _ThinkingMotion(
        feedback: Duration.zero,
        chevron: Duration.zero,
        status: Duration.zero,
        disclosure: Duration.zero,
        itemBase: Duration.zero,
        itemStagger: Duration.zero,
        translateItems: false,
      );
    }
    if (environment.motionPolicy == BeautifulMotionPolicy.reduced) {
      return _ThinkingMotion(
        feedback: theme.motion.quick,
        chevron: theme.motion.quick,
        status: theme.motion.quick,
        disclosure: theme.motion.quick,
        itemBase: theme.motion.quick,
        itemStagger: Duration.zero,
        translateItems: false,
      );
    }
    return const _ThinkingMotion(
      feedback: Duration(milliseconds: 120),
      chevron: Duration(milliseconds: 300),
      status: Duration(milliseconds: 350),
      disclosure: Duration(milliseconds: 400),
      itemBase: Duration(milliseconds: 320),
      itemStagger: Duration(milliseconds: 120),
      translateItems: true,
    );
  }

  final Duration feedback;
  final Duration chevron;
  final Duration status;
  final Duration disclosure;
  final Duration itemBase;
  final Duration itemStagger;
  final bool translateItems;

  // A trace is caller-sized. Keep the initial stagger while preventing later
  // rows from animating for tens of seconds in a long completed trace.
  Duration itemDuration(int index) =>
      itemBase + itemStagger * index.clamp(0, 3);
}

final class _ThinkingControl extends StatefulWidget {
  const _ThinkingControl({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    required this.minHeight,
    required this.padding,
    required this.borderRadius,
    required this.hoverColor,
    required this.focusColor,
    required this.transitionDuration,
    required this.child,
    this.identifier,
    this.preserveChildSemantics = false,
    this.expanded,
    this.selected,
    this.link = false,
    this.selectedColor,
    this.fullWidth = false,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color hoverColor;
  final Color focusColor;
  final Duration transitionDuration;
  final Widget child;
  final String? identifier;
  final bool preserveChildSemantics;
  final bool? expanded;
  final bool? selected;
  final bool link;
  final Color? selectedColor;
  final bool fullWidth;

  @override
  State<_ThinkingControl> createState() => _ThinkingControlState();
}

final class _ThinkingControlState extends State<_ThinkingControl> {
  late final FocusNode _focusNode;
  var _hovered = false;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.semanticLabel);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.selected == true
        ? widget.selectedColor ?? widget.hoverColor
        : _hovered
        ? widget.hoverColor
        : const Color(0x00000000);
    return Semantics(
      container: true,
      explicitChildNodes: widget.preserveChildSemantics,
      identifier: widget.identifier,
      button: !widget.link,
      link: widget.link,
      enabled: true,
      selected: widget.selected,
      expanded: widget.expanded,
      excludeSemantics: !widget.preserveChildSemantics,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      onExpand: widget.expanded == false ? widget.onPressed : null,
      onCollapse: widget.expanded == true ? widget.onPressed : null,
      child: SizedBox(
        width: widget.fullWidth ? double.infinity : null,
        child: FocusableActionDetector(
          focusNode: _focusNode,
          mouseCursor: SystemMouseCursors.click,
          onShowHoverHighlight: (value) => setState(() => _hovered = value),
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focusNode.requestFocus();
              widget.onPressed();
            },
            child: AnimatedContainer(
              duration: widget.transitionDuration,
              curve: const Cubic(0.23, 1, 0.32, 1),
              constraints: BoxConstraints(
                minWidth: 44,
                minHeight: widget.minHeight,
              ),
              padding: widget.padding,
              decoration: BoxDecoration(
                color: background,
                border: Border.all(
                  color: _focused ? widget.focusColor : const Color(0x00000000),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(widget.borderRadius),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

final class _ThinkingStatusEntrance extends StatelessWidget {
  const _ThinkingStatusEntrance({
    required this.duration,
    required this.curve,
    required this.child,
  });

  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

final class _ThinkingItemEntrance extends StatelessWidget {
  const _ThinkingItemEntrance({
    super.key,
    required this.duration,
    required this.curve,
    required this.translate,
    required this.child,
  });

  final Duration duration;
  final Curve curve;
  final bool translate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, translate ? 8 * (1 - value) : 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

final class _ThinkingStaticRow extends StatelessWidget {
  const _ThinkingStaticRow({
    this.leading,
    required this.child,
    this.minHeight = 28,
  });

  final Widget? leading;
  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        child: Row(
          children: <Widget>[
            if (leading case final leading?) ...<Widget>[
              ExcludeSemantics(child: leading),
              SizedBox(width: theme.spacing.sm),
            ],
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

final class _ThinkingItemCopy extends StatelessWidget {
  const _ThinkingItemCopy({
    required this.item,
    required this.theme,
    this.coding = false,
  });

  final BeautifulThinkingItem item;
  final BeautifulUiThemeData theme;
  final bool coding;

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[];
    final detail = item.detail?.trim();
    if (detail != null && detail.isNotEmpty) {
      details.add(
        Text(
          detail,
          style: (coding ? theme.typography.mono : theme.typography.caption)
              .copyWith(color: theme.colors.inkSubtle, fontSize: 11.5),
        ),
      );
    }
    if (coding && (item.additions != null || item.deletions != null)) {
      details.add(
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              if (item.additions case final additions?)
                TextSpan(
                  text: '+$additions',
                  style: TextStyle(color: theme.colors.success),
                ),
              if (item.additions != null && item.deletions != null)
                const TextSpan(text: ' '),
              if (item.deletions case final deletions?)
                TextSpan(
                  text: '−$deletions',
                  style: TextStyle(color: theme.colors.destructive),
                ),
            ],
          ),
          style: theme.typography.mono.copyWith(fontSize: 11),
          textDirection: TextDirection.ltr,
        ),
      );
    }

    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          item.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.label.copyWith(
            color: theme.colors.ink,
            fontSize: 12.5,
          ),
        ),
        ...details,
      ],
    );
  }
}

final class _ThinkingShimmerLabel extends StatelessWidget {
  const _ThinkingShimmerLabel({
    required this.label,
    required this.animation,
    required this.enabled,
    required this.theme,
  });

  final String label;
  final Animation<double> animation;
  final bool enabled;
  final BeautifulUiThemeData theme;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.label.copyWith(
        color: theme.colors.inkMuted,
        fontSize: 13,
      ),
    );
    if (!enabled) {
      return text;
    }
    return AnimatedBuilder(
      animation: animation,
      child: text,
      builder: (context, child) {
        final center = -2.5 + animation.value * 5;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(center - 1.2, 0),
            end: Alignment(center + 1.2, 0),
            colors: <Color>[
              theme.colors.inkMuted,
              theme.colors.ink,
              theme.colors.inkMuted,
            ],
            stops: const <double>[0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

final class _ThinkingSpinner extends StatelessWidget {
  const _ThinkingSpinner({
    required this.animation,
    required this.enabled,
    required this.lineColor,
    required this.activeColor,
  });

  final Animation<double> animation;
  final bool enabled;
  final Color lineColor;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final painter = _SpinnerPainter(
      lineColor: lineColor,
      activeColor: activeColor,
    );
    final spinner = SizedBox.square(
      dimension: 12,
      child: CustomPaint(painter: painter),
    );
    if (!enabled) {
      return spinner;
    }
    return RotationTransition(
      turns: Tween<double>(begin: 0, end: 2).animate(animation),
      child: spinner,
    );
  }
}

final class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.lineColor, required this.activeColor});

  final Color lineColor;
  final Color activeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - 1.5) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi / 2,
      false,
      Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.activeColor != activeColor;
  }
}

final class _ThinkingSparkle extends StatelessWidget {
  const _ThinkingSparkle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: CustomPaint(painter: _SparklePainter(color)),
    );
  }
}

final class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24;
    final sy = size.height / 24;
    final path = Path()
      ..moveTo(12 * sx, 2 * sy)
      ..lineTo(14.4 * sx, 9.2 * sy)
      ..lineTo(22 * sx, 12 * sy)
      ..lineTo(14.4 * sx, 14.8 * sy)
      ..lineTo(12 * sx, 22 * sy)
      ..lineTo(9.6 * sx, 14.8 * sy)
      ..lineTo(2 * sx, 12 * sy)
      ..lineTo(9.6 * sx, 9.2 * sy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}

final class _ThinkingChevron extends StatelessWidget {
  const _ThinkingChevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 14,
      child: CustomPaint(painter: _ChevronPainter(color)),
    );
  }
}

final class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.25, size.height * 0.38)
        ..lineTo(size.width * 0.5, size.height * 0.63)
        ..lineTo(size.width * 0.75, size.height * 0.38),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}

final class _ThinkingSearchIcon extends StatelessWidget {
  const _ThinkingSearchIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 14,
      child: CustomPaint(painter: _SearchPainter(color)),
    );
  }
}

final class _SearchPainter extends CustomPainter {
  const _SearchPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(size.width * 0.44, size.height * 0.44),
      size.shortestSide * 0.3,
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.66, size.height * 0.66),
      Offset(size.width * 0.9, size.height * 0.9),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SearchPainter oldDelegate) => oldDelegate.color != color;
}

final class _ThinkingCheck extends StatelessWidget {
  const _ThinkingCheck({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 14,
      child: CustomPaint(painter: _CheckPainter(color)),
    );
  }
}

final class _CheckPainter extends CustomPainter {
  const _CheckPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.17, size.height * 0.52)
        ..lineTo(size.width * 0.4, size.height * 0.74)
        ..lineTo(size.width * 0.84, size.height * 0.28),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => oldDelegate.color != color;
}

final class _ThinkingGlobe extends StatelessWidget {
  const _ThinkingGlobe({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: const SizedBox.square(
        dimension: 14,
        child: Padding(
          padding: EdgeInsets.all(2.5),
          child: CustomPaint(painter: _GlobePainter()),
        ),
      ),
    );
  }
}

final class _GlobePainter extends CustomPainter {
  const _GlobePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffffffff)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 0.5;
    canvas
      ..drawCircle(center, radius, paint)
      ..drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint)
      ..drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * 0.45,
          height: size.height,
        ),
        paint,
      );
  }

  @override
  bool shouldRepaint(_GlobePainter oldDelegate) => false;
}
