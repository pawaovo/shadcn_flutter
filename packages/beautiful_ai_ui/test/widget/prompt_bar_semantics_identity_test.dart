import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('Prompt menus retain the editor semantic node and connection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final snapshots = <String, int>{};
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulPromptBar(
          composerId: 'stable-composer',
          initialDraft: 'Draft 中文',
          commands: const <BeautifulPromptCommand>[
            BeautifulPromptCommand(id: 'restock', label: 'restock'),
            BeautifulPromptCommand(id: 'compare', label: 'compare'),
          ],
          models: const <BeautifulPromptModel>[
            BeautifulPromptModel(id: 'basic', label: 'Basic'),
            BeautifulPromptModel(id: 'precise', label: 'Precise'),
          ],
          selectedModelId: 'basic',
          onModelChanged: (_) {},
        ),
      ),
    );
    try {
      final input = find.byType(EditableText);
      await tester.showKeyboard(input);
      await tester.pump();
      final state = tester.state<EditableTextState>(input);
      final controller = state.widget.controller;
      Object? connectionId() =>
          (tester.testTextInput.log
                      .lastWhere((call) => call.method == 'TextInput.setClient')
                      .arguments
                  as List)
              .first;
      final originalConnection = connectionId();

      void capture(String transition, TextEditingValue expected) {
        expect(tester.state<EditableTextState>(input), same(state));
        expect(state.widget.controller, same(controller));
        expect(state.widget.focusNode.hasPrimaryFocus, isTrue);
        expect(controller.value, expected);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(connectionId(), originalConnection);
        snapshots[transition] = tester
            .getSemantics(find.bySemanticsLabel('Prompt'))
            .id;
      }

      capture('closed', controller.value);
      await tester.enterText(input, '/');
      await tester.pump();
      expect(find.text('Commands'), findsOneWidget);
      capture(
        'slash menu',
        const TextEditingValue(
          text: '/',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.text('Commands'), findsNothing);
      capture(
        'command selected',
        const TextEditingValue(
          text: '/compare ',
          selection: TextSelection.collapsed(offset: 9),
        ),
      );

      await tester.enterText(input, 'browser 中文 draft\nsecond line');
      controller.selection = const TextSelection(
        baseOffset: 8,
        extentOffset: 10,
      );
      await tester.pump();
      final retained = controller.value;
      capture('multiline selected draft', retained);
      await tester.tap(find.byKey(const Key('beautiful-prompt-model')));
      await tester.pump();
      expect(
        find.byKey(const Key('beautiful-prompt-option-model-precise')),
        findsOneWidget,
      );
      capture('model menu', retained);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(
        find.byKey(const Key('beautiful-prompt-option-model-precise')),
        findsNothing,
      );
      capture('model dismissed', retained);

      // Flutter web binds its editing DOM element to this semantic identity.
      // Keeping only the GlobalKey EditableText state is insufficient if an
      // unkeyed ancestor is replaced when the menu is inserted or removed.
      expect(
        snapshots.values.toSet(),
        hasLength(1),
        reason: 'Prompt semantic identity changed across menus: $snapshots',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      semantics.dispose();
    }
  });
}
