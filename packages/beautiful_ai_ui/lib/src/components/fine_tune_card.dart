import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';
import '../implementation/controls/text_selection.dart';

/// Layout choices offered by [BeautifulFineTuneCard].
enum BeautifulFineTuneLayout {
  /// Arrange content horizontally.
  row,

  /// Arrange content vertically.
  column,

  /// Arrange content in a grid.
  grid,
}

/// An immutable numeric property and its accepted value.
///
/// [id] is stable identity and must be unique within a settings snapshot.
/// All numbers must be finite, [step] must be positive, and [value] must be
/// between [min] and [max]. [BeautifulFineTuneSettings] checks these invariants
/// in release builds as well as debug builds.
@immutable
final class BeautifulFineTuneField {
  /// Creates a numeric property. [suffix] is a visible unit, such as `%`.
  const BeautifulFineTuneField({
    required this.id,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    this.suffix = '',
  });

  /// Stable, non-empty identity used to retain drafts and focus on reorder.
  final String id;

  /// Localized, non-empty property name.
  final String label;

  /// Current value accepted by the host.
  final double value;

  /// Inclusive lower bound.
  final double min;

  /// Inclusive upper bound.
  final double max;

  /// Positive increment used by touch, keyboard, and pointer adjustment.
  final double step;

  /// Optional localized display unit.
  final String suffix;

  BeautifulFineTuneField _withValue(double next) => BeautifulFineTuneField(
    id: id,
    label: label,
    value: next,
    min: min,
    max: max,
    step: step,
    suffix: suffix,
  );
}

/// An immutable snapshot of all settings edited by [BeautifulFineTuneCard].
///
/// Collections are defensively copied. The host accepts an edit by replacing
/// the card's [BeautifulFineTuneCard.settings] with the callback's snapshot.
@immutable
final class BeautifulFineTuneSettings {
  /// Creates settings and validates numeric ranges and unique field IDs.
  BeautifulFineTuneSettings({
    required Iterable<BeautifulFineTuneField> fields,
    this.layout = BeautifulFineTuneLayout.row,
    this.typeId,
  }) : fields = List<BeautifulFineTuneField>.unmodifiable(fields) {
    final ids = <String>{};
    for (final field in this.fields) {
      if (field.id.trim().isEmpty || !ids.add(field.id)) {
        throw ArgumentError.value(
          field.id,
          'fields',
          'IDs must be unique and non-empty.',
        );
      }
      if (field.label.trim().isEmpty ||
          !field.min.isFinite ||
          !field.max.isFinite ||
          !field.value.isFinite ||
          !field.step.isFinite ||
          field.step <= 0 ||
          field.min > field.max ||
          field.value < field.min ||
          field.value > field.max) {
        throw ArgumentError.value(
          field.id,
          'fields',
          'Use a label, finite ordered bounds, an in-range value, and a positive finite step.',
        );
      }
    }
    if (typeId != null && typeId!.trim().isEmpty) {
      throw ArgumentError.value(
        typeId,
        'typeId',
        'Use a non-empty ID or null.',
      );
    }
  }

  /// Numeric properties in their visible and traversal order.
  final List<BeautifulFineTuneField> fields;

  /// Current layout choice.
  final BeautifulFineTuneLayout layout;

  /// Selected [BeautifulFineTuneOption.id], or null before selection.
  final String? typeId;
}

/// A stable type choice with independently localizable text.
@immutable
final class BeautifulFineTuneOption {
  /// Creates a type choice with non-empty [id] and [label].
  const BeautifulFineTuneOption({required this.id, required this.label});

  /// Stable identity, unique within the card's options.
  final String id;

  /// Localized visible and assistive text.
  final String label;
}

/// Localized copy for [BeautifulFineTuneCard].
@immutable
final class BeautifulFineTuneLabels {
  /// Creates labels for card sections, actions, status, and validation.
  const BeautifulFineTuneLabels({
    this.title = 'Fine-tune',
    this.layout = 'Layout',
    this.type = 'Type',
    this.placeholder = 'Select type',
    this.adjust = 'Adjust',
    this.edited = 'Edited',
    this.row = 'Row',
    this.column = 'Column',
    this.grid = 'Grid',
    this.increase = 'Increase',
    this.decrease = 'Decrease',
    this.value = 'value',
    this.invalidNumber = 'Enter a finite number',
  });

