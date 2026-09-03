import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _rows = <BeautifulFilterTableRow>[
  BeautifulFilterTableRow(
    id: 'first',
    task: 'Review inventory',
    date: 'Sep 3',
    status: BeautifulFilterTableStatus.todo,
    owner: 'Operations',
  ),
  BeautifulFilterTableRow(
    id: 'second',
    task: 'Prepare report',
    date: 'Sep 4',
    status: BeautifulFilterTableStatus.completed,
    owner: 'Research',
  ),
];

Widget _app({double width = 390}) => beautifulTestApp(
  size: Size(width, 1200),
  disableAnimations: true,
  child: SingleChildScrollView(
    child: SizedBox(
      width: width,
      child: const BeautifulFilterTable(rows: _rows),
    ),
  ),
);

void main() {
  testWidgets('filters expose selected button state and actual counts', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    final all = tester
        .getSemantics(find.bySemanticsLabel('All, 2'))
        .getSemanticsData();
    final completed = tester
        .getSemantics(find.bySemanticsLabel('Completed, 1'))
        .getSemanticsData();
    expect(all.flagsCollection.isButton, isTrue);
    expect(all.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(completed.flagsCollection.isSelected, ui.Tristate.isFalse);
    expect(completed.hasAction(SemanticsAction.tap), isTrue);

    tester.semantics.tap(find.semantics.byLabel('Completed, 1'));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Completed, 1'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets(
    'compact rows are complete list items and hidden rows disappear',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      const first =
          'Task name: Review inventory. Date: Sep 3. '
          'Status: To do. Advisor: Operations';
      const second =
          'Task name: Prepare report. Date: Sep 4. '
          'Status: Completed. Advisor: Research';
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Tasks'))
            .getSemanticsData()
            .role,
        SemanticsRole.list,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(first))
            .getSemanticsData()
            .role,
        SemanticsRole.listItem,
      );
      tester.semantics.tap(find.semantics.byLabel('Completed, 1'));
      await tester.pump();
      expect(find.bySemanticsLabel(first), findsNothing);
      expect(find.bySemanticsLabel(second), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('matching count uses a changing native live-region label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    final before = tester
        .getSemantics(find.bySemanticsLabel('Matching tasks: 2 / 2'))
        .getSemanticsData();
    expect(before.flagsCollection.isLiveRegion, isTrue);
    expect(before.label, 'Matching tasks: 2 / 2');
    tester.semantics.tap(find.semantics.byLabel('In progress, 0'));
    await tester.pump();
    final after = tester
        .getSemantics(find.bySemanticsLabel('Matching tasks: 0 / 2'))
        .getSemanticsData();
    expect(after.flagsCollection.isLiveRegion, isTrue);
    expect(after.label, 'Matching tasks: 0 / 2');
    expect(find.bySemanticsLabel('No matching tasks'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('expanded presentation exposes table, headers, rows, and cells', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(width: 1024));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Tasks'))
          .getSemanticsData()
          .role,
      SemanticsRole.table,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Task name'))
          .getSemanticsData()
          .role,
      SemanticsRole.columnHeader,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey<String>('filter-table-row-first')),
          )
          .getSemanticsData()
          .role,
      SemanticsRole.row,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Review inventory'))
          .getSemanticsData()
          .role,
      SemanticsRole.cell,
    );
    semantics.dispose();
  });
}
