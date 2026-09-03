import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('nodes expose kind, name, selection and readable connections', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    final node = find.bySemanticsLabel('Trigger: Start');
    var data = tester.getSemantics(node).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, ui.Tristate.isFalse);
    expect(data.value, 'A new request arrives');
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(
      find.bySemanticsLabel('Connected to: Check request (Next)'),
      findsOneWidget,
    );
    tester.semantics.tap(find.semantics.byLabel('Trigger: Start'));
    await tester.pump();
    data = tester.getSemantics(node).getSemanticsData();
    expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(data.flagsCollection.isFocused, ui.Tristate.isTrue);
    handle.dispose();
  });

  testWidgets(
    'condition options disclose selected values and leave semantics when closed',
    (tester) async {
      final handle = tester.ensureSemantics();
      final proposals = <BeautifulFlowchartData>[];
      await tester.pumpWidget(_app(onChanged: proposals.add));
      final field = find.bySemanticsLabel('Property: Priority');
      expect(
        tester
            .getSemantics(field)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        ui.Tristate.isFalse,
      );
      expect(find.bySemanticsLabel('Category'), findsNothing);
      tester.semantics.tap(find.semantics.byLabel('Property: Priority'));
      await tester.pump();
      expect(
        tester
            .getSemantics(field)
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        ui.Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Priority'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Category'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isFalse,
      );
      tester.semantics.tap(find.semantics.byLabel('Category'));
      await tester.pump();
      expect(
        proposals.single.nodes.last.conditions.single.fields.single.valueId,
        'category',
      );
      expect(find.bySemanticsLabel('Category'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets(
    'read-only selectors remove editing actions and report disabled state',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      final field = tester
          .getSemantics(find.bySemanticsLabel('Property: Priority'))
          .getSemanticsData();
      expect(field.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(field.hasAction(SemanticsAction.tap), isFalse);
      expect(find.bySemanticsLabel('Read only'), findsOneWidget);
      handle.dispose();
    },
  );

  testWidgets(
    'canvas movement has semantic buttons and editable header instructions',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final proposals = <BeautifulFlowchartData>[];
      await tester.pumpWidget(
        _app(size: const Size(1280, 1200), onChanged: proposals.add),
      );
      await tester.pump();
      tester.semantics.tap(find.semantics.byLabel('Trigger: Start'));
      await tester.pump();
      final header = tester
          .getSemantics(find.bySemanticsLabel('Trigger: Start'))
          .getSemanticsData();
      expect(header.hint, 'Drag or use arrow keys to move; Shift moves faster');
      final move = tester
          .getSemantics(find.bySemanticsLabel('Move right'))
          .getSemanticsData();
      expect(move.flagsCollection.isButton, isTrue);
      expect(move.hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Move right'));
      await tester.pump();
      expect(proposals.single.nodes.first.position, const Offset(80, 32));
      handle.dispose();
    },
  );

  testWidgets(
    'compact and canvas controls meet Android target and label guidelines',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(1280, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in <double>[390, 1280]) {
        await tester.pumpWidget(
          _app(size: Size(width, 1200), onChanged: (_) {}),
        );
        await tester.pump();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
      handle.dispose();
    },
  );
}

Widget _app({
  ValueChanged<BeautifulFlowchartData>? onChanged,
  Size size = const Size(390, 844),
}) => beautifulTestApp(
  size: size,
  disableAnimations: true,
  child: SizedBox(
    width: size.width,
    child: SingleChildScrollView(
      child: BeautifulFlowchart(
        data: BeautifulFlowchartData(
          id: 'workflow',
          nodes: <BeautifulFlowchartNode>[
            BeautifulFlowchartNode(
              id: 'trigger',
              kind: BeautifulFlowchartNodeKind.trigger,
              title: 'Start',
              caption: 'A new request arrives',
              position: const Offset(64, 32),
            ),
            BeautifulFlowchartNode(
              id: 'condition',
              kind: BeautifulFlowchartNodeKind.condition,
              title: 'Check request',
              position: const Offset(64, 200),
              conditions: <BeautifulFlowchartCondition>[
                BeautifulFlowchartCondition(
                  id: 'if',
                  label: 'If',
                  sourceLabel: 'request',
                  fields: <BeautifulFlowchartField>[
                    BeautifulFlowchartField(
                      id: 'property',
                      label: 'Property',
                      valueId: 'priority',
                      options: const <BeautifulFlowchartOption>[
                        BeautifulFlowchartOption(
                          id: 'priority',
                          label: 'Priority',
                        ),
                        BeautifulFlowchartOption(
                          id: 'category',
                          label: 'Category',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
          edges: const <BeautifulFlowchartEdge>[
            BeautifulFlowchartEdge(
              id: 'next',
              from: 'trigger',
              to: 'condition',
              label: 'Next',
            ),
          ],
        ),
        onChanged: onChanged,
      ),
    ),
  ),
);
