import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  test('workflow snapshots defensively copy every collection', () {
    final options = <BeautifulFlowchartOption>[
      const BeautifulFlowchartOption(id: 'a', label: 'A'),
    ];
    final field = BeautifulFlowchartField(
      id: 'property',
      label: 'Property',
      valueId: 'a',
      options: options,
    );
    final fields = <BeautifulFlowchartField>[field];
    final condition = BeautifulFlowchartCondition(
      id: 'if',
      label: 'If',
      fields: fields,
    );
    final conditions = <BeautifulFlowchartCondition>[condition];
    final node = BeautifulFlowchartNode(
      id: 'condition',
      kind: BeautifulFlowchartNodeKind.condition,
      title: 'Condition',
      conditions: conditions,
    );
    final nodes = <BeautifulFlowchartNode>[node];
    final edges = <BeautifulFlowchartEdge>[];
    final data = BeautifulFlowchartData(
      id: 'workflow',
      nodes: nodes,
      edges: edges,
    );
    options.clear();
    fields.clear();
    conditions.clear();
    nodes.clear();
    edges.add(
      const BeautifulFlowchartEdge(id: 'bad', from: 'missing', to: 'missing'),
    );
    expect(
      data.nodes.single.conditions.single.fields.single.options.single.label,
      'A',
    );
    expect(data.edges, isEmpty);
    expect(() => data.nodes.clear(), throwsUnsupportedError);
    expect(() => data.nodes.single.conditions.clear(), throwsUnsupportedError);
    expect(() => field.options.clear(), throwsUnsupportedError);
  });

  test(
    'invalid graph identities, positions, endpoints and cycles are rejected',
    () {
      final one = _trigger('one');
      final two = _trigger('two');
      for (final nodes in <List<BeautifulFlowchartNode>>[
        <BeautifulFlowchartNode>[one, one],
        <BeautifulFlowchartNode>[_trigger('')],
        <BeautifulFlowchartNode>[
          one.copyWith(position: const Offset(double.nan, 0)),
        ],
        <BeautifulFlowchartNode>[one.copyWith(position: const Offset(-1, 0))],
        <BeautifulFlowchartNode>[one.copyWith(position: const Offset(4097, 0))],
        List<BeautifulFlowchartNode>.generate(
          25,
          (index) => _trigger('$index'),
        ),
      ]) {
        expect(
          () => BeautifulFlowchartData(id: 'workflow', nodes: nodes),
          throwsArgumentError,
        );
      }
      for (final edges in <List<BeautifulFlowchartEdge>>[
        <BeautifulFlowchartEdge>[
          const BeautifulFlowchartEdge(id: '', from: 'one', to: 'two'),
        ],
        <BeautifulFlowchartEdge>[
          const BeautifulFlowchartEdge(id: 'edge', from: 'one', to: 'one'),
        ],
        <BeautifulFlowchartEdge>[
          const BeautifulFlowchartEdge(id: 'edge', from: 'one', to: 'missing'),
        ],
        <BeautifulFlowchartEdge>[
          const BeautifulFlowchartEdge(id: 'edge', from: 'one', to: 'two'),
          const BeautifulFlowchartEdge(id: 'edge', from: 'two', to: 'one'),
        ],
        <BeautifulFlowchartEdge>[
          const BeautifulFlowchartEdge(id: 'a', from: 'one', to: 'two'),
          const BeautifulFlowchartEdge(id: 'b', from: 'one', to: 'two'),
        ],
        <BeautifulFlowchartEdge>[
          const BeautifulFlowchartEdge(id: 'a', from: 'one', to: 'two'),
          const BeautifulFlowchartEdge(id: 'b', from: 'two', to: 'one'),
        ],
        List<BeautifulFlowchartEdge>.generate(
          49,
          (index) =>
              BeautifulFlowchartEdge(id: '$index', from: 'one', to: 'two'),
        ),
      ]) {
        expect(
          () => BeautifulFlowchartData(
            id: 'workflow',
            nodes: <BeautifulFlowchartNode>[one, two],
            edges: edges,
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test(
    'condition configuration rejects ambiguous or excessive field options',
    () {
      BeautifulFlowchartNode node(List<BeautifulFlowchartField> fields) =>
          BeautifulFlowchartNode(
            id: 'condition',
            kind: BeautifulFlowchartNodeKind.condition,
            title: 'Condition',
            conditions: <BeautifulFlowchartCondition>[
              BeautifulFlowchartCondition(
                id: 'if',
                label: 'If',
                fields: fields,
              ),
            ],
          );
      final good = _field();
      final duplicate = BeautifulFlowchartField(
        id: 'property',
        label: 'Property',
        valueId: 'a',
        options: const <BeautifulFlowchartOption>[
          BeautifulFlowchartOption(id: 'a', label: 'A'),
          BeautifulFlowchartOption(id: 'a', label: 'Again'),
        ],
      );
      for (final fields in <List<BeautifulFlowchartField>>[
        <BeautifulFlowchartField>[good, good],
        <BeautifulFlowchartField>[duplicate],
        <BeautifulFlowchartField>[_field(value: 'missing')],
        <BeautifulFlowchartField>[],
        List<BeautifulFlowchartField>.generate(
          9,
          (index) => _field(id: '$index'),
        ),
        <BeautifulFlowchartField>[
          BeautifulFlowchartField(
            id: 'property',
            label: 'Property',
            valueId: '0',
            options: List<BeautifulFlowchartOption>.generate(
              33,
              (index) =>
                  BeautifulFlowchartOption(id: '$index', label: '$index'),
            ),
          ),
        ],
      ]) {
        expect(
          () => BeautifulFlowchartData(
            id: 'workflow',
            nodes: <BeautifulFlowchartNode>[node(fields)],
          ),
          throwsArgumentError,
        );
      }
    },
  );

  testWidgets(
    'condition edits emit complete accepted snapshots without changing the original',
    (tester) async {
      final original = _data();
      final proposals = <BeautifulFlowchartData>[];
      await tester.pumpWidget(
        _controlled(data: original, onChanged: proposals.add),
      );
      await tester.tap(_fieldFinder());
      await tester.pump();
      await tester.tap(_option('topping'));
      await tester.pump();
      expect(proposals.single.id, original.id);
      expect(proposals.single.edges.single.id, 'trigger-condition');
      expect(
        proposals.single.nodes.last.conditions.single.fields.single.valueId,
        'topping',
      );
      expect(
        original.nodes.last.conditions.single.fields.single.valueId,
        'flavor',
      );
      expect(find.text('Property: Topping'), findsOneWidget);
      expect(_option('topping'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('declining a proposal retains accepted condition values', (
    tester,
  ) async {
    final proposals = <BeautifulFlowchartData>[];
    await tester.pumpWidget(_app(onChanged: proposals.add));
    await tester.tap(_fieldFinder());
    await tester.pump();
    await tester.tap(_option('topping'));
    await tester.pump();
    expect(
      proposals.single.nodes.last.conditions.single.fields.single.valueId,
      'topping',
    );
    expect(find.text('Property: Flavor'), findsOneWidget);
  });

  testWidgets(
    'keyboard condition choice and Escape restore an operable trigger',
    (tester) async {
      final proposals = <BeautifulFlowchartData>[];
      await tester.pumpWidget(_controlled(onChanged: proposals.add));
      await tester.tap(_fieldFinder());
      await tester.pump();
      _focusAction(tester, _option('topping'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_option('topping'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_option('topping'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        proposals.single.nodes.last.conditions.single.fields.single.valueId,
        'topping',
      );
      expect(proposals.single.nodes.last.position, const Offset(64, 200));
    },
  );

  testWidgets(
    'compact mode edits conditions without node drag or canvas gestures',
    (tester) async {
      final proposals = <BeautifulFlowchartData>[];
      await tester.pumpWidget(_app(onChanged: proposals.add));
      expect(find.byType(InteractiveViewer), findsNothing);
      await tester.drag(_node('trigger'), const Offset(80, 0));
      await tester.pump();
      expect(proposals, isEmpty);
      expect(find.text('Connected to: Check order (Next)'), findsOneWidget);
    },
  );

  testWidgets(
    'canvas dragging, directional movement and clamping remain controlled',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final proposals = <BeautifulFlowchartData>[];
      await tester.pumpWidget(
        _controlled(size: const Size(1280, 1200), onChanged: proposals.add),
      );
      await tester.pump();
      await tester.drag(_node('trigger'), const Offset(80, 40));
      await tester.pump();
      expect(proposals.last.nodes.first.position.dx, greaterThan(64));
      expect(proposals.last.nodes.first.position.dy, greaterThan(32));
      final accepted = proposals.last.nodes.first.position;
      _focusAction(tester, _node('trigger'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        proposals.last.nodes.first.position,
        accepted + const Offset(16, 0),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        proposals.last.nodes.first.position,
        accepted + const Offset(16, 64),
      );
      await tester.tap(find.byKey(const Key('beautiful-flowchart-move-left')));
      await tester.pump();
      expect(
        proposals.last.nodes.first.position,
        accepted + const Offset(0, 64),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('boundary movement does not propose out-of-range positions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final proposals = <BeautifulFlowchartData>[];
    await tester.pumpWidget(
      _controlled(
        data: BeautifulFlowchartData(
          id: 'workflow',
          nodes: <BeautifulFlowchartNode>[
            _trigger('trigger', position: const Offset(4090, 4090)),
          ],
        ),
        size: const Size(1280, 1200),
        onChanged: proposals.add,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('beautiful-flowchart-next')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(proposals.last.nodes.single.position, const Offset(4096, 4096));
    final count = proposals.length;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(proposals, hasLength(count));
    final extent = tester.getSize(
      find.byKey(const Key('beautiful-flowchart-canvas-extent')),
    );
    expect(extent.width, lessThanOrEqualTo(8192));
    expect(extent.height, lessThanOrEqualTo(8192));
  });

  testWidgets(
    'pointer selection transfers keyboard movement from the previously focused node',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final proposals = <BeautifulFlowchartData>[];
      await tester.pumpWidget(
        _controlled(size: const Size(1280, 1200), onChanged: proposals.add),
      );
      await tester.pump();
      _focusAction(tester, _node('trigger'));
      await tester.pump();
      await tester.tap(_node('condition'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(proposals.single.nodes.first.position, const Offset(64, 32));
      expect(proposals.single.nodes.last.position, const Offset(80, 200));
    },
  );

  testWidgets(
    'reduced motion stops viewport inertia without resuming it after preference changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(
          size: const Size(1280, 1200),
          motion: BeautifulMotionPolicy.reduced,
          disableAnimations: false,
        ),
      );
      await tester.pump();
      await tester.fling(
        find.byKey(const Key('beautiful-flowchart-viewport')),
        const Offset(-250, 0),
        1400,
      );
      await tester.pump();
      var viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final stopped = viewer.transformationController!.value.clone();
      expect(stopped.getTranslation().x, lessThan(0));
      await tester.pump(const Duration(milliseconds: 500));
      expect(viewer.transformationController!.value, stopped);
      await tester.pumpWidget(
        _app(size: const Size(1280, 1200), disableAnimations: false),
      );
      await tester.pump();
      viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      expect(viewer.transformationController!.value, stopped);
      await tester.pump(const Duration(milliseconds: 500));
      expect(viewer.transformationController!.value, stopped);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('read-only canvas still navigates but never moves or edits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(size: const Size(1280, 1200)));
    await tester.pump();
    await tester.tap(find.byKey(const Key('beautiful-flowchart-next')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('Read only'), findsOneWidget);
    expect(
      find.byKey(const Key('beautiful-flowchart-move-right')),
      findsNothing,
    );
    final node = tester
        .widget<BeautifulFlowchart>(find.byType(BeautifulFlowchart))
        .data
        .nodes
        .first;
    expect(node.position, const Offset(64, 32));
  });

  testWidgets(
    'zoom protects target size and viewport survives ordered mode changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(size: const Size(1280, 1200), onChanged: (_) {}),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('beautiful-flowchart-pan-right')));
      await tester.tap(find.byKey(const Key('beautiful-flowchart-zoom-in')));
      await tester.pump();
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final matrix = viewer.transformationController!.value.clone();
      expect(viewer.minScale, 1);
      expect(matrix.getMaxScaleOnAxis(), 1.25);
      await tester.pumpWidget(
        _app(size: const Size(599, 1200), onChanged: (_) {}),
      );
      await tester.pump();
      expect(find.byType(InteractiveViewer), findsNothing);
      await tester.pumpWidget(
        _app(size: const Size(1280, 1200), onChanged: (_) {}),
      );
      await tester.pump();
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value,
        matrix,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('open condition and keyboard focus survive adaptive changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(onChanged: (_) {}));
    _focusAction(tester, _fieldFinder());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_option('topping'), findsOneWidget);
    await tester.pumpWidget(
      _app(size: const Size(1280, 1200), onChanged: (_) {}),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_option('topping'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_option('topping'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'replacing workflow or removing an open node invalidates disclosure',
    (tester) async {
      await tester.pumpWidget(_app(onChanged: (_) {}));
      await tester.tap(_fieldFinder());
      await tester.pump();
      await tester.pumpWidget(
        _app(
          data: _data(id: 'replacement'),
          onChanged: (_) {},
        ),
      );
      await tester.pump();
      expect(_option('topping'), findsNothing);
      await tester.tap(_fieldFinder());
      await tester.pump();
      await tester.pumpWidget(
        _app(
          data: BeautifulFlowchartData(
            id: 'replacement',
            nodes: <BeautifulFlowchartNode>[_trigger('trigger')],
          ),
          onChanged: (_) {},
        ),
      );
      await tester.pump();
      expect(_fieldFinder(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('boundary widths, RTL and 200% long labels remain editable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longTitle = '一个完整的多语言工作流步骤名称用于检查边界布局 والشرط التالي';
    for (final width in <double>[320, 599, 600, 1023, 1024]) {
      await tester.pumpWidget(
        _app(
          data: _data(conditionTitle: longTitle),
          size: Size(width, 1800),
          textDirection: TextDirection.rtl,
          textScaler: const TextScaler.linear(2),
          highContrast: true,
          brightness: Brightness.dark,
          onChanged: (_) {},
        ),
      );
      await tester.pump();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text(longTitle))
            .didExceedMaxLines,
        isFalse,
      );
      expect(tester.getSize(_fieldFinder()).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(_node('trigger')).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('ordered steps follow dependencies and handle an empty graph', (
    tester,
  ) async {
    final original = _data();
    await tester.pumpWidget(
      _app(
        data: BeautifulFlowchartData(
          id: 'workflow',
          nodes: original.nodes.reversed,
          edges: original.edges,
        ),
      ),
    );
    expect(
      tester.getTopLeft(_node('trigger')).dy,
      lessThan(tester.getTopLeft(_node('condition')).dy),
    );
    await tester.pumpWidget(
      _app(
        data: BeautifulFlowchartData(
          id: 'workflow',
          nodes: const <BeautifulFlowchartNode>[],
        ),
      ),
    );
    expect(find.text('No workflow steps'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'maximum graph realizes 24 nodes and paints exactly one connector per edge',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final nodes = List<BeautifulFlowchartNode>.generate(
        24,
        (index) => _trigger(
          'n$index',
          position: Offset((index % 4) * 420, (index ~/ 4) * 200),
        ),
      );
      final edges = <BeautifulFlowchartEdge>[
        for (var gap = 1; gap <= 3; gap++)
          for (var from = 0; from + gap < 24; from++)
            BeautifulFlowchartEdge(
              id: '$from-${from + gap}',
              from: 'n$from',
              to: 'n${from + gap}',
            ),
      ].take(48).toList();
      final data = BeautifulFlowchartData(
        id: 'maximum',
        nodes: nodes,
        edges: edges,
      );
      final watch = Stopwatch()..start();
      await tester.pumpWidget(
        _controlled(data: data, size: const Size(1280, 1200)),
      );
      await tester.pump();
      final initialMicros = watch.elapsedMicroseconds;
      for (var index = 0; index < 24; index++) {
        expect(_node('n$index'), findsOneWidget);
      }
      final paint = tester
          .widget<CustomPaint>(
            find.byKey(const Key('beautiful-flowchart-connectors')),
          )
          .painter!;
      final canvas = _ClipCanvas();
      paint.paint(canvas, const Size(8192, 8192));
      expect(
        canvas.invocations.where(
          (call) => call.invocation.memberName == #drawPath,
        ),
        hasLength(48),
      );
      expect(
        canvas.invocations
            .where((call) => call.invocation.memberName == #drawCircle)
            .length,
        lessThanOrEqualTo(4096 + 48),
      );
      _focusAction(tester, _node('n0'));
      await tester.pump();
      final movementMicros = <int>[];
      for (var index = 0; index < 20; index++) {
        watch.reset();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        movementMicros.add(watch.elapsedMicroseconds);
      }
      watch.stop();
      movementMicros.sort();
      // Diagnostics are evidence for this host; no timing gate claims a device
      // frame budget or introduces scheduler-dependent CI failures.
      debugPrint(
        'Flowchart 24 nodes / 48 edges: initial ${initialMicros / 1000} ms; median accepted move ${movementMicros[10] / 1000} ms; maximum ${movementMicros.last / 1000} ms.',
      );
      expect(
        tester
            .widget<BeautifulFlowchart>(find.byType(BeautifulFlowchart))
            .data
            .nodes
            .first
            .position
            .dx,
        320,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

final class _ClipCanvas extends TestRecordingCanvas {
  @override
  Rect getLocalClipBounds() => const Rect.fromLTWH(0, 0, 8192, 8192);
}

BeautifulFlowchartNode _trigger(
  String id, {
  Offset position = const Offset(64, 32),
}) => BeautifulFlowchartNode(
  id: id,
  kind: BeautifulFlowchartNodeKind.trigger,
  title: 'New order',
  caption: 'Starts when an order is created',
  position: position,
);

BeautifulFlowchartField _field({
  String id = 'property',
  String value = 'flavor',
}) => BeautifulFlowchartField(
  id: id,
  label: 'Property',
  valueId: value,
  options: const <BeautifulFlowchartOption>[
    BeautifulFlowchartOption(id: 'flavor', label: 'Flavor'),
    BeautifulFlowchartOption(id: 'topping', label: 'Topping'),
  ],
);

BeautifulFlowchartData _data({
  String id = 'workflow',
  String conditionTitle = 'Check order',
}) => BeautifulFlowchartData(
  id: id,
  nodes: <BeautifulFlowchartNode>[
    _trigger('trigger'),
    BeautifulFlowchartNode(
      id: 'condition',
      kind: BeautifulFlowchartNodeKind.condition,
      title: conditionTitle,
      position: const Offset(64, 200),
      conditions: <BeautifulFlowchartCondition>[
        BeautifulFlowchartCondition(
          id: 'if',
          label: 'If',
          sourceLabel: 'order',
          fields: <BeautifulFlowchartField>[_field()],
        ),
      ],
    ),
  ],
  edges: const <BeautifulFlowchartEdge>[
    BeautifulFlowchartEdge(
      id: 'trigger-condition',
      from: 'trigger',
      to: 'condition',
      label: 'Next',
    ),
  ],
);

Finder _fieldFinder() =>
    find.byKey(const Key('beautiful-flowchart-field-condition-if-property'));
Finder _option(String id) => find.byKey(
  ValueKey<String>('beautiful-flowchart-option-condition-if-property-$id'),
);
Finder _node(String id) =>
    find.byKey(ValueKey<String>('beautiful-flowchart-node-$id'));

void _focusAction(WidgetTester tester, Finder finder) {
  Focus.of(
    tester.element(
      find.descendant(of: finder, matching: find.byType(GestureDetector)).last,
    ),
  ).requestFocus();
}

Widget _app({
  BeautifulFlowchartData? data,
  ValueChanged<BeautifulFlowchartData>? onChanged,
  Size size = const Size(390, 844),
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  bool highContrast = false,
  Brightness brightness = Brightness.light,
  bool disableAnimations = true,
  BeautifulMotionPolicy motion = BeautifulMotionPolicy.system,
}) => beautifulTestApp(
  size: size,
  textDirection: textDirection,
  textScaler: textScaler,
  highContrast: highContrast,
  brightness: brightness,
  disableAnimations: disableAnimations,
  motion: motion,
  child: SizedBox(
    width: size.width,
    child: SingleChildScrollView(
      child: BeautifulFlowchart(data: data ?? _data(), onChanged: onChanged),
    ),
  ),
);

Widget _controlled({
  BeautifulFlowchartData? data,
  ValueChanged<BeautifulFlowchartData>? onChanged,
  Size size = const Size(390, 844),
}) {
  var accepted = data ?? _data();
  return StatefulBuilder(
    builder: (context, setState) => _app(
      data: accepted,
      size: size,
      onChanged: (next) {
        onChanged?.call(next);
        setState(() => accepted = next);
      },
    ),
  );
}
