import 'package:beautiful_ai_ui_catalog/main.dart' as catalog;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'catalog launches and completes its critical interaction journey',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        catalog.main();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Beautiful AI UI · P1 + P2 Catalog'), findsOneWidget);
        expect(find.text('Loading · Drive'), findsOneWidget);
        expect(find.text('Loading · Dots'), findsOneWidget);
        expect(find.text('Loading · Orbit'), findsOneWidget);
        expect(find.text('Loading · Surfer'), findsOneWidget);

        await tester.tap(find.text('Theme: system'));
        await tester.pump();
        expect(find.text('Theme: light'), findsOneWidget);

        await tester.tap(find.text('Motion: system'));
        await tester.pump();
        expect(find.text('Motion: reduced'), findsOneWidget);

        final scrollable = find.byType(Scrollable).first;

        final thinking = find.byKey(const Key('catalog-thinking-steps'));
        await tester.scrollUntilVisible(thinking, 700, scrollable: scrollable);
        final thinkingItem = find.descendant(
          of: thinking,
          matching: find.text('Reading flavor briefs'),
        );
        expect(thinkingItem, findsOneWidget);
        expect(
          find.bySemanticsLabel('Hide steps thinking details'),
          findsOneWidget,
        );
        tester.semantics.tap(
          find.semantics.byLabel('Hide steps thinking details'),
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.bySemanticsLabel('Show steps thinking details'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Hide steps thinking details'),
          findsNothing,
        );

        final contextCards = find.byKey(const Key('catalog-context-cards'));
        await tester.scrollUntilVisible(
          contextCards,
          700,
          scrollable: scrollable,
        );
        await tester.tap(
          find.descendant(
            of: contextCards,
            matching: find.text('Dairy Onboarding SOP.pdf'),
          ),
        );
        await tester.pump();
        expect(find.text('Opened source: vendor-rule'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const Key('catalog-recommendation-card')),
          700,
          scrollable: scrollable,
        );
        await tester.tap(
          _inside('catalog-recommendation-card', find.text('Alternatives')),
        );
        await tester.pump();
        expect(find.text('Other options'), findsOneWidget);
        await tester.tap(
          _inside('catalog-recommendation-card', find.text('Accept')),
        );
        await tester.pump();
        expect(find.text('Accepted'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const Key('catalog-search')),
          700,
          scrollable: scrollable,
        );
        final searchInput = _inside(
          'catalog-search',
          find.byType(EditableText),
        );
        await tester.enterText(searchInput, 'waffle');
        await tester.pump();
        expect(find.text('Find waffle cone suppliers'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          tester.widget<EditableText>(searchInput).controller.text,
          'Find waffle cone suppliers',
        );

        await tester.scrollUntilVisible(
          find.byKey(const Key('catalog-code-block')),
          700,
          scrollable: scrollable,
        );
        await tester.tap(_inside('catalog-code-block', find.text('Copy')));
        await tester.pump();
        expect(find.text('Copied'), findsOneWidget);
        await _runP2Journey(tester);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        runApp(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}

Finder _inside(String key, Finder matching) =>
    find.descendant(of: find.byKey(Key(key)), matching: matching);

Future<void> _runP2Journey(WidgetTester tester) async {
  Future<void> tap(String key, Finder target) async {
    final finder = _inside(key, target);
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 180));
  }

  await tap('catalog-streaming-complete', find.text('Copy response'));
  expect(find.text('Response copied'), findsOneWidget);
  await tap('catalog-streaming-complete', find.text('Sources (2)'));
  await tap(
    'catalog-streaming-complete',
    find.textContaining('[1] September sales forecast'),
  );
  expect(
    find.text('Opened citation: September sales forecast'),
    findsOneWidget,
  );
  await tap(
    'catalog-streaming-complete',
    find.text('Compare supplier lead times'),
  );
  expect(
    find.text('Follow-up selected: Compare supplier lead times'),
    findsOneWidget,
  );
  await tap('catalog-streaming-failed', find.text('Retry answer'));
  await tester.pump(const Duration(milliseconds: 180));
  expect(find.text('Response recovered'), findsOneWidget);

  final runStream = find.text('Run stream demo');
  await tester.ensureVisible(runStream);
  await tester.pump();
  await tester.tap(runStream);
  await tester.pump(const Duration(milliseconds: 1800));
  expect(find.text('Demonstration response complete'), findsOneWidget);

  await tap('catalog-approval', find.text('Scoop shops'));
  await tap('catalog-approval', find.text('Pistachio'));
  await tap('catalog-approval', find.text('Vanilla'));
  await tap('catalog-approval', find.text('Continue'));
  await tap('catalog-approval', find.text('This Friday'));
  await tester.pump(const Duration(milliseconds: 180));
  expect(find.text('Submitted 3 approval answers'), findsOneWidget);

  await tap('catalog-tool-chips', find.text('Plan restock'));
  expect(find.text('Prioritize the top three flavors.'), findsOneWidget);
  await tap('catalog-tool-chips', find.text('Show more files'));
  expect(find.text('restock.json'), findsOneWidget);
  await tap(
    'catalog-tool-chips',
    find.byKey(const Key('beautiful-tool-diff-control-forecast')),
  );
  expect(find.textContaining('pistachio,100'), findsOneWidget);

  for (final variant in <String>['capsules', 'list']) {
    await tap('catalog-task-rows-$variant', find.text('Retry'));
    await tester.pump(const Duration(milliseconds: 180));
    expect(
      _inside('catalog-task-rows-$variant', find.text('Retry')),
      findsNothing,
    );
  }
  expect(find.text('Supplier email draft recovered'), findsNWidgets(2));

  final composer = _inside('catalog-chat', find.byType(EditableText));
  await Scrollable.ensureVisible(tester.element(composer), alignment: 0.5);
  await tester.pump();
  await tester.enterText(composer, 'Check cone inventory');
  await tap('catalog-chat', find.text('Send'));
  expect(
    _inside('catalog-chat', find.text('Check cone inventory')),
    findsOneWidget,
  );
  await tap('catalog-chat', find.text('Stop response'));
  expect(find.text('Demonstration response stopped.'), findsOneWidget);
  await tap('catalog-chat', find.text('Suppliers'));
  expect(
    find.text('Active context: suppliers · local demonstration replies'),
    findsOneWidget,
  );

  await tap(
    'catalog-filter-table',
    find.byKey(const Key('filter-table-filter-completed')),
  );
  expect(find.text('Review seasonal forecast'), findsOneWidget);
  expect(find.text('Count waffle cone stock'), findsNothing);

  await tap('catalog-fine-tune', find.text('Grid'));
  expect(find.textContaining('Accepted layout: grid'), findsOneWidget);
  await tap('catalog-fine-tune', find.text('Select type'));
  await tap('catalog-fine-tune', find.text('Seasonal'));
  final width = find.descendant(
    of: _inside(
      'catalog-fine-tune',
      find.byKey(const Key('beautiful-fine-tune-input-width')),
    ),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(width);
  await tester.pump();
  await tester.enterText(width, '360');
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  expect(tester.widget<EditableText>(width).controller.text, '360');
}
