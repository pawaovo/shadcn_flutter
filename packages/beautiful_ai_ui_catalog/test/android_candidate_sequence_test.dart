import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/catalog_android_candidate_test.dart'
    show readAndroidCandidateStageSnapshot;
import '../integration_test/support/android_candidate_protocol.dart';
import '../integration_test/support/chat_send_diagnostics.dart';
import '../integration_test/support/interactions.dart';

void main() {
  test(
    'prompt command requires its real menu before action and activation',
    () {
      const nonce = '00000000000000000000000000000000';
      const source = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const stageNonce = '11111111111111111111111111111111';
      const spec = AndroidCandidateStageSpec.promptCommand;
      var snapshot = <String, Object?>{
        'input': <String, Object?>{
          'text': spec.text,
          'selectionBase': 5,
          'selectionExtent': 5,
          'composingBase': 1,
          'composingExtent': 5,
        },
        'editor_primary_focus': true,
        'send_count': 1,
        'send_enabled_semantics': 'isFalse',
        'view_insets_bottom_physical': 300,
        'observation_error': null,
      };
      final protocol = AndroidCandidateProtocol(
        nonce: nonce,
        sourceSha: source,
        spec: spec,
        stageNonce: stageNonce,
        readSnapshot: () => snapshot,
        elapsedMilliseconds: () => 0,
        newLeaseId: () => 'lease',
      );
      Map<String, String> action(String name) => <String, String>{
        'action': name,
        'nonce': nonce,
        'source_sha': source,
        'stage_id': spec.id,
        'stage_nonce': stageNonce,
        'candidate_id': 'rest-candidate',
      };
      protocol.offerCandidate();
      protocol.handle(action('claim'));
      protocol.handle(
        action('result')
          ..['lease_id'] = 'lease'
          ..['clicked'] = 'true'
          ..['native_drained'] = 'true',
      );
      snapshot = <String, Object?>{
        ...snapshot,
        'send_enabled_semantics': 'isTrue',
        'input': <String, Object?>{
          ...(snapshot['input']! as Map<String, Object?>),
          'composingBase': -1,
          'composingExtent': -1,
        },
      };
      expect(protocol.matchesCommitted(snapshot), isFalse);
      expect(protocol.beginSend, throwsStateError);
      const menu = <String, Object?>{
        'commands_label_count': 1,
        'restock_option_count': 1,
        'restock_option_enabled': 'isTrue',
      };
      for (final missing in <String, Object?>{
        'commands_label_count': 0,
        'restock_option_count': 0,
        'restock_option_enabled': 'isFalse',
      }.entries) {
        snapshot = <String, Object?>{
          ...snapshot,
          ...menu,
          missing.key: missing.value,
        };
        expect(protocol.matchesCommitted(snapshot), isFalse);
        expect(protocol.beginSend, throwsStateError);
      }
      snapshot = <String, Object?>{...snapshot, ...menu};
      protocol.beginSend();
      snapshot['restock_option_count'] = 0;
      expect(() => protocol.guardSendActivation(snapshot), throwsStateError);
      expect(protocol.stage, 'failed');
      expect(protocol.state()['send_activation_checked'], isFalse);
    },
  );

  test(
    'completed stages cannot pass a full journey at its target deadline',
    () {
      var now = 0;
      var next = 1;
      const nonce = '00000000000000000000000000000000';
      const source = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final sequence = AndroidCandidateSequence(
        nonce: nonce,
        sourceSha: source,
        elapsedMilliseconds: () => now,
        newStageNonce: () => (++next).toRadixString(16).padLeft(32, '0'),
        newLeaseId: () => 'lease-${++next}',
      );
      for (final spec in AndroidCandidateStageSpec.ordered) {
        final session = sequence.enterStage(spec.id);
        var snapshot = <String, Object?>{
          'input': <String, Object?>{
            'text': spec.text,
            'selectionBase': spec.selectionOffset,
            'selectionExtent': spec.selectionOffset,
            'composingBase': spec.composingBase,
            'composingExtent': spec.composingExtent,
          },
          'editor_primary_focus': true,
          'send_count': 1,
          'send_enabled_semantics': 'isFalse',
          'view_insets_bottom_physical': 300,
          'observation_error': null,
        };
        session.readSnapshot = () => snapshot;
        final protocol = session.protocol;
        protocol.offerCandidate();
        Map<String, String> action(String name) => <String, String>{
          'action': name,
          'nonce': nonce,
          'source_sha': source,
          'stage_id': spec.id,
          'stage_nonce': session.stageNonce,
          'candidate_id': 'candidate-${spec.id}',
        };
        final claim = protocol.handle(action('claim'));
        protocol.handle(
          action('result')
            ..['lease_id'] = claim['lease_id']! as String
            ..['clicked'] = 'true'
            ..['native_drained'] = 'true',
        );
        snapshot = <String, Object?>{
          ...snapshot,
          'send_enabled_semantics': 'isTrue',
          if (spec ==
              AndroidCandidateStageSpec.promptCommand) ...<String, Object?>{
            'commands_label_count': 1,
            'restock_option_count': 1,
            'restock_option_enabled': 'isTrue',
          },
          'input': <String, Object?>{
            ...(snapshot['input']! as Map<String, Object?>),
            'composingBase': -1,
            'composingExtent': -1,
          },
        };
        protocol.beginSend();
        protocol.guardSendActivation(snapshot);
        session.rpc.freeze();
        sequence.completeStage(spec.id);
      }
      expect(sequence.stageResults, hasLength(3));
      now = 600000;
      sequence.finishJourney(true);
      expect(sequence.journeyStatus, 'failed');
    },
  );

  testWidgets(
    'three fixed stage values commit before their real original actions',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      final semantics = tester.ensureSemantics();
      const nonce = '00000000000000000000000000000000';
      const source = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      var identifier = 10;
      final sequence = AndroidCandidateSequence(
        nonce: nonce,
        sourceSha: source,
        initialStageNonce: '11111111111111111111111111111111',
        elapsedMilliseconds: () => 0,
        newStageNonce: () => (++identifier).toRadixString(16).padLeft(32, '0'),
        newLeaseId: () => 'lease-${++identifier}',
      );
      Future<void> tap(Finder finder) async {
        await tapCatalogTarget(tester, finder);
        await tester.pump(const Duration(milliseconds: 180));
      }

      try {
        await tester.pumpWidget(const CatalogApp());
        final chat = find.byKey(const Key('catalog-chat'));
        final prompt = find.byKey(const Key('catalog-prompt-bar'));
        Finder promptControl(String key) =>
            find.descendant(of: prompt, matching: find.byKey(Key(key)));
        for (final spec in AndroidCandidateStageSpec.ordered) {
          if (spec == AndroidCandidateStageSpec.promptSend) {
            await tap(promptControl('beautiful-prompt-model'));
            await tap(promptControl('beautiful-prompt-option-model-precise'));
            await tap(promptControl('beautiful-prompt-add'));
            await tap(
              find.descendant(
                of: prompt,
                matching: find.text('Add photos and files'),
              ),
            );
          }
          final root = spec == AndroidCandidateStageSpec.chatSend
              ? chat
              : prompt;
          final editor = find.descendant(
            of: root,
            matching: find.byType(EditableText),
          );
          await tester.ensureVisible(editor);
          await enterCatalogText(tester, editor, spec.text);
          final committed = tester
              .widget<EditableText>(editor)
              .controller
              .value;
          // These platform-value updates replay the three composition boundaries
          // in a headless regression. They are not native IME acceptance evidence.
          tester.testTextInput.updateEditingValue(
            committed.copyWith(
              composing: TextRange(
                start: spec.composingBase,
                end: spec.composingExtent,
              ),
            ),
          );
          await tester.pump();
          final session = sequence.enterStage(spec.id);
          session.readSnapshot = () =>
              readAndroidCandidateStageSnapshot(tester, root, spec);
          session.rpc.beginLiveObservation();
          final protocol = session.protocol;
          protocol.beginCandidateWindow();
          final composing = session.readSnapshot();
          expect(protocol.matchesComposing(composing), isTrue);
          expect(composing['send_enabled_semantics'], 'isFalse');
          if (spec == AndroidCandidateStageSpec.promptSend) {
            expect(composing['selected_model_id'], 'precise');
            expect(composing['inventory_attachment_count'], 1);
          }
          protocol.offerCandidate();
          Future<Map<String, Object?>> request(
            String action, [
            Map<String, String> values = const {},
          ]) async {
            final response = sequence.request(<String, String>{
              'nonce': nonce,
              'source_sha': source,
              'stage_id': spec.id,
              'stage_nonce': session.stageNonce,
              'action': action,
              ...values,
            });
            session.rpc.drain();
            return response;
          }

          final claim = await request('claim', <String, String>{
            'candidate_id': 'candidate-${spec.id}',
          });
          // A candidate receipt without an actual committed editing value still
          // cannot start the original action.
          await request('result', <String, String>{
            'candidate_id': 'candidate-${spec.id}',
            'lease_id': claim['lease_id']! as String,
            'clicked': 'true',
            'native_drained': 'true',
          });
          expect(protocol.beginSend, throwsStateError);
          tester.testTextInput.updateEditingValue(committed);
          await tester.pump();
          expect(protocol.matchesCommitted(session.readSnapshot()), isTrue);
          protocol.beginSend();
          protocol.guardSendActivation(session.readSnapshot());
          if (spec == AndroidCandidateStageSpec.chatSend) {
            await sendCatalogChatOnce(
              tester,
              chat,
              spec.text,
              onDiagnostic: (_) {},
            );
            await tap(
              find.descendant(of: chat, matching: find.text('Stop response')),
            );
            expect(
              find.text('Demonstration response stopped.'),
              findsOneWidget,
            );
          } else if (spec == AndroidCandidateStageSpec.promptCommand) {
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pump();
            expect(
              tester.widget<EditableText>(editor).controller.text,
              '/restock ',
            );
          } else {
            await tap(promptControl('beautiful-prompt-send'));
            expect(
              find.text(
                'Prompt received: Prepare the seasonal restock · 1 files · precise',
              ),
              findsOneWidget,
            );
            expect(
              tester.widget<EditableText>(editor).controller.text,
              isEmpty,
            );
          }
          final after = session.readSnapshot();
          session.readSnapshot = () => after;
          protocol.state();
          session.rpc.freeze();
          sequence.completeStage(spec.id);
          expect(sequence.state()['stage'], 'stage_done');
          expect(sequence.state()['original_action_passed'], isTrue);
        }
        expect(sequence.state()['completed_stage_ids'], <String>[
          'chat_send',
          'prompt_command',
          'prompt_send',
        ]);
        // Completing these three actions alone never claims the remainder of the
        // full P3 journey; its original Response still owns final acceptance.
        expect(sequence.state()['journey_status'], 'running');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
        tester.view.resetViewInsets();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
