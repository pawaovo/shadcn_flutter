import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _items = <BeautifulSearchItem>[
  BeautifulSearchItem(
    id: 'forecast',
    title: 'Forecast summer demand',
    subtitle: 'Seasonal planning',
    group: 'Planning',
  ),
  BeautifulSearchItem(
    id: 'suppliers',
    title: 'Find waffle cone suppliers',
    subtitle: 'Approved partners',
    group: 'Sourcing',
    keywords: <String>['vendors', 'procurement'],
  ),
  BeautifulSearchItem(
    id: 'seasonal',
    title: 'Compare seasonal flavors',
    group: 'Research',
  ),
  BeautifulSearchItem(
    id: 'launch',
    title: 'Draft flavor launch plan',
    group: 'Planning',
  ),
  BeautifulSearchItem(
    id: 'cold-chain',
    title: 'Check cold-chain status',
    subtitle: 'Refrigerated delivery',
    group: 'Operations',
  ),
  BeautifulSearchItem(
    id: 'costs',
    title: 'Audit sugar costs',
    group: 'Finance',
  ),
  BeautifulSearchItem(
    id: 'retire',
    title: 'Retire low sellers',
    group: 'Catalog',
  ),
];

void main() {
  testWidgets('shows the first five items for an empty query', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.text('Forecast summer demand'), findsOneWidget);
    expect(find.text('Check cold-chain status'), findsOneWidget);
    expect(find.text('Audit sugar costs'), findsNothing);
    expect(find.text('Retire low sellers'), findsNothing);
  });

  testWidgets('filters every searchable field without changing item order', (
    tester,
  ) async {
    await tester.pumpWidget(_app(initialQuery: 'PLANNING'));

    expect(find.text('Forecast summer demand'), findsOneWidget);
    expect(find.text('Draft flavor launch plan'), findsOneWidget);
    expect(find.text('Find waffle cone suppliers'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'VENDORS');
    await tester.pump();

    expect(find.text('Find waffle cone suppliers'), findsOneWidget);
    expect(find.text('Forecast summer demand'), findsNothing);
  });

  testWidgets('delays the empty state until three query characters', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.enterText(find.byType(EditableText), 'zz');
    await tester.pump();
    expect(find.text('No results found'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'zzz');
    await tester.pump();
    expect(find.text('No results found'), findsOneWidget);
    expect(find.text('Adjust your search to try again'), findsOneWidget);
  });

  testWidgets('clear restores the initial results and field focus', (
    tester,
  ) async {
    final queries = <String>[];
    await tester.pumpWidget(_app(onQueryChanged: queries.add));

    await tester.enterText(find.byType(EditableText), 'vendors');
    await tester.pump();
    expect(find.text('Find waffle cone suppliers'), findsOneWidget);

    await tester.tap(find.byKey(const Key('beautiful-search-clear')));
    await tester.pump();

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.text, isEmpty);
    expect(field.focusNode.hasFocus, isTrue);
    expect(find.text('Forecast summer demand'), findsOneWidget);
    expect(find.byKey(const Key('beautiful-search-clear')), findsNothing);
    expect(queries, <String>['vendors', '']);
  });

  testWidgets('selection fills the title before notifying the caller', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      _app(
        onQueryChanged: (query) => events.add('query:$query'),
        onSelected: (item) => events.add('selected:${item.id}'),
      ),
    );

    await tester.tap(find.text('Find waffle cone suppliers'));
    await tester.pump();

    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.controller.text, 'Find waffle cone suppliers');
    expect(events, <String>[
      'query:Find waffle cone suppliers',
      'selected:suppliers',
    ]);
  });

  testWidgets('ArrowDown and Enter select the highlighted result', (
    tester,
  ) async {
    BeautifulSearchItem? selected;
    await tester.pumpWidget(_app(onSelected: (item) => selected = item));

    tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected?.id, 'forecast');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Forecast summer demand',
    );
  });

  testWidgets('ArrowUp wraps to the final visible item', (tester) async {
    BeautifulSearchItem? selected;
    await tester.pumpWidget(_app(onSelected: (item) => selected = item));

    tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selected?.id, 'cold-chain');
  });

  testWidgets('Escape clears the current query', (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(_app(onQueryChanged: queries.add));

    await tester.enterText(find.byType(EditableText), 'cold-chain');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
    expect(find.text('Forecast summer demand'), findsOneWidget);
    expect(queries.last, isEmpty);
  });

  testWidgets('pointer hover is visual only and does not select semantics', (
    tester,
  ) async {
    BeautifulSearchItem? selected;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(onSelected: (item) => selected = item));
    final result = find.byKey(
      const ValueKey<String>('beautiful-search-result-forecast'),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(result));
    await tester.pump();

    final data = tester
        .getSemantics(
          find.bySemanticsLabel(
            'Forecast summer demand. Seasonal planning. Planning',
          ),
        )
        .getSemanticsData();
    expect(data.flagsCollection.isSelected, isNot(ui.Tristate.isTrue));
    expect(selected, isNull);

    await mouse.removePointer();
    semantics.dispose();
  });

  testWidgets('keeps query state across adaptive width changes', (
    tester,
  ) async {
    Widget atWidth(double width) {
      return _app(
        size: Size(width, 900),
        searchKey: const Key('resizable-search'),
      );
    }

    await tester.pumpWidget(atWidth(599));
    await tester.enterText(find.byType(EditableText), 'cold-chain');
    await tester.pump();
    await tester.pumpWidget(atWidth(1024));
    await tester.pump();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'cold-chain',
    );
    expect(find.text('Check cold-chain status'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders at every adaptive boundary without overflow', (
    tester,
  ) async {
    for (final width in <double>[599, 600, 1023, 1024]) {
      await tester.pumpWidget(
        _app(size: Size(width, 900), searchKey: ValueKey<double>(width)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('keeps 48dp targets across wide touch layouts', (tester) async {
    final originalPlatform = debugDefaultTargetPlatformOverride;
    addTearDown(() => debugDefaultTargetPlatformOverride = originalPlatform);

    for (final platform in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      for (final width in <double>[599, 600, 1023, 1024]) {
        await tester.pumpWidget(
          _app(
            initialQuery: 'waffle',
            size: Size(width, 900),
            searchKey: ValueKey<String>('target-${platform.name}-$width'),
          ),
        );
        await tester.pump();

        expect(
          tester
              .getSize(find.byKey(const Key('beautiful-search-field-target')))
              .height,
          greaterThanOrEqualTo(48),
          reason: '${platform.name} field at $width',
        );
        expect(
          tester
              .getSize(find.byKey(const Key('beautiful-search-clear')))
              .height,
          greaterThanOrEqualTo(48),
          reason: '${platform.name} clear at $width',
        );
        expect(
          tester
              .getSize(
                find.byKey(
                  const ValueKey<String>('beautiful-search-result-suppliers'),
                ),
              )
              .height,
          greaterThanOrEqualTo(48),
          reason: '${platform.name} result at $width',
        );
      }
    }
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  testWidgets('defensively snapshots items and nested keywords', (
    tester,
  ) async {
    final keywords = <String>['seasonal'];
    final items = <BeautifulSearchItem>[
      BeautifulSearchItem(
        id: 'mutable',
        title: 'Stable result',
        keywords: keywords,
      ),
    ];
    const searchKey = Key('snapshot-search');
    await tester.pumpWidget(_app(items: items, searchKey: searchKey));

    keywords
      ..clear()
      ..add('mutated');
    items.add(
      const BeautifulSearchItem(id: 'late', title: 'Late list mutation'),
    );
    await tester.enterText(find.byType(EditableText), 'mutated');
    await tester.pump();

    expect(find.text('Stable result'), findsNothing);
    expect(find.text('Late list mutation'), findsNothing);

    await tester.enterText(find.byType(EditableText), 'Late');
    await tester.pump();
    expect(find.text('Late list mutation'), findsNothing);

    await tester.pumpWidget(_app(items: items, searchKey: searchKey));
    await tester.pump();
    expect(find.text('Late list mutation'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'mutated');
    await tester.pump();
    expect(find.text('Stable result'), findsOneWidget);
  });

  testWidgets('supports RTL, 200 percent text, and long item content', (
    tester,
  ) async {
    const longItems = <BeautifulSearchItem>[
      BeautifulSearchItem(
        id: 'arabic',
        title: 'بحث طويل عن سلسلة توريد نكهات الفستق للموسم القادم',
        subtitle: 'وصف طويل يبقى قابلا للقراءة دون تجاوز حدود البطاقة',
        group: 'التخطيط والتوريد',
        keywords: <String>['فستق'],
      ),
    ];
    await tester.pumpWidget(
      _app(
        items: longItems,
        size: const Size(320, 568),
        textDirection: TextDirection.rtl,
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pump();

    expect(
      find.text('بحث طويل عن سلسلة توريد نكهات الفستق للموسم القادم'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejects duplicate and blank item IDs', (tester) async {
    await tester.pumpWidget(
      _app(
        items: const <BeautifulSearchItem>[
          BeautifulSearchItem(id: 'duplicate', title: 'First'),
          BeautifulSearchItem(id: 'duplicate', title: 'Second'),
        ],
      ),
    );
    expect(tester.takeException(), isFlutterError);

    await tester.pumpWidget(
      _app(
        items: const <BeautifulSearchItem>[
          BeautifulSearchItem(id: '   ', title: 'Blank'),
        ],
        searchKey: const Key('blank-id-search'),
      ),
    );
    expect(tester.takeException(), isFlutterError);
  });
}

Widget _app({
  List<BeautifulSearchItem> items = _items,
  String initialQuery = '',
  ValueChanged<String>? onQueryChanged,
  ValueChanged<BeautifulSearchItem>? onSelected,
  Size size = const Size(390, 844),
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  Key? searchKey,
}) {
  return beautifulTestApp(
    size: size,
    textDirection: textDirection,
    textScaler: textScaler,
    disableAnimations: true,
    child: BeautifulSearch(
      key: searchKey,
      items: items,
      initialQuery: initialQuery,
      onQueryChanged: onQueryChanged,
      onSelected: onSelected ?? (_) {},
    ),
  );
}
