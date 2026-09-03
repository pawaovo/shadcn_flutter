import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

Finder _key(String key) => find.byKey(ValueKey<String>(key));

List<BeautifulRecordColumn> _columns() => List.generate(
  20,
  (index) => BeautifulRecordColumn(
    id: 'c$index',
    label: 'Property $index',
    width: 180,
  ),
);

List<BeautifulRecordRow> _rows() => List.generate(
  1000,
  (row) => BeautifulRecordRow(
    id: 'r$row',
    label: 'Record ${row.toString().padLeft(4, '0')}',
    cells: <String, BeautifulRecordCell>{
      for (var column = 0; column < 20; column++)
        'c$column': BeautifulRecordCell(
          text: 'r$row.c$column',
          number: row * 20 + column,
        ),
    },
  ),
);

Widget _app({
  required List<BeautifulRecordRow> rows,
  required List<BeautifulRecordColumn> columns,
  String id = 'records-rebuild',
  double width = 1200,
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
  BeautifulRecordsTableLabels labels = const BeautifulRecordsTableLabels(),
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (_, _) => Overlay.wrap(
    child: beautifulTestApp(
      size: Size(width, 1000),
      textDirection: direction,
      brightness: brightness,
      disableAnimations: true,
      child: SingleChildScrollView(
        child: BeautifulRecordsTable(
          id: id,
          columns: columns,
          rows: rows,
          height: 400,
          labels: labels,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('unchanged order retains rows and unaffected property headers', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final rows = _rows();
    final columns = _columns();
    await tester.pumpWidget(_app(rows: rows, columns: columns));
    final originalRow = tester.element(_key('records-row-r0'));
    final originalCell = tester.renderObject<RenderParagraph>(
      find.text('r0.c1'),
    );
    final unaffectedHeader = tester.widget(_key('records-header-c1'));

    await tester.tap(_key('records-sort-c0'));
    await tester.pump();
    expect(tester.element(_key('records-row-r0')), same(originalRow));
    expect(
      tester.renderObject<RenderParagraph>(find.text('r0.c1')),
      same(originalCell),
    );
    expect(tester.widget(_key('records-header-c1')), same(unaffectedHeader));

    await tester.tap(_key('records-sort-c0'));
    await tester.pump();
    expect(_key('records-row-r999'), findsOneWidget);
    expect(_key('records-row-r0'), findsNothing);
    expect(tester.widget(_key('records-header-c1')), same(unaffectedHeader));
    final realized = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('records-row-'),
    );
    expect(realized.evaluate().length, lessThan(40));
    final vertical = tester
        .widget<CustomScrollView>(_key('records-list'))
        .controller!;
    vertical.jumpTo(vertical.position.maxScrollExtent);
    await tester.pump();
    expect(_key('records-row-r0'), findsOneWidget);
    expect(realized.evaluate().length, lessThan(40));

    // A query with unchanged membership still restarts the row viewport.
    await tester.enterText(find.byType(EditableText), 'Record');
    await tester.pump();
    expect(vertical.offset, 0);
    expect(_key('records-row-r999'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    tester.semantics.tap(find.semantics.byLabel('Select: Record 0999'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'Record 0999');
    await tester.pump();
    expect(_key('records-row-r998'), findsNothing);
    await tester.enterText(find.byType(EditableText), '');
    await tester.pump();
    expect(
      tester.widget<Semantics>(_key('records-row-r999')).properties.selected,
      isTrue,
    );
    expect(tester.widget(_key('records-header-c1')), same(unaffectedHeader));
    semantics.dispose();

    await tester.pumpWidget(
      _app(rows: rows, columns: columns, id: 'new-table'),
    );
    await tester.pump();
    expect(_key('records-row-r0'), findsOneWidget);
    expect(
      tester.widget(_key('records-header-c1')),
      isNot(same(unaffectedHeader)),
    );
    expect(
      tester.widget<Semantics>(_key('records-row-r0')).properties.selected,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reuse refreshes host content, labels, column settings and theme',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final rows = _rows();
      final columns = _columns();
      await tester.pumpWidget(_app(rows: rows, columns: columns));
      final originalRow = tester.element(_key('records-row-r0'));
      final originalHeader = tester.widget(_key('records-header-c1'));
      final originalColor = tester
          .renderObject<RenderParagraph>(find.text('r0.c1'))
          .text
          .style!
          .color;
      final originalHeaderColor = tester
          .renderObject<RenderParagraph>(find.text('Property 1'))
          .text
          .style!
          .color;

      // Reused widgets still receive inherited theme and direction changes.
      await tester.pumpWidget(
        _app(
          rows: rows,
          columns: columns,
          direction: TextDirection.rtl,
          brightness: Brightness.dark,
        ),
      );
      await tester.pump();
      expect(tester.widget(_key('records-header-c1')), same(originalHeader));
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Property 1'))
            .text
            .style!
            .color,
        isNot(originalHeaderColor),
      );
      final semantics = tester.ensureSemantics();
      final resize = find.bySemanticsLabel('Resize column: Property 1');
      final gesture = find
          .descendant(of: resize, matching: find.byType(GestureDetector))
          .last;
      Focus.of(tester.element(gesture)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(tester.getSize(_key('records-header-c1')).width, 156);
      semantics.dispose();

      // The host can reuse its list container while replacing immutable entries.
      rows[0] = BeautifulRecordRow(
        id: 'r0',
        label: 'Updated record',
        cells: <String, BeautifulRecordCell>{
          ...rows[0].cells,
          'c1': BeautifulRecordCell(text: 'Updated cell', number: 1),
        },
      );
      columns[1] = BeautifulRecordColumn(
        id: 'c1',
        label: 'Updated property',
        width: 240,
        sortable: false,
      );
      await tester.pumpWidget(
        _app(
          rows: rows,
          columns: columns,
          direction: TextDirection.rtl,
          brightness: Brightness.dark,
          labels: const BeautifulRecordsTableLabels(configure: 'Configure new'),
        ),
      );
      await tester.pump();
      expect(tester.element(_key('records-row-r0')), same(originalRow));
      expect(find.text('Updated cell'), findsOneWidget);
      expect(find.text('r0.c1'), findsNothing);
      expect(
        tester.widget(_key('records-header-c1')),
        isNot(same(originalHeader)),
      );
      expect(_key('records-sort-c1'), findsNothing);
      expect(find.text('Updated property'), findsOneWidget);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Updated cell'))
            .text
            .style!
            .color,
        isNot(originalColor),
      );
      expect(
        Directionality.of(tester.element(_key('records-row-r0'))),
        TextDirection.rtl,
      );

      // Header actions must open the replacement configuration, not captured data.
      await tester.ensureVisible(_key('records-header-c1'));
      await tester.tap(_key('records-header-c1'));
      await tester.pump();
      expect(find.text('Configure new: Updated property'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
