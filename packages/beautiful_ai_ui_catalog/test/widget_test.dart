import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('catalog renders all Loading State variants', (tester) async {
    await tester.pumpWidget(const CatalogApp());
    await tester.pump();

    expect(find.text('Beautiful AI UI · Loading State'), findsOneWidget);
    expect(find.text('Drive'), findsOneWidget);
    expect(find.text('Dots'), findsOneWidget);
    expect(find.text('Orbit'), findsOneWidget);
    expect(find.text('Surfer'), findsOneWidget);
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
    expect(find.text('Surfer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
