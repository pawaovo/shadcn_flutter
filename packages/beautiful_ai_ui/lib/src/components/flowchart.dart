import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/environment.dart';
import '../foundation/theme.dart';
import '../implementation/controls/action_control.dart';

/// The two workflow node kinds supported by [BeautifulFlowchart].
enum BeautifulFlowchartNodeKind {
  /// An event that starts the workflow.
  trigger,

  /// A branch whose condition fields can be edited.
  condition,
}

/// A stable, localized condition choice.
@immutable
final class BeautifulFlowchartOption {
  /// Creates an option with a unique, non-empty [id] and [label].
  const BeautifulFlowchartOption({
    required this.id,
    required this.label,
    this.tag,
  });

  /// Identity within its field.
  final String id;

  /// Visible and assistive option name.
  final String label;

  /// Optional supplementary category, such as a host-defined group name.
  final String? tag;
}

/// A controlled property or value selector within a condition.
@immutable
final class BeautifulFlowchartField {
  /// Creates a selector. Its immutable choices must contain [valueId].
  BeautifulFlowchartField({
    required this.id,
    required this.label,
    required this.valueId,
    required Iterable<BeautifulFlowchartOption> options,
  }) : options = List<BeautifulFlowchartOption>.unmodifiable(options);

  /// Stable identity within its condition.
  final String id;

  /// Localized property or value label.
  final String label;

  /// Accepted option identity.
  final String valueId;

  /// At most 32 choices; identities are unique within this field.
  final List<BeautifulFlowchartOption> options;

  BeautifulFlowchartField _withValue(String value) => BeautifulFlowchartField(
    id: id,
    label: label,
    valueId: value,
    options: options,
  );
}

/// A group of selectors, for example an If or And condition row.
@immutable
final class BeautifulFlowchartCondition {
  /// Creates an immutable group of editable fields.
  BeautifulFlowchartCondition({
    required this.id,
    required this.label,
    this.sourceLabel,
    required Iterable<BeautifulFlowchartField> fields,
  }) : fields = List<BeautifulFlowchartField>.unmodifiable(fields);

  /// Stable identity within its node.
  final String id;

  /// Host-localized connective, such as If or And.
  final String label;

  /// Optional host-localized source name.
  final String? sourceLabel;

  /// Ordered selectors, with at most eight fields across the entire node.
  final List<BeautifulFlowchartField> fields;

  BeautifulFlowchartCondition _withFields(
    Iterable<BeautifulFlowchartField> next,
  ) => BeautifulFlowchartCondition(
    id: id,
    label: label,
    sourceLabel: sourceLabel,
    fields: next,
  );
}

/// An immutable workflow step with a host-owned canvas position.
@immutable
final class BeautifulFlowchartNode {
  /// Creates a trigger or condition node.
  BeautifulFlowchartNode({
    required this.id,
    required this.kind,
    required this.title,
    this.caption,
    this.position = Offset.zero,
    Iterable<BeautifulFlowchartCondition> conditions =
        const <BeautifulFlowchartCondition>[],
  }) : conditions = List<BeautifulFlowchartCondition>.unmodifiable(conditions);

  /// Stable identity within a workflow.
  final String id;

  /// Semantic node kind; no external icon or asset is required.
  final BeautifulFlowchartNodeKind kind;

  /// Localized step name.
  final String title;

  /// Optional explanation.
  final String? caption;

  /// Top-left position in logical canvas pixels, independent of viewport size.
  /// Both coordinates must be finite and between zero and 4096, inclusive.
  final Offset position;

  /// Editable condition rows. Trigger nodes cannot contain conditions.
  final List<BeautifulFlowchartCondition> conditions;

  /// Copies this step with accepted position or condition changes.
  BeautifulFlowchartNode copyWith({
    Offset? position,
    Iterable<BeautifulFlowchartCondition>? conditions,
  }) => BeautifulFlowchartNode(
    id: id,
    kind: kind,
    title: title,
    caption: caption,
    position: position ?? this.position,
    conditions: conditions ?? this.conditions,
  );
}

/// An immutable directed connection between two existing workflow nodes.
@immutable
final class BeautifulFlowchartEdge {
  /// Creates a connection. Identity, endpoints and DAG validity are checked by
  /// [BeautifulFlowchartData], including in release builds.
  const BeautifulFlowchartEdge({
    required this.id,
    required this.from,
    required this.to,
    this.label,
  });

  /// Stable identity within its workflow.
  final String id;

  /// Source node identity.
  final String from;

  /// Destination node identity.
  final String to;

  /// Optional localized branch name, also present in the ordered presentation.
  final String? label;
}

