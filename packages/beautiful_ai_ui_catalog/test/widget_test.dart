import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalog renders the complete P1 and P2 module set', (
    tester,
  ) async {
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    expect(find.text('Beautiful AI UI · P1 + P2 Catalog'), findsOneWidget);
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
