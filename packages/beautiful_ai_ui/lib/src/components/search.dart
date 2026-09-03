import 'dart:math' as math;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/layout.dart';
import '../foundation/motion.dart';
import '../foundation/theme.dart';

/// An immutable, searchable entry displayed by [BeautifulSearch].
///
/// [id] is identity, not display text. It must be non-empty and unique within
/// one [BeautifulSearch.items] snapshot. The module searches [title],
/// [subtitle], [group], and [keywords] with case-insensitive substring
/// matching while preserving the caller's item order.
final class BeautifulSearchItem {
  /// Creates a search entry.
  ///
  /// Parameters:
  /// - [id] (`String`, required): Stable, non-empty identity.
  /// - [title] (`String`, required): Primary visible and semantic label.
  /// - [subtitle] (`String?`, optional): Secondary visible searchable text.
  /// - [group] (`String?`, optional): Visible searchable grouping metadata.
  /// - [keywords] (`List<String>`, default: empty): Search-only aliases.
  const BeautifulSearchItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.group,
    this.keywords = const <String>[],
  }) : assert(id != ''),
       assert(title != '');

  /// Stable identity used to retain highlight and focus across updates.
  final String id;

  /// Primary visible and semantic label.
  final String title;

  /// Optional secondary visible and searchable text.
  final String? subtitle;

  /// Optional visible and searchable grouping metadata.
  final String? group;

  /// Search-only aliases that are not rendered or announced.
  final List<String> keywords;
}

/// A compact command search with filtering, selection, and keyboard control.
///
/// The module owns its query, text controller, focus, highlight, scrolling,
/// filtering, adaptive density, motion, and Semantics. The caller supplies an
/// immutable item snapshot and receives query and selection notifications.
/// No controller or shadcn type crosses the public seam.
///
/// An empty query shows the first five items. A non-empty query searches all
/// item text with case-insensitive substring matching. The empty message is
/// shown only after a query reaches three Unicode scalar values, matching the
/// reference component's delayed empty-state intent.
///
/// Example:
/// ```dart
/// BeautifulSearch(
///   items: const <BeautifulSearchItem>[
///     BeautifulSearchItem(id: 'forecast', title: 'Forecast demand'),
///   ],
///   onSelected: (item) => openItem(item.id),
/// )
/// ```
final class BeautifulSearch extends StatefulWidget {
  /// Creates a search module.
  ///
  /// Parameters:
  /// - [items] (`List<BeautifulSearchItem>`, required): Immutable item
  ///   snapshot with unique, non-empty IDs.
  /// - [onSelected] (`ValueChanged<BeautifulSearchItem>`, required): Called
  ///   after the selected title has been committed as the query.
  /// - [initialQuery] (`String`, default: empty): Query used only when this
  ///   state object is first created.
  /// - [placeholder] (`String`, default: `Search…`): Visible empty-field hint.
  /// - [searchLabel] (`String`, default: `Search`): Text-field Semantics label.
  /// - [clearLabel] (`String`, default: `Clear search`): Clear-button label.
  /// - [emptyTitle] (`String`, default: `No results found`): Empty heading.
  /// - [emptyHint] (`String`, default: `Adjust your search to try again`):
  ///   Empty-state guidance.
  /// - [autofocus] (`bool`, default: false): Whether the field initially asks
  ///   for keyboard focus.
  /// - [onQueryChanged] (`ValueChanged<String>?`, optional): Called once for
  ///   each user edit, clear, and selection query commit.
  ///
  /// Selection callback ordering is stable: [onQueryChanged] receives the
  /// selected title first, then [onSelected] receives the selected item.
  const BeautifulSearch({
    super.key,
    required this.items,
    required this.onSelected,
    this.initialQuery = '',
    this.placeholder = 'Search…',
    this.searchLabel = 'Search',
    this.clearLabel = 'Clear search',
    this.emptyTitle = 'No results found',
    this.emptyHint = 'Adjust your search to try again',
    this.autofocus = false,
    this.onQueryChanged,
  }) : assert(placeholder != ''),
       assert(searchLabel != ''),
       assert(clearLabel != ''),
       assert(emptyTitle != ''),
       assert(emptyHint != '');

