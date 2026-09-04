import 'dart:convert';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'interactions.dart';
import 'android_candidate_protocol.dart';

/// Observes the original one-tap Chat send, then verifies host acceptance.
/// Default observations add no edit, focus change, frame, retry, or IME commit.
/// The explicit Android diagnostic first waits for an external native candidate;
/// the original tap and host acceptance guards below remain unchanged.
Future<void> sendCatalogChatOnce(
  WidgetTester tester,
  Finder chat,
  String expectedText, {
  void Function(Map<String, Object?>)? onDiagnostic,
}) async {
  if (const bool.fromEnvironment('CATALOG_ANDROID_CANDIDATE')) {
    await awaitAndroidCandidateBeforeSend(tester, chat, expectedText);
  }
  final elapsed = Stopwatch()..start();
  final composer = find.descendant(
    of: chat,
    matching: find.byType(EditableText),
  );
  final send = find.descendant(of: chat, matching: find.text('Send'));
  final samples = <Map<String, Object?>>[];

  Map<String, Object?> readSnapshot(String phase, [PointerEvent? event]) {
    final host = tester.widget<BeautifulChat>(chat);
    final editor = tester.widget<EditableText>(composer);
    final mountedSendCount = send.evaluate().length;
    final rect = mountedSendCount == 1 ? tester.getRect(send) : null;
    String? enabled;
    String? semanticsError;
    if (mountedSendCount == 1) {
      try {
        enabled = tester
            .getSemantics(send)
            .getSemanticsData()
            .flagsCollection
            .isEnabled
            .name;
      } catch (error) {
        semanticsError = error.toString();
      }
    }
    return <String, Object?>{
      'phase': phase,
      'input': editor.controller.value.toJSON(),
      'editor_primary_focus': editor.focusNode.hasPrimaryFocus,
      'primary_focus': FocusManager.instance.primaryFocus?.debugLabel,
      'send_count': mountedSendCount,
      'send_enabled_semantics': enabled,
      'observation_error': semanticsError,
      'send_rect': rect == null
          ? null
          : <double>[rect.left, rect.top, rect.width, rect.height],
      'view_insets_bottom_physical': tester.view.viewInsets.bottom,
      'device_pixel_ratio': tester.view.devicePixelRatio,
      'host_status': host.status.name,
      'host_messages': <Map<String, Object?>>[
        for (final message in host.messages)
          <String, Object?>{
            'id': message.id,
            'role': message.role.name,
            'text': message.text,
            'resolving': message.isResolving,
          },
      ],
      if (event != null) ...<String, Object?>{
        'pointer': event.pointer,
        'kind': event.kind.name,
        'position': <double>[event.position.dx, event.position.dy],
      },
    };
  }

  Map<String, Object?> snapshot(String phase, [PointerEvent? event]) {
    final sample = <String, Object?>{
      'phase': phase,
      'utc_epoch_us': DateTime.now().microsecondsSinceEpoch,
      'elapsed_us': elapsed.elapsedMicroseconds,
    };
    try {
      sample.addAll(readSnapshot(phase, event));
    } catch (error) {
      // An observer must not escape a global pointer callback or replace a
      // failed tap when the after_tap snapshot runs in finally.
      sample['observation_error'] = '${error.runtimeType}: $error';
    }
    return sample;
  }

  void observePointer(PointerEvent event) {
    if (samples.length >= 8) return;
    final phase = switch (event) {
      PointerDownEvent() => 'pointer_down',
      PointerUpEvent() => 'pointer_up',
      PointerCancelEvent() => 'pointer_cancel',
      _ => null,
    };
    if (phase != null) samples.add(snapshot(phase, event));
  }

  samples.add(snapshot('before_tap'));
  tester.binding.pointerRouter.addGlobalRoute(observePointer);
  try {
    await tapCatalogTarget(
      tester,
      send,
      beforeActivation: const bool.fromEnvironment('CATALOG_ANDROID_CANDIDATE')
          ? () => guardAndroidCandidateBeforeActivation(
              tester,
              chat,
              expectedText,
            )
          : null,
    );
    // This is the existing P2 journey post-tap frame, with its original duration.
    await tester.pump(const Duration(milliseconds: 180));
  } finally {
    tester.binding.pointerRouter.removeGlobalRoute(observePointer);
    samples.add(snapshot('after_tap'));
    final diagnostic = <String, Object?>{
      'expected_text': expectedText,
      'scope': 'framework_touch_one_send_tap',
      'pointer_snapshots':
          'rendered widget and semantics state; no frame is forced',
      'samples': samples,
    };
    try {
      if (onDiagnostic != null) {
        onDiagnostic(diagnostic);
      } else {
        // Separate records stay below Android log-line limits for this fixture.
        for (final sample in samples) {
          debugPrint(
            'CATALOG_CHAT_SEND_DIAGNOSTIC: ${jsonEncode(<String, Object?>{'expected_text': expectedText, 'scope': diagnostic['scope'], 'pointer_snapshots': diagnostic['pointer_snapshots'], 'sample': sample})}',
          );
        }
      }
    } catch (error) {
      // Keep an output-sink failure observable without masking the original tap.
      samples.add(<String, Object?>{
        'phase': 'diagnostic_output',
        'utc_epoch_us': DateTime.now().microsecondsSinceEpoch,
        'elapsed_us': elapsed.elapsedMicroseconds,
        'observation_error': '${error.runtimeType}: $error',
      });
    }
    if (const bool.fromEnvironment('CATALOG_ANDROID_CANDIDATE')) {
      androidCandidateAfterTap?.call();
    }
  }
  final host = tester.widget<BeautifulChat>(chat);
  expect(
    host.messages.where(
      (message) =>
          message.role == BeautifulChatRole.user &&
          message.text == expectedText,
    ),
    hasLength(1),
    reason: 'Chat host must accept the sent text; the editor draft is not a sent message.',
  );
  expect(host.status, BeautifulChatStatus.responding);
}
