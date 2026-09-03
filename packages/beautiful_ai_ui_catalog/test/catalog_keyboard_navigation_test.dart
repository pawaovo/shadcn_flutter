import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Catalog retains forward reverse navigation and its theme shortcut',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(const CatalogApp());
      await tester.pump();
      try {
        final theme = Focus.of(tester.element(find.text('Theme: system')));
        final motion = Focus.of(tester.element(find.text('Motion: system')));
        theme.requestFocus();
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, same(theme));

        await tester.sendKeyEvent(
          LogicalKeyboardKey.tab,
          physicalKey: PhysicalKeyboardKey.tab,
        );
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, same(motion));

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
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, same(theme));

        final prompt = find.descendant(
          of: find.byKey(const Key('catalog-prompt-bar')),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(prompt);
        await tester.pump();
        await tester.enterText(prompt, 'Preserve 中文 draft');
        final editor = tester.widget<EditableText>(prompt);
        final value = editor.controller.value;
        await tester.sendKeyDownEvent(
          LogicalKeyboardKey.metaLeft,
          physicalKey: PhysicalKeyboardKey.metaLeft,
        );
        try {
          await tester.sendKeyEvent(
            LogicalKeyboardKey.keyD,
            physicalKey: PhysicalKeyboardKey.keyD,
          );
        } finally {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        }
        await tester.pump();
        expect(find.text('Theme: light'), findsOneWidget);
        expect(tester.widget<EditableText>(prompt).controller.value, value);
        expect(tester.widget<EditableText>(prompt).focusNode.hasFocus, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
