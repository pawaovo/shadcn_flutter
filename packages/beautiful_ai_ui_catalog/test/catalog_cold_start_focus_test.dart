import 'dart:ui' as ui;

import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void _viewFocus(
  WidgetTester tester,
  ui.ViewFocusState state,
  ui.ViewFocusDirection direction,
) {
  tester.binding.handleViewFocusChanged(
    ui.ViewFocusEvent(
      viewId: tester.view.viewId,
      state: state,
      direction: direction,
    ),
  );
}

Future<void> _key(
  WidgetTester tester,
  LogicalKeyboardKey logical,
  PhysicalKeyboardKey physical,
) async {
  await tester.sendKeyEvent(logical, physicalKey: physical);
  await tester.pump();
}

void main() {
  for (final timing in [
    'no native focus event',
    'undefined after mount',
    'forward before mount',
  ]) {
    testWidgets('Catalog first Tab and Space work with $timing', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        // Model a cold/parked root, without choosing a Catalog control or editor.
        FocusManager.instance.rootScope.requestScopeFocus();
        await tester.pump();
        expect(
          FocusManager.instance.primaryFocus,
          same(FocusManager.instance.rootScope),
        );
        if (timing == 'forward before mount') {
          _viewFocus(
            tester,
            ui.ViewFocusState.focused,
            ui.ViewFocusDirection.forward,
          );
          await tester.pump();
        }
        await tester.pumpWidget(const CatalogApp());
        await tester.pump();
        if (timing == 'undefined after mount') {
          _viewFocus(
            tester,
            ui.ViewFocusState.focused,
            ui.ViewFocusDirection.undefined,
          );
          await tester.pump();
        }

        await _key(tester, LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab);
        expect(
          Focus.of(tester.element(find.text('Theme: system'))).hasFocus,
          isTrue,
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Theme: system'))
              .getSemanticsData()
              .flagsCollection
              .isFocused,
          ui.Tristate.isTrue,
        );
        await _key(tester, LogicalKeyboardKey.space, PhysicalKeyboardKey.space);
        expect(find.text('Theme: system'), findsNothing);
        expect(find.text('Theme: light'), findsOneWidget);
        expect(
          Focus.of(tester.element(find.text('Theme: light'))).hasFocus,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        _viewFocus(
          tester,
          ui.ViewFocusState.unfocused,
          ui.ViewFocusDirection.undefined,
        );
        await tester.pump();
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets(
    'Catalog scope preserves the editor through view focus and theme changes',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(const CatalogApp());
        await tester.pump();
        final input = find.descendant(
          of: find.byKey(const Key('catalog-search')),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(input);
        await tester.pump();
        await tester.tap(input);
        await tester.pump();
        await tester.enterText(input, 'cone');
        await tester.pump();
        final editor = tester.widget<EditableText>(input);
        final focus = editor.focusNode;
        final value = editor.controller.value;
        expect(focus.hasFocus, isTrue);

        _viewFocus(
          tester,
          ui.ViewFocusState.unfocused,
          ui.ViewFocusDirection.undefined,
        );
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        _viewFocus(
          tester,
          ui.ViewFocusState.focused,
          ui.ViewFocusDirection.undefined,
        );
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(tester.widget<EditableText>(input).controller.text, value.text);
        // Desktop focus regain may select all; shell rebuilds must preserve the
        // resulting editor value rather than stealing focus or changing its draft.
        final resumedValue = tester
            .widget<EditableText>(input)
            .controller
            .value;

        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.metaLeft,
          physicalKey: PhysicalKeyboardKey.metaLeft,
        );
        try {
          await _key(tester, LogicalKeyboardKey.keyD, PhysicalKeyboardKey.keyD);
        } finally {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        }
        await tester.pump();
        expect(find.text('Theme: light'), findsOneWidget);
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(
          tester.widget<EditableText>(input).controller.value,
          resumedValue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        _viewFocus(
          tester,
          ui.ViewFocusState.unfocused,
          ui.ViewFocusDirection.undefined,
        );
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