  /// Searchable entries in deterministic display order.
  final List<BeautifulSearchItem> items;

  /// Initial query used only when the widget's state is first created.
  final String initialQuery;

  /// Visible hint shown while the query is empty.
  final String placeholder;

  /// Localized Semantics label for the editable search field.
  final String searchLabel;

  /// Localized Semantics label for the clear action.
  final String clearLabel;

  /// Localized empty-state heading.
  final String emptyTitle;

  /// Localized empty-state guidance.
  final String emptyHint;

  /// Whether the editable field initially requests focus.
  final bool autofocus;

  /// Receives raw query changes without trimming, normalization, or debounce.
  final ValueChanged<String>? onQueryChanged;

  /// Receives a selected item after its title is committed to the query.
  final ValueChanged<BeautifulSearchItem> onSelected;

  @override
  State<BeautifulSearch> createState() => _BeautifulSearchState();
}

final class _BeautifulSearchState extends State<BeautifulSearch> {
  static const _surfaceKey = Key('beautiful-search-surface');
  static const _fieldKey = Key('beautiful-search-field');
  static const _fieldTargetKey = Key('beautiful-search-field-target');
  static const _clearKey = Key('beautiful-search-clear');
  static const _emptyKey = Key('beautiful-search-empty');

  late final TextEditingController _controller;
  late final FocusNode _fieldFocusNode;
  final ScrollController _resultsScrollController = ScrollController();
  final Map<String, GlobalKey> _resultKeys = <String, GlobalKey>{};

  late String _query;
  late List<BeautifulSearchItem> _items;
  late Map<String, List<String>> _searchTextById;
  String? _filteredQuery;
  List<BeautifulSearchItem>? _filteredCache;
  Object? _measurementInputs;
  final Map<(String, String?, String?), double> _rowMeasurements = {};
  final Map<String, (double, double)> _resultOffsets = {};
  double _resultsExtent = 0;
  String? _highlightedId;
  String? _focusedResultId;
  var _fieldFocused = false;

  @override
  void initState() {
    super.initState();
    _takeItemsSnapshot();
    _query = widget.initialQuery;
    _controller = TextEditingController(text: _query)
      ..selection = TextSelection.collapsed(offset: _query.length);
    _fieldFocusNode = FocusNode(
      debugLabel: 'BeautifulSearch field',
      onKeyEvent: _handleFieldKeyEvent,
    )..addListener(_handleFieldFocusChanged);
    PaintingBinding.instance.systemFonts.addListener(_handleFontsChanged);
  }

  @override
  void didUpdateWidget(BeautifulSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    _takeItemsSnapshot();
    final currentIds = _items.map((item) => item.id).toSet();
    if (!currentIds.contains(_highlightedId)) {
      _highlightedId = null;
    }
    if (!currentIds.contains(_focusedResultId)) {
      _focusedResultId = null;
    }
    _resultKeys.removeWhere((id, _) => !currentIds.contains(id));
  }

  void _takeItemsSnapshot() {
    _items = List<BeautifulSearchItem>.unmodifiable(widget.items);
    _searchTextById = Map<String, List<String>>.unmodifiable(
      <String, List<String>>{
        for (final item in _items)
          item.id: <String>[
            item.title.toLowerCase(),
            if (item.subtitle != null) item.subtitle!.toLowerCase(),
            if (item.group != null) item.group!.toLowerCase(),
            for (final keyword in item.keywords) keyword.toLowerCase(),
          ],
      },
    );
    _filteredQuery = null;
    _filteredCache = null;
  }

  void _handleFontsChanged() {
    if (mounted) setState(_rowMeasurements.clear);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_handleFontsChanged);
    _fieldFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _controller.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  void _handleFieldFocusChanged() {
    if (_fieldFocused == _fieldFocusNode.hasFocus || !mounted) {
      return;
    }
    setState(() => _fieldFocused = _fieldFocusNode.hasFocus);
  }

