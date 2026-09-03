import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

Widget _app({double width = 390}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (_, _) => Overlay.wrap(
    child: beautifulTestApp(
      size: Size(width, 1200),
      disableAnimations: true,
      child: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: BeautifulRecordsTable(
            id: 'semantics',
            height: 400,
            columns: <BeautifulRecordColumn>[
              BeautifulRecordColumn(id: 'category', label: 'Categories'),
              BeautifulRecordColumn(id: 'ai', label: 'Research'),
            ],
            rows: <BeautifulRecordRow>[
              BeautifulRecordRow(
                id: 'first',
                label: 'Full company name without truncation',
                cells: <String, BeautifulRecordCell>{
                  'category': BeautifulRecordCell(
                    text: 'Cafe',
                    tags: <String>['Cafe', 'Local', 'Wholesale'],
                  ),
                  'ai': BeautifulRecordCell(
                    text: '',
                    status: BeautifulRecordCellStatus.running,
                  ),
                },
              ),
              BeautifulRecordRow(
                id: 'second',
                label: 'Other company',
                cells: <String, BeautifulRecordCell>{
                  'category': BeautifulRecordCell(text: 'Manufacturer'),
                },
              ),
            ],
            onPropertyChanged: (_, _) {},
            onPropertyAdded: (_) {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'empty native editors expose enabled editable textbox semantics',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());

      Future<void> expectEditable(String label, String replacement) async {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label).last)
            .getSemanticsData();
        expect(data.flagsCollection.isTextField, isTrue);
        expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
        expect(data.flagsCollection.isReadOnly, isFalse);
        expect(data.value, isEmpty);
        final input = find.descendant(
          of: find.bySemanticsLabel(label).last,
          matching: find.byType(EditableText),
        );
        tester.widget<EditableText>(input).focusNode.requestFocus();
        await tester.pump();
        final focused = tester.getSemantics(find.bySemanticsLabel(label).last);
        expect(
          focused.getSemanticsData().hasAction(SemanticsAction.setText),
          isTrue,
        );
        focused.owner!.performAction(
          focused.id,
          SemanticsAction.setText,
          replacement,
        );
        await tester.pump();
        expect(
          tester
              .getSemantics(find.bySemanticsLabel(label).last)
              .getSemanticsData()
              .value,
          replacement,
        );
      }

      await expectEditable('Search records', 'Cafe');
      await tester.tap(
        find.byKey(const ValueKey<String>('records-properties')),
      );
      await tester.pump();
      final property = find.byKey(const ValueKey<String>('records-config-ai'));
      await tester.ensureVisible(property);
      await tester.tap(property);
      await tester.pump();
      final prompt = find.bySemanticsLabel('Calculation prompt').last;
      await tester.ensureVisible(prompt);
      await tester.pump();
      await expectEditable('Calculation prompt', 'Research this record');

      final close = find.byKey(const ValueKey<String>('records-close-editor'));
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pump();
      final add = find.byKey(const ValueKey<String>('records-add'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      final name = find.bySemanticsLabel('Property name').last;
      await tester.ensureVisible(name);
      await tester.pump();
      await expectEditable('Property name', 'New property');
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  testWidgets(
    'compact list exposes complete labels, checked state and live counts',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Records'))
            .getSemanticsData()
            .role,
        SemanticsRole.list,
      );
      final row = tester
          .getSemantics(find.byKey(const ValueKey<String>('records-row-first')))
          .getSemanticsData();
      expect(row.role, SemanticsRole.listItem);
      expect(row.label, 'Full company name without truncation');
      expect(
        find.bySemanticsLabel('Categories: Cafe, Local, Wholesale'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Research: Calculating'), findsOneWidget);
      final selection = find.bySemanticsLabel(
        'Select: Full company name without truncation',
      );
      expect(
        tester
            .getSemantics(selection)
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        ui.CheckedState.isFalse,
      );
      tester.semantics.tap(
        find.semantics.byLabel('Select: Full company name without truncation'),
      );
      await tester.pump();
      expect(
        tester
            .getSemantics(selection)
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        ui.CheckedState.isTrue,
      );
      final count = tester
          .getSemantics(
            find.bySemanticsLabel('Matching records: 2 / 2. Selected: 1'),
          )
          .getSemanticsData();
      expect(count.flagsCollection.isLiveRegion, isTrue);
      expect(tester.takeException(), isNull);
      handle.dispose();
    },
  );

  testWidgets('expanded native table has valid table-row-cell parent roles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(width: 1100));
    final table = tester.getSemantics(find.bySemanticsLabel('Records'));
    expect(table.getSemanticsData().role, SemanticsRole.table);
    final row = tester.getSemantics(
      find.byKey(const ValueKey<String>('records-row-first')),
    );
    expect(row.getSemanticsData().role, SemanticsRole.row);
    expect(row.parent, same(table));
    final cell = tester.getSemantics(
      find.bySemanticsLabel('Categories: Cafe, Local, Wholesale'),
    );
    expect(cell.getSemanticsData().role, SemanticsRole.cell);
    expect(cell.parent, same(row));
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Categories'))
          .getSemanticsData()
          .role,
      SemanticsRole.columnHeader,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets(
    'select-all reports mixed state and accessible sort/resize remain actionable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(width: 1100));
      tester.semantics.tap(find.semantics.byLabel('Select: Other company'));
      await tester.pump();
      final all = tester
          .getSemantics(find.bySemanticsLabel('Select matching records'))
          .getSemanticsData();
      expect(all.flagsCollection.isChecked, ui.CheckedState.mixed);
      final resize = tester
          .getSemantics(find.bySemanticsLabel('Resize column: Categories'))
          .getSemanticsData();
      expect(resize.flagsCollection.isSlider, isTrue);
      expect(resize.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(resize.hasAction(SemanticsAction.increase), isTrue);
      expect(resize.hasAction(SemanticsAction.decrease), isTrue);
      expect(resize.value, '220');
      tester.semantics.increase(
        find.semantics.byLabel('Resize column: Categories'),
      );
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Resize column: Categories'))
            .getSemanticsData()
            .value,
        '244',
      );
      tester.semantics.decrease(
        find.semantics.byLabel('Resize column: Categories'),
      );
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Resize column: Categories'))
            .getSemanticsData()
            .value,
        '220',
      );
      tester.semantics.tap(
        find.semantics.byLabel('Sort: Categories. Ascending'),
      );
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Sort: Categories. Ascending'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      handle.dispose();
    },
  );
}
