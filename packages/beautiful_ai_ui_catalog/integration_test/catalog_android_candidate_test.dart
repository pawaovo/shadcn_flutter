import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'catalog_journey_test.dart' as original;
import 'support/android_candidate_protocol.dart';

String? _enabled(WidgetTester tester, Finder finder, int count) => count == 1
    ? tester
          .getSemantics(finder)
          .getSemanticsData()
          .flagsCollection
          .isEnabled
          .name
    : null;

/// Reads the actual Catalog state for candidate gates and final observation.
Map<String, Object?> readAndroidCandidateSnapshot(
  WidgetTester tester,
  Finder chat,
) {
  final composer = find.descendant(
    of: chat,
    matching: find.byType(EditableText),
  );
  final send = find.descendant(of: chat, matching: find.text('Send'));
  final sendCount = send.evaluate().length;
  final editor = tester.widget<EditableText>(composer);
  final host = tester.widget<BeautifulChat>(chat);
  return <String, Object?>{
    'input': editor.controller.value.toJSON(),
    'editor_primary_focus': editor.focusNode.hasPrimaryFocus,
    'send_count': sendCount,
    'send_enabled_semantics': _enabled(tester, send, sendCount),
    'view_insets_bottom_physical': tester.view.viewInsets.bottom,
    'platform_semantics_enabled':
        tester.binding.platformDispatcher.semanticsEnabled,
    'device_pixel_ratio': tester.view.devicePixelRatio,
    'host_status': host.status.name,
    'host_messages': <Map<String, Object?>>[
      for (final message in host.messages)
        <String, Object?>{'role': message.role.name, 'text': message.text},
    ],
    'observation_error': null,
  };
}

Map<String, Object?> readAndroidCandidateStageSnapshot(
  WidgetTester tester,
  Finder root,
  AndroidCandidateStageSpec spec,
) {
  if (spec == AndroidCandidateStageSpec.chatSend) {
    return readAndroidCandidateSnapshot(tester, root);
  }
  Finder inside(Finder finder) => find.descendant(of: root, matching: finder);
  final editor = tester.widget<EditableText>(inside(find.byType(EditableText)));
  final component = tester.widget<BeautifulPromptBar>(root);
  final send = inside(find.byKey(const Key('beautiful-prompt-send')));
  final sendCount = send.evaluate().length;
  final option = inside(
    find.byKey(const Key('beautiful-prompt-option-command-restock')),
  );
  final optionCount = option.evaluate().length;
  return <String, Object?>{
    'input': editor.controller.value.toJSON(),
    'editor_primary_focus': editor.focusNode.hasPrimaryFocus,
    'send_count': sendCount,
    'send_enabled_semantics': _enabled(tester, send, sendCount),
    'view_insets_bottom_physical': tester.view.viewInsets.bottom,
    'platform_semantics_enabled':
        tester.binding.platformDispatcher.semanticsEnabled,
    'device_pixel_ratio': tester.view.devicePixelRatio,
    'selected_model_id': component.selectedModelId,
    'inventory_attachment_count': inside(find.text('Remove inventory-1.csv'))
        .evaluate()
        .length,
    'commands_label_count': inside(find.text(component.commandsLabel))
        .evaluate()
        .length,
    'restock_option_count': optionCount,
    'restock_option_enabled': _enabled(tester, option, optionCount),
    'host_prompt_received': <String>[
      for (final text in tester.widgetList<Text>(
        find.textContaining('Prompt received:'),
      ))
        if (text.data != null) text.data!,
    ],
    'observation_error': null,
  };
}

