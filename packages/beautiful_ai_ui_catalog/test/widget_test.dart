import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalog renders the complete P1, P2 and P3 module set', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    expect(find.text('Beautiful AI UI · P1 + P2 + P3 Catalog'), findsOneWidget);
    expect(find.text('Loading · Drive'), findsOneWidget);
    expect(find.text('Loading · Dots'), findsOneWidget);
    expect(find.text('Loading · Orbit'), findsOneWidget);
    expect(find.text('Loading · Surfer'), findsOneWidget);
    expect(find.text('Thinking · steps'), findsOneWidget);
    expect(find.text('Thinking · reasoning'), findsOneWidget);
    expect(find.text('Thinking · search'), findsOneWidget);
    expect(find.text('Thinking · coding'), findsOneWidget);
    expect(find.text('Context Cards'), findsOneWidget);
    expect(find.text('Recommendation Card'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Code Block · Code'), findsOneWidget);
    expect(find.text('Code Block · Diff'), findsOneWidget);
    expect(find.text('Streaming Text · Complete'), findsOneWidget);
    expect(find.text('Streaming Text · Live'), findsOneWidget);
    expect(find.text('Streaming Text · Failed'), findsOneWidget);
    expect(find.text('Approval Card'), findsOneWidget);
    expect(find.text('Tool Chips'), findsOneWidget);
    expect(find.text('Task Rows · capsules'), findsOneWidget);
    expect(find.text('Task Rows · list'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Filter Table'), findsOneWidget);
    expect(find.text('Fine-tune Card'), findsOneWidget);
    for (final title in <String>[
      'Prompt Bar',
      'Diff Table',
      'Records Table',
      'Sidebar Nav',
      'Flowchart',
      'Insight Cards',
      'Selection Actions',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('catalog controls support pointer and keyboard activation', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    await tester.tap(find.text('Theme: system'));
    await tester.pump();
    expect(find.text('Theme: light'), findsOneWidget);

    await tester.tap(find.text('Motion: system'));
    await tester.pump();
    expect(find.text('Motion: reduced'), findsOneWidget);

    await tester.pumpWidget(const CatalogApp());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Theme: light'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('catalog P1 examples remain directly interactive', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('catalog-recommendation-card')),
      700,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Alternatives'));
    await tester.pump();
    expect(find.text('Other options'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('catalog-search')),
      700,
      scrollable: scrollable,
    );
    await tester.enterText(
      _inside('catalog-search', find.byType(EditableText)),
      'waffle',
    );
    await tester.pump();
    expect(find.text('Find waffle cone suppliers'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('catalog-code-block')),
      700,
      scrollable: scrollable,
    );
    await tester.tap(_inside('catalog-code-block', find.text('Copy')));
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('catalog controls support semantics activation', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    final themeButton = find.semantics.byLabel('Theme: system');
    expect(themeButton, findsOne);

    tester.semantics.tap(themeButton);
    await tester.pump();
    expect(find.text('Theme: light'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('catalog P2 host callbacks complete the workflow', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

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
    expect(find.text('Response recovered'), findsOneWidget);

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
    await tester.enterText(width, '360');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(tester.widget<EditableText>(width).controller.text, '360');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('P2 state survives grid resize and finite stream completion', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    final filter = _inside(
      'catalog-filter-table',
      find.byKey(const Key('filter-table-filter-completed')),
    );
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pump();
    final composer = _inside('catalog-chat', find.byType(EditableText));
    await tester.ensureVisible(composer);
    await tester.enterText(composer, 'Keep this draft');
    final runStream = find.text('Run stream demo');
    await tester.ensureVisible(runStream);
    await tester.tap(runStream);
    await tester.pump();

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(
      tester.widget<EditableText>(composer).controller.text,
      'Keep this draft',
    );
    expect(find.text('Selected filter: completed'), findsOneWidget);
    expect(find.text('Count waffle cone stock'), findsNothing);
    expect(find.text('Demonstration response complete'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('catalog P3 host callbacks complete every module workflow', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();
    await _runP3Journey(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'P3 drafts and accepted snapshots survive desktop to phone resize',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const CatalogApp());
      await tester.pump();
      expect(
        tester.getSize(find.byKey(const Key('catalog-records-table'))).width,
        greaterThan(1024),
      );
      expect(
        find.byKey(const Key('beautiful-flowchart-viewport')),
        findsOneWidget,
      );

      final prompt = _inside('catalog-prompt-bar', find.byType(EditableText));
      await tester.ensureVisible(prompt);
      await tester.enterText(prompt, 'Preserve this P3 draft');
      final search = _inside(
        'catalog-records-table',
        find.byType(EditableText),
      ).first;
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Cone');
      final include = _inside(
        'catalog-diff-table',
        find.byKey(const Key('diff-table-include-sorbet')),
      );
      await tester.ensureVisible(include);
      await tester.tap(include);
      await tester.pump();

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(
        tester.widget<EditableText>(prompt).controller.text,
        'Preserve this P3 draft',
      );
      expect(tester.widget<EditableText>(search).controller.text, 'Cone');
      expect(
        _inside('catalog-diff-table', find.text('Apply changes (2)')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('beautiful-flowchart-ordered-steps')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('beautiful-flowchart-viewport')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('catalog stays overflow-free at compact viewport width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Loading · Surfer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Finder _inside(String key, Finder matching) =>
    find.descendant(of: find.byKey(Key(key)), matching: matching);

Future<void> _runP3Journey(WidgetTester tester) async {
  Future<void> tap(String key, Finder target) async {
    final finder = _inside(key, target);
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pump();
    await tester.tap(finder);
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
