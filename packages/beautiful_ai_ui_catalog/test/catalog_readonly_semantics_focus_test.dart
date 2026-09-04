import 'dart:ui' show SemanticsAction;

import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('readonly document accepts semantic focus from the prompt', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(const CatalogApp());
      await tester.pump(const Duration(milliseconds: 500));
      final prompt = find.descendant(
        of: find.byKey(const Key('catalog-prompt-bar')),
        matching: find.byType(EditableText),
      );
      final document = find
          .descendant(
            of: find.byKey(const Key('catalog-selection-actions')),
            matching: find.byType(EditableText),
          )
          .first;
      final promptEditor = tester.widget<EditableText>(prompt);
      final documentState = tester.state<EditableTextState>(document);
      final documentEditor = documentState.widget;
      final original = documentEditor.controller.value;

      promptEditor.focusNode.requestFocus();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.ensureVisible(document);
      await tester.pump(const Duration(milliseconds: 150));
      expect(promptEditor.focusNode.hasFocus, isTrue);
      expect(documentEditor.focusNode.hasFocus, isFalse);
      expect(documentEditor.readOnly, isTrue);

      final node = tester.getSemantics(document);
      // A browser's semantic text-field focus event dispatches this action;
      // being marked focusable does not itself transfer Flutter keyboard focus.
      node.owner!.performAction(node.id, SemanticsAction.focus);
      await tester.pump(const Duration(milliseconds: 150));
      expect(documentEditor.focusNode.hasFocus, isTrue);
      expect(promptEditor.focusNode.hasFocus, isFalse);
      expect(
        tester
            .getSemantics(document)
            .getSemanticsData()
            .hasAction(SemanticsAction.focus),
        isTrue,
      );
      expect(tester.state<EditableTextState>(document), same(documentState));
      expect(documentEditor.controller.value, original);

      // DOM focus/click can dispatch focus more than once. Repeating it must
      // preserve the source text and selected range, rather than reset them.
      final focusedNode = tester.getSemantics(document);
      focusedNode.owner!.performAction(focusedNode.id, SemanticsAction.focus);
      await tester.pump(const Duration(milliseconds: 150));
      expect(documentEditor.focusNode.hasFocus, isTrue);
      expect(documentEditor.controller.value, original);
      expect(documentState.widget.readOnly, isTrue);
    } finally {
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
