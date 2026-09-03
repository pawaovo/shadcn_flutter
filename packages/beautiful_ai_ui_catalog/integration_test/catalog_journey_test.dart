import 'package:beautiful_ai_ui_catalog/main.dart' as catalog;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/interactions.dart';
import 'support/catalog_semantics_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final nativeSemantics = CatalogSemanticsFixture(binding);

  setUpAll(() async {
    if (!kIsWeb) {
      await nativeSemantics.prepare(
        () => prepareCatalogNativeSemantics(binding),
      );
    }
  });
  tearDownAll(nativeSemantics.dispose);

  testWidgets(
    'catalog launches and completes its critical interaction journey',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        catalog.main();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Beautiful AI UI · P1 + P2 + P3 Catalog'),
          findsOneWidget,
        );
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
        await _runP3Journey(tester);
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
    await tapCatalogTarget(tester, finder);
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

Future<void> _runP3Journey(WidgetTester tester) async {
  Future<void> tap(String key, Finder target) async {
    final finder = _inside(key, target);
    await tapCatalogTarget(tester, finder);
    await tester.pump(const Duration(milliseconds: 180));
  }

  final prompt = _inside('catalog-prompt-bar', find.byType(EditableText));
  await tester.ensureVisible(prompt);
  await tester.pump();
  await tester.enterText(prompt, '/rest');
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  expect(tester.widget<EditableText>(prompt).controller.text, '/restock ');
  await tap(
    'catalog-prompt-bar',
    find.byKey(const Key('beautiful-prompt-model')),
  );
  await tap(
    'catalog-prompt-bar',
    find.byKey(const Key('beautiful-prompt-option-model-precise')),
  );
  await tap(
    'catalog-prompt-bar',
    find.byKey(const Key('beautiful-prompt-add')),
  );
  await tap('catalog-prompt-bar', find.text('Add photos and files'));
  expect(
    _inside('catalog-prompt-bar', find.text('Remove inventory-1.csv')),
    findsOneWidget,
  );
  await tester.ensureVisible(prompt);
  await tester.enterText(prompt, 'Prepare the seasonal restock');
  await tap(
    'catalog-prompt-bar',
    find.byKey(const Key('beautiful-prompt-send')),
  );
  expect(
    find.text(
      'Prompt received: Prepare the seasonal restock · 1 files · precise',
    ),
    findsOneWidget,
  );
  expect(tester.widget<EditableText>(prompt).controller.text, isEmpty);

  await tap(
    'catalog-diff-table',
    find.byKey(const Key('diff-table-include-sorbet')),
  );
  await tap('catalog-diff-table', find.byKey(const Key('diff-table-next')));
  expect(_inside('catalog-diff-table', find.text('Unchanged')), findsOneWidget);
  await tap('catalog-diff-table', find.byKey(const Key('diff-table-apply')));
  expect(
    find.text('Applied inventory changes: pistachio, rocky-road'),
    findsOneWidget,
  );

  final recordsSearch = _inside(
    'catalog-records-table',
    find.byType(EditableText),
  ).first;
  await tester.ensureVisible(recordsSearch);
  await tester.enterText(recordsSearch, 'Cone');
  await tester.pump();
  await tap(
    'catalog-records-table',
    find.byKey(const Key('records-properties')),
  );
  await tap(
    'catalog-records-table',
    find.byKey(const Key('records-config-summary')),
  );
  await tap('catalog-records-table', find.byKey(const Key('records-run')));
  expect(find.text('Calculated 1 supplier records'), findsOneWidget);
  await tap('catalog-records-table', find.byKey(const Key('records-save')));
  expect(find.text('Saved supplier property: summary'), findsOneWidget);
  await tap(
    'catalog-records-table',
    find.byKey(const Key('records-close-editor')),
  );
  await tap(
    'catalog-records-table',
    find.byKey(const Key('records-detail-cone')),
  );
  expect(
    _inside(
      'catalog-records-table',
      find.textContaining('Cone King: 7 days lead time; ready for review.'),
    ),
    findsWidgets,
  );

  final openNavigation = _inside(
    'catalog-sidebar-nav',
    find.text('Open navigation'),
  );
  if (openNavigation.evaluate().isNotEmpty) {
    await tap('catalog-sidebar-nav', find.text('Open navigation'));
  }
  await tap(
    'catalog-sidebar-nav',
    find.byKey(const Key('beautiful-sidebar-workspace')),
  );
  await tap(
    'catalog-sidebar-nav',
    find.byKey(const Key('beautiful-sidebar-workspace-seasonal')),
  );
  await tap(
    'catalog-sidebar-nav',
    find.byKey(const Key('beautiful-sidebar-item-inventory')),
  );
  expect(
    find.text('Selected workspace: seasonal · destination: inventory'),
    findsOneWidget,
  );

  final steps = _inside('catalog-flowchart', find.text('Steps'));
  if (steps.evaluate().isNotEmpty) {
    await tap('catalog-flowchart', find.text('Steps'));
  }
  await tap(
    'catalog-flowchart',
    find.byKey(const Key('beautiful-flowchart-field-stock-rule-threshold')),
  );
  await tap(
    'catalog-flowchart',
    find.byKey(const Key('beautiful-flowchart-option-stock-rule-threshold-60')),
  );
  expect(
    find.textContaining('Accepted stock threshold: 60 tubs'),
    findsOneWidget,
  );

  await tap(
    'catalog-insight-cards',
    find.byKey(const Key('beautiful-insight-data-comparison')),
  );
  expect(
    _inside('catalog-insight-cards', find.text('Hide chart data')),
    findsOneWidget,
  );
  await tap(
    'catalog-insight-cards',
    find.byKey(const Key('beautiful-insight-next')),
  );
  await tap(
    'catalog-insight-cards',
    find.byKey(const Key('beautiful-insight-metric-anomaly-delay')),
  );
  expect(find.text('Selected delivery metric: delay'), findsOneWidget);
  await tap(
    'catalog-insight-cards',
    find.byKey(const Key('beautiful-insight-next')),
  );
  await tap(
    'catalog-insight-cards',
    find.byKey(const Key('beautiful-insight-segment-allocation-sorbet')),
  );
  expect(find.text('Selected order allocation: sorbet'), findsOneWidget);
  await tap('catalog-insight-cards', find.text('Review allocation plan'));
  expect(find.text('Opened insight follow-up: allocation'), findsOneWidget);

  await tap('catalog-selection-actions', find.text('Improve'));
  expect(
    _inside('catalog-selection-actions', find.text('Suggested text')),
    findsOneWidget,
  );
  await tap('catalog-selection-actions', find.text('Keep change'));
  expect(find.text('Accepted document edit: improve'), findsOneWidget);
  final document = _inside(
    'catalog-selection-actions',
    find.byType(EditableText),
  ).first;
  expect(
    tester.widget<EditableText>(document).controller.text,
    startsWith('Review pistachio stock and confirm the required quantity.'),
  );
}
