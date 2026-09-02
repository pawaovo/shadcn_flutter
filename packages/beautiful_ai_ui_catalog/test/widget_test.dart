import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalog renders the complete P1 module set', (tester) async {
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    expect(find.text('Beautiful AI UI · P1 Catalog'), findsOneWidget);
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
    await tester.enterText(find.byType(EditableText), 'waffle');
    await tester.pump();
    expect(find.text('Find waffle cone suppliers'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('catalog-code-block')),
      700,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Copy'));
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
