import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _columns = <BeautifulDiffColumn>[
  BeautifulDiffColumn(id: 'name', label: 'Name'),
  BeautifulDiffColumn(id: 'category', label: 'Category'),
];

List<BeautifulDiffRow> _rows() => <BeautifulDiffRow>[
  BeautifulDiffRow(
    id: 'remove',
    before: {'name': 'Rocky', 'category': 'Classic'},
  ),
  BeautifulDiffRow(
    id: 'add',
    after: {'name': 'Pistachio', 'category': 'Seasonal'},
  ),
  BeautifulDiffRow(
    id: 'modify',
    before: {'name': 'Mint', 'category': 'Classic'},
    after: {'name': 'Mint', 'category': 'Seasonal'},
  ),
  BeautifulDiffRow(
    id: 'same',
    before: {'name': 'Vanilla'},
    after: {'name': 'Vanilla'},
  ),
];

Finder _key(String id) => find.byKey(ValueKey<String>('diff-table-$id'));

Widget _app({
  String id = 'proposal',
  List<BeautifulDiffRow>? rows,
  List<BeautifulDiffColumn> columns = _columns,
  Set<String>? initial,
  Future<void> Function(Set<String>)? onApply,
  BeautifulUiFailureHandler? onFailure,
  double width = 390,
  int pageSize = 20,
  String? errorMessage,
}) => WidgetsApp(
  color: const Color(0xff000000),
  builder: (context, child) => FocusScope(
    autofocus: true,
    child: beautifulTestApp(
      size: Size(width, 1200),
      disableAnimations: true,
      child: BeautifulUiScope(
        onFailure: onFailure,
        child: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: BeautifulDiffTable(
              id: id,
              title: 'Proposed updates',
              columns: columns,
              rows: rows ?? _rows(),
              initialIncludedRowIds: initial,
              onApply: onApply,
              pageSize: pageSize,
              errorMessage: errorMessage,
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _tap(WidgetTester tester, String id) async {
  await tester.ensureVisible(_key(id));
  await tester.pump();
  await tester.tap(_key(id));
  await tester.pump();
}

void main() {
  testWidgets('derives change meaning and submits only included changed IDs', (
    tester,
  ) async {
    Set<String>? submitted;
    final pending = Completer<void>();
    await tester.pumpWidget(
      _app(
        onApply: (ids) {
          submitted = ids;
          return pending.future;
        },
      ),
    );
    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Changed'), findsOneWidget);
    expect(find.text('Unchanged'), findsOneWidget);
    expect(_key('include-same'), findsNothing);
    expect(
      find.text('Selected changes: 3. Removed: 1, Added: 1, Changed: 1'),
      findsOneWidget,
    );
    await _tap(tester, 'include-remove');
    await _tap(tester, 'apply');
    expect(submitted, {'add', 'modify'});
    expect(() => submitted!.clear(), throwsUnsupportedError);
    expect(find.text('Changes applied: 2'), findsNothing);
    expect(find.text('Applying changes'), findsNWidgets(2));
    pending.complete();
    await tester.pump();
    expect(find.text('Changes applied: 2'), findsNWidgets(2));
    await _tap(tester, 'include-add');
    expect(find.text('Excluded'), findsOneWidget);
  });

  testWidgets(
    'deduplicates application and preserves callback result on equal refresh',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _app(
          onApply: (_) {
            calls++;
            return pending.future;
          },
        ),
      );
      await _tap(tester, 'apply');
      await _tap(tester, 'apply');
      expect(calls, 1);
      await tester.pumpWidget(
        _app(
          rows: _rows(),
          onApply: (_) async {
            calls++;
          },
        ),
      );
      expect(find.text('Applying changes'), findsNWidgets(2));
      pending.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Changes applied: 3'), findsNWidgets(2));
      expect(calls, 1);
    },
  );

  testWidgets(
    'replaced proposal isolates obsolete success and resets initial choice',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(_app(onApply: (_) => pending.future));
      await _tap(tester, 'apply');
      await tester.pumpWidget(
        _app(id: 'replacement', initial: {'add'}, onApply: (_) async {}),
      );
      pending.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Changes applied: 3'), findsNothing);
      expect(
        find.text('Selected changes: 1. Removed: 0, Added: 1, Changed: 0'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'meaningful data changes invalidate pending work and preserve choices',
    (tester) async {
      final pending = Completer<void>();
      final failures = <BeautifulUiFailure>[];
      await tester.pumpWidget(
        _app(onApply: (_) => pending.future, onFailure: failures.add),
      );
      await _tap(tester, 'include-remove');
      await _tap(tester, 'apply');
      final rows = _rows();
      rows[1] = BeautifulDiffRow(
        id: 'add',
        after: {'name': 'Updated pistachio'},
      );
      rows.add(BeautifulDiffRow(id: 'new', after: {'name': 'New'}));
      await tester.pumpWidget(
        _app(rows: rows, onApply: (_) async {}, onFailure: failures.add),
      );
      pending.completeError(StateError('obsolete'));
      await tester.pump();
      expect(failures, isEmpty);
      expect(
        find.text('Selected changes: 3. Removed: 0, Added: 2, Changed: 1'),
        findsOneWidget,
      );
      expect(find.text('Applying changes'), findsNothing);
    },
  );

  testWidgets(
    'failure keeps selection, reports normalized error, and permits retry',
    (tester) async {
      var calls = 0;
      final failures = <BeautifulUiFailure>[];
      await tester.pumpWidget(
        _app(
          onApply: (_) async {
            if (calls++ == 0) throw StateError('unavailable');
          },
          onFailure: failures.add,
        ),
      );
      await _tap(tester, 'apply');
      expect(
        find.text('Changes could not be applied. Try again.'),
        findsOneWidget,
      );
      expect(failures.single.operation, BeautifulUiOperation.diff);
      expect(find.text('Apply changes (3)'), findsOneWidget);
      await _tap(tester, 'apply');
      expect(calls, 2);
      expect(find.text('Changes applied: 3'), findsNWidgets(2));
    },
  );

  testWidgets('disposal ignores pending failure', (tester) async {
    final pending = Completer<void>();
    final failures = <BeautifulUiFailure>[];
    await tester.pumpWidget(
      _app(onApply: (_) => pending.future, onFailure: failures.add),
    );
    await _tap(tester, 'apply');
    await tester.pumpWidget(const SizedBox.shrink());
    pending.completeError(StateError('obsolete'));
    await tester.pump();
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'defensive nested snapshots survive caller mutation and local rebuild',
    (tester) async {
      final values = <String, String>{'name': 'Original'};
      final row = BeautifulDiffRow(id: 'add', after: values);
      final rows = <BeautifulDiffRow>[row];
      final columns = <BeautifulDiffColumn>[..._columns];
      await tester.pumpWidget(
        _app(rows: rows, columns: columns, onApply: (_) async {}),
      );
      values['name'] = 'Unexpected mutation';
      rows.clear();
      columns.clear();
      await _tap(tester, 'include-add');
      expect(find.text('Name: Original'), findsOneWidget);
      expect(find.textContaining('Unexpected mutation'), findsNothing);
      expect(() => row.after!['name'] = 'mutate', throwsUnsupportedError);
    },
  );

  testWidgets(
    'seed is read once per identity and row refresh reconciles selection',
    (tester) async {
      await tester.pumpWidget(_app(initial: {'add', 'same', 'unknown'}));
      await tester.pumpWidget(_app(initial: {'remove'}));
      expect(
        find.text('Selected changes: 1. Removed: 0, Added: 1, Changed: 0'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        _app(
          rows: <BeautifulDiffRow>[
            _rows().first,
            BeautifulDiffRow(id: 'other', after: {'name': 'Another'}),
          ],
          initial: {'remove'},
        ),
      );
      expect(
        find.text('Selected changes: 1. Removed: 0, Added: 1, Changed: 0'),
        findsOneWidget,
      );
    },
  );

  testWidgets('bounded pages preserve selections across the full dataset', (
    tester,
  ) async {
    final rows = List<BeautifulDiffRow>.generate(
      5,
      (index) => BeautifulDiffRow(id: 'r$index', after: {'name': 'Row $index'}),
    );
    Set<String>? submitted;
    await tester.pumpWidget(
      _app(
        rows: rows,
        pageSize: 2,
        onApply: (ids) async {
          submitted = ids;
        },
      ),
    );
    expect(_key('row-r0'), findsOneWidget);
    expect(_key('row-r2'), findsNothing);
    await _tap(tester, 'include-r0');
    await _tap(tester, 'next');
    expect(_key('row-r0'), findsNothing);
    expect(_key('row-r2'), findsOneWidget);
    expect(find.text('Page 2 / 3'), findsOneWidget);
    await _tap(tester, 'include-r2');
    await _tap(tester, 'next');
    await _tap(tester, 'apply');
    expect(submitted, {'r1', 'r3', 'r4'});
  });

  testWidgets(
    '500 rows retain a bounded render window and collect workload timings',
    (tester) async {
      final rows = List<BeautifulDiffRow>.generate(
        500,
        (index) => BeautifulDiffRow(
          id: 'r$index',
          before: {
            'name': 'Record $index',
            'category': 'Prior',
            'owner': 'Operations',
          },
          after: {
            'name': 'Record $index',
            'category': 'Proposed',
            'owner': 'Operations',
          },
        ),
      );
      const columns = <BeautifulDiffColumn>[
        ..._columns,
        BeautifulDiffColumn(id: 'owner', label: 'Owner'),
      ];
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(_app(rows: rows, columns: columns));
      final initialMicros = stopwatch.elapsedMicroseconds;
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'diff-table-row-',
              ),
        ),
        findsNWidgets(20),
      );
      expect(_key('row-r20'), findsNothing);
      stopwatch.reset();
      await _tap(tester, 'next');
      final pageMicros = stopwatch.elapsedMicroseconds;
      expect(_key('row-r0'), findsNothing);
      expect(_key('row-r20'), findsOneWidget);
      expect(_key('row-r40'), findsNothing);
      stopwatch.reset();
      await tester.pumpWidget(_app(rows: List.of(rows), columns: columns));
      final refreshMicros = stopwatch.elapsedMicroseconds;
      // Diagnostic timing only; deterministic rendering bounds are the gate.
      debugPrint(
        'Diff workload 500 x 3 / page 20: first=$initialMicros us, '
        'page=$pageMicros us, equivalent refresh=$refreshMicros us',
      );
      expect(find.text('Page 2 / 25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('keyboard selection retains focus through adaptive resizing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(width: 599, rows: [_rows().first]));
    await tester.pump();
    final gesture = find.descendant(
      of: _key('include-remove'),
      matching: find.byType(GestureDetector),
    );
    FocusNode inclusionFocus() => Focus.of(tester.element(gesture));
    for (var step = 0; step < 5 && !inclusionFocus().hasFocus; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(inclusionFocus().hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Excluded'), findsOneWidget);
    for (final width in <double>[600, 1023, 1024, 599]) {
      await tester.pumpWidget(_app(width: width, rows: [_rows().first]));
      expect(find.text('Excluded'), findsOneWidget);
      expect(
        inclusionFocus().hasFocus,
        isTrue,
        reason: 'Focus at width $width',
      );
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('Included'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'supports RTL, long labels, 200 percent text and high contrast boundaries',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final rows = <BeautifulDiffRow>[
        BeautifulDiffRow(
          id: 'localized',
          before: {
            'name': 'مراجعة المخزون والتحقق من كل المعلومات السابقة 非常长的数据记录',
          },
          after: {
            'name': 'معلومات جديدة تتطلب مراجعة دقيقة قبل تطبيق التغييرات 数据更新',
          },
        ),
      ];
      for (final width in <double>[320, 599, 600, 1023, 1024]) {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            beautifulTestApp(
              size: Size(width, 1600),
              brightness: brightness,
              textScaler: const TextScaler.linear(2),
              textDirection: TextDirection.rtl,
              highContrast: true,
              disableAnimations: true,
              child: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: BeautifulDiffTable(
                    id: 'localized',
                    title: 'مقترح التغييرات على السجلات الحالية',
                    columns: const [
                      BeautifulDiffColumn(
                        id: 'name',
                        label: 'العنوان الكامل للسجل الذي نراجعه',
                      ),
                    ],
                    rows: rows,
                    labels: const BeautifulDiffTableLabels(
                      before: 'القيم السابقة في السجلات',
                      after: 'القيم المقترحة بعد التعديلات',
                      included: 'تم تضمين هذه التغييرات في الاختيار',
                      excluded: 'تم استبعاد هذه التغييرات من الاختيار',
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$width $brightness');
        }
      }
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('48dp labeled controls meet touch guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(rows: [_rows().first], onApply: (_) async {}));
    expect(
      tester.getSize(_key('include-remove')).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.getSize(_key('apply')).height, greaterThanOrEqualTo(48));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('empty and unselected proposals disable application honestly', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        rows: [],
        onApply: (_) async {
          calls++;
        },
      ),
    );
    expect(find.text('No records to compare'), findsOneWidget);
    await _tap(tester, 'apply');
    expect(calls, 0);
    await tester.pumpWidget(
      _app(
        id: 'next',
        initial: {},
        onApply: (_) async {
          calls++;
        },
        errorMessage: 'Host review error',
      ),
    );
    expect(find.text('Apply changes (0)'), findsOneWidget);
    expect(find.text('Host review error'), findsOneWidget);
    await _tap(tester, 'apply');
    expect(calls, 0);
  });

  testWidgets('duplicate row and column IDs report contract errors', (
    tester,
  ) async {
    final row = _rows().first;
    await tester.pumpWidget(_app(rows: [row, row]));
    expect(
      tester.takeException().toString(),
      contains('unique, non-empty row ids'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(columns: [_columns.first, _columns.first]));
    expect(tester.takeException().toString(), contains('non-empty column ids'));
  });
}
