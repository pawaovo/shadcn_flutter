import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _columns = <BeautifulDiffColumn>[
  BeautifulDiffColumn(id: 'name', label: 'Name'),
  BeautifulDiffColumn(id: 'category', label: 'Category'),
  BeautifulDiffColumn(id: 'quantity', label: 'Quantity'),
];

BeautifulDiffRow _row(int index, int kind) {
  final before = <String, String>{
    'name': 'Name $index',
    'category': 'Category $index',
    'quantity': '$index',
  };
  return BeautifulDiffRow(
    id: 'r$index',
    before: kind == 1 ? null : before,
    after: kind == 2
        ? null
        : <String, String>{
            ...before,
            if (kind == 0) 'quantity': '${index + 1}',
          },
  );
}

List<BeautifulDiffRow> _rows() =>
    List<BeautifulDiffRow>.generate(500, (index) => _row(index, index % 4));

Finder _key(String suffix) =>
    find.byKey(ValueKey<String>('diff-table-$suffix'));

Widget _app({
  required List<BeautifulDiffRow> rows,
  String id = 'summary-count',
  List<BeautifulDiffColumn> columns = _columns,
  BeautifulDiffTableLabels labels = const BeautifulDiffTableLabels(),
  Set<String>? initial,
  Future<void> Function(Set<String>)? onApply,
  String title = 'All 500 proposed records',
  String? error,
  int pageSize = 20,
  double width = 1200,
  TextDirection direction = TextDirection.ltr,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (_, _) => FocusScope(
    autofocus: true,
    child: beautifulTestApp(
      size: Size(width, 1100),
      textDirection: direction,
      disableAnimations: true,
      child: SingleChildScrollView(
        child: BeautifulDiffTable(
          id: id,
          title: title,
          rows: rows,
          columns: columns,
          labels: labels,
          initialIncludedRowIds: initial,
          onApply: onApply,
          errorMessage: error,
          pageSize: pageSize,
        ),
      ),
    ),
  ),
);

/// Read the actual aggregation diagnostics of the publicly mounted component.
/// These are assert-only work counts, never native timing or memory evidence.
({int computations, int rows}) _work(WidgetTester tester) {
  final properties = DiagnosticPropertiesBuilder();
  tester.state(find.byType(BeautifulDiffTable)).debugFillProperties(properties);
  int value(String name) => (properties.properties.singleWhere(
    (entry) => entry.name == name,
  ) as IntProperty).value!;
  return (
    computations: value('summaryComputations'),
    rows: value('summaryRowVisits'),
  );
}

Future<void> _tap(WidgetTester tester, String suffix) async {
  await tester.ensureVisible(_key(suffix));
  await tester.pump();
  await tester.tap(_key(suffix));
  await tester.pumpAndSettle();
}

void _prepareView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1100);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  testWidgets(
    '500-row pagination reuses aggregate work until inclusion changes',
    (tester) async {
      _prepareView(tester);
      await tester.pumpWidget(_app(rows: _rows()));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Selected changes: 375. Removed: 125, Added: 125, Changed: 125',
        ),
        findsOneWidget,
      );
      final initial = _work(tester);
      expect(initial.computations, greaterThan(0));
      expect(initial.rows, initial.computations * 500);
      // Repeat the actual six page changes used by three native workload rounds.
      for (var round = 0; round < 3; round++) {
        await _tap(tester, 'next');
        expect(find.text('Page 2 / 25'), findsOneWidget);
        expect(_key('row-r20'), findsOneWidget);
        expect(_key('row-r0'), findsNothing);
        await _tap(tester, 'previous');
        expect(find.text('Page 1 / 25'), findsOneWidget);
        expect(_key('row-r0'), findsOneWidget);
        expect(_key('row-r20'), findsNothing);
      }
      expect(
        _work(tester).rows - initial.rows,
        0,
        reason: 'Changing only page must not scan all 500 records again.',
      );
      expect(_work(tester).computations, initial.computations);

      await _tap(tester, 'include-r0');
      expect(
        find.text(
          'Selected changes: 374. Removed: 125, Added: 125, Changed: 124',
        ),
        findsOneWidget,
      );
      expect(_work(tester).computations, initial.computations + 1);
      expect(_work(tester).rows, initial.rows + 500);
      final excluded = _work(tester);
      await _tap(tester, 'next');
      expect(_work(tester), excluded);
      await _tap(tester, 'previous');
      expect(_work(tester), excluded);
      await _tap(tester, 'include-r0');
      expect(
        find.text(
          'Selected changes: 375. Removed: 125, Added: 125, Changed: 125',
        ),
        findsOneWidget,
      );
      expect(_work(tester).computations, initial.computations + 2);
    },
  );

  testWidgets(
    'same-list row replacement refreshes classifications and inclusion',
    (tester) async {
      _prepareView(tester);
      final rows = _rows();
      Set<String>? submitted;
      Future<void> apply(Set<String> ids) async => submitted = ids;
      await tester.pumpWidget(_app(rows: rows, onApply: apply));
      await tester.pumpAndSettle();
      await _tap(tester, 'include-r0');
      final before = _work(tester);
      // Same id and inclusion count, different change classification.
      rows[1] = _row(1, 0);
      await tester.pumpWidget(_app(rows: rows, onApply: apply));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Selected changes: 374. Removed: 125, Added: 124, Changed: 125',
        ),
        findsOneWidget,
      );
      expect(_work(tester).computations, before.computations + 1);
      rows[1] = _row(1, 3);
      await tester.pumpWidget(_app(rows: rows, onApply: apply));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Selected changes: 373. Removed: 125, Added: 124, Changed: 124',
        ),
        findsOneWidget,
      );
      expect(_key('include-r1'), findsNothing);
      rows[1] = _row(1, 1);
      await tester.pumpWidget(_app(rows: rows, onApply: apply));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Selected changes: 374. Removed: 125, Added: 125, Changed: 124',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'apply');
      expect(submitted, hasLength(374));
      expect(submitted, contains('r1'));
      expect(submitted, isNot(contains('r0')));
      expect(submitted, isNot(contains('r3')));
    },
  );

  testWidgets('equivalent host updates retain counts but use current labels', (
    tester,
  ) async {
    _prepareView(tester);
    await tester.pumpWidget(_app(rows: _rows()));
    await tester.pumpAndSettle();
    final initial = _work(tester);
    final pending = Completer<void>();
    const labels = BeautifulDiffTableLabels(
      selected: 'Chosen',
      removed: 'Deleted',
      added: 'Created',
      modified: 'Updated',
      applying: 'Saving current proposal',
      applied: 'Saved current proposal',
    );
    await tester.pumpWidget(
      _app(
        rows: _rows(),
        labels: labels,
        initial: {'r1'}, // Same proposal must not reseed inclusion.
        onApply: (_) => pending.future,
        title: 'Current title',
        error: 'Current host error',
        pageSize: 25,
        width: 800,
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Current title'), findsOneWidget);
    expect(find.text('Current host error'), findsOneWidget);
    expect(find.text('Page 1 / 20'), findsOneWidget);
    expect(
      find.text('Chosen: 375. Deleted: 125, Created: 125, Updated: 125'),
      findsOneWidget,
    );
    expect(_work(tester), initial);
    await _tap(tester, 'apply');
    expect(find.text('Saving current proposal'), findsNWidgets(2));
    expect(_work(tester), initial);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Saved current proposal: 375'), findsNWidgets(2));
    expect(_work(tester), initial);
  });

  testWidgets(
    'shrinking rows and resetting proposal retain correct page bounds',
    (tester) async {
      _prepareView(tester);
      final rows = _rows();
      await tester.pumpWidget(_app(rows: rows));
      await tester.pumpAndSettle();
      await _tap(tester, 'next');
      await _tap(tester, 'next');
      expect(find.text('Page 3 / 25'), findsOneWidget);
      rows.removeRange(21, rows.length);
      await tester.pumpWidget(_app(rows: rows));
      await tester.pumpAndSettle();
      expect(find.text('Page 2 / 2'), findsOneWidget);
      expect(_key('row-r20'), findsOneWidget);
      expect(
        find.text('Selected changes: 16. Removed: 5, Added: 5, Changed: 6'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        _app(rows: rows, id: 'new-proposal', initial: {'r1', 'r3', 'missing'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Page 1 / 2'), findsOneWidget);
      expect(_key('row-r0'), findsOneWidget);
      expect(
        find.text('Selected changes: 1. Removed: 0, Added: 1, Changed: 0'),
        findsOneWidget,
      );
      rows.clear();
      await tester.pumpWidget(_app(rows: rows, id: 'new-proposal'));
      await tester.pumpAndSettle();
      expect(find.text('No records to compare'), findsOneWidget);
      expect(_key('next'), findsNothing);
      expect(_key('previous'), findsNothing);
      expect(
        find.text('Selected changes: 0. Removed: 0, Added: 0, Changed: 0'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
