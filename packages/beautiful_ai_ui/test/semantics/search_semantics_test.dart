import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
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
    id: 'supplier',
    title: 'Find waffle cone suppliers',
    group: 'Sourcing',
  ),
];

void main() {
  testWidgets('exposes a labeled editable field and localized clear action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        initialQuery: 'waffle',
        searchLabel: 'Search workspace',
        clearLabel: 'Remove search text',
      ),
    );

    final field = tester
        .getSemantics(find.bySemanticsLabel('Search workspace'))
        .getSemanticsData();
    final clear = tester
        .getSemantics(find.bySemanticsLabel('Remove search text'))
        .getSemanticsData();

    expect(field.flagsCollection.isTextField, isTrue);
    expect(field.value, 'waffle');
    expect(field.hasAction(SemanticsAction.setText), isTrue);
    expect(clear.flagsCollection.isButton, isTrue);
    expect(clear.hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets('results are ordered buttons with full non-keyword labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());

    final first = tester
        .getSemantics(
          find.bySemanticsLabel(
            'Forecast summer demand. Seasonal planning. Planning',
          ),
        )
        .getSemanticsData();
    final second = tester
        .getSemantics(
          find.bySemanticsLabel('Find waffle cone suppliers. Sourcing'),
        )
        .getSemanticsData();

    expect(first.flagsCollection.isButton, isTrue);
    expect(first.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(first.hasAction(SemanticsAction.tap), isTrue);
    expect(second.flagsCollection.isButton, isTrue);
    expect(
      tester.getTopLeft(find.text('Forecast summer demand')).dy,
      lessThan(tester.getTopLeft(find.text('Find waffle cone suppliers')).dy),
    );
    expect(first.label, isNot(contains('keyword')));
    semantics.dispose();
  });

  testWidgets('keyboard highlight is exposed as selected', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(autofocus: true));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    final highlighted = tester
        .getSemantics(
          find.bySemanticsLabel(
            'Forecast summer demand. Seasonal planning. Planning',
          ),
        )
        .getSemanticsData();
    expect(highlighted.flagsCollection.isSelected, ui.Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('empty state is one status announcement', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        initialQuery: 'missing',
        emptyTitle: 'Nothing matched',
        emptyHint: 'Try a broader phrase',
      ),
    );

    final emptyFinder = find.bySemanticsLabel(
      'Nothing matched. Try a broader phrase',
    );
    final empty = tester.getSemantics(emptyFinder).getSemanticsData();
    expect(emptyFinder, findsOneWidget);
    expect(empty.role, SemanticsRole.status);
    expect(empty.flagsCollection.isLiveRegion, isFalse);
    expect(find.bySemanticsLabel('Nothing matched'), findsNothing);
    expect(find.bySemanticsLabel('Try a broader phrase'), findsNothing);
    semantics.dispose();
  });

  testWidgets('semantic tap selects the result and commits its title', (
    tester,
  ) async {
    BeautifulSearchItem? selected;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(onSelected: (item) => selected = item));

    tester.semantics.tap(
      find.semantics.byLabel('Find waffle cone suppliers. Sourcing'),
    );
    await tester.pump();

    expect(selected?.id, 'supplier');
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Find waffle cone suppliers',
    );
    semantics.dispose();
  });
}

Widget _app({
  String initialQuery = '',
  String searchLabel = 'Search',
  String clearLabel = 'Clear search',
  String emptyTitle = 'No results found',
  String emptyHint = 'Adjust your search to try again',
  bool autofocus = false,
  ValueChanged<BeautifulSearchItem>? onSelected,
}) {
  return beautifulTestApp(
    disableAnimations: true,
    child: BeautifulSearch(
      items: _items,
      initialQuery: initialQuery,
      searchLabel: searchLabel,
      clearLabel: clearLabel,
      emptyTitle: emptyTitle,
      emptyHint: emptyHint,
      autofocus: autofocus,
      onSelected: onSelected ?? (_) {},
    ),
  );
}
