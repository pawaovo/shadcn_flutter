import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

List<BeautifulRecordColumn> _columns({
  String prompt = 'Find competitors',
  bool hideable = true,
}) => <BeautifulRecordColumn>[
  BeautifulRecordColumn(
    id: 'score',
    label: 'Score',
    property: BeautifulRecordPropertyConfig(
      type: BeautifulRecordPropertyType.singleSelect,
    ),
    summary: 'Host summary',
  ),
  BeautifulRecordColumn(
    id: 'category',
    label: 'Categories',
    property: BeautifulRecordPropertyConfig(
      type: BeautifulRecordPropertyType.multiSelect,
    ),
  ),
  BeautifulRecordColumn(
    id: 'ai',
    label: 'Competitors',
    hideable: hideable,
    property: BeautifulRecordPropertyConfig(
      toolId: 'search',
      prompt: prompt,
      inputColumnIds: <String>['category'],
    ),
  ),
];

List<BeautifulRecordRow> _rows() => <BeautifulRecordRow>[
  BeautifulRecordRow(
    id: 'beta',
    label: 'Beta company',
    cells: <String, BeautifulRecordCell>{
      'score': BeautifulRecordCell(text: 'Ten', number: 10),
      'category': BeautifulRecordCell(
        text: 'Wholesale',
        tags: <String>['Wholesale', 'Local'],
      ),
      'ai': BeautifulRecordCell(
        text: 'Beta link',
        uri: Uri.parse('https://example.com/beta'),
      ),
    },
  ),
  BeautifulRecordRow(
    id: 'alpha',
    label: 'Alpha company',
    cells: <String, BeautifulRecordCell>{
      'score': BeautifulRecordCell(text: 'Two', number: 2),
      'category': BeautifulRecordCell(text: 'Cafe'),
      'ai': BeautifulRecordCell(text: 'Host competitor'),
    },
  ),
  BeautifulRecordRow(
    id: 'gamma',
    label: 'Gamma company',
    cells: <String, BeautifulRecordCell>{
      'category': BeautifulRecordCell(text: 'Cafe'),
    },
  ),
];

Finder _key(String key) => find.byKey(ValueKey<String>(key));
Finder _entry(String label) => find
    .descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == label,
      ),
      matching: find.byType(EditableText),
    )
    .first;