/// The original full journey with exactly three fixed native candidate stages.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final clock = Stopwatch()..start();
  String randomNonce() {
    final random = Random.secure();
    return List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  final sequence = AndroidCandidateSequence(
    nonce: const String.fromEnvironment('CATALOG_ANDROID_CANDIDATE_NONCE'),
    sourceSha: const String.fromEnvironment(
      'CATALOG_ANDROID_CANDIDATE_SOURCE_SHA',
    ),
    initialStageNonce: const String.fromEnvironment(
      'CATALOG_ANDROID_CANDIDATE_CHAT_STAGE_NONCE',
    ),
    elapsedMilliseconds: () => clock.elapsedMilliseconds,
    newStageNonce: randomNonce,
    newLeaseId: randomNonce,
  );
  final stages = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'suite': 'catalog_android_candidate',
    'scope':
        'original full Catalog journey with three fixed native IME candidates',
    'status': 'started',
    'stages': stages,
  };
  binding.reportData = <String, dynamic>{'android_candidate': report};
  String? activeId;
  void Function()? activeFreeze;
  void Function(Object, Object)? activeGuard;

  developer.registerExtension(AndroidCandidateProtocol.extensionName, (
    method,
    parameters,
  ) async {
    await Future<void>.delayed(Duration.zero);
    try {
      return developer.ServiceExtensionResponse.result(
        jsonEncode(await sequence.request(parameters)),
      );
    } catch (error) {
      return developer.ServiceExtensionResponse.error(
        developer.ServiceExtensionResponse.extensionError,
        '$error',
      );
    }
  });
  setUpAll(() {
    if (!kDebugMode ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !const bool.fromEnvironment('CATALOG_ANDROID_CANDIDATE')) {
      throw StateError(
        'This explicit candidate target requires Android debug.',
      );
    }
  });

  androidCandidateBeforeStageAction =
      (testerObject, rootObject, stageId) async {
        final tester = testerObject as WidgetTester;
        final root = rootObject as Finder;
        final session = sequence.enterStage(stageId);
        final spec = session.spec;
        final protocol = session.protocol;
        final rpc = session.rpc;
        protocol.beginCandidateWindow();
        final composer = find.descendant(
          of: root,
          matching: find.byType(EditableText),
        );
        final controller = tester.widget<EditableText>(composer).controller;
        final inputTrace = <Map<String, Object?>>[];
        final stageReport = <String, Object?>{
          'stage_id': spec.id,
          'stage_nonce': session.stageNonce,
          'events': protocol.events,
          'input_trace': inputTrace,
        };
        stages.add(stageReport);
        activeId = stageId;
        rpc.beginLiveObservation();
        session.readSnapshot = () =>
            readAndroidCandidateStageSnapshot(tester, root, spec);
        final readActivationSnapshot = session.readSnapshot;
        var frozen = false;
        void freezeObservation() {
          if (frozen) return;
          try {
            final last = readActivationSnapshot();
            stageReport['after_action_or_terminal_snapshot'] = last;
            session.readSnapshot = () => last;
            protocol.state();
          } catch (error) {
            protocol.fail('Final candidate observer failed: $error');
            stageReport['final_observer_error'] = '$error';
            session.readSnapshot = () => <String, Object?>{
              'observation_error': '$error',
            };
          } finally {
            frozen = true;
            rpc.freeze();
            activeGuard = null;
          }
        }

        activeFreeze = freezeObservation;
        activeGuard = (activationTester, activationRoot) {
          rpc.drain();
          if (frozen ||
              !identical(tester, activationTester) ||
              !identical(root, activationRoot) ||
              sequence.current != session) {
            throw StateError(
              'The original action no longer owns this candidate stage.',
            );
          }
          final fresh = readActivationSnapshot();
          protocol.guardSendActivation(fresh);
          stageReport['activation_snapshot'] = fresh;
        };
        void recordInput() {
          if (inputTrace.length >= 128) {
            protocol.fail('Unexpectedly many actual editing updates.');
            return;
          }
          inputTrace.add(<String, Object?>{
            'elapsed_ms': clock.elapsedMilliseconds,
            'input': controller.value.toJSON(),
          });
          if (controller.text != spec.text) {
            protocol.fail('The native candidate changed the original text.');
          }
        }

        controller.addListener(recordInput);
        recordInput();
        Object? primaryError;
        Future<void> until(bool Function() condition) async {
          while (true) {
            rpc.drain();
            if (protocol.stage == 'failed') {
              throw StateError('${protocol.state()['failure']}');
            }
            if (controller.text != spec.text ||
                !tester
                    .widget<EditableText>(composer)
                    .focusNode
                    .hasPrimaryFocus) {
              throw StateError('The original focused draft changed.');
            }
            if (condition()) return;
            await tester.pump(const Duration(milliseconds: 40));
          }
        }

        try {
          if (spec == AndroidCandidateStageSpec.chatSend) {
            final send = find.descendant(of: root, matching: find.text('Send'));
            await Scrollable.ensureVisible(
              tester.element(send),
              alignment: 0.5,
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          await until(() => protocol.matchesComposing(session.readSnapshot()));
          protocol.offerCandidate();
          await until(
            () =>
                protocol.stage == 'awaiting_commit' &&
                protocol.matchesCommitted(session.readSnapshot()),
          );
          protocol.beginSend();
          stageReport['before_original_action'] = protocol.state();
        } catch (error, stack) {
          primaryError = error;
          protocol.fail('$error');
          stageReport.addAll(<String, Object?>{
            'error': '$error',
            'stack': '$stack',
          });
          rethrow;
        } finally {
          try {
            while (protocol.nativeCallPending) {
              await tester.pump(const Duration(milliseconds: 40));
              rpc.drain();
            }
          } catch (error, stack) {
            stageReport['native_drain_wait_error'] = '$error';
            protocol.fail('$error');
            rpc.freeze();
            while (protocol.nativeCallPending) {
              await Future<void>.delayed(const Duration(milliseconds: 40));
            }
            if (primaryError == null) Error.throwWithStackTrace(error, stack);
          } finally {
            controller.removeListener(recordInput);
            if (protocol.isTerminal) freezeObservation();
          }
        }
      };
  androidCandidateGuardStageAction = (tester, root, stageId) {
    if (activeId != stageId ||
        sequence.current.spec.id != stageId ||
        activeGuard == null) {
      throw StateError('The action does not own the current candidate stage.');
    }
    activeGuard!(tester, root);
  };
  androidCandidateAfterStageAction = (stageId) {
    if (activeId == stageId) activeFreeze?.call();
  };
  androidCandidateStageCompleted = (stageId) {
    sequence.completeStage(stageId);
    stages.last['final_state'] = sequence.state();
  };
  androidCandidateBeforeSend = (tester, chat, text) {
    if (text != AndroidCandidateStageSpec.chatSend.text) {
      throw StateError('The original Chat text changed.');
    }
    return awaitAndroidCandidateStage(tester, chat, 'chat_send');
  };
  androidCandidateBeforeActivation = (tester, chat, text) {
    if (text != AndroidCandidateStageSpec.chatSend.text) {
      throw StateError('The original Chat text changed.');
    }
    guardAndroidCandidateStage(tester, chat, 'chat_send');
  };
  androidCandidateAfterTap = () =>
      androidCandidateAfterStageAction?.call('chat_send');

  original.main();
  tearDownAll(() {
    sequence.finishJourney(
      binding.failureMethodsDetails.isEmpty && binding.results.isNotEmpty,
    );
    report['status'] = sequence.journeyStatus;
    report['final_state'] = sequence.state();
    androidCandidateBeforeSend = null;
    androidCandidateBeforeActivation = null;
    androidCandidateAfterTap = null;
    androidCandidateBeforeStageAction = null;
    androidCandidateGuardStageAction = null;
    androidCandidateAfterStageAction = null;
    androidCandidateStageCompleted = null;
  });
}
