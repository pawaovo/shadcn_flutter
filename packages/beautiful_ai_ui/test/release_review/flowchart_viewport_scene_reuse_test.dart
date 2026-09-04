import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui/src/implementation/controls/action_control.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('viewport toolbar reuses the 24-node 48-edge scene', (
    tester,
  ) async {
    _surface(tester);
    final graph = _graph();
    final edits = <BeautifulFlowchartData>[];
    await tester.pumpWidget(
      _app(
        BeautifulFlowchart(
          data: graph,
          onChanged: edits.add,
          viewportHeight: 420,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = _scene(tester, graph);
    final transform = _viewer(tester).transformationController!;
    try {
      await _tap(tester, 'pan-right');
      expect(transform.value.getTranslation().x, -160);
      _expectScene(tester, graph, before);
      await _tap(tester, 'pan-left');
      expect(transform.value.getTranslation().x, 0);
      _expectScene(tester, graph, before);

      await _tap(tester, 'zoom-in');
      expect(transform.value.getMaxScaleOnAxis(), 1.25);
      expect(find.text('125%'), findsOneWidget);
      expect(_control(tester, 'zoom-out').onPressed, isNotNull);
      _expectScene(tester, graph, before);
      await _tap(tester, 'zoom-out');
      expect(transform.value.getMaxScaleOnAxis(), 1);
      expect(find.text('100%'), findsOneWidget);
      expect(_control(tester, 'zoom-out').onPressed, isNull);
      _expectScene(tester, graph, before);
      expect(_viewer(tester).transformationController, same(transform));
      expect(
        edits,
        isEmpty,
        reason: 'Viewport changes must not propose graph edits.',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('pointer pan completion does not reconstruct the scene', (
    tester,
  ) async {
    _surface(tester);
    final graph = _graph();
    final edits = <BeautifulFlowchartData>[];
    await tester.pumpWidget(
      _app(
        BeautifulFlowchart(
          data: graph,
          onChanged: edits.add,
          viewportHeight: 420,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = _scene(tester, graph);
    try {
      final viewport = tester.getTopLeft(_key('viewport'));
      // x=858 is the gap between 360px cards at x=468 and x=888.
      // Keep the pointer in that gap for the entire gesture.
      await tester.dragFrom(
        viewport + const Offset(858, 80),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(
        _viewer(tester).transformationController!.value.getTranslation().y,
        lessThan(-20),
      );
      _expectScene(tester, graph, before);
      expect(edits, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('selection and same-ID host updates still refresh the scene', (
    tester,
  ) async {
    _surface(tester);
    final semantics = tester.ensureSemantics();
    var graph = _graph();
    var callbackVersion = 0;
    final observedCallbacks = <int>[];
    late StateSetter updateHost;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, update) {
            updateHost = update;
            final version = callbackVersion;
            return BeautifulFlowchart(
              data: graph,
              viewportHeight: 420,
              onChanged: (next) {
                observedCallbacks.add(version);
                update(() => graph = next);
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    try {
      final initial = _scene(tester, graph);
      await tester.tap(_key('node-n0'));
      await tester.pumpAndSettle();
      final selected = _scene(tester, graph);
      expect(selected.scene, isNot(same(initial.scene)));
      expect(selected.painter, isNot(same(initial.painter)));
      expect(
        tester
            .getSemantics(_key('node-n0'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );

      await _tap(tester, 'zoom-in');
      _expectScene(tester, graph, selected);
      updateHost(() {
        callbackVersion = 1;
        graph = BeautifulFlowchartData(
          id: graph.id,
          nodes: <BeautifulFlowchartNode>[
            for (final node in graph.nodes)
              if (node.id == 'n0')
                BeautifulFlowchartNode(
                  id: node.id,
                  kind: node.kind,
                  title: 'Updated host title',
                  caption:
                      'A taller host caption that must refresh measured connectors. ' *
                      8,
                  position: const Offset(100, 80),
                )
              else
                node,
          ],
          edges: graph.edges,
        );
      });
      await tester.pumpAndSettle();
      final updated = _scene(tester, graph);
      expect(updated.scene, isNot(same(selected.scene)));
      expect(updated.painter, isNot(same(selected.painter)));
      expect(find.text('Updated host title'), findsNWidgets(2));
      expect(
        _viewer(tester).transformationController!.value.getMaxScaleOnAxis(),
        1.25,
      );

      // Toolbar movement must use the new host node and callback, not closures
      // retained from the viewport's earlier scene.
      await _tap(tester, 'move-right');
      expect(graph.nodes.first.position, const Offset(116, 80));
      expect(observedCallbacks, <int>[1]);
      final moved = _scene(tester, graph);
      expect(moved.painter, isNot(same(updated.painter)));
      await _tap(tester, 'pan-right');
      _expectScene(tester, graph, moved);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    }
  });
}

typedef _Scene = ({
  Widget scene,
  Object painter,
  List<Widget> nodes,
  List<Widget> edges,
});

_Scene _scene(WidgetTester tester, BeautifulFlowchartData graph) => (
  scene: _viewer(tester).child!,
  painter: tester.widget<CustomPaint>(_key('connectors')).painter!,
  nodes: <Widget>[
    for (final node in graph.nodes) tester.widget(_key('node-${node.id}')),
  ],
  edges: <Widget>[
    for (final edge in graph.edges) tester.widget(_key('edge-${edge.id}')),
  ],
);

void _expectScene(
  WidgetTester tester,
  BeautifulFlowchartData graph,
  _Scene before,
) {
  final after = _scene(tester, graph);
  expect(
    after.scene,
    same(before.scene),
    reason: 'Viewport-only input rebuilt the canvas child.',
  );
  expect(
    after.painter,
    same(before.painter),
    reason: 'Viewport-only input reconstructed connector geometry.',
  );
  for (var index = 0; index < after.nodes.length; index++) {
    expect(
      after.nodes[index],
      same(before.nodes[index]),
      reason: 'Node $index was reconstructed for a viewport-only change.',
    );
  }
  for (var index = 0; index < after.edges.length; index++) {
    expect(
      after.edges[index],
      same(before.edges[index]),
      reason: 'Edge label $index was reconstructed for a viewport-only change.',
    );
  }
}

Finder _key(String suffix) => find.byKey(Key('beautiful-flowchart-$suffix'));
InteractiveViewer _viewer(WidgetTester tester) =>
    tester.widget<InteractiveViewer>(_key('viewer'));
BeautifulActionControl _control(WidgetTester tester, String suffix) =>
    tester.widget<BeautifulActionControl>(_key(suffix));
Future<void> _tap(WidgetTester tester, String suffix) async {
  await tester.ensureVisible(_key(suffix));
  await tester.pump();
  await tester.tap(_key(suffix));
  await tester.pumpAndSettle();
}

void _surface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget child) => beautifulTestApp(
  size: const Size(1280, 1000),
  disableAnimations: true,
  motion: BeautifulMotionPolicy.none,
  child: SingleChildScrollView(child: child),
);
BeautifulFlowchartData _graph() => BeautifulFlowchartData(
  id: 'viewport-scene',
  nodes: <BeautifulFlowchartNode>[
    for (var index = 0; index < 24; index++)
      BeautifulFlowchartNode(
        id: 'n$index',
        kind: BeautifulFlowchartNodeKind.trigger,
        title: 'Step $index',
        position: Offset(48 + (index % 4) * 420, 48 + (index ~/ 4) * 200),
      ),
  ],
  edges: <BeautifulFlowchartEdge>[
    for (var index = 0; index < 23; index++)
      BeautifulFlowchartEdge(
        id: 'next-$index',
        from: 'n$index',
        to: 'n${index + 1}',
      ),
    for (var index = 0; index < 22; index++)
      BeautifulFlowchartEdge(
        id: 'skip-$index',
        from: 'n$index',
        to: 'n${index + 2}',
      ),
    for (var index = 0; index < 3; index++)
      BeautifulFlowchartEdge(
        id: 'branch-$index',
        from: 'n$index',
        to: 'n${index + 3}',
      ),
  ],
);