/// A bounded, immutable directed acyclic workflow snapshot.
///
/// The editor supports at most 24 nodes, 48 edges, eight condition fields per
/// node and 32 choices per field. Validation rejects duplicate or empty IDs,
/// missing endpoints, self edges, duplicate endpoint pairs, cycles, invalid
/// selected values and positions outside 0–4096 logical pixels. Conditions and
/// fields require non-empty labels and fields. These bounds keep realization
/// and connector painting predictable; this is not a general graph engine.
@immutable
final class BeautifulFlowchartData {
  /// Creates and validates a workflow. Collections are defensively copied.
  BeautifulFlowchartData({
    required this.id,
    required Iterable<BeautifulFlowchartNode> nodes,
    Iterable<BeautifulFlowchartEdge> edges = const <BeautifulFlowchartEdge>[],
  }) : nodes = List<BeautifulFlowchartNode>.unmodifiable(nodes),
       edges = List<BeautifulFlowchartEdge>.unmodifiable(edges) {
    _validate();
  }

  /// Workflow identity. Replacing it resets local selection, menus and viewport.
  final String id;

  /// At most 24 steps. Ties in the ordered presentation follow this order.
  final List<BeautifulFlowchartNode> nodes;

  /// At most 48 existing, directed connections. The widget does not create edges.
  final List<BeautifulFlowchartEdge> edges;

  void _validate() {
    if (id.trim().isEmpty || nodes.length > 24 || edges.length > 48) {
      throw ArgumentError(
        'A workflow needs a non-empty id, at most 24 nodes and at most 48 edges.',
      );
    }
    final nodeIds = <String>{};
    for (final node in nodes) {
      _requireIdentity(node.id, nodeIds, 'node');
      if (node.title.trim().isEmpty ||
          !node.position.dx.isFinite ||
          !node.position.dy.isFinite ||
          node.position.dx < 0 ||
          node.position.dy < 0 ||
          node.position.dx > 4096 ||
          node.position.dy > 4096 ||
          (node.kind == BeautifulFlowchartNodeKind.trigger &&
              node.conditions.isNotEmpty)) {
        throw ArgumentError(
          'Node ${node.id} has an invalid title, position or kind.',
        );
      }
      final conditionIds = <String>{};
      var fieldCount = 0;
      for (final condition in node.conditions) {
        _requireIdentity(condition.id, conditionIds, 'condition');
        if (condition.label.trim().isEmpty || condition.fields.isEmpty) {
          throw ArgumentError(
            'Condition ${condition.id} needs a label and fields.',
          );
        }
        final fieldIds = <String>{};
        for (final field in condition.fields) {
          fieldCount++;
          _requireIdentity(field.id, fieldIds, 'field');
          final optionIds = <String>{};
          for (final option in field.options) {
            _requireIdentity(option.id, optionIds, 'option');
            if (option.label.trim().isEmpty) {
              throw ArgumentError(
                'Option ${option.id} needs a non-empty label.',
              );
            }
          }
          if (field.label.trim().isEmpty ||
              field.options.length > 32 ||
              !optionIds.contains(field.valueId)) {
            throw ArgumentError(
              'Field ${field.id} needs a label, at most 32 options and a selected option.',
            );
          }
        }
      }
      if (fieldCount > 8) {
        throw ArgumentError('Node ${node.id} exceeds eight condition fields.');
      }
    }
    final edgeIds = <String>{};
    final pairs = <(String, String)>{};
    for (final edge in edges) {
      _requireIdentity(edge.id, edgeIds, 'edge');
      if (!nodeIds.contains(edge.from) ||
          !nodeIds.contains(edge.to) ||
          edge.from == edge.to ||
          !pairs.add((edge.from, edge.to))) {
        throw ArgumentError(
          'Edge ${edge.id} has missing, identical or duplicate endpoints.',
        );
      }
    }
    if (_orderedNodes.length != nodes.length) {
      throw ArgumentError('Workflow connections must not contain cycles.');
    }
  }

  List<BeautifulFlowchartNode> get _orderedNodes {
    final incoming = <String, int>{for (final node in nodes) node.id: 0};
    final outgoing = <String, List<String>>{
      for (final node in nodes) node.id: <String>[],
    };
    for (final edge in edges) {
      incoming[edge.to] = incoming[edge.to]! + 1;
      outgoing[edge.from]!.add(edge.to);
    }
    final byId = <String, BeautifulFlowchartNode>{
      for (final node in nodes) node.id: node,
    };
    final queue = <String>[
      for (final node in nodes)
        if (incoming[node.id] == 0) node.id,
    ];
    final result = <BeautifulFlowchartNode>[];
    for (var index = 0; index < queue.length; index++) {
      final id = queue[index];
      result.add(byId[id]!);
      for (final to in outgoing[id]!) {
        incoming[to] = incoming[to]! - 1;
        if (incoming[to] == 0) queue.add(to);
      }
    }
    return result;
  }
}

