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

        expect(find.text('Beautiful AI UI · P1 Catalog'), findsOneWidget);
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
        await tester.tap(find.text('Alternatives'));
        await tester.pump();
        expect(find.text('Other options'), findsOneWidget);
        await tester.tap(find.text('Accept'));
        await tester.pump();
        expect(find.text('Accepted'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const Key('catalog-search')),
          700,
          scrollable: scrollable,
        );
        await tester.enterText(find.byType(EditableText), 'waffle');
        await tester.pump();
        expect(find.text('Find waffle cone suppliers'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'Find waffle cone suppliers',
        );

        await tester.scrollUntilVisible(
          find.byKey(const Key('catalog-code-block')),
          700,
          scrollable: scrollable,
        );
        await tester.tap(find.text('Copy'));
        await tester.pump();
        expect(find.text('Copied'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        runApp(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );
}
