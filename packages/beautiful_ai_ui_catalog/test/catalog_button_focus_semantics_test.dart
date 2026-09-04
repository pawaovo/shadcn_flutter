import 'dart:ui' as ui;

import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

SemanticsData _data(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();

double _borderWidth(WidgetTester tester, String label) {
  final decoration =
      tester
              .widget<DecoratedBox>(
                find
                    .ancestor(
                      of: find.text(label),
                      matching: find.byType(DecoratedBox),
                    )
                    .first,
              )
              .decoration
          as BoxDecoration;
  return (decoration.border! as Border).top.width;
}

Future<void> _reverseTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(
    LogicalKeyboardKey.shiftLeft,
    physicalKey: PhysicalKeyboardKey.shiftLeft,
  );
  try {
    await tester.sendKeyEvent(
      LogicalKeyboardKey.tab,
      physicalKey: PhysicalKeyboardKey.tab,
    );
  } finally {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
}

void main() {
  testWidgets('Tab and Space expose real focus on Theme and Motion semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final previousHighlight = FocusManager.instance.highlightStrategy;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    try {
      await tester.pumpWidget(const CatalogApp());
      await tester.pump();
      // Establish a deterministic origin, then traverse using actual key events.
      Focus.of(tester.element(find.text('Motion: system'))).requestFocus();
      await tester.pump();
      await _reverseTab(tester);
      await tester.pump();
      expect(
        Focus.of(tester.element(find.text('Theme: system'))).hasFocus,
        isTrue,
      );
      expect(
        _data(tester, 'Theme: system').flagsCollection.isFocused,
        ui.Tristate.isTrue,
      );
      expect(_borderWidth(tester, 'Theme: system'), 2);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.pump();
      expect(
        _data(tester, 'Theme: light').flagsCollection.isFocused,
        ui.Tristate.isTrue,
      );
      expect(
        _data(tester, 'Motion: system').flagsCollection.isFocused,
        ui.Tristate.isFalse,
      );

      await tester.sendKeyEvent(
        LogicalKeyboardKey.tab,
        physicalKey: PhysicalKeyboardKey.tab,
      );
      await tester.pump();
      expect(
        _data(tester, 'Theme: light').flagsCollection.isFocused,
        ui.Tristate.isFalse,
      );
      expect(
        _data(tester, 'Motion: system').flagsCollection.isFocused,
        ui.Tristate.isTrue,
      );
      await tester.sendKeyEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.pump();
      expect(
        _data(tester, 'Motion: reduced').flagsCollection.isFocused,
        ui.Tristate.isTrue,
      );
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      semantics.dispose();
      FocusManager.instance.highlightStrategy = previousHighlight;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'pointer activation and suppressed highlight retain truthful focus',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final previousHighlight = FocusManager.instance.highlightStrategy;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      try {
        await tester.pumpWidget(const CatalogApp());
        await tester.pump();
        await tester.tap(
          find.text('Theme: system'),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(
          Focus.of(tester.element(find.text('Theme: light'))).hasFocus,
          isFalse,
        );
        expect(
          _data(tester, 'Theme: light').flagsCollection.isFocused,
          ui.Tristate.isFalse,
        );
        expect(_borderWidth(tester, 'Theme: light'), 1);

        Focus.of(tester.element(find.text('Motion: system'))).requestFocus();
        await tester.pump();
        await _reverseTab(tester);
        await tester.pump();
        expect(
          Focus.of(tester.element(find.text('Theme: light'))).hasFocus,
          isTrue,
        );
        expect(
          _data(tester, 'Theme: light').flagsCollection.isFocused,
          ui.Tristate.isTrue,
        );
        // Actual keyboard focus must remain announced while focus highlighting is off.
        expect(_borderWidth(tester, 'Theme: light'), 1);

        await tester.tap(
          find.text('Theme: light'),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(
          _data(tester, 'Theme: dark').flagsCollection.isFocused,
          ui.Tristate.isTrue,
        );
        expect(_borderWidth(tester, 'Theme: dark'), 1);
        await tester.tap(
          find.text('Motion: system'),
          kind: ui.PointerDeviceKind.mouse,
        );
        await tester.pump();
        expect(
          _data(tester, 'Motion: reduced').flagsCollection.isFocused,
          ui.Tristate.isFalse,
        );
        expect(
          _data(tester, 'Theme: dark').flagsCollection.isFocused,
          ui.Tristate.isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
        FocusManager.instance.highlightStrategy = previousHighlight;
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
