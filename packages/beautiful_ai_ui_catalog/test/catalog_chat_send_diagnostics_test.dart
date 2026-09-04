import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/chat_send_diagnostics.dart';
import '../integration_test/support/interactions.dart';

void main() {
  testWidgets(
    'diagnostic getter failure preserves the original missing tap error',
    (tester) async {
      // The diagnostic expects BeautifulChat, but the actual tap target is absent.
      // Both before/after diagnostic getters fail; the original tap error must win.
      const key = Key('invalid-chat-fixture');
      await tester.pumpWidget(const SizedBox(key: key));
      Map<String, Object?>? diagnostic;
      await expectLater(
        sendCatalogChatOnce(
          tester,
          find.byKey(key),
          'Check cone inventory',
          onDiagnostic: (value) {
            diagnostic = value;
            throw StateError('synthetic diagnostic output failure');
          },
        ),
        throwsA(
          isA<TestFailure>().having(
            (error) => error.message,
            'original tap failure',
            contains('expected exactly one mounted target, found 0'),
          ),
        ),
      );
      final samples = diagnostic!['samples']! as List<Map<String, Object?>>;
      expect(samples.first['phase'], 'before_tap');
      expect(samples.first['observation_error'], contains('BeautifulChat'));
      expect(samples[1]['phase'], 'after_tap');
      expect(samples[1]['observation_error'], contains('BeautifulChat'));
      expect(
        samples.last['observation_error'],
        contains('synthetic diagnostic output failure'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pointer diagnostic getter errors do not interrupt one real Send',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var failReads = false;
      final chat = find.byWidgetPredicate((widget) {
        if (widget is! BeautifulChat) return false;
        if (failReads) {
          throw StateError('synthetic pointer diagnostic getter failure');
        }
        return true;
      });
      void injectReadFailure(PointerEvent event) {
        if (event is PointerDownEvent) failReads = true;
      }

      try {
        await tester.pumpWidget(const CatalogApp());
        final composer = find.descendant(
          of: chat,
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(composer);
        await enterCatalogText(tester, composer, 'Check cone inventory');
        Map<String, Object?>? diagnostic;
        tester.binding.pointerRouter.addGlobalRoute(injectReadFailure);
        await sendCatalogChatOnce(
          tester,
          chat,
          'Check cone inventory',
          onDiagnostic: (value) {
            diagnostic = value;
            failReads =
                false; // Restore the finder for the unchanged host guard.
          },
        );
        final samples = diagnostic!['samples']! as List<Map<String, Object?>>;
        for (final phase in <String>[
          'pointer_down',
          'pointer_up',
          'after_tap',
        ]) {
          final sample = samples.singleWhere(
            (sample) => sample['phase'] == phase,
          );
          expect(
            sample['observation_error'],
            contains('synthetic pointer diagnostic getter failure'),
          );
        }
        expect(
          tester.widget<BeautifulChat>(chat).status,
          BeautifulChatStatus.responding,
        );
        expect(tester.takeException(), isNull);
      } finally {
        tester.binding.pointerRouter.removeGlobalRoute(injectReadFailure);
        failReads = false;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
      }
    },
  );

  for (final composing in <bool>[true, false]) {
    testWidgets(
      composing
          ? 'draft-only text cannot pass host acceptance after disabled Send'
          : 'one Android touch sends once and records pointer focus and geometry',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(const CatalogApp());
          await tester.pump();
          final chat = find.byKey(const Key('catalog-chat'));
          final composer = find.descendant(
            of: chat,
            matching: find.byType(EditableText),
          );
          await tester.ensureVisible(composer);
          await enterCatalogText(tester, composer, 'Check cone inventory');
          if (composing) {
            // Deliberate negative control, not an observed Android CI event.
            tester.testTextInput.updateEditingValue(
              const TextEditingValue(
                text: 'Check cone inventory',
                selection: TextSelection.collapsed(offset: 20),
                composing: TextRange(start: 11, end: 20),
              ),
            );
            await tester.pump();
          }
          Map<String, Object?>? diagnostic;
          final send = sendCatalogChatOnce(
            tester,
            chat,
            'Check cone inventory',
            onDiagnostic: (value) => diagnostic = value,
          );
          if (composing) {
            await expectLater(
              send,
              throwsA(
                isA<TestFailure>().having(
                  (failure) => failure.message,
                  'host acceptance failure',
                  contains('Chat host must accept'),
                ),
              ),
            );
            // This old journey assertion still passes on the unsent draft.
            expect(
              find.descendant(
                of: chat,
                matching: find.text('Check cone inventory'),
              ),
              findsOneWidget,
            );
            expect(
              tester.widget<BeautifulChat>(chat).status,
              BeautifulChatStatus.idle,
            );
            expect(find.text('Stop response'), findsNothing);
          } else {
            await send;
            expect(
              tester.widget<BeautifulChat>(chat).status,
              BeautifulChatStatus.responding,
            );
            expect(find.text('Stop response'), findsOneWidget);
          }
          final samples = diagnostic!['samples']! as List<Map<String, Object?>>;
          final down = samples
              .where((sample) => sample['phase'] == 'pointer_down')
              .single;
          final up = samples
              .where((sample) => sample['phase'] == 'pointer_up')
              .single;
          expect(down['pointer'], up['pointer']);
          expect(down['kind'], 'touch');
          expect(down['send_rect'], up['send_rect']);
          expect(down['editor_primary_focus'], isTrue);
          expect(up['editor_primary_focus'], isTrue);
          expect(
            samples.first['send_enabled_semantics'],
            composing ? 'isFalse' : 'isTrue',
          );
          var previousOffset = -1;
          for (final sample in samples) {
            expect(
              sample['utc_epoch_us'],
              isA<int>().having(
                (value) => value,
                'actual epoch',
                greaterThan(0),
              ),
            );
            expect(sample['elapsed_us'], greaterThanOrEqualTo(previousOffset));
            previousOffset = sample['elapsed_us']! as int;
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          semantics.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
