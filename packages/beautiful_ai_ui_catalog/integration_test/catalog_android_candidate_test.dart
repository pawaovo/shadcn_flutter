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

/// The complete, unchanged Catalog journey with one explicit native candidate
/// handoff before its original Chat Send. This is Android debug diagnosis only.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final clock = Stopwatch()..start();
  final inputTrace = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'suite': 'catalog_android_candidate',
    'scope': 'original full Catalog journey with one native IME candidate',
    'status': 'started',
    'input_trace': inputTrace,
  };
  binding.reportData = <String, dynamic>{'android_candidate': report};
  Map<String, Object?> Function() readSnapshot = () => <String, Object?>{
    'observation_error': 'The original journey has not reached Chat yet.',
  };
  final protocol = AndroidCandidateProtocol(
    nonce: const String.fromEnvironment('CATALOG_ANDROID_CANDIDATE_NONCE'),
    sourceSha: const String.fromEnvironment(
      'CATALOG_ANDROID_CANDIDATE_SOURCE_SHA',
    ),
    deadlineMilliseconds: 600000,
    elapsedMilliseconds: () => clock.elapsedMilliseconds,
    readSnapshot: () => readSnapshot(),
    newLeaseId: () {
      final random = Random.secure();
      return List<String>.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
    },
  );
  report['events'] = protocol.events;

  developer.registerExtension(AndroidCandidateProtocol.extensionName, (
    method,
    parameters,
  ) async {
    // VM callbacks arrive out-of-band. Use the same outer-event-loop defer
    // as Flutter's extension wrapper before reading widgets. The subsequent
    // snapshot validation and claim have no asynchronous gap.
    await Future<void>.delayed(Duration.zero);
    try {
      return developer.ServiceExtensionResponse.result(
        jsonEncode(protocol.handle(parameters)),
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

  androidCandidateBeforeSend = (testerObject, chatObject, expectedText) async {
    final tester = testerObject as WidgetTester;
    final chat = chatObject as Finder;
    if (expectedText != AndroidCandidateProtocol.expectedText) {
      throw StateError('The original Chat draft changed.');
    }
    protocol.beginCandidateWindow();
    final composer = find.descendant(
      of: chat,
      matching: find.byType(EditableText),
    );
    final send = find.descendant(of: chat, matching: find.text('Send'));
    final controller = tester.widget<EditableText>(composer).controller;
    readSnapshot = () {
      final editor = tester.widget<EditableText>(composer);
      final host = tester.widget<BeautifulChat>(chat);
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
        'device_pixel_ratio': tester.view.devicePixelRatio,
        'host_status': host.status.name,
        'host_messages': <Map<String, Object?>>[
          for (final message in host.messages)
            <String, Object?>{'role': message.role.name, 'text': message.text},
        ],
        'observation_error': null,
      };
    };
    final readActivationSnapshot = readSnapshot;
    void freezeObservation() {
      try {
        final last = readActivationSnapshot();
        report['after_tap_or_terminal_snapshot'] = last;
        readSnapshot = () => last;
      } catch (error) {
        // Preserve the original tap failure if its final observer also fails.
        protocol.fail('Final candidate observer failed: $error');
        report['final_observer_error'] = '$error';
        readSnapshot = () => <String, Object?>{'observation_error': '$error'};
      } finally {
        androidCandidateBeforeActivation = null;
        androidCandidateAfterTap = null;
      }
    }

    androidCandidateAfterTap = freezeObservation;
    androidCandidateBeforeActivation = (testerObject, chatObject, text) {
      if (!identical(testerObject, tester) ||
          !identical(chatObject, chat) ||
          text != expectedText) {
        protocol.fail('The original Send activation target changed.');
        throw StateError('The original Send activation target changed.');
      }
      // Keep a separate binding to the actual widget getter. No preserved VM
      // snapshot may authorize a pointer after asynchronous reveal/pump work.
      final fresh = readActivationSnapshot();
      protocol.guardSendActivation(fresh);
      report['send_activation_snapshot'] = fresh;
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
      if (controller.text != AndroidCandidateProtocol.expectedText) {
        protocol.fail('The native candidate changed the original Chat text.');
      }
    }

    controller.addListener(recordInput);
    recordInput();
    Object? primaryError;

    Future<void> until(bool Function() condition) async {
      while (true) {
        if (protocol.stage == 'failed') {
          throw StateError('${protocol.state()['failure']}');
        }
        if (controller.text != expectedText ||
            !tester.widget<EditableText>(composer).focusNode.hasPrimaryFocus) {
          throw StateError('The original focused Chat draft changed.');
        }
        if (condition()) return;
        await tester.pump(const Duration(milliseconds: 40));
      }
    }

    try {
      // Reveal the same target that the original one-tap helper will reveal.
      // There is no pointer, new edit, focus request, or composing clear here.
      await Scrollable.ensureVisible(tester.element(send), alignment: 0.5);
      await tester.pump(const Duration(milliseconds: 16));
      await until(
        () => AndroidCandidateProtocol.isComposingCandidate(readSnapshot()),
      );
      protocol.offerCandidate();
      await until(
        () =>
            protocol.stage == 'awaiting_commit' &&
            AndroidCandidateProtocol.isCommittedCandidate(readSnapshot()),
      );
      // A successful result confirms that the native call actually returned.
      // The original Send is permitted only while its action lease is live.
      protocol.beginSend();
      report['before_original_send'] = protocol.state();
    } catch (error, stack) {
      primaryError = error;
      protocol.fail('$error');
      report.addAll(<String, Object?>{
        'status': 'failed',
        'error': '$error',
        'stack': '$stack',
      });
      rethrow;
    } finally {
      try {
        while (protocol.nativeCallPending) {
          await tester.pump(const Duration(milliseconds: 40));
        }
      } catch (error, stack) {
        // Public UiAutomation may block beyond a checked deadline. Time passing
        // is not a drain acknowledgment. Even if pumping fails, keep the target
        // mounted and the VM event loop alive until a matching real drain. If
        // none arrives, the outer owner must destroy this disposable run.
        report['native_drain_wait_error'] = '$error';
        protocol.fail('$error');
        while (protocol.nativeCallPending) {
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }
        if (primaryError == null) Error.throwWithStackTrace(error, stack);
      } finally {
        controller.removeListener(recordInput);
        // A successful hook keeps the live getter through the final activation.
        // Freeze only after the tap finally callback, or a terminal hook failure.
        if (protocol.isTerminal) freezeObservation();
      }
    }
  };

  // Reuse all original P1/P2/P3 operations, one Send, and host assertions.
  original.main();
  tearDownAll(() {
    if (binding.failureMethodsDetails.isEmpty &&
        binding.results.isNotEmpty &&
        protocol.stage == 'sending') {
      protocol.pass(captureSnapshot: false);
      report['status'] = 'passed';
    } else {
      protocol.fail('The original complete Catalog journey did not pass.');
      report['status'] = 'failed';
    }
    report['final_state'] = protocol.state();
    androidCandidateBeforeSend = null;
    androidCandidateBeforeActivation = null;
    androidCandidateAfterTap = null;
  });
}