Widget _app({
  String id = 'companies',
  double width = 390,
  double viewportHeight = 340,
  List<BeautifulRecordRow>? rows,
  List<BeautifulRecordColumn>? columns,
  Set<String> selected = const <String>{},
  BeautifulRecordSort? sort,
  String query = '',
  ValueChanged<Set<String>>? onSelectionChanged,
  FutureOr<void> Function(String, BeautifulRecordPropertyConfig)?
  onPropertyChanged,
  FutureOr<void> Function(BeautifulRecordPropertyDraft)? onPropertyAdded,
  FutureOr<void> Function(BeautifulRecordRunRequest)? onRun,
  FutureOr<void> Function(
    BeautifulRecordRow,
    BeautifulRecordColumn,
    BeautifulRecordCell,
  )?
  onCellActivated,
  BeautifulUiFailureHandler? onFailure,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => Overlay.wrap(
    child: beautifulTestApp(
      size: Size(width, 1200),
      textScaler: textScaler,
      textDirection: direction,
      brightness: brightness,
      highContrast: highContrast,
      disableAnimations: true,
      child: BeautifulUiScope(
        onFailure: onFailure,
        child: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: BeautifulRecordsTable(
              id: id,
              rows: rows ?? _rows(),
              columns: columns ?? _columns(),
              height: viewportHeight,
              tools: const <BeautifulRecordTool>[
                BeautifulRecordTool(id: 'search', label: 'Web search'),
                BeautifulRecordTool(id: 'model', label: 'Host model'),
              ],
              initialSelectedIds: selected,
              initialSort: sort,
              initialQuery: query,
              onSelectionChanged: onSelectionChanged,
              onPropertyChanged: onPropertyChanged,
              onPropertyAdded: onPropertyAdded,
              onRun: onRun,
              onCellActivated: onCellActivated,
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pump();
}

Future<void> _configure(WidgetTester tester, String id) async {
  await _tap(tester, 'records-properties');
  await _tap(tester, 'records-config-$id');
}

void main() {
  test(
    'model collections are immutable and invalid configurations are rejected',
    () {
      final inputs = <String>['source'];
      final config = BeautifulRecordPropertyConfig(inputColumnIds: inputs);
      inputs.clear();
      expect(config.inputColumnIds, <String>['source']);
      expect(() => config.inputColumnIds.clear(), throwsUnsupportedError);
      final tags = <String>['Local'];
      final cell = BeautifulRecordCell(text: 'value', tags: tags);
      tags.clear();
      expect(cell.tags, <String>['Local']);
      expect(
        () => BeautifulRecordCell(text: 'NaN', number: double.nan),
        throwsArgumentError,
      );
      expect(
        () => BeautifulRecordPropertyConfig(
          inputColumnIds: <String>['same', 'same'],
        ),
        throwsArgumentError,
      );
      expect(
        () => BeautifulRecordColumn(id: 'column', label: 'Name', width: 12),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'search, selection and select-all operate on matching stable IDs',
    (tester) async {
      final changes = <Set<String>>[];
      await tester.pumpWidget(_app(onSelectionChanged: changes.add));
      final semantics = tester.ensureSemantics();
      tester.semantics.tap(find.semantics.byLabel('Select: Beta company'));
      await tester.pump();
      await tester.enterText(_entry('Search records'), 'Cafe');
      await tester.pump();
      expect(find.text('Beta company'), findsNothing);
      expect(find.textContaining('Matching records: 2 / 3'), findsOneWidget);
      tester.semantics.tap(find.semantics.byLabel('Select matching records'));
      await tester.pump();
      expect(changes.last, <String>{'beta', 'alpha', 'gamma'});
      tester.semantics.tap(find.semantics.byLabel('Select matching records'));
      await tester.pump();
      expect(changes.last, <String>{'beta'});
      await tester.enterText(_entry('Search records'), 'no match');
      await tester.pump();
      expect(find.text('No matching records'), findsOneWidget);
      expect(changes.last, <String>{'beta'});
      semantics.dispose();
    },
  );

  testWidgets(
    'sort uses typed numbers and leaves missing values last in either direction',
    (tester) async {
      await tester.pumpWidget(_app(viewportHeight: 700));
      await _tap(tester, 'records-properties');
      await _tap(tester, 'records-sort-score');
      List<String> order() => tester
          .widgetList<Semantics>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.key is ValueKey<String> &&
                  (widget.key! as ValueKey<String>).value.startsWith(
                    'records-row-',
                  ),
            ),
          )
          .map((widget) => (widget.key! as ValueKey<String>).value)
          .toList();
      expect(order(), <String>[
        'records-row-alpha',
        'records-row-beta',
        'records-row-gamma',
      ]);
      await _tap(tester, 'records-sort-score');
      expect(order(), <String>[
        'records-row-beta',
        'records-row-alpha',
        'records-row-gamma',
      ]);
    },
  );

  testWidgets(
    'detail exposes all values, host link action, and host running/error states',
    (tester) async {
      final rows = _rows();
      rows[0] = BeautifulRecordRow(
        id: 'beta',
        label: 'Beta company',
        cells: <String, BeautifulRecordCell>{
          ...rows[0].cells,
          'score': BeautifulRecordCell(
            text: '',
            status: BeautifulRecordCellStatus.running,
          ),
          'category': BeautifulRecordCell(
            text: '',
            status: BeautifulRecordCellStatus.failed,
            error: 'Source unavailable',
          ),
        },
      );
      Uri? opened;
      await tester.pumpWidget(
        _app(
          rows: rows,
          onCellActivated: (_, _, cell) {
            opened = cell.uri;
          },
        ),
      );
      expect(find.text('Score: Calculating'), findsOneWidget);
      expect(
        find.text('Categories: Calculation failed: Source unavailable'),
        findsOneWidget,
      );
      await _tap(tester, 'records-detail-beta');
      await _tap(tester, 'records-cell-action-beta-ai');
      expect(opened, Uri.parse('https://example.com/beta'));
      expect(find.text('Request completed'), findsOneWidget);
    },
  );

  testWidgets(
    'complete property proposals preserve config, inputs, prompt and advanced settings',
    (tester) async {
      BeautifulRecordPropertyConfig? saved;
      await tester.pumpWidget(
        _app(
          onPropertyChanged: (id, config) {
            expect(id, 'ai');
            saved = config;
          },
        ),
      );
      await _configure(tester, 'ai');
      await _tap(tester, 'records-type-json');
      await _tap(tester, 'records-tool-model');
      await _tap(tester, 'records-grounding');
      await _tap(tester, 'records-input-score');
      await tester.ensureVisible(_entry('Calculation prompt'));
      await tester.enterText(
        _entry('Calculation prompt'),
        'Research @category and @score',
      );
      await _tap(tester, 'records-more-settings');
      await _tap(tester, 'records-required');
      await _tap(tester, 'records-allow-empty');
      await _tap(tester, 'records-confidence');
      await _tap(tester, 'records-save');
      expect(saved!.type, BeautifulRecordPropertyType.json);
      expect(saved!.toolId, 'model');
      expect(saved!.grounding, isTrue);
      expect(saved!.inputColumnIds, <String>['category', 'score']);
      expect(saved!.prompt, 'Research @category and @score');
      expect(saved!.requiredValue, isTrue);
      expect(saved!.allowEmpty, isFalse);
      expect(saved!.showConfidence, isTrue);
      await _tap(tester, 'records-close-editor');
      await _tap(tester, 'records-config-ai');
      expect(
        tester
            .widget<EditableText>(_entry('Calculation prompt'))
            .controller
            .text,
        'Find competitors',
        reason: 'Accepted host settings remain authoritative.',
      );
    },
  );

  testWidgets('add property validates name and only submits a proposal', (
    tester,
  ) async {
    BeautifulRecordPropertyDraft? proposal;
    await tester.pumpWidget(
      _app(
        onPropertyAdded: (draft) {
          proposal = draft;
        },
      ),
    );
    await _tap(tester, 'records-add');
    await _tap(tester, 'records-save');
    expect(find.text('Enter a property name'), findsOneWidget);
    await tester.ensureVisible(_entry('Property name'));
    await tester.enterText(_entry('Property name'), 'New research');
    await _tap(tester, 'records-type-file');
    await _tap(tester, 'records-save');
    expect(proposal!.label, 'New research');
    expect(proposal!.property.type, BeautifulRecordPropertyType.file);
    await _tap(tester, 'records-close-editor');
    await _tap(tester, 'records-properties');
    expect(_key('records-config-New research'), findsNothing);
  });

  testWidgets(
    'calculate sends filtered sort order and de-duplicates until completion',
    (tester) async {
      final complete = Completer<void>();
      final requests = <BeautifulRecordRunRequest>[];
      await tester.pumpWidget(
        _app(
          query: 'Cafe',
          sort: const BeautifulRecordSort(columnId: 'score'),
          selected: <String>{'beta'},
          onRun: (request) {
            requests.add(request);
            return complete.future;
          },
        ),
      );
      await _configure(tester, 'ai');
      await _tap(tester, 'records-run');
      await _tap(tester, 'records-run');
      expect(requests, hasLength(1));
      expect(requests.single.rowIds, <String>['alpha', 'gamma']);
      expect(requests.single.property.prompt, 'Find competitors');
      expect(find.text('Working'), findsOneWidget);
      complete.complete();
      await tester.pump();
      expect(find.text('Request completed'), findsOneWidget);
      expect(
        find.text('Calculating'),
        findsNothing,
        reason: 'Only the host can set cell lifecycle.',
      );
    },
  );

  testWidgets(
    'equal config rebuild keeps pending request while changed config invalidates it',
    (tester) async {
      final complete = Completer<void>();
      var calls = 0;
      Widget app({String prompt = 'Find competitors'}) => _app(
        columns: _columns(prompt: prompt),
        onRun: (_) {
          calls++;
          return complete.future;
        },
      );
      await tester.pumpWidget(app());
      await _configure(tester, 'ai');
      await _tap(tester, 'records-run');
      await tester.pumpWidget(app());
      await _tap(tester, 'records-run');
      expect(
        calls,
        1,
        reason: 'Recreated equal config and callback closure must not unlock an existing request.',
      );
      await tester.pumpWidget(app(prompt: 'Replacement accepted prompt'));
      expect(
        tester
            .widget<EditableText>(_entry('Calculation prompt'))
            .controller
            .text,
        'Replacement accepted prompt',
      );
      complete.complete();
      await tester.pump();
      expect(find.text('Request completed'), findsNothing);
      expect(find.text('Working'), findsNothing);
    },
  );

  testWidgets(
    'table replacement isolates delayed errors and resets seeded view state',
    (tester) async {
      final complete = Completer<void>();
      final failures = <BeautifulUiFailure>[];
      await tester.pumpWidget(
        _app(
          onRun: (_) => complete.future,
          onFailure: failures.add,
          selected: <String>{'beta'},
        ),
      );
      await _configure(tester, 'ai');
      await _tap(tester, 'records-run');
      await tester.pumpWidget(
        _app(
          id: 'replacement',
          query: 'Alpha',
          onRun: (_) {},
          onFailure: failures.add,
        ),
      );
      complete.completeError(StateError('old request'));
      await tester.pump();
      expect(failures, isEmpty);
      expect(find.text('Action failed. Try again.'), findsNothing);
      expect(find.textContaining('Matching records: 1 / 3'), findsOneWidget);
      expect(_key('records-close-editor'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'current action failure reports records operation and permits retry',
    (tester) async {
      var calls = 0;
      final failures = <BeautifulUiFailure>[];
      await tester.pumpWidget(
        _app(
          onRun: (_) {
            calls++;
            throw StateError('host failed');
          },
          onFailure: failures.add,
        ),
      );
      await _configure(tester, 'ai');
      await _tap(tester, 'records-run');
      expect(failures.single.operation, BeautifulUiOperation.records);
      expect(find.text('Action failed. Try again.'), findsOneWidget);
      await _tap(tester, 'records-run');
      expect(calls, 2);
    },
  );

  testWidgets(
    'pin, hide, restore and width controls are reversible local presentation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_app(width: 1100));
      await _configure(tester, 'ai');
      await _tap(tester, 'records-pin');
      await _tap(tester, 'records-widen');
      await _tap(tester, 'records-hide');
      await _tap(tester, 'records-close-editor');
      expect(_key('records-header-ai'), findsNothing);
      await _tap(tester, 'records-show-ai');
      expect(_key('records-header-ai'), findsOneWidget);
      final headerX = tester.getTopLeft(_key('records-header-ai')).dx;
      expect(
        headerX,
        lessThan(tester.getTopLeft(_key('records-header-score')).dx),
      );
      final widened = tester.getSize(_key('records-header-ai')).width;
      expect(widened, 244);
      await _tap(tester, 'records-compact-columns');
      expect(tester.getSize(_key('records-header-ai')).width, 160);
      await _tap(tester, 'records-reset-widths');
      expect(tester.getSize(_key('records-header-ai')).width, 220);
    },
  );

  testWidgets(
    '1000 records are realized lazily and sorting reaches the correct last record',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final rows = List<BeautifulRecordRow>.generate(
        1000,
        (index) => BeautifulRecordRow(
          id: 'r$index',
          label: 'Record $index',
          cells: <String, BeautifulRecordCell>{
            'score': BeautifulRecordCell(text: 'Score $index', number: index),
          },
        ),
      );
      final watch = Stopwatch()..start();
      await tester.pumpWidget(_app(width: 1100, rows: rows));
      final elapsed = watch.elapsedMicroseconds;
      final realized = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('records-row-'),
      );
      expect(realized.evaluate().length, lessThan(30));
      expect(_key('records-row-r999'), findsNothing);
      await _tap(tester, 'records-sort-score');
      await _tap(tester, 'records-sort-score');
      expect(_key('records-row-r999'), findsOneWidget);
      expect(realized.evaluate().length, lessThan(30));
      final list = tester.widget<CustomScrollView>(_key('records-list'));
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pump();
      expect(_key('records-row-r0'), findsOneWidget);
      expect(realized.evaluate().length, lessThan(30));
      // Recorded as diagnostic evidence only; correctness does not depend on CI timing.
      debugPrint(
        'Records Table 1000 rows: first build ${elapsed}us; realized ${realized.evaluate().length}.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resize preserves query, selection, draft and vertical scroll controller',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final rows = List<BeautifulRecordRow>.generate(
        100,
        (index) => BeautifulRecordRow(
          id: 'r$index',
          label: 'Record $index',
          cells: <String, BeautifulRecordCell>{
            'score': BeautifulRecordCell(text: '$index', number: index),
          },
        ),
      );
      await tester.pumpWidget(
        _app(width: 1024, rows: rows, selected: <String>{'r0'}, onRun: (_) {}),
      );
      final controller = tester
          .widget<CustomScrollView>(_key('records-list'))
          .controller!;
      controller.jumpTo(200);
      await tester.pump();
      await _configure(tester, 'ai');
      await tester.ensureVisible(_entry('Calculation prompt'));
      await tester.enterText(
        _entry('Calculation prompt'),
        'Draft survives resize',
      );
      for (final width in <double>[599, 600, 1023, 1024]) {
        await tester.pumpWidget(
          _app(
            width: width,
            rows: rows,
            query: 'ignored new seed',
            onRun: (_) {},
          ),
        );
        expect(
          tester.widget<CustomScrollView>(_key('records-list')).controller,
          same(controller),
        );
        expect(controller.offset, 200);
        expect(
          tester
              .widget<EditableText>(_entry('Calculation prompt'))
              .controller
              .text,
          'Draft survives resize',
        );
        expect(find.textContaining('Selected: 1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_key('records-close-editor'), findsNothing);
    },
  );

  testWidgets(
    'long RTL 200 percent controls and row details remain usable at all boundaries',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final rows = <BeautifulRecordRow>[
        BeautifulRecordRow(
          id: 'long',
          label: 'مراجعة جميع السجلات والبيانات الطويلة 这是中文长标题',
          cells: <String, BeautifulRecordCell>{
            'score': BeautifulRecordCell(
              text: 'نتيجة طويلة جدا تصف حالة الحساب والبيانات بشكل كامل',
            ),
          },
        ),
      ];
      for (final width in <double>[320, 599, 600, 1023, 1024]) {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            _app(
              width: width,
              rows: rows,
              direction: TextDirection.rtl,
              textScaler: const TextScaler.linear(2),
              brightness: brightness,
              highContrast: true,
              onRun: (_) {},
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$width $brightness');
        }
      }
      await _configure(tester, 'ai');
      await _tap(tester, 'records-more-settings');
      await _tap(tester, 'records-run');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('checkbox is keyboard accessible and meets 48dp target gates', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pump();
    final selectAll = find.bySemanticsLabel('Select matching records');
    final focusable = find
        .descendant(
          of: selectAll,
          matching: find.byType(FocusableActionDetector),
        )
        .first;
    final focus = tester.widget<FocusableActionDetector>(focusable);
    focus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.textContaining('Selected: 3'), findsOneWidget);
    expect(focus.enabled, isTrue);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
  testWidgets(
    'removed input columns are pruned from active drafts before save and run',
    (tester) async {
      final proposals = <BeautifulRecordPropertyConfig>[];
      Widget app(List<BeautifulRecordColumn> columns) => _app(
        columns: columns,
        onPropertyChanged: (_, property) {
          proposals.add(property);
        },
        onRun: (request) {
          proposals.add(request.property);
        },
      );
      await tester.pumpWidget(app(_columns()));
      await _configure(tester, 'ai');
      await _tap(tester, 'records-input-score');
      await tester.pumpWidget(
        app(_columns().where((column) => column.id != 'category').toList()),
      );
      expect(_key('records-input-category'), findsNothing);
      await _tap(tester, 'records-save');
      await _tap(tester, 'records-run');
      expect(proposals, hasLength(2));
      expect(
        proposals.every(
          (property) =>
              property.inputColumnIds.length == 1 &&
              property.inputColumnIds.single == 'score',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing and reopening the same property cannot duplicate pending requests',
    (tester) async {
      final complete = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        _app(
          onRun: (_) {
            calls++;
            return complete.future;
          },
        ),
      );
      await _configure(tester, 'ai');
      await _tap(tester, 'records-run');
      await _tap(tester, 'records-close-editor');
      await _tap(tester, 'records-config-ai');
      await _tap(tester, 'records-run');
      expect(calls, 1);
      complete.complete();
      await tester.pump();
      expect(find.text('Request completed'), findsOneWidget);
    },
  );

  testWidgets(
    'equal rows retain pending work but changed records release old callbacks',
    (tester) async {
      final old = Completer<void>();
      final current = Completer<void>();
      final failures = <BeautifulUiFailure>[];
      var calls = 0;
      Widget app(List<BeautifulRecordRow> rows) => _app(
        rows: rows,
        onFailure: failures.add,
        onRun: (_) {
          calls++;
          return calls == 1 ? old.future : current.future;
        },
      );
      await tester.pumpWidget(app(_rows()));
      await _configure(tester, 'ai');
      await _tap(tester, 'records-run');
      await tester.pumpWidget(app(_rows()));
      await _tap(tester, 'records-run');
      expect(calls, 1);
      await tester.pumpWidget(app(<BeautifulRecordRow>[_rows().last]));
      await _tap(tester, 'records-run');
      expect(calls, 2);
      old.completeError(StateError('obsolete rows'));
      await tester.pump();
      expect(failures, isEmpty);
      expect(find.text('Working'), findsOneWidget);
      current.complete();
      await tester.pump();
      expect(find.text('Request completed'), findsOneWidget);
    },
  );

  testWidgets('hidden properties stay hidden in record detail', (tester) async {
    await tester.pumpWidget(_app(onRun: (_) {}));
    await _configure(tester, 'ai');
    await _tap(tester, 'records-hide');
    await _tap(tester, 'records-close-editor');
    await _tap(tester, 'records-detail-alpha');
    expect(find.text('Competitors: Host competitor'), findsNothing);
    expect(find.text('Score: Two'), findsWidgets);
  });

  testWidgets('focused record action survives layout and text-scale changes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_app(width: 1100));
    final control = _key('records-detail-beta');
    final gesture = find
        .descendant(of: control, matching: find.byType(GestureDetector))
        .last;
    final focus = Focus.of(tester.element(gesture));
    focus.requestFocus();
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(focus));
    await tester.pumpWidget(_app(width: 599));
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(focus));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Details: Beta company'), findsOneWidget);
    await tester.pumpWidget(
      _app(width: 1100, textScaler: const TextScaler.linear(2)),
    );
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, same(focus));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Details: Beta company'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'column resizing supports pointer drag and directional keyboard input',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(width: 1100));
      final handle = find.bySemanticsLabel('Resize column: Score');
      await tester.drag(handle, const Offset(50, 0));
      await tester.pump();
      expect(tester.getSize(_key('records-header-score')).width, 270);
      final gesture = find
          .descendant(of: handle, matching: find.byType(GestureDetector))
          .last;
      Focus.of(tester.element(gesture)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(tester.getSize(_key('records-header-score')).width, 294);
      semantics.dispose();
    },
  );

  testWidgets(
    'touch prompt selection copies through the shared clipboard menu',
    (tester) async {
      var clipboard = '';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, String>{'text': clipboard};
        }
        if (call.method == 'Clipboard.hasStrings') {
          return <String, bool>{'value': clipboard.isNotEmpty};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        _app(
          columns: _columns(prompt: 'Research'),
          onRun: (_) {},
        ),
      );
      await _configure(tester, 'ai');
      final prompt = _entry('Calculation prompt');
      await tester.ensureVisible(prompt);
      await tester.longPressAt(
        tester.getTopLeft(prompt) + const Offset(10, 10),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, 'Research');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delayed native paste cannot modify a replacement property editor',
    (tester) async {
      final paste = Completer<Object?>();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return paste.future;
        if (call.method == 'Clipboard.hasStrings') {
          return <String, bool>{'value': true};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(_app(onRun: (_) {}));
      await _configure(tester, 'ai');
      final prompt = _entry('Calculation prompt');
      final editable = tester.widget<EditableText>(prompt);
      editable.focusNode.requestFocus();
      editable.controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: editable.controller.text.length,
      );
      await tester.pump();
      final semantics = tester.ensureSemantics();
      final editorLabel = find.bySemanticsLabel('Calculation prompt').last;
      final node = tester.getSemantics(editorLabel);
      node.owner!.performAction(node.id, SemanticsAction.paste);
      await tester.pump();
      await tester.pumpWidget(
        _app(
          columns: _columns(prompt: 'Accepted replacement'),
          onRun: (_) {},
        ),
      );
      paste.complete(<String, String>{'text': 'Obsolete clipboard'});
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(_entry('Calculation prompt'))
            .controller
            .text,
        'Accepted replacement',
      );
      semantics.dispose();
    },
  );
  testWidgets(
    'normal host output progress does not release a pending calculation',
    (tester) async {
      final complete = Completer<void>();
      var calls = 0;
      Widget app(BeautifulRecordCellStatus status) {
        final rows = _rows()
            .map(
              (row) => BeautifulRecordRow(
                id: row.id,
                label: row.label,
                cells: <String, BeautifulRecordCell>{
                  ...row.cells,
                  'ai': BeautifulRecordCell(
                    text: status == BeautifulRecordCellStatus.ready
                        ? 'Current result'
                        : '',
                    status: status,
                  ),
                },
              ),
            )
            .toList();
        return _app(
          rows: rows,
          onRun: (_) {
            calls++;
            return complete.future;
          },
        );
      }

      await tester.pumpWidget(app(BeautifulRecordCellStatus.ready));
      await _configure(tester, 'ai');
      await _tap(tester, 'records-run');
      await tester.pumpWidget(app(BeautifulRecordCellStatus.running));
      await _tap(tester, 'records-run');
      await tester.pumpWidget(app(BeautifulRecordCellStatus.ready));
      await _tap(tester, 'records-run');
      expect(calls, 1);
      expect(find.text('Working'), findsOneWidget);
      complete.complete();
      await tester.pump();
      expect(find.text('Request completed'), findsOneWidget);
    },
  );
}
