import 'dart:async';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

Widget _app({
  double width = 390,
  Future<void> Function(Set<String>)? onApply,
  int pageSize = 20,
}) => beautifulTestApp(
  size: Size(width, 1600),
  disableAnimations: true,
  child: SingleChildScrollView(
    child: SizedBox(
      width: width,
      child: BeautifulDiffTable(
        id: 'proposal',
        title: 'Review changes',
        columns: const [BeautifulDiffColumn(id: 'name', label: 'Name')],
        rows: [
          BeautifulDiffRow(id: 'removed', before: {'name': 'Original'}),
          BeautifulDiffRow(id: 'added', after: {'name': 'Proposed'}),
        ],
        onApply: onApply,
        pageSize: pageSize,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'record inclusion is a selected button with keyboard/tap semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      const name = 'Include change: Original, Removed';
      final data = tester
          .getSemantics(find.bySemanticsLabel(name))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel(name));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(name))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isFalse,
      );
      expect(find.text('Before'), findsNWidgets(2));
      expect(find.text('After'), findsNWidgets(2));
      expect(find.text('No record'), findsNWidgets(2));
      expect(find.text('Removed'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('selection and real apply completion announce status natively', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final pending = Completer<void>();
    await tester.pumpWidget(_app(onApply: (_) => pending.future));
    const initial = 'Selected changes: 2. Removed: 1, Added: 1, Changed: 0';
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(initial))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    tester.semantics.tap(find.semantics.byLabel('Apply changes (2)'));
    await tester.pump();
    final pendingNodes = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where(
          (node) =>
              node.properties.liveRegion == true &&
              node.properties.label == 'Applying changes',
        );
    expect(pendingNodes, hasLength(1));
    final include = tester
        .getSemantics(
          find.bySemanticsLabel('Include change: Original, Removed'),
        )
        .getSemanticsData();
    expect(include.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(include.hasAction(SemanticsAction.tap), isFalse);
    pending.complete();
    await tester.pump();
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where(
            (node) =>
                node.properties.liveRegion == true &&
                node.properties.label == 'Changes applied: 2',
          ),
      hasLength(1),
    );
    semantics.dispose();
  });

  testWidgets(
    'adaptive comparison exposes table and explicit old/new headers',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(width: 1024));
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey<String>('diff-table-records')),
            )
            .getSemanticsData()
            .role,
        SemanticsRole.table,
      );
      final headers = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((node) => node.properties.role == SemanticsRole.columnHeader);
      expect(headers, hasLength(3));
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey<String>('diff-table-row-removed')),
            )
            .getSemanticsData()
            .role,
        SemanticsRole.row,
      );
      await tester.pumpWidget(_app(width: 390));
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey<String>('diff-table-records')),
            )
            .getSemanticsData()
            .role,
        SemanticsRole.list,
      );
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey<String>('diff-table-row-removed')),
            )
            .getSemanticsData()
            .role,
        SemanticsRole.listItem,
      );
      semantics.dispose();
    },
  );

  testWidgets('pagination removes off-page controls from accessibility tree', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(pageSize: 1));
    expect(
      find.bySemanticsLabel('Include change: Original, Removed'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Include change: Proposed, Added'),
      findsNothing,
    );
    tester.semantics.tap(find.semantics.byLabel('Next page'));
    await tester.pump();
    expect(
      find.bySemanticsLabel('Include change: Original, Removed'),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Include change: Proposed, Added'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