  void _handleQueryChanged(String value) {
    if (value == _query) {
      return;
    }
    setState(() {
      _query = value;
      _highlightedId = null;
      _focusedResultId = null;
    });
    widget.onQueryChanged?.call(value);
  }

  void _handleSemanticTextChanged(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _handleQueryChanged(value);
  }

  void _clear() {
    final changed = _query.isNotEmpty;
    _controller.value = const TextEditingValue();
    setState(() {
      _query = '';
      _highlightedId = null;
      _focusedResultId = null;
    });
    _fieldFocusNode.requestFocus();
    if (changed) {
      widget.onQueryChanged?.call('');
    }
  }

  void _select(BeautifulSearchItem item) {
    _controller.value = TextEditingValue(
      text: item.title,
      selection: TextSelection.collapsed(offset: item.title.length),
    );
    setState(() {
      _query = item.title;
      _highlightedId = item.id;
      _focusedResultId = null;
    });
    _fieldFocusNode.requestFocus();
    widget.onQueryChanged?.call(item.title);
    widget.onSelected(item);
  }

  KeyEventResult _handleFieldKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _clear();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter) {
      if (_controller.value.composing.isValid &&
          !_controller.value.composing.isCollapsed) {
        return KeyEventResult.ignored;
      }
      _selectHighlighted();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleModuleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _clear();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusedResultId != null) {
        _highlightedId = _focusedResultId;
      }
      _fieldFocusNode.requestFocus();
      _moveHighlight(event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveHighlight(int delta) {
    final items = _filteredItems();
    if (items.isEmpty) {
      if (_highlightedId != null) {
        setState(() => _highlightedId = null);
      }
      return;
    }
    final current = items.indexWhere((item) => item.id == _highlightedId);
    final next = current < 0
        ? (delta > 0 ? 0 : items.length - 1)
        : (current + delta) % items.length;
    setState(() => _highlightedId = items[next].id);
    _ensureHighlightedVisible();
  }

  void _selectHighlighted() {
    final item = _itemForId(_highlightedId, _filteredItems());
    if (item != null) {
      _select(item);
    }
  }

  void _ensureHighlightedVisible() {
    final id = _highlightedId;
    if (id == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _highlightedId != id) {
        return;
      }
      final targetContext = _resultKeys[id]?.currentContext;
      if (targetContext == null) {
        // An arbitrary keyboard target (including the first ArrowUp) may be
        // outside the lazy viewport. Exact measured offsets reveal it without
        // requiring all preceding result widgets to exist.
        final offsets = _resultOffsets[id];
        if (offsets == null || !_resultsScrollController.hasClients) return;
        final position = _resultsScrollController.position;
        final target = offsets.$1 < position.pixels
            ? offsets.$1
            : offsets.$2 - position.viewportDimension;
        _resultsScrollController.jumpTo(
          target.clamp(
            0,
            math.max(0, _resultsExtent - position.viewportDimension),
          ),
        );
        _ensureHighlightedVisible();
        return;
      }
      final duration = _motionDuration(
        context,
        BeautifulUiTheme.of(context).motion.standard,
      );
      Scrollable.ensureVisible(
        targetContext,
        duration: duration,
        curve: BeautifulUiTheme.of(context).motion.outCurve,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  List<BeautifulSearchItem> _filteredItems() {
    if (_filteredQuery == _query && _filteredCache != null) {
      return _filteredCache!;
    }
    final needle = _query.toLowerCase();
    _filteredQuery = _query;
    return _filteredCache = _query.isEmpty
        ? _items.take(5).toList(growable: false)
        : _items
              .where(
                (item) => _searchTextById[item.id]!.any(
                  (text) => text.contains(needle),
                ),
              )
              .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    assert(_debugValidateItems(_items));
    final theme = BeautifulUiTheme.of(context);
    final environment = BeautifulUiEnvironment.of(context);
    final items = _filteredItems();
    final visibleIds = items.map((item) => item.id).toSet();
    if (!visibleIds.contains(_highlightedId)) {
      _highlightedId = null;
    }
    if (!visibleIds.contains(_focusedResultId)) {
      _focusedResultId = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = environment.modeFor(context, constraints);
        final mediaWidth = MediaQuery.maybeSizeOf(context)?.width ?? 288.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaWidth;
        final panelWidth = math.max(0.0, math.min(288.0, availableWidth));
        return Focus(
          canRequestFocus: false,
          onKeyEvent: _handleModuleKeyEvent,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: panelWidth,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 248),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: _buildSurface(context, theme, mode, items),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurface(
    BuildContext context,
    BeautifulUiThemeData theme,
    BeautifulLayoutMode mode,
    List<BeautifulSearchItem> items,
  ) {
    return Container(
      key: _surfaceKey,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.line),
        borderRadius: BorderRadius.circular(theme.radii.card),
        boxShadow: theme.shadows.raised,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildField(context, theme),
          _buildResults(context, theme, mode, items),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, BeautifulUiThemeData theme) {
    const minHeight = 48.0;
    final duration = _motionDuration(context, theme.motion.quick);
    return AnimatedContainer(
      key: _fieldTargetKey,
      duration: duration,
      curve: theme.motion.outCurve,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: EdgeInsetsDirectional.only(
        start: theme.spacing.md,
        end: _query.isEmpty ? theme.spacing.md : theme.spacing.xs,
        top: theme.spacing.sm,
        bottom: theme.spacing.sm,
      ),
      decoration: BoxDecoration(
        color: _fieldFocused
            ? theme.colors.hover.withValues(alpha: 0.45)
            : theme.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: _fieldFocused ? theme.colors.accent : theme.colors.line,
            width: _fieldFocused ? 2 : 1,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: _SearchGlyph(
              kind: _SearchGlyphKind.search,
              size: 14,
              color: theme.colors.inkSubtle,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: MergeSemantics(
              child: Semantics(
                label: widget.searchLabel,
                value: _query,
                enabled: true,
                readOnly: false,
                textField: true,
                focusable: true,
                focused: _fieldFocused,
                onTap: _fieldFocusNode.requestFocus,
                onFocus: _fieldFocusNode.requestFocus,
                onSetText: _handleSemanticTextChanged,
                child: Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: <Widget>[
                    if (_query.isEmpty)
                      ExcludeSemantics(
                        child: Text(
                          widget.placeholder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.label.copyWith(
                            color: theme.colors.inkSubtle,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    EditableText(
                      key: _fieldKey,
                      controller: _controller,
                      focusNode: _fieldFocusNode,
                      style: theme.typography.label.copyWith(
                        color: theme.colors.ink,
                        fontWeight: FontWeight.w400,
                      ),
                      cursorColor: theme.colors.accent,
                      backgroundCursorColor: theme.colors.inkSubtle,
                      selectionColor: theme.colors.accentTint,
                      maxLines: 1,
                      textAlign: TextAlign.start,
                      textDirection: Directionality.of(context),
                      autofocus: widget.autofocus,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      autocorrect: true,
                      enableSuggestions: true,
                      onChanged: _handleQueryChanged,
                      onSubmitted: (_) => _selectHighlighted(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_query.isNotEmpty) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            _SearchAction(
              key: _clearKey,
              semanticLabel: widget.clearLabel,
              onActivate: _clear,
              builder: (context, highlighted) {
                return AnimatedContainer(
                  duration: duration,
                  curve: theme.motion.outCurve,
                  width: minHeight,
                  height: minHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? theme.colors.hoverStrong
                        : const Color(0x00000000),
                    shape: BoxShape.circle,
                  ),
                  child: ExcludeSemantics(
                    child: _SearchGlyph(
                      kind: _SearchGlyphKind.clear,
                      size: 12,
                      color: highlighted
                          ? theme.colors.ink
                          : theme.colors.inkSubtle,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    BeautifulUiThemeData theme,
    BeautifulLayoutMode mode,
    List<BeautifulSearchItem> items,
  ) {
    final showEmpty = _query.runes.length > 2 && items.isEmpty;
    if (showEmpty) {
      return _buildEmptyState(theme);
    }
    if (items.isEmpty) {
      return SizedBox(height: theme.spacing.sm);
    }
    final maxHeight = mode == BeautifulLayoutMode.compact ? 320.0 : 240.0;
    // Keep the compact default/unique-match layout unchanged. Only a larger
    // result set needs extent measurement and lazy row construction.
    if (items.length <= 5) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          controller: _resultsScrollController,
          padding: EdgeInsets.all(theme.spacing.xs),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var index = 0; index < items.length; index++) ...<Widget>[
                  if (index > 0) const SizedBox(height: 1),
                  _buildResult(context, theme, items[index], index),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final extents = _measureResults(
          context,
          theme,
          items,
          constraints.maxWidth,
        );
        return SizedBox(
          height: math.min(maxHeight, _resultsExtent),
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: ListView.builder(
              controller: _resultsScrollController,
              primary: false,
              padding: EdgeInsets.all(theme.spacing.xs),
              itemCount: items.length,
              itemExtentBuilder: (index, _) => extents[index],
              findChildIndexCallback: (key) {
                final index = items.indexWhere(
                  (item) => ValueKey(item.id) == key,
                );
                return index < 0 ? null : index;
              },
              itemBuilder: (context, index) => Padding(
                key: ValueKey(items[index].id),
                padding: EdgeInsets.only(top: index == 0 ? 0 : 1),
                child: _buildResult(context, theme, items[index], index),
              ),
            ),
          ),
        );
      },
    );
  }

  List<double> _measureResults(
    BuildContext context,
    BeautifulUiThemeData theme,
    List<BeautifulSearchItem> items,
    double width,
  ) {
    final defaults = DefaultTextStyle.of(context);
    TextStyle resolve(TextStyle style) {
      if (style.inherit) style = defaults.style.merge(style);
      if (MediaQuery.boldTextOf(context)) {
        style = style.merge(const TextStyle(fontWeight: FontWeight.bold));
      }
      return style.merge(
        TextStyle(
          height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
          letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
          wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
        ),
      );
    }

    final titleStyle = resolve(theme.typography.label);
    final captionStyle = resolve(theme.typography.caption);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    final textAlign = defaults.textAlign ?? TextAlign.start;
    final heightBehavior =
        defaults.textHeightBehavior ??
        DefaultTextHeightBehavior.maybeOf(context);
    final textWidth = math.max(
      0.0,
      width - (theme.spacing.xs + theme.spacing.sm) * 2,
    );
    final inputs = (
      titleStyle,
      captionStyle,
      direction,
      scaler,
      locale,
      textAlign,
      heightBehavior,
      defaults.textWidthBasis,
      textWidth,
      theme.spacing.sm,
    );
    if (_measurementInputs != inputs) {
      _measurementInputs = inputs;
      _rowMeasurements.clear();
    }
    TextPainter? painter;
    double measure(String text, TextStyle style, int lines) {
      painter ??= TextPainter(
        textDirection: direction,
        textAlign: textAlign,
        textScaler: scaler,
        locale: locale,
        textWidthBasis: defaults.textWidthBasis,
        textHeightBehavior: heightBehavior,
        ellipsis: '\u2026',
      );
      painter!
        ..text = TextSpan(text: text, style: style)
        ..maxLines = lines
        ..layout(maxWidth: textWidth);
      return painter!.height;
    }

    final extents = <double>[];
    _resultOffsets.clear();
    var offset = theme.spacing.xs;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      final key = (item.title, item.subtitle, item.group);
      var height = _rowMeasurements[key];
      if (height == null) {
        height = measure(item.title, titleStyle, 2);
        if (item.subtitle?.isNotEmpty ?? false) {
          height += measure(item.subtitle!, captionStyle, 2);
        }
        if (item.group?.isNotEmpty ?? false) {
          height += measure(item.group!, captionStyle, 1);
        }
        height = math.max(48.0, height + theme.spacing.sm * 2);
        // Bound retained query/layout history independently of result count.
        if (_rowMeasurements.length >= 4096) {
          _rowMeasurements.remove(_rowMeasurements.keys.first);
        }
        _rowMeasurements[key] = height;
      }
      final gap = index == 0 ? 0.0 : 1.0;
      _resultOffsets[item.id] = (offset + gap, offset + gap + height);
      extents.add(height + gap);
      offset += height + gap;
    }
    painter?.dispose();
    _resultsExtent = offset + theme.spacing.xs;
    return extents;
  }

  Widget _buildResult(
    BuildContext context,
    BeautifulUiThemeData theme,
    BeautifulSearchItem item,
    int index,
  ) {
    const minHeight = 48.0;
    final duration = _motionDuration(context, theme.motion.standard);
    final key = _resultKeys.putIfAbsent(
      item.id,
      () => GlobalKey(debugLabel: 'BeautifulSearch result ${item.id}'),
    );
    return _SearchAction(
      key: key,
      semanticLabel: _semanticLabelFor(item),
      selected: item.id == _highlightedId,
      sortKey: OrdinalSortKey(index.toDouble(), name: 'BeautifulSearch'),
      onFocusChanged: (focused) {
        if (!mounted) {
          return;
        }
        if (focused) {
          setState(() {
            _focusedResultId = item.id;
            _highlightedId = item.id;
          });
        } else if (_focusedResultId == item.id) {
          setState(() => _focusedResultId = null);
        }
      },
      onActivate: () => _select(item),
      builder: (context, highlighted) {
        return AnimatedContainer(
          key: ValueKey<String>('beautiful-search-result-${item.id}'),
          duration: duration,
          curve: theme.motion.outCurve,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.sm,
            vertical: theme.spacing.sm,
          ),
          decoration: BoxDecoration(
            color: highlighted ? theme.colors.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(theme.radii.chip),
          ),
          child: _buildResultText(theme, item),
        );
      },
    );
  }

  Widget _buildResultText(
    BeautifulUiThemeData theme,
    BeautifulSearchItem item,
  ) {
    final subtitle = item.subtitle;
    final group = item.group;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.label.copyWith(color: theme.colors.ink),
        ),
        if (subtitle != null && subtitle.isNotEmpty)
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(
              color: theme.colors.inkMuted,
            ),
          ),
        if (group != null && group.isNotEmpty)
          Text(
            group,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.caption.copyWith(
              color: theme.colors.inkSubtle,
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BeautifulUiThemeData theme) {
    final semanticLabel = '${widget.emptyTitle}. ${widget.emptyHint}';
    return Semantics(
      key: _emptyKey,
      container: true,
      role: SemanticsRole.status,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: theme.spacing.lg,
            vertical: theme.spacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(bottom: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colors.inset,
                  border: Border.all(color: theme.colors.line),
                  borderRadius: BorderRadius.circular(theme.radii.control),
                ),
                child: _SearchGlyph(
                  kind: _SearchGlyphKind.search,
                  size: 15,
                  color: theme.colors.inkSubtle,
                ),
              ),
              Text(
                widget.emptyTitle,
                textAlign: TextAlign.center,
                style: theme.typography.label.copyWith(color: theme.colors.ink),
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                widget.emptyHint,
                textAlign: TextAlign.center,
                style: theme.typography.caption.copyWith(
                  color: theme.colors.inkSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _SearchAction extends StatefulWidget {
  const _SearchAction({
    super.key,
    required this.semanticLabel,
    required this.onActivate,
    required this.builder,
    this.selected = false,
    this.sortKey,
    this.onFocusChanged,
  });

  final String semanticLabel;
  final VoidCallback onActivate;
  final Widget Function(BuildContext context, bool highlighted) builder;
  final bool selected;
  final SemanticsSortKey? sortKey;
  final ValueChanged<bool>? onFocusChanged;

  @override
  State<_SearchAction> createState() => _SearchActionState();
}

enum _SearchGlyphKind { search, clear }

final class _SearchGlyph extends StatelessWidget {
  const _SearchGlyph({
    required this.kind,
    required this.size,
    required this.color,
  });

  final _SearchGlyphKind kind;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SearchGlyphPainter(kind: kind, color: color),
    );
  }
}

final class _SearchGlyphPainter extends CustomPainter {
  const _SearchGlyphPainter({required this.kind, required this.color});

  final _SearchGlyphKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, size.shortestSide * 0.13)
      ..strokeCap = StrokeCap.round;
    switch (kind) {
      case _SearchGlyphKind.search:
        final radius = size.shortestSide * 0.28;
        final center = Offset(size.width * 0.43, size.height * 0.43);
        canvas.drawCircle(center, radius, paint);
        canvas.drawLine(
          Offset(size.width * 0.64, size.height * 0.64),
          Offset(size.width * 0.88, size.height * 0.88),
          paint,
        );
      case _SearchGlyphKind.clear:
        canvas.drawLine(
          Offset(size.width * 0.24, size.height * 0.24),
          Offset(size.width * 0.76, size.height * 0.76),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.76, size.height * 0.24),
          Offset(size.width * 0.24, size.height * 0.76),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_SearchGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

final class _SearchActionState extends State<_SearchAction>
    with AutomaticKeepAliveClientMixin<_SearchAction> {
  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'BeautifulSearch action: ${widget.semanticLabel}',
  );
  var _hovered = false;
  var _focused = false;
  var _showFocusHighlight = false;

  @override
  bool get wantKeepAlive => _focused;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final highlighted = widget.selected || _hovered || _showFocusHighlight;
    return Semantics(
      container: true,
      button: true,
      enabled: true,
      focusable: true,
      focused: _focused,
      selected: widget.selected,
      excludeSemantics: true,
      label: widget.semanticLabel,
      sortKey: widget.sortKey,
      onTap: widget.onActivate,
      onFocus: _focusNode.requestFocus,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!_hovered) {
            setState(() => _hovered = true);
          }
        },
        onExit: (_) {
          if (_hovered) {
            setState(() => _hovered = false);
          }
        },
        child: FocusableActionDetector(
          focusNode: _focusNode,
          includeFocusSemantics: false,
          mouseCursor: MouseCursor.defer,
          onShowFocusHighlight: (value) {
            if (_showFocusHighlight != value) {
              setState(() => _showFocusHighlight = value);
            }
          },
          onFocusChange: (value) {
            if (_focused != value) {
              setState(() => _focused = value);
              updateKeepAlive();
            }
            widget.onFocusChanged?.call(value);
          },
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onActivate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.onActivate,
            child: widget.builder(context, highlighted),
          ),
        ),
      ),
    );
  }
}

BeautifulSearchItem? _itemForId(String? id, List<BeautifulSearchItem> items) {
  if (id == null) {
    return null;
  }
  for (final item in items) {
    if (item.id == id) {
      return item;
    }
  }
  return null;
}

String _semanticLabelFor(BeautifulSearchItem item) {
  return <String>[
    item.title,
    if (item.subtitle case final subtitle? when subtitle.isNotEmpty) subtitle,
    if (item.group case final group? when group.isNotEmpty) group,
  ].join('. ');
}

Duration _motionDuration(BuildContext context, Duration enabledDuration) {
  final disabledByPlatform =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  final policy = BeautifulUiEnvironment.of(context).motionPolicy;
  return disabledByPlatform || policy == BeautifulMotionPolicy.none
      ? Duration.zero
      : enabledDuration;
}

bool _debugValidateItems(List<BeautifulSearchItem> items) {
  final ids = <String>{};
  for (final item in items) {
    if (item.id.trim().isEmpty) {
      throw FlutterError('BeautifulSearch item IDs must be non-empty.');
    }
    if (!ids.add(item.id)) {
      throw FlutterError(
        'BeautifulSearch item IDs must be unique; duplicate "${item.id}".',
      );
    }
    if (item.title.trim().isEmpty) {
      throw FlutterError(
        'BeautifulSearch item titles must be non-empty; item "${item.id}".',
      );
    }
  }
  return true;
}
