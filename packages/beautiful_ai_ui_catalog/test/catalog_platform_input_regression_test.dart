import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/interactions.dart';

void main() {
  for (final platform in <TargetPlatform>[
    TargetPlatform.linux,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets('Catalog prompt keyboard menus preserve focus on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1120, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const CatalogApp());
      await tester.pump(const Duration(seconds: 1));
      try {
        final prompt = find.descendant(
          of: find.byKey(const Key('catalog-prompt-bar')),
          matching: find.byType(EditableText),
        );
        final editor = tester.widget<EditableText>(prompt);
        await Scrollable.ensureVisible(tester.element(prompt), alignment: 0.5);
        await tester.pump(const Duration(milliseconds: 16));
        editor.focusNode.requestFocus();
        await tester.pump();
        for (final selectionKey
            in const <(LogicalKeyboardKey, PhysicalKeyboardKey)>[
              (LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab),
              (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter),
            ]) {
          tester
              .state<EditableTextState>(prompt)
              .userUpdateTextEditingValue(
                const TextEditingValue(
                  text: '/',
                  selection: TextSelection.collapsed(offset: 1),
                ),
                SelectionChangedCause.keyboard,
              );
          await tester.pump(const Duration(milliseconds: 16));
          await tester.sendKeyEvent(
            LogicalKeyboardKey.arrowDown,
            physicalKey: PhysicalKeyboardKey.arrowDown,
          );
          await tester.pump(const Duration(milliseconds: 16));
          await tester.sendKeyEvent(
            selectionKey.$1,
            physicalKey: selectionKey.$2,
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(editor.controller.text, '/compare ');
          expect(editor.focusNode.hasFocus, isTrue);
          expect(find.textContaining('Prompt received:'), findsNothing);
        }

        await tapCatalogTarget(
          tester,
          find.byKey(const Key('beautiful-prompt-model')),
        );
        await tester.pump(const Duration(milliseconds: 180));
        final precise = find.byKey(
          const Key('beautiful-prompt-option-model-precise'),
        );
        expect(precise, findsOneWidget);
        await tester.sendKeyEvent(
          LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
        );
        await tester.pump(const Duration(milliseconds: 16));
        expect(precise, findsNothing);
        expect(editor.focusNode.hasFocus, isTrue);
        expect(editor.controller.text, '/compare ');
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
