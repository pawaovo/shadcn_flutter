import 'dart:convert';

import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/interactions.dart';
import '../integration_test/support/prompt_input_diagnostics.dart';

void main() {
  testWidgets(
    'passive observer preserves slash Enter and captures actual state',
    (tester) async {
      final semantics = tester.ensureSemantics();
      CatalogPromptInputObserver? observer;
      try {
        await tester.pumpWidget(const CatalogApp());
        final prompt = find.byKey(const Key('catalog-prompt-bar'));
        final editor = find.descendant(
          of: prompt,
          matching: find.byType(EditableText),
        );
        final report = <String, dynamic>{};
        observer = CatalogPromptInputObserver(
          tester,
          prompt,
          action: 'slash_enter',
          reportData: report,
        );
        await tester.ensureVisible(editor);
        await tester.pump();
        await enterCatalogText(tester, editor, '/rest');
        await tester.pump();
        observer.sample('before_enter');
        final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        observer.sample('after_enter', keyDownHandled: handled);
        await tester.pump();
        expect(
          tester.widget<EditableText>(editor).controller.text,
          '/restock ',
        );
        observer.finish();
        final before = observer.samples.singleWhere(
          (sample) => sample['phase'] == 'before_enter',
        );
        expect((before['input']! as Map)['text'], '/rest');
        expect((before['input']! as Map)['composingBase'], -1);
        expect(before['editor_primary_focus'], isTrue);
        expect(before['commands_label_count'], 1);
        expect((before['restock_option']! as Map)['count'], 1);
        expect((before['restock_option']! as Map)['enabled'], 'isTrue');
        final events = observer.samples
            .where((sample) => sample['phase'] == 'keyboard_event')
            .toList();
        expect(
          events.map((sample) => (sample['key']! as Map)['type']),
          <String>['KeyDownEvent', 'KeyUpEvent'],
        );
        expect(
          events.every(
            (sample) =>
                (sample['key']! as Map)['logical_key'] ==
                LogicalKeyboardKey.enter.keyId,
          ),
          isTrue,
        );
        expect(
          observer.samples.singleWhere(
            (sample) => sample['phase'] == 'after_enter',
          )['key_down_handled_by_framework'],
          handled,
        );
        expect(
          observer.samples
              .where((sample) => sample['phase'] == 'controller_changed')
              .map((sample) => (sample['input']! as Map)['text']),
          containsAll(<String>['/rest', '/restock ']),
        );
        expect(observer.errors, isEmpty);
        expect(() => jsonEncode(report), returnsNormally);
        expect(tester.takeException(), isNull);
      } finally {
        observer?.finish();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'passive observer preserves one Prompt Send and records host receipt',
    (tester) async {
      final semantics = tester.ensureSemantics();
      CatalogPromptInputObserver? observer;
      var pointerDowns = 0;
      void countPointer(PointerEvent event) {
        if (event is PointerDownEvent) pointerDowns++;
      }

      try {
        await tester.pumpWidget(const CatalogApp());
        final prompt = find.byKey(const Key('catalog-prompt-bar'));
        final editor = find.descendant(
          of: prompt,
          matching: find.byType(EditableText),
        );
        observer = CatalogPromptInputObserver(
          tester,
          prompt,
          action: 'prompt_send',
          reportData: <String, dynamic>{},
        );
        await tester.ensureVisible(editor);
        await enterCatalogText(tester, editor, 'Observer prompt message');
        observer.sample('before_send');
        tester.binding.pointerRouter.addGlobalRoute(countPointer);
        await tapCatalogTarget(
          tester,
          find.descendant(
            of: prompt,
            matching: find.byKey(const Key('beautiful-prompt-send')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 180));
        observer.sample('after_send');
        expect(pointerDowns, 1);
        expect(tester.widget<EditableText>(editor).controller.text, isEmpty);
        final after = observer.samples.last;
        expect(
          after['host_prompt_received'],
          contains(
            'Prompt received: Observer prompt message · 0 files · balanced',
          ),
        );
        expect((after['input']! as Map)['text'], isEmpty);
        expect(observer.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        tester.binding.pointerRouter.removeGlobalRoute(countPointer);
        observer?.finish();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
      }
    },
  );

  testWidgets('observer getter failures retain the original action failure', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    final report = <String, dynamic>{};
    final observer = CatalogPromptInputObserver(
      tester,
      find.byKey(const Key('missing-prompt')),
      action: 'slash_enter',
      reportData: report,
    );
    final original = StateError('original action failure');
    expect(() {
      try {
        observer.sample('before_enter');
        throw original;
      } finally {
        observer.finish();
      }
    }, throwsA(same(original)));
    expect(observer.errors, isNotEmpty);
    expect(
      (report['prompt_input_diagnostics'] as List).single,
      same(observer.report),
    );
    expect(() => jsonEncode(report), returnsNormally);
    expect(tester.takeException(), isNull);
  });
}