  /// Card heading.
  final String title;

  /// Layout section heading.
  final String layout;

  /// Type section heading.
  final String type;

  /// Type disclosure text before a selection.
  final String placeholder;

  /// Status while settings match the initial mounted snapshot.
  final String adjust;

  /// Status when settings differ from the initial mounted snapshot.
  final String edited;

  /// Horizontal layout choice.
  final String row;

  /// Vertical layout choice.
  final String column;

  /// Grid layout choice.
  final String grid;

  /// Prefix for increment action labels.
  final String increase;

  /// Prefix for decrement action labels.
  final String decrease;

  /// Suffix for numeric entry assistive labels.
  final String value;

  /// Validation feedback for malformed or non-finite numeric drafts.
  final String invalidNumber;
}

/// A controlled inspector for numeric properties, layout, and a type choice.
///
/// [settings] is the accepted host snapshot. Every adjustment emits a full
/// proposed snapshot through [onChanged]; the card never accepts business
/// state on the host's behalf. A null callback disables all editing.
///
/// Numeric drafts commit on Enter, the keyboard Done action, or focus loss.
/// Invalid drafts stay visible with validation feedback. Escape restores the
/// accepted value. Active IME composition is never submitted or rewritten.
/// Direct entry clamps to the property's bounds. Arrow keys and 48dp touch
/// buttons adjust by its step; Shift multiplies keyboard steps by ten. The
/// property label also supports horizontal pointer scrubbing and assistive
/// increase/decrease actions. Vertical gestures remain available to scrolling.
///
/// When the host provides an [Overlay], numeric entries support Flutter text
/// selection gestures, platform-shaped handles, and localized clipboard
/// actions. Delayed clipboard results cannot replace a newer draft or property.
///
/// The Edited marker compares accepted values with the initial mounted
/// snapshot; use a new widget key when inspecting a different object. Type
/// options open inline, so narrow layouts do not require an anchored overlay.
/// The host supplies scrolling when the available height is constrained.
final class BeautifulFineTuneCard extends StatefulWidget {
  /// Creates a controlled fine-tuning inspector.
  const BeautifulFineTuneCard({
    super.key,
    required this.settings,
    this.options = const <BeautifulFineTuneOption>[],
    this.onChanged,
    this.labels = const BeautifulFineTuneLabels(),
  });

  /// Accepted numeric, layout, and type settings.
  final BeautifulFineTuneSettings settings;

  /// Type choices with unique, non-empty IDs and non-empty labels.
  final List<BeautifulFineTuneOption> options;

  /// Receives a proposed full snapshot, or null to disable all controls.
  final ValueChanged<BeautifulFineTuneSettings>? onChanged;

  /// Localized card copy.
  final BeautifulFineTuneLabels labels;

  @override
  State<BeautifulFineTuneCard> createState() => _BeautifulFineTuneCardState();
}

final class _BeautifulFineTuneCardState extends State<BeautifulFineTuneCard> {
  late final BeautifulFineTuneSettings _baseline = widget.settings;
  late List<BeautifulFineTuneOption> _options;
  var _menuOpen = false;
  FocusNode? _typeButtonFocus;

  @override
  void initState() {
    super.initState();
    _snapshotOptions();
  }

  @override
  void didUpdateWidget(BeautifulFineTuneCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _snapshotOptions();
    if (widget.onChanged == null || _options.isEmpty) {
      _menuOpen = false;
    }
  }

  void _snapshotOptions() {
    _options = List<BeautifulFineTuneOption>.unmodifiable(widget.options);
    final ids = <String>{};
    for (final option in _options) {
      if (option.id.trim().isEmpty ||
          option.label.trim().isEmpty ||
          !ids.add(option.id)) {
        throw ArgumentError.value(
          option.id,
          'options',
          'Use unique non-empty IDs and non-empty labels.',
        );
      }
    }
  }

