import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui_catalog/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/android_candidate_protocol.dart';
import '../integration_test/support/interactions.dart';

void main() {
  const nonce = '0123456789abcdef0123456789abcdef';
  const source = '0123456789abcdef0123456789abcdef01234567';
  late int now;
  late Map<String, Object?> snapshot;
  late AndroidCandidateProtocol protocol;

  Map<String, String> action(String name) => <String, String>{
    'action': name,
    'nonce': nonce,
    'source_sha': source,
  };
  Map<String, Object?> composing() => <String, Object?>{
    'input': <String, Object?>{
      'text': AndroidCandidateProtocol.expectedText,
      'selectionBase': 20,
      'selectionExtent': 20,
      'composingBase': 11,
      'composingExtent': 20,
    },
    'editor_primary_focus': true,
    'send_count': 1,
    'send_enabled_semantics': 'isFalse',
    'view_insets_bottom_physical': 800.0,
    'observation_error': null,
  };
  Map<String, Object?> committed() => composing()
    ..['input'] = <String, Object?>{
      'text': AndroidCandidateProtocol.expectedText,
      'selectionBase': 20,
      'selectionExtent': 20,
      'composingBase': -1,
      'composingExtent': -1,
    }
    ..['send_enabled_semantics'] = 'isTrue';
  Map<String, Object?> claim() => protocol.handle(
    action('claim')..['candidate_id'] = 'actual-native-ticket',
  );
  void acknowledge() => protocol.handle(
    action('result')
      ..['candidate_id'] = 'actual-native-ticket'
      ..['lease_id'] = 'one-lease'
      ..['clicked'] = 'true'
      ..['native_drained'] = 'true',
  );

  setUp(() {
    now = 0;
    snapshot = composing();
    protocol = AndroidCandidateProtocol(
      nonce: nonce,
      sourceSha: source,
      readSnapshot: () => snapshot,
      elapsedMilliseconds: () => now,
      newLeaseId: () => 'one-lease',
    );
  });

  test('one native acknowledgment and committed input permit one send', () {
    protocol.offerCandidate();
    final lease = claim();
    expect(lease['lease_remaining_ms'], 5000);
    expect(lease['snapshot'], same(snapshot));
    // A host click receipt alone is never a committed editing value.
    acknowledge();
    expect(protocol.beginSend, throwsStateError);
    snapshot = committed();
    protocol.beginSend();
    expect(protocol.beginSend, throwsStateError);
    protocol.guardSendActivation(snapshot);
    protocol.pass();
    expect(protocol.state()['stage'], 'passed');
    expect(claim, throwsStateError);
  });

  test('a framework committed value cannot impersonate native preparation', () {
    snapshot = committed();
    expect(protocol.offerCandidate, throwsStateError);
    expect(protocol.stage, 'preparing');
  });

  test('wrong nonce or source never obtains authority', () {
    protocol.offerCandidate();
    for (final key in <String>['nonce', 'source_sha']) {
      expect(
        () => protocol.handle(
          action('claim')
            ..[key] = 'wrong'
            ..['candidate_id'] = 'native',
        ),
        throwsStateError,
      );
    }
    expect(protocol.stage, 'awaiting_candidate');
  });

  test('claim re-reads actual editor and fails after input changes', () {
    protocol.offerCandidate();
    snapshot = committed();
    expect(claim, throwsStateError);
    expect(protocol.stage, 'failed');
    snapshot = composing();
    expect(claim, throwsStateError);
  });

  test('repeat claim cannot renew the monotonic action lease', () {
    protocol.offerCandidate();
    claim();
    now = 800;
    expect(claim, throwsStateError);
    expect(protocol.state()['lease_remaining_ms'], 4200);
  });

  test('late click receipt cannot revive the target after lease expiry', () {
    protocol.offerCandidate();
    claim();
    now = 5000;
    snapshot = committed();
    expect(acknowledge, throwsStateError);
    expect(protocol.stage, 'failed');
    expect(protocol.beginSend, throwsStateError);
  });

  test('expired lease still holds target until matching native drain', () {
    protocol.offerCandidate();
    claim();
    expect(protocol.state()['native_drained'], isFalse);
    now = 5000;
    expect(protocol.stage, 'failed');
    expect(protocol.state()['native_call_pending'], isTrue);
    expect(protocol.state()['lease_remaining_ms'], 0);
    now = 40000;
    expect(protocol.state()['native_call_pending'], isTrue);
    expect(
      () => protocol.handle(action('drained')..['lease_id'] = 'other'),
      throwsStateError,
    );
    expect(protocol.state()['native_call_pending'], isTrue);
    protocol.handle(action('drained')..['lease_id'] = 'one-lease');
    expect(protocol.state()['native_drained'], isTrue);
    expect(protocol.state()['native_call_pending'], isFalse);
    expect(protocol.stage, 'failed');
    snapshot = committed();
    expect(acknowledge, throwsStateError);
    expect(protocol.beginSend, throwsStateError);
  });

  test('success without native call return cannot authorize Send', () {
    protocol.offerCandidate();
    claim();
    protocol.handle(
      action('result')
        ..['candidate_id'] = 'actual-native-ticket'
        ..['lease_id'] = 'one-lease'
        ..['clicked'] = 'true',
    );
    expect(protocol.stage, 'failed');
    expect(protocol.state()['native_call_pending'], isTrue);
    snapshot = committed();
    expect(protocol.beginSend, throwsStateError);
  });

  test('abort before claim requires no artificial native drain', () {
    protocol.handle(
      action('abort')..['error'] = 'stopped before native action',
    );
    expect(protocol.state()['native_drained'], isTrue);
    expect(protocol.state()['native_call_pending'], isFalse);
    expect(
      () => protocol.handle(action('drained')..['lease_id'] = 'one-lease'),
      throwsStateError,
    );
  });

  test('a returned native call cannot authorize Send after lease expiry', () {
    protocol.offerCandidate();
    claim();
    acknowledge();
    expect(protocol.state()['native_drained'], isTrue);
    now = 5000;
    snapshot = committed();
    expect(protocol.beginSend, throwsStateError);
    expect(protocol.stage, 'failed');
    expect(protocol.nativeCallPending, isFalse);
  });

  test('wrong lease or candidate receipt cannot acknowledge the click', () {
    protocol.offerCandidate();
    claim();
    for (final key in <String>['lease_id', 'candidate_id']) {
      expect(
        () => protocol.handle(
          action('result')
            ..['lease_id'] = 'one-lease'
            ..['candidate_id'] = 'actual-native-ticket'
            ..['clicked'] = 'true'
            ..[key] = 'other',
        ),
        throwsStateError,
      );
    }
    expect(protocol.state()['native_click_acknowledged'], isFalse);
    acknowledge();
    expect(acknowledge, throwsStateError);
  });

  test('abort refuses future actions while preserving lease drain', () {
    protocol.offerCandidate();
    claim();
    now = 1250;
    protocol.handle(action('abort')..['error'] = 'native transport failed');
    expect(protocol.stage, 'failed');
    expect(protocol.leaseRemainingMilliseconds, 3750);
    expect(protocol.nativeCallPending, isTrue);
    expect(acknowledge, throwsStateError);
    expect(claim, throwsStateError);
    protocol.fail('later cleanup error');
    expect(protocol.state()['failure'], contains('native transport failed'));
  });

  test('host failure is terminal and no empty composition can override it', () {
    protocol.offerCandidate();
    claim();
    protocol.handle(
      action('result')
        ..['lease_id'] = 'one-lease'
        ..['candidate_id'] = 'actual-native-ticket'
        ..['clicked'] = 'false'
        ..['error'] = 'candidate expired',
    );
    snapshot = committed();
    expect(protocol.stage, 'failed');
    expect(protocol.beginSend, throwsStateError);
  });

  test('insufficient remaining time cannot issue an action lease', () {
    protocol.offerCandidate();
    now = 80001;
    expect(claim, throwsStateError);
    expect(protocol.leaseRemainingMilliseconds, 0);
    expect(protocol.stage, 'failed');
  });

  test('overall deadline is terminal even when no native claim arrives', () {
    protocol.offerCandidate();
    now = 90000;
    expect(protocol.state()['stage'], 'failed');
    expect(claim, throwsStateError);
  });

  test(
    'full journey time before Chat does not consume the candidate window',
    () {
      protocol = AndroidCandidateProtocol(
        nonce: nonce,
        sourceSha: source,
        readSnapshot: () => snapshot,
        elapsedMilliseconds: () => now,
        newLeaseId: () => 'one-lease',
        deadlineMilliseconds: 600000,
      );
      now = 200000;
      expect(protocol.stage, 'preparing');
      protocol.beginCandidateWindow();
      expect(protocol.state()['remaining_ms'], 120000);
      expect(protocol.beginCandidateWindow, throwsStateError);
      protocol.offerCandidate();
      now = 320000;
      expect(protocol.stage, 'failed');
    },
  );

  test('P2 and P3 regain full journey deadline after native handoff', () {
    protocol = AndroidCandidateProtocol(
      nonce: nonce,
      sourceSha: source,
      readSnapshot: () => snapshot,
      elapsedMilliseconds: () => now,
      newLeaseId: () => 'one-lease',
      deadlineMilliseconds: 600000,
    );
    protocol.beginCandidateWindow();
    protocol.offerCandidate();
    claim();
    acknowledge();
    snapshot = committed();
    protocol.beginSend();
    protocol.guardSendActivation(snapshot);
    now = 130000;
    expect(protocol.stage, 'sending');
    protocol.pass(captureSnapshot: false);
    expect(protocol.stage, 'passed');
  });

  test('input alone cannot send without the matching native receipt', () {
    protocol.offerCandidate();
    claim();
    snapshot = committed();
    expect(protocol.beginSend, throwsStateError);
    expect(protocol.stage, 'action_claimed');
  });

  for (final failure in <String>['guard_throw', 'abort', 'composition']) {
    testWidgets('final activation $failure sends no pointer or host message', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      final semantics = tester.ensureSemantics();
      var pointerDowns = 0;
      var guardCalls = 0;
      var revealChanged = false;
      void observePointer(PointerEvent event) {
        if (event is PointerDownEvent) pointerDowns++;
      }

      try {
        await tester.pumpWidget(const CatalogApp());
        final chat = find.byKey(const Key('catalog-chat'));
        final composer = find.descendant(
          of: chat,
          matching: find.byType(EditableText),
        );
        final send = find.descendant(of: chat, matching: find.text('Send'));
        await tester.ensureVisible(composer);
        await enterCatalogText(
          tester,
          composer,
          AndroidCandidateProtocol.expectedText,
        );
        final committedValue = tester
            .widget<EditableText>(composer)
            .controller
            .value;
        Map<String, Object?> readLiveSnapshot() {
          final editor = tester.widget<EditableText>(composer);
          return <String, Object?>{
            'input': editor.controller.value.toJSON(),
            'editor_primary_focus': editor.focusNode.hasPrimaryFocus,
            'send_count': send.evaluate().length,
            'send_enabled_semantics': tester
                .getSemantics(send)
                .getSemanticsData()
                .flagsCollection
                .isEnabled
                .name,
            'view_insets_bottom_physical': tester.view.viewInsets.bottom,
            'observation_error': null,
          };
        }

        protocol = AndroidCandidateProtocol(
          nonce: nonce,
          sourceSha: source,
          readSnapshot: readLiveSnapshot,
          elapsedMilliseconds: () => now,
          newLeaseId: () => 'one-lease',
        );
        // Reproduce the actual editing-value race through TestTextInput. This
        // headless regression verifies the guard, not an Android IME session.
        void beginComposition() => tester.testTextInput.updateEditingValue(
          committedValue.copyWith(
            composing: const TextRange(start: 11, end: 20),
          ),
        );
        beginComposition();
        await tester.pump();
        protocol.offerCandidate();
        claim();
        tester.testTextInput.updateEditingValue(committedValue);
        await tester.pump();
        acknowledge();
        protocol.beginSend();
        tester.binding.pointerRouter.addGlobalRoute(observePointer);
        await expectLater(
          tapCatalogTarget(
            tester,
            send,
            pump: (duration) async {
              await tester.pump(duration);
              if (!revealChanged) {
                revealChanged = true;
                if (failure == 'abort') {
                  protocol.handle(
                    action('abort')..['error'] = 'abort during reveal',
                  );
                } else if (failure == 'composition') {
                  beginComposition();
                  await tester.pump();
                }
              }
            },
            beforeActivation: () {
              guardCalls++;
              if (failure == 'guard_throw') {
                throw StateError('Activation rejected.');
              }
              protocol.guardSendActivation(readLiveSnapshot());
            },
          ),
          throwsStateError,
        );
        expect(guardCalls, 1);
        expect(pointerDowns, 0);
        final host = tester.widget<BeautifulChat>(chat);
        expect(
          host.messages.where(
            (message) =>
                message.role == BeautifulChatRole.user &&
                message.text == AndroidCandidateProtocol.expectedText,
          ),
          isEmpty,
        );
        expect(host.status, BeautifulChatStatus.idle);
        expect(tester.takeException(), isNull);
      } finally {
        tester.binding.pointerRouter.removeGlobalRoute(observePointer);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
        tester.view.resetViewInsets();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  for (final change in <String, Object?>{
    'editor_primary_focus': false,
    'send_count': 2,
    'send_enabled_semantics': 'isTrue',
    'view_insets_bottom_physical': 0.0,
    'observation_error': 'semantics lookup failed',
  }.entries) {
    test('candidate precondition rejects ${change.key}', () {
      snapshot[change.key] = change.value;
      expect(protocol.offerCandidate, throwsStateError);
    });
  }

  for (final change in <String, Object?>{
    'text': 'Check cone inventories',
    'selectionBase': 11,
    'selectionExtent': 11,
    'composingBase': 0,
    'composingExtent': 10,
  }.entries) {
    test('candidate precondition rejects changed ${change.key}', () {
      (snapshot['input']! as Map<String, Object?>)[change.key] = change.value;
      expect(protocol.offerCandidate, throwsStateError);
    });
  }
}
