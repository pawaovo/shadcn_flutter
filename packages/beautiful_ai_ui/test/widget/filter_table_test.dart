import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _rows = <BeautifulFilterTableRow>[
  BeautifulFilterTableRow(
    id: 'stock',
    task: 'Review inventory',
    date: 'Sep 3',
    status: BeautifulFilterTableStatus.todo,
    owner: 'Operations',
  ),
  BeautifulFilterTableRow(
    id: 'report',
    task: 'Prepare report',
    date: 'Sep 4',
    status: BeautifulFilterTableStatus.inProgress,
    owner: 'Research',
  ),
  BeautifulFilterTableRow(
    id: 'audit',
    task: 'Audit sources',
    date: 'Sep 2',
    status: BeautifulFilterTableStatus.completed,
    owner: 'Quality',
  ),
];

Finder _filter(String name) =>
    find.byKey(ValueKey<String>('filter-table-filter-$name'));

Widget _app({
  List<BeautifulFilterTableRow> rows = _rows,
  double width = 390,
  BeautifulFilterTableStatus? initialStatus,
  ValueChanged<BeautifulFilterTableStatus?>? onFilterChanged,
}) => WidgetsApp(
  color: const Color(0xff000000),
  builder: (context, child) => FocusScope(
    autofocus: true,
    child: beautifulTestApp(
      size: Size(width, 1000),
      disableAnimations: true,
      child: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: BeautifulFilterTable(
            rows: rows,
            initialStatus: initialStatus,
            onFilterChanged: onFilterChanged,
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('derives all filter counts and displays caller-owned rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        rows: <BeautifulFilterTableRow>[
          ..._rows,
          const BeautifulFilterTableRow(
            id: 'verify',
            task: 'Verify findings',
            date: 'Sep 8',
            status: BeautifulFilterTableStatus.todo,
            owner: 'Review',
          ),
        ],
      ),
    );
    expect(find.text('All (4)'), findsOneWidget);
    expect(find.text('To do (2)'), findsOneWidget);
    expect(find.text('In progress (1)'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('Review inventory'), findsOneWidget);
    expect(find.text('Matching tasks: 4 / 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'filters rows and emits only changes, including returning to all',
    (tester) async {
      final changes = <BeautifulFilterTableStatus?>[];
      await tester.pumpWidget(_app(onFilterChanged: changes.add));

      await tester.tap(_filter('inProgress'));
      await tester.pump();
      expect(find.text('Prepare report'), findsOneWidget);
      expect(find.text('Review inventory'), findsNothing);
      expect(find.text('Audit sources'), findsNothing);
      expect(find.text('Matching tasks: 1 / 3'), findsOneWidget);

      await tester.tap(_filter('inProgress'));
      await tester.pump();
      await tester.tap(_filter('all'));
      await tester.pump();
      expect(changes, <BeautifulFilterTableStatus?>[
        BeautifulFilterTableStatus.inProgress,
        null,
      ]);
      expect(find.text('Review inventory'), findsOneWidget);
    },
  );

  testWidgets('initial filter is read once and persists across row refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(initialStatus: BeautifulFilterTableStatus.completed),
    );
    expect(find.text('Audit sources'), findsOneWidget);
    await tester.pumpWidget(
      _app(
        rows: <BeautifulFilterTableRow>[_rows.first],
        initialStatus: BeautifulFilterTableStatus.todo,
      ),
    );
    expect(find.text('No matching tasks'), findsOneWidget);
    expect(find.text('Matching tasks: 0 / 1'), findsOneWidget);
    expect(find.text('Completed (0)'), findsOneWidget);
    expect(find.text('Review inventory'), findsNothing);

    await tester.tap(_filter('todo'));
    await tester.pump();
    expect(find.text('Review inventory'), findsOneWidget);
  });

  testWidgets('takes a defensive snapshot until the host updates the widget', (
    tester,
  ) async {
    final mutableRows = <BeautifulFilterTableRow>[..._rows];
    await tester.pumpWidget(_app(rows: mutableRows));
    mutableRows.clear();
    await tester.tap(_filter('completed'));
    await tester.pump();
    expect(find.text('Audit sources'), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);

    await tester.pumpWidget(_app(rows: mutableRows));
    expect(find.text('All (0)'), findsOneWidget);
    expect(find.text('No matching tasks'), findsOneWidget);
  });

  testWidgets('Tab, Enter, and Space operate the filter controls', (
    tester,
  ) async {
    final changes = <BeautifulFilterTableStatus?>[];
    await tester.pumpWidget(_app(onFilterChanged: changes.add));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Scrollable region.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // All.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // To do.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Review inventory'), findsOneWidget);
    expect(find.text('Prepare report'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('Prepare report'), findsOneWidget);
    expect(changes, <BeautifulFilterTableStatus?>[
      BeautifulFilterTableStatus.todo,
      BeautifulFilterTableStatus.inProgress,
    ]);
  });

  testWidgets('resizing preserves selection and focused filter activation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(width: 599));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Scrollable region.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // All.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // To do.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    for (final width in <double>[600, 1023, 1024, 599]) {
      await tester.pumpWidget(_app(width: width));
      expect(find.text('Review inventory'), findsOneWidget);
      expect(find.text('Prepare report'), findsNothing);
      expect(
        find.byKey(
          ValueKey<String>(
            width >= 1024 ? 'filter-table-expanded' : 'filter-table-list',
          ),
        ),
        findsOneWidget,
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Prepare report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports 200 percent localized text, RTL, and all boundaries', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const row = BeautifulFilterTableRow(
      id: 'localized',
      task: 'مراجعة المخزون والتأكد من اكتمال جميع البيانات المطلوبة 任务长标题',
      date: 'الثالث من سبتمبر لعام ألفين وستة وعشرين',
      status: BeautifulFilterTableStatus.inProgress,
      owner: 'فريق العمليات والتحقق من المعلومات الطويلة جداً',
    );
    for (final width in <double>[320, 599, 600, 1023, 1024]) {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          beautifulTestApp(
            size: Size(width, 1600),
            brightness: brightness,
            highContrast: true,
            textDirection: TextDirection.rtl,
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
            child: SingleChildScrollView(
              child: SizedBox(
                width: width,
                child: const BeautifulFilterTable(
                  rows: <BeautifulFilterTableRow>[row],
                  labels: BeautifulFilterTableLabels(
                    all: 'جميع المهام التي تم تسجيلها',
                    todo: 'المهام التي لم يبدأ العمل عليها بعد',
                    inProgress: 'العمل الجاري تنفيذه الآن',
                    completed: 'المهام المكتملة بالفعل',
                    taskColumn: 'اسم المهمة',
                    dateColumn: 'تاريخ المهمة',
                    statusColumn: 'الحالة الحالية',
                    ownerColumn: 'الفريق المسؤول عن المهمة',
                    table: 'المهام',
                    results: 'المهام المطابقة',
                    empty: 'لا توجد مهام مطابقة',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$width $brightness');
        for (final name in <String>['all', 'todo', 'inProgress', 'completed']) {
          final paragraphs = tester.renderObjectList<RenderParagraph>(
            find.descendant(of: _filter(name), matching: find.byType(RichText)),
          );
          for (final paragraph in paragraphs) {
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: 'Filter $name must retain its full label and count',
            );
          }
        }
      }
    }
  });

  testWidgets('all filter targets meet 48dp touch and accessible-label gates', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    for (final name in <String>['all', 'todo', 'inProgress', 'completed']) {
      expect(tester.getSize(_filter(name)).height, greaterThanOrEqualTo(48));
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('empty data remains filterable with honest zero counts', (
    tester,
  ) async {
    await tester.pumpWidget(_app(rows: const <BeautifulFilterTableRow>[]));
    expect(find.text('All (0)'), findsOneWidget);
    expect(find.text('No matching tasks'), findsOneWidget);
    await tester.tap(_filter('completed'));
    await tester.pump();
    expect(find.text('Matching tasks: 0 / 0'), findsOneWidget);
    expect(find.text('No matching tasks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled motion does not animate removed result rows', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.tap(_filter('completed'));
    await tester.pump();
    expect(find.text('Review inventory'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('duplicate row IDs report a useful contract error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(rows: <BeautifulFilterTableRow>[_rows.first, _rows.first]),
    );
    expect(
      tester.takeException().toString(),
      contains('unique, non-empty row ids'),
    );
  });
}