void _requireIdentity(String id, Set<String> ids, String kind) {
  if (id.trim().isEmpty || !ids.add(id)) {
    throw ArgumentError('$kind IDs must be non-empty and unique: "$id".');
  }
}

/// Localized interface copy for [BeautifulFlowchart].
@immutable
final class BeautifulFlowchartLabels {
  /// Creates labels. Business labels and condition connective text live in data.
  const BeautifulFlowchartLabels({
    this.title = 'Workflow',
    this.empty = 'No workflow steps',
    this.trigger = 'Trigger',
    this.condition = 'If / Else',
    this.steps = 'Steps',
    this.canvas = 'Canvas',
    this.connectedTo = 'Connected to',
    this.moveLeft = 'Move left',
    this.moveRight = 'Move right',
    this.moveUp = 'Move up',
    this.moveDown = 'Move down',
    this.panLeft = 'Pan left',
    this.panRight = 'Pan right',
    this.panUp = 'Pan up',
    this.panDown = 'Pan down',
    this.zoomIn = 'Zoom in',
    this.zoomOut = 'Zoom out',
    this.resetView = 'Reset view',
    this.previousStep = 'Previous step',
    this.nextStep = 'Next step',
    this.moveHint = 'Drag or use arrow keys to move; Shift moves faster',
    this.readOnly = 'Read only',
  });

  /// Component heading.
  final String title;

  /// Empty workflow copy.
  final String empty;

  /// Trigger node kind.
  final String trigger;

  /// Condition node kind.
  final String condition;

  /// Ordered editor presentation.
  final String steps;

  /// Canvas presentation.
  final String canvas;

  /// Prefix for accessible connection descriptions.
  final String connectedTo;

  /// Move a selected node toward the physical left.
  final String moveLeft;

  /// Move a selected node toward the physical right.
  final String moveRight;

  /// Move a selected node upward.
  final String moveUp;

  /// Move a selected node downward.
  final String moveDown;

  /// Move the visible canvas window left.
  final String panLeft;

  /// Move the visible canvas window right.
  final String panRight;

  /// Move the visible canvas window upward.
  final String panUp;

  /// Move the visible canvas window downward.
  final String panDown;

  /// Enlarge canvas content, up to 200%.
  final String zoomIn;

  /// Reduce enlargement, down to 100%.
  final String zoomOut;

  /// Restore the canvas origin and 100% zoom.
  final String resetView;

  /// Select and reveal the previous ordered step.
  final String previousStep;

  /// Select and reveal the next ordered step.
  final String nextStep;

  /// Assistive movement instructions for editable canvas headers.
  final String moveHint;

  /// Non-color indication when editing is disabled.
  final String readOnly;
}

/// A controlled editor for a small trigger/condition workflow.
///
/// [data] holds accepted positions and condition selections; [onChanged] emits
/// a complete proposed snapshot. A null callback makes editing read only.
/// No business state is accepted locally. Change [BeautifulFlowchartData.id]
/// when replacing the workflow, even if the new workflow reuses node IDs.
///
/// Widths below 1024dp and text above 130% use ordered editable steps. This
/// presentation retains complete condition editing without touch drag/scroll
/// conflicts. Expanded layouts offer an optional canvas, measured connectors,
/// header-only dragging, arrows/Shift+arrows, visible movement and viewport
/// controls, and a permanent Steps alternative. Conditions never initiate a
/// node drag. Node positions are physical canvas coordinates, including in RTL.
///
/// The canvas ranges from 1600 to 8192 logical pixels per axis. Node width is
/// 360dp; exceptionally tall content scrolls within a 2048dp node. Zoom is
/// bounded to 1–2x so controls never shrink below 48dp. Node and toolbar movement
/// is immediate; reduced motion also disables viewport inertia. Selection, open conditions,
/// focus identity and the canvas transform survive adaptive presentation changes.
/// The host supplies outer scrolling when the component height is constrained.
final class BeautifulFlowchart extends StatefulWidget {
  /// Creates a small workflow editor with host-owned accepted state.
  const BeautifulFlowchart({
    super.key,
    required this.data,
    this.onChanged,
    this.labels = const BeautifulFlowchartLabels(),
    this.viewportHeight = 560,
  }) : assert(viewportHeight >= 240 && viewportHeight <= 1200);

  /// Accepted immutable workflow snapshot.
  final BeautifulFlowchartData data;

  /// Full proposed workflow, or null for read-only editing.
  final ValueChanged<BeautifulFlowchartData>? onChanged;