  bool get _edited {
    final current = widget.settings;
    return current.layout != _baseline.layout ||
        current.typeId != _baseline.typeId ||
        !mapEquals(
          <String, double>{for (final f in current.fields) f.id: f.value},
          <String, double>{for (final f in _baseline.fields) f.id: f.value},
        );
  }

  void _setValue(String id, double value) {
    widget.onChanged?.call(
      BeautifulFineTuneSettings(
        fields: <BeautifulFineTuneField>[
          for (final field in widget.settings.fields)
            if (field.id == id) field._withValue(value) else field,
        ],
        layout: widget.settings.layout,
        typeId: widget.settings.typeId,
      ),
    );
  }

  void _setLayout(BeautifulFineTuneLayout layout) {
    if (layout == widget.settings.layout) return;
    widget.onChanged?.call(
      BeautifulFineTuneSettings(
        fields: widget.settings.fields,
        layout: layout,
        typeId: widget.settings.typeId,
      ),
    );
  }

  void _setType(String id) {
    setState(() => _menuOpen = false);
    _typeButtonFocus?.requestFocus();
    if (id == widget.settings.typeId) return;
    widget.onChanged?.call(
      BeautifulFineTuneSettings(
        fields: widget.settings.fields,
        layout: widget.settings.layout,
        typeId: id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(
            width: math.min(480, available),
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) {
                if (_menuOpen &&
                    event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  setState(() => _menuOpen = false);
                  _typeButtonFocus?.requestFocus();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Container(
                key: const Key('beautiful-fine-tune-surface'),
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
                    Padding(
                      padding: EdgeInsets.all(theme.spacing.md),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: theme.spacing.md,
                        runSpacing: theme.spacing.sm,
                        children: <Widget>[
                          Semantics(
                            header: true,
                            child: Text(
                              widget.labels.title,
                              style: theme.typography.label,
                            ),
                          ),
                          Semantics(
                            role: SemanticsRole.status,
                            child: Text(
                              _edited
                                  ? widget.labels.edited
                                  : widget.labels.adjust,
                              style: theme.typography.caption.copyWith(
                                color: _edited
                                    ? theme.colors.success
                                    : theme.colors.accentInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _divider(theme),
                    Padding(
                      padding: EdgeInsets.all(theme.spacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            widget.labels.layout,
                            style: theme.typography.label,
                          ),
                          SizedBox(height: theme.spacing.sm),
                          _layoutChoices(theme),
                          if (widget.settings.fields.isNotEmpty) ...<Widget>[
                            SizedBox(height: theme.spacing.md),
                            _fields(theme),
                          ],
                        ],
                      ),
                    ),
                    if (_options.isNotEmpty ||
                        widget.settings.typeId != null) ...<Widget>[
                      _divider(theme),
                      Padding(
                        padding: EdgeInsets.all(theme.spacing.md),
                        child: _typeChoices(theme),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _divider(BeautifulUiThemeData theme) =>
      SizedBox(height: 1, child: ColoredBox(color: theme.colors.line));

  Widget _layoutChoices(BeautifulUiThemeData theme) {
    final labels = <BeautifulFineTuneLayout, String>{
      BeautifulFineTuneLayout.row: widget.labels.row,
      BeautifulFineTuneLayout.column: widget.labels.column,
      BeautifulFineTuneLayout.grid: widget.labels.grid,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 260 ||
            MediaQuery.textScalerOf(context).scale(14) > 21;
        final width = stacked
            ? constraints.maxWidth
            : (constraints.maxWidth - theme.spacing.xs * 2) / 3;
        return Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            for (final layout in BeautifulFineTuneLayout.values)
              SizedBox(
                width: width,
                child: BeautifulActionControl(
                  key: ValueKey<String>(
                    'beautiful-fine-tune-layout-${layout.name}',
                  ),
                  label: labels[layout]!,
                  maxLines: null,
                  semanticLabel: '${labels[layout]} ${widget.labels.layout}',
                  selected: widget.settings.layout == layout,
                  tone: widget.settings.layout == layout
                      ? BeautifulActionTone.primary
                      : BeautifulActionTone.secondary,
                  minHeight: 48,
                  fullWidth: true,
                  onPressed: widget.onChanged == null
                      ? null
                      : () => _setLayout(layout),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _fields(BeautifulUiThemeData theme) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 392 &&
              MediaQuery.textScalerOf(context).scale(14) <= 21
          ? 2
          : 1;
      final width =
          (constraints.maxWidth - theme.spacing.sm * (columns - 1)) / columns;
      return Wrap(
        spacing: theme.spacing.sm,
        runSpacing: theme.spacing.sm,
        children: <Widget>[
          for (final field in widget.settings.fields)
            SizedBox(
              key: ValueKey<String>('beautiful-fine-tune-property-${field.id}'),
              width: width,
              child: _NumericProperty(
                field: field,
                labels: widget.labels,
                onChanged: widget.onChanged == null
                    ? null
                    : (value) => _setValue(field.id, value),
              ),
            ),
        ],
      );
    },
  );

  Widget _typeChoices(BeautifulUiThemeData theme) {
    var title = widget.settings.typeId ?? widget.labels.placeholder;
    for (final option in _options) {
      if (option.id == widget.settings.typeId) title = option.label;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(widget.labels.type, style: theme.typography.caption),
        SizedBox(height: theme.spacing.sm),
        Focus(
          canRequestFocus: false,
          onFocusChange: (focused) {
            if (focused) _typeButtonFocus = FocusManager.instance.primaryFocus;
          },
          child: BeautifulActionControl(
            key: const Key('beautiful-fine-tune-type'),
            label: title,
            maxLines: null,
            semanticLabel: '${widget.labels.type}: $title',
            expanded: _menuOpen,
            minHeight: 48,
            fullWidth: true,
            onPressed: widget.onChanged == null || _options.isEmpty
                ? null
                : () => setState(() => _menuOpen = !_menuOpen),
          ),
        ),
        if (_menuOpen)
          for (final option in _options) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            BeautifulActionControl(
              key: ValueKey<String>('beautiful-fine-tune-option-${option.id}'),
              label: option.label,
              maxLines: null,
              selected: option.id == widget.settings.typeId,
              minHeight: 48,
              fullWidth: true,
              onPressed: () => _setType(option.id),
            ),
          ],
      ],
    );
  }
}

final class _NumericProperty extends StatefulWidget {
  const _NumericProperty({
    required this.field,
    required this.labels,
    this.onChanged,
  });

  final BeautifulFineTuneField field;
  final BeautifulFineTuneLabels labels;
  final ValueChanged<double>? onChanged;

  @override
  State<_NumericProperty> createState() => _NumericPropertyState();
}

final class _NumericPropertyState extends State<_NumericProperty> {
  final _editableTextKey = GlobalKey<EditableTextState>();
  late final TextEditingController _controller = TextEditingController(
    text: _number(widget.field.value),
  );
  late final FocusNode _inputFocus = FocusNode(
    onKeyEvent: _inputKey,
    canRequestFocus: _enabled,
  )..addListener(_inputFocusChanged);
  var _invalid = false;
  var _inputFocused = false;
  var _scrubFocused = false;
  var _dragStart = 0.0;
  var _dragDistance = 0.0;

  bool get _composing =>
      _controller.value.composing.isValid &&
      !_controller.value.composing.isCollapsed;
  bool get _enabled => widget.onChanged != null;
  bool get _canDecrease => _enabled && widget.field.value > widget.field.min;
  bool get _canIncrease => _enabled && widget.field.value < widget.field.max;

  @override
  void didUpdateWidget(_NumericProperty oldWidget) {
    super.didUpdateWidget(oldWidget);
    _inputFocus.canRequestFocus = _enabled;
    if (!_composing &&
        (oldWidget.field.value != widget.field.value ||
            oldWidget.field.min != widget.field.min ||
            oldWidget.field.max != widget.field.max ||
            oldWidget.onChanged != null && !_enabled)) {
      _restore();
    }
  }

  @override
  void dispose() {
    _inputFocus
      ..removeListener(_inputFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _restore() {
    final text = _number(widget.field.value);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _invalid = false;
  }

  void _inputFocusChanged() {
    if (!mounted) return;
    if (!_inputFocus.hasFocus) _commit();
    setState(() => _inputFocused = _inputFocus.hasFocus);
  }

  void _commit() {
    if (!_enabled || _composing) return;
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || !parsed.isFinite) {
      setState(() => _invalid = true);
      return;
    }
    _propose(parsed);
  }

  void _setSemanticText(String text) {
    if (!_enabled || _composing) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _commit();
  }

  void _propose(double value) {
    if (!_enabled || _composing) return;
    final next = value.clamp(widget.field.min, widget.field.max).toDouble();
    setState(_restore);
    if (next != widget.field.value) widget.onChanged?.call(next);
  }

  void _adjust(int direction, {bool accelerated = false}) {
    if (_composing) return;
    final draft = double.tryParse(_controller.text.trim());
    final base = draft != null && draft.isFinite ? draft : widget.field.value;
    final delta = widget.field.step * direction * (accelerated ? 10 : 1);
    final value = base + delta;
    _propose(value);
  }

  KeyEventResult _inputKey(FocusNode node, KeyEvent event) =>
      _key(event, scrub: false);

  KeyEventResult _key(KeyEvent event, {required bool scrub}) {
    if (!_enabled ||
        _composing ||
        event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(_restore);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && !scrub) {
      _commit();
      return KeyEventResult.handled;
    }
    var direction = 0;
    if (key == LogicalKeyboardKey.arrowUp) direction = 1;
    if (key == LogicalKeyboardKey.arrowDown) direction = -1;
    if (scrub) {
      final rtl = Directionality.of(context) == TextDirection.rtl;
      if (key == LogicalKeyboardKey.arrowRight) direction = rtl ? -1 : 1;
      if (key == LogicalKeyboardKey.arrowLeft) direction = rtl ? 1 : -1;
    }
    if (direction == 0) return KeyEventResult.ignored;
    _adjust(direction, accelerated: HardwareKeyboard.instance.isShiftPressed);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final field = widget.field;
    final enabledColor = _enabled ? theme.colors.ink : theme.colors.inkSubtle;
    final valueLabel = '${field.label} ${widget.labels.value}';
    final hasSelectionOverlay = Overlay.maybeOf(context) != null;
    return Container(
      decoration: BoxDecoration(
        color: theme.colors.field,
        border: Border.all(
          color: _invalid ? theme.colors.destructive : theme.colors.lineStrong,
        ),
        borderRadius: BorderRadius.circular(theme.radii.control),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            key: ValueKey<String>('beautiful-fine-tune-scrub-${field.id}'),
            slider: true,
            enabled: _enabled,
            focusable: _enabled,
            focused: _scrubFocused,
            label: field.label,
            value: '${_number(field.value)}${field.suffix}',
            increasedValue: _canIncrease
                ? '${_number((field.value + field.step).clamp(field.min, field.max).toDouble())}${field.suffix}'
                : null,
            decreasedValue: _canDecrease
                ? '${_number((field.value - field.step).clamp(field.min, field.max).toDouble())}${field.suffix}'
                : null,
            onIncrease: _canIncrease ? () => _adjust(1) : null,
            onDecrease: _canDecrease ? () => _adjust(-1) : null,
            excludeSemantics: true,
            child: Focus(
              canRequestFocus: _enabled,
              onFocusChange: (value) => setState(() => _scrubFocused = value),
              onKeyEvent: (_, event) => _key(event, scrub: true),
              child: MouseRegion(
                cursor: _enabled
                    ? SystemMouseCursors.resizeLeftRight
                    : SystemMouseCursors.basic,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: !_enabled
                      ? null
                      : (_) {
                          _dragStart = field.value;
                          _dragDistance = 0;
                        },
                  onHorizontalDragUpdate: !_enabled
                      ? null
                      : (details) {
                          _dragDistance += details.primaryDelta ?? 0;
                          final direction =
                              Directionality.of(context) == TextDirection.rtl
                              ? -1
                              : 1;
                          _propose(
                            _dragStart +
                                (_dragDistance / 4).round() *
                                    field.step *
                                    direction,
                          );
                        },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: EdgeInsets.all(theme.spacing.sm),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _scrubFocused
                            ? theme.colors.accent
                            : const Color(0x00000000),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(theme.radii.control),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        field.suffix.isEmpty
                            ? field.label
                            : '${field.label} (${field.suffix})',
                        style: theme.typography.label.copyWith(
                          color: enabledColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(theme.spacing.xs),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: MergeSemantics(
                    child: Semantics(
                      label: valueLabel,
                      enabled: _enabled,
                      readOnly: !_enabled,
                      textField: true,
                      onTap: _enabled ? _inputFocus.requestFocus : null,
                      onSetText: _enabled ? _setSemanticText : null,
                      child: BeautifulTextSelectionGestureDetector(
                        editableTextKey: _editableTextKey,
                        identity: field.id,
                        child: Container(
                          key: ValueKey<String>(
                            'beautiful-fine-tune-input-target-${field.id}',
                          ),
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: EdgeInsets.symmetric(
                            horizontal: theme.spacing.sm,
                          ),
                          alignment: AlignmentDirectional.centerStart,
                          decoration: BoxDecoration(
                            color: theme.colors.surface,
                            border: Border.all(
                              color: _inputFocused
                                  ? theme.colors.accent
                                  : theme.colors.lineStrong,
                              width: _inputFocused ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(
                              theme.radii.control,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey<String>(
                              'beautiful-fine-tune-input-${field.id}',
                            ),
                            child: EditableText(
                              key: _editableTextKey,
                              controller: _controller,
                              focusNode: _inputFocus,
                              readOnly: !_enabled,
                              rendererIgnoresPointer: true,
                              enableInteractiveSelection: _enabled,
                              selectionControls: hasSelectionOverlay
                                  ? BeautifulTextSelectionControls(
                                      theme.colors.accent,
                                    )
                                  : null,
                              showSelectionHandles: hasSelectionOverlay,
                              contextMenuBuilder: hasSelectionOverlay
                                  ? (_, editable) =>
                                        beautifulEditableTextContextMenu(
                                          editable.context,
                                          editable,
                                          isCurrent: () =>
                                              mounted &&
                                              identical(widget.field, field) &&
                                              !_composing,
                                        )
                                  : null,
                              style: theme.typography.label.copyWith(
                                color: enabledColor,
                              ),
                              cursorColor: theme.colors.accent,
                              backgroundCursorColor: theme.colors.inkSubtle,
                              selectionColor: theme.colors.accentTint,
                              keyboardType: TextInputType.numberWithOptions(
                                signed: field.min < 0,
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.done,
                              autocorrect: false,
                              enableSuggestions: false,
                              textDirection: TextDirection.ltr,
                              onChanged: (_) {
                                if (_invalid) setState(() => _invalid = false);
                              },
                              onSubmitted: (_) => _commit(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: theme.spacing.xs),
                SizedBox(
                  width: 48,
                  child: BeautifulActionControl(
                    key: ValueKey<String>(
                      'beautiful-fine-tune-decrease-${field.id}',
                    ),
                    label: '−',
                    semanticLabel: '${widget.labels.decrease} ${field.label}',
                    minHeight: 48,
                    fullWidth: true,
                    onPressed: _canDecrease ? () => _adjust(-1) : null,
                  ),
                ),
                SizedBox(width: theme.spacing.xs),
                SizedBox(
                  width: 48,
                  child: BeautifulActionControl(
                    key: ValueKey<String>(
                      'beautiful-fine-tune-increase-${field.id}',
                    ),
                    label: '+',
                    semanticLabel: '${widget.labels.increase} ${field.label}',
                    minHeight: 48,
                    fullWidth: true,
                    onPressed: _canIncrease ? () => _adjust(1) : null,
                  ),
                ),
              ],
            ),
          ),
          if (_invalid)
            Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  widget.labels.invalidNumber,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.destructive,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _number(double value) => value == value.truncateToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();