  /// Localized interface labels.
  final BeautifulFlowchartLabels labels;

  /// Canvas viewport height, from 240 to 1200 logical pixels.
  final double viewportHeight;

  @override
  State<BeautifulFlowchart> createState() => _BeautifulFlowchartState();
}

final class _BeautifulFlowchartState extends State<BeautifulFlowchart> {
  final _transform = TransformationController();
  final _sizes = <String, Size>{};
  final _cardKeys = <String, GlobalKey>{};
  final _nodeFocus = <String, FocusNode>{};
  final _fieldFocus = <(String, String, String), FocusNode>{};
  String? _selected;
  (String, String, String)? _openField;
  bool _preferSteps = false;
  bool _canvas = false;
  String? _dragId;
  Offset _dragOrigin = Offset.zero;
  Offset _dragDelta = Offset.zero;
  Size _viewport = Size.zero;

  @override
  void initState() {
    super.initState();
    _syncIdentity();
  }

  @override
  void didUpdateWidget(BeautifulFlowchart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id) {
      _selected = null;
      _openField = null;
      _dragId = null;
      _preferSteps = false;
      _sizes.clear();
      _transform.value = Matrix4.identity();
    }
    _syncIdentity();
    if (widget.onChanged == null) {
      _openField = null;
      _dragId = null;
    }
  }

  void _syncIdentity() {
    final ids = widget.data.nodes.map((node) => node.id).toSet();
    for (final id in _nodeFocus.keys.toList()) {
      if (!ids.contains(id)) {
        _nodeFocus.remove(id)!.dispose();
        _cardKeys.remove(id);
        _sizes.remove(id);
      }
    }
    final fields = <(String, String, String)>{};
    for (final node in widget.data.nodes) {
      _nodeFocus.putIfAbsent(node.id, FocusNode.new);
      _cardKeys.putIfAbsent(node.id, GlobalKey.new);
      for (final condition in node.conditions) {
        for (final field in condition.fields) {
          final key = (node.id, condition.id, field.id);
          fields.add(key);
          _fieldFocus.putIfAbsent(key, FocusNode.new);
        }
      }
    }
    for (final key in _fieldFocus.keys.toList()) {
      if (!fields.contains(key)) _fieldFocus.remove(key)!.dispose();
    }
    if (!ids.contains(_selected)) _selected = null;
    if (!ids.contains(_dragId)) _dragId = null;
    if (!fields.contains(_openField)) _openField = null;
  }

  @override
  void dispose() {
    _transform.dispose();
    for (final node in <FocusNode>[
      ..._nodeFocus.values,
      ..._fieldFocus.values,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  Size get _extent {
    var width = 1600.0;
    var height = 1600.0;
    for (final node in widget.data.nodes) {
      width = math.max(width, node.position.dx + 360 + 64);
      height = math.max(
        height,
        node.position.dy + (_sizes[node.id]?.height ?? 180) + 64,
      );
    }
    return Size(math.min(8192, width), math.min(8192, height));
  }

  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_canvas) return;
      var changed = false;
      for (final entry in _cardKeys.entries) {
        final box = entry.value.currentContext?.findRenderObject();
        final size = box is RenderBox && box.hasSize
            ? Size(box.size.width, math.min(2048, box.size.height))
            : null;
        if (size != null && _sizes[entry.key] != size) {
          _sizes[entry.key] = size;
          changed = true;
        }
      }
      if (changed) setState(() {});
    });
  }

  void _proposeNode(BeautifulFlowchartNode node) {
    widget.onChanged?.call(
      BeautifulFlowchartData(
        id: widget.data.id,
        nodes: <BeautifulFlowchartNode>[
          for (final current in widget.data.nodes)
            if (current.id == node.id) node else current,
        ],
        edges: widget.data.edges,
      ),
    );
  }

  void _move(BeautifulFlowchartNode node, Offset delta) {
    final position = node.position + delta;
    final bounded = Offset(
      position.dx.clamp(0, 4096),
      position.dy.clamp(0, 4096),
    );
    if (bounded != node.position) {
      _proposeNode(node.copyWith(position: bounded));
    }
  }

  void _pick(
    BeautifulFlowchartNode node,
    BeautifulFlowchartCondition condition,
    BeautifulFlowchartField field,
    String value,
  ) {
    setState(() => _openField = null);
    _fieldFocus[(node.id, condition.id, field.id)]?.requestFocus();
    if (field.valueId == value) return;
    _proposeNode(
      node.copyWith(
        conditions: <BeautifulFlowchartCondition>[
          for (final current in node.conditions)
            if (current.id == condition.id)
              current._withFields(<BeautifulFlowchartField>[
                for (final item in current.fields)
                  if (item.id == field.id) item._withValue(value) else item,
              ])
            else
              current,
        ],
      ),
    );
  }

  void _select(String id, {bool reveal = false}) {
    if (_selected != id) setState(() => _selected = id);
    if (reveal && _canvas) {
      final node = widget.data.nodes.firstWhere((node) => node.id == id);
      final scale = _transform.value.getMaxScaleOnAxis();
      _setTransform(
        scale,
        Offset(24 - node.position.dx * scale, 24 - node.position.dy * scale),
      );
    }
  }

  void _setTransform(double scale, Offset translation) {
    final extent = _extent;
    final x = translation.dx.clamp(
      math.min(0.0, _viewport.width - extent.width * scale),
      0.0,
    );
    final y = translation.dy.clamp(
      math.min(0.0, _viewport.height - extent.height * scale),
      0.0,
    );
    setState(() {
      _transform.value = Matrix4.identity()
        ..translateByDouble(x.toDouble(), y.toDouble(), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    });
  }

  void _pan(Offset delta) {
    final position = _transform.value.getTranslation();
    _setTransform(
      _transform.value.getMaxScaleOnAxis(),
      Offset(position.x, position.y) + delta,
    );
  }

  void _zoom(double delta) {
    final oldScale = _transform.value.getMaxScaleOnAxis();
    final scale = (oldScale + delta).clamp(1.0, 2.0);
    final position = _transform.value.getTranslation();
    final center = _viewport.center(Offset.zero);
    final translation =
        center - (center - Offset(position.x, position.y)) * (scale / oldScale);
    _setTransform(scale, translation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final supportsCanvas =
            width >= 1024 && MediaQuery.textScalerOf(context).scale(14) <= 18.2;
        final nextCanvas = supportsCanvas && !_preferSteps;
        if (_canvas != nextCanvas) {
          final focused = <FocusNode>[
            ..._nodeFocus.values,
            ..._fieldFocus.values,
          ].where((node) => node.hasFocus).firstOrNull;
          if (focused != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && focused.context != null) focused.requestFocus();
            });
          }
          _dragId = null;
        }
        _canvas = nextCanvas;
        if (_canvas) _measure();
        return SizedBox(
          width: width,
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape &&
                  _openField != null) {
                final field = _openField;
                setState(() => _openField = null);
                _fieldFocus[field]?.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              decoration: BoxDecoration(
                color: theme.colors.page,
                border: Border.all(color: theme.colors.lineStrong),
                borderRadius: BorderRadius.circular(theme.radii.card),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.all(theme.spacing.md),
                    child: Wrap(
                      spacing: theme.spacing.sm,
                      runSpacing: theme.spacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            widget.labels.title,
                            style: theme.typography.label,
                          ),
                        ),
                        if (widget.onChanged == null)
                          Semantics(
                            container: true,
                            child: Text(
                              widget.labels.readOnly,
                              style: theme.typography.caption,
                            ),
                          ),
                        if (supportsCanvas) ...<Widget>[
                          _action(
                            'steps',
                            widget.labels.steps,
                            () => setState(() => _preferSteps = true),
                            selected: !_canvas,
                          ),
                          _action(
                            'canvas-mode',
                            widget.labels.canvas,
                            () => setState(() => _preferSteps = false),
                            selected: _canvas,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.data.nodes.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(theme.spacing.lg),
                      child: Text(
                        widget.labels.empty,
                        style: theme.typography.body,
                      ),
                    )
                  else if (_canvas) ...<Widget>[
                    _canvasToolbar(theme),
                    _canvasView(theme, width),
                  ] else
                    _steps(theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _action(
    String id,
    String label,
    VoidCallback? onPressed, {
    bool? selected,
  }) => BeautifulActionControl(
    key: ValueKey<String>('beautiful-flowchart-$id'),
    label: label,
    selected: selected,
    maxLines: null,
    minHeight: 48,
    onPressed: onPressed,
  );

  Widget _canvasToolbar(BeautifulUiThemeData theme) {
    final ordered = widget.data._orderedNodes;
    final index = ordered.indexWhere((node) => node.id == _selected);
    final selected = index < 0 ? null : ordered[index];
    final scale = _transform.value.getMaxScaleOnAxis();
    void navigate(int next) {
      final node = ordered[next];
      _select(node.id, reveal: true);
      _nodeFocus[node.id]!.requestFocus();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.md,
        0,
        theme.spacing.md,
        theme.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: theme.spacing.xs,
            runSpacing: theme.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _action(
                'previous',
                widget.labels.previousStep,
                index > 0 ? () => navigate(index - 1) : null,
              ),
              _action(
                'next',
                widget.labels.nextStep,
                index < ordered.length - 1 ? () => navigate(index + 1) : null,
              ),
              _action(
                'zoom-out',
                widget.labels.zoomOut,
                scale > 1.001 ? () => _zoom(-0.25) : null,
              ),
              Text(
                '${(scale * 100).round()}%',
                style: theme.typography.caption,
              ),
              _action(
                'zoom-in',
                widget.labels.zoomIn,
                scale < 1.999 ? () => _zoom(0.25) : null,
              ),
              _action(
                'reset',
                widget.labels.resetView,
                () => _setTransform(1, Offset.zero),
              ),
              _action(
                'pan-left',
                widget.labels.panLeft,
                () => _pan(const Offset(160, 0)),
              ),
              _action(
                'pan-right',
                widget.labels.panRight,
                () => _pan(const Offset(-160, 0)),
              ),
              _action(
                'pan-up',
                widget.labels.panUp,
                () => _pan(const Offset(0, 160)),
              ),
              _action(
                'pan-down',
                widget.labels.panDown,
                () => _pan(const Offset(0, -160)),
              ),
            ],
          ),
          if (selected != null) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(selected.title, style: theme.typography.label),
            if (widget.onChanged != null)
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                children: <Widget>[
                  _action(
                    'move-left',
                    widget.labels.moveLeft,
                    selected.position.dx > 0
                        ? () => _move(selected, const Offset(-16, 0))
                        : null,
                  ),
                  _action(
                    'move-right',
                    widget.labels.moveRight,
                    selected.position.dx < 4096
                        ? () => _move(selected, const Offset(16, 0))
                        : null,
                  ),
                  _action(
                    'move-up',
                    widget.labels.moveUp,
                    selected.position.dy > 0
                        ? () => _move(selected, const Offset(0, -16))
                        : null,
                  ),
                  _action(
                    'move-down',
                    widget.labels.moveDown,
                    selected.position.dy < 4096
                        ? () => _move(selected, const Offset(0, 16))
                        : null,
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _canvasView(BeautifulUiThemeData theme, double width) {
    _viewport = Size(math.max(0, width - 2), widget.viewportHeight);
    final extent = _extent;
    final rects = <String, Rect>{
      for (final node in widget.data.nodes)
        node.id: node.position & (_sizes[node.id] ?? const Size(360, 180)),
    };
    final motion = BeautifulUiEnvironment.of(context)
        .continuousMotionEnabled(context);
    return SizedBox(
      key: const Key('beautiful-flowchart-viewport'),
      height: widget.viewportHeight,
      child: KeyedSubtree(
        // Dispose suspended inertia when the preference changes; the transform
        // itself belongs to the workflow owner and survives this replacement.
        key: ValueKey<bool>(motion),
        child: TickerMode(
          enabled: motion,
          child: InteractiveViewer(
            key: const Key('beautiful-flowchart-viewer'),
            transformationController: _transform,
            constrained: false,
            alignment: Alignment.topLeft,
            minScale: 1,
            maxScale: 2,
            onInteractionEnd: (_) => setState(() {}),
            child: SizedBox.fromSize(
              key: const Key('beautiful-flowchart-canvas-extent'),
              size: extent,
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const Key('beautiful-flowchart-connectors'),
                  painter: _ConnectorPainter(
                    rects: rects,
                    edges: widget.data.edges,
                    selected: _selected,
                    line: theme.colors.lineStrong,
                    connector: theme.colors.inkMuted,
                    accent: theme.colors.accent,
                    background: theme.colors.canvas,
                  ),
                  child: Stack(
                    children: <Widget>[
                      for (final node in widget.data.nodes)
                        Positioned(
                          left: node.position.dx,
                          top: node.position.dy,
                          width: 360,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 2048),
                            child: SingleChildScrollView(
                              child: _nodeCard(node, theme, canvas: true),
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
      ),
    );
  }

  Widget _steps(BeautifulUiThemeData theme) => Padding(
    key: const Key('beautiful-flowchart-ordered-steps'),
    padding: EdgeInsets.all(theme.spacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final node in widget.data._orderedNodes) ...<Widget>[
          _nodeCard(node, theme, canvas: false),
          SizedBox(height: theme.spacing.md),
        ],
      ],
    ),
  );

  Widget _nodeCard(
    BeautifulFlowchartNode node,
    BeautifulUiThemeData theme, {
    required bool canvas,
  }) {
    final selected = _selected == node.id;
    final kind = node.kind == BeautifulFlowchartNodeKind.trigger
        ? widget.labels.trigger
        : widget.labels.condition;
    final edges = widget.data.edges.where((edge) => edge.from == node.id);
    return Container(
      key: _cardKeys[node.id],
      padding: EdgeInsets.all(theme.spacing.sm),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        borderRadius: BorderRadius.circular(theme.radii.card),
        border: Border.all(
          color: selected ? theme.colors.accent : theme.colors.lineStrong,
          width: selected ? 2 : 1,
        ),
        boxShadow: theme.shadows.raised,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: !canvas || widget.onChanged == null
                ? null
                : (_) {
                    _dragId = node.id;
                    _dragOrigin = node.position;
                    _dragDelta = Offset.zero;
                    _select(node.id);
                    _nodeFocus[node.id]!.requestFocus();
                  },
            onPanUpdate: !canvas || widget.onChanged == null
                ? null
                : (details) {
                    if (_dragId != node.id) return;
                    _dragDelta += details.delta;
                    _move(node, _dragOrigin + _dragDelta - node.position);
                  },
            onPanEnd: (_) => _dragId = null,
            onPanCancel: () => _dragId = null,
            child: _FlowchartHeader(
              key: ValueKey<String>('beautiful-flowchart-node-${node.id}'),
              focusNode: _nodeFocus[node.id]!,
              title: node.title,
              kind: kind,
              caption: node.caption,
              selected: selected,
              moveHint: canvas && widget.onChanged != null
                  ? widget.labels.moveHint
                  : null,
              onSelect: () {
                _select(node.id);
                _nodeFocus[node.id]!.requestFocus();
              },
              onFocus: () => _select(node.id, reveal: _dragId == null),
              onKey: (event) {
                if (!canvas ||
                    widget.onChanged == null ||
                    (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
                  return KeyEventResult.ignored;
                }
                final distance = HardwareKeyboard.instance.isShiftPressed
                    ? 64.0
                    : 16.0;
                final delta = switch (event.logicalKey) {
                  LogicalKeyboardKey.arrowLeft => Offset(-distance, 0),
                  LogicalKeyboardKey.arrowRight => Offset(distance, 0),
                  LogicalKeyboardKey.arrowUp => Offset(0, -distance),
                  LogicalKeyboardKey.arrowDown => Offset(0, distance),
                  _ => null,
                };
                if (delta == null) return KeyEventResult.ignored;
                _move(node, delta);
                return KeyEventResult.handled;
              },
            ),
          ),
          for (final condition in node.conditions) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Text(
              <String>[condition.label, ?condition.sourceLabel].join(' '),
              style: theme.typography.label,
            ),
            for (final field in condition.fields) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              _field(node, condition, field, theme),
            ],
          ],
          for (final edge in edges) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            Semantics(
              container: true,
              child: Text(
                '${widget.labels.connectedTo}: ${widget.data.nodes.firstWhere((item) => item.id == edge.to).title}'
                '${edge.label == null ? '' : ' (${edge.label})'}',
                key: ValueKey<String>('beautiful-flowchart-edge-${edge.id}'),
                style: theme.typography.caption.copyWith(
                  color: theme.colors.inkMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    BeautifulFlowchartNode node,
    BeautifulFlowchartCondition condition,
    BeautifulFlowchartField field,
    BeautifulUiThemeData theme,
  ) {
    final key = (node.id, condition.id, field.id);
    final value = field.options.firstWhere(
      (option) => option.id == field.valueId,
    );
    final open = key == _openField;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Focus(
          focusNode: _fieldFocus[key],
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                _fieldFocus[key]!.hasPrimaryFocus &&
                widget.onChanged != null &&
                (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.space)) {
              setState(() => _openField = open ? null : key);
              return KeyEventResult.handled;
            }
            if ((event is KeyDownEvent || event is KeyRepeatEvent) &&
                (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                    event.logicalKey == LogicalKeyboardKey.arrowUp) &&
                widget.onChanged != null) {
              final index = field.options.indexWhere(
                (option) => option.id == field.valueId,
              );
              final direction = event.logicalKey == LogicalKeyboardKey.arrowDown
                  ? 1
                  : -1;
              final next = (index + direction).clamp(
                0,
                field.options.length - 1,
              );
              _pick(node, condition, field, field.options[next].id);
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: BeautifulActionControl(
            key: ValueKey<String>(
              'beautiful-flowchart-field-${node.id}-${condition.id}-${field.id}',
            ),
            label: '${field.label}: ${value.label}',
            expanded: open,
            maxLines: null,
            fullWidth: true,
            minHeight: 48,
            onPressed: widget.onChanged == null
                ? null
                : () => setState(() => _openField = open ? null : key),
          ),
        ),
        if (open)
          for (final option in field.options) ...<Widget>[
            SizedBox(height: theme.spacing.xs),
            BeautifulActionControl(
              key: ValueKey<String>(
                'beautiful-flowchart-option-${node.id}-${condition.id}-${field.id}-${option.id}',
              ),
              label: <String>[option.label, ?option.tag].join(' · '),
              selected: option.id == field.valueId,
              tone: option.id == field.valueId
                  ? BeautifulActionTone.primary
                  : BeautifulActionTone.quiet,
              fullWidth: true,
              maxLines: null,
              minHeight: 48,
              onPressed: () => _pick(node, condition, field, option.id),
            ),
          ],
      ],
    );
  }
}

final class _FlowchartHeader extends StatefulWidget {
  const _FlowchartHeader({
    super.key,
    required this.focusNode,
    required this.title,
    required this.kind,
    required this.caption,
    required this.selected,
    required this.moveHint,
    required this.onSelect,
    required this.onFocus,
    required this.onKey,
  });

  final FocusNode focusNode;
  final String title;
  final String kind;
  final String? caption;
  final bool selected;
  final String? moveHint;
  final VoidCallback onSelect;
  final VoidCallback onFocus;
  final KeyEventResult Function(KeyEvent) onKey;

  @override
  State<_FlowchartHeader> createState() => _FlowchartHeaderState();
}

final class _FlowchartHeaderState extends State<_FlowchartHeader> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      focusable: true,
      focused: widget.focusNode.hasFocus,
      label: '${widget.kind}: ${widget.title}',
      hint: widget.moveHint,
      value: widget.caption,
      excludeSemantics: true,
      onTap: widget.onSelect,
      child: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) => widget.onKey(event),
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          mouseCursor: widget.moveHint == null
              ? SystemMouseCursors.click
              : SystemMouseCursors.grab,
          onFocusChange: (focused) {
            setState(() {});
            if (focused) widget.onFocus();
          },
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onSelect();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSelect,
            child: Container(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: EdgeInsets.all(theme.spacing.sm),
              decoration: BoxDecoration(
                color: widget.selected
                    ? theme.colors.accentTint
                    : theme.colors.inset,
                borderRadius: BorderRadius.circular(theme.radii.control),
                border: Border.all(
                  color: _focused
                      ? theme.colors.accent
                      : const Color(0x00000000),
                  width: 2,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 20,
                    height: 24,
                    child: CustomPaint(
                      painter: _NodeIconPainter(theme.colors.accentInk),
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.kind,
                          style: theme.typography.caption.copyWith(
                            color: theme.colors.accentInk,
                          ),
                        ),
                        Text(widget.title, style: theme.typography.label),
                        if (widget.caption case final caption?)
                          Text(
                            caption,
                            style: theme.typography.caption.copyWith(
                              color: theme.colors.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _NodeIconPainter extends CustomPainter {
  const _NodeIconPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final x in <double>[6, 14]) {
      for (final y in <double>[5, 12, 19]) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_NodeIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

final class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.rects,
    required this.edges,
    required this.selected,
    required this.line,
    required this.connector,
    required this.accent,
    required this.background,
  });

  final Map<String, Rect> rects;
  final List<BeautifulFlowchartEdge> edges;
  final String? selected;
  final Color line;
  final Color connector;
  final Color accent;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final clip = canvas.getLocalClipBounds().intersect(Offset.zero & size);
    final dots = Paint()..color = line;
    // Decoration has a constant upper work bound, even when the graph spans
    // the entire canvas. Connector work below remains exactly one path/edge.
    final spacing = math.max(24.0, math.sqrt(size.width * size.height / 4096));
    for (
      var x = (clip.left / spacing).floor() * spacing;
      x < clip.right;
      x += spacing
    ) {
      for (
        var y = (clip.top / spacing).floor() * spacing;
        y < clip.bottom;
        y += spacing
      ) {
        canvas.drawCircle(Offset(x, y), 1, dots);
      }
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final edge in edges) {
      final from = rects[edge.from]!.bottomCenter;
      final to = rects[edge.to]!.topCenter;
      final curve = ((to.dy - from.dy).abs() * 0.55).clamp(24.0, 84.0);
      paint.color = edge.from == selected || edge.to == selected
          ? accent
          : connector;
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(
            from.dx,
            from.dy + curve,
            to.dx,
            to.dy - curve,
            to.dx,
            to.dy,
          ),
        paint,
      );
      canvas.drawCircle(to, 3, Paint()..color = paint.color);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter oldDelegate) =>
      !mapEquals(rects, oldDelegate.rects) ||
      !listEquals(edges, oldDelegate.edges) ||
      selected != oldDelegate.selected ||
      line != oldDelegate.line ||
      connector != oldDelegate.connector ||
      accent != oldDelegate.accent ||
      background != oldDelegate.background;
}
