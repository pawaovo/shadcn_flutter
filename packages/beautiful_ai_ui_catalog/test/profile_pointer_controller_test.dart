import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/profile_async_guard.dart';
import '../integration_test/support/profile_pointer_controller.dart';

/// Controllable native frame transport. SDK timedDragFrom still generates the
/// real pointer sequence; the unit test only controls when the binding returns.
final class _PointerBinding extends Fake implements TestWidgetsFlutterBinding {
  _PointerBinding(this.real, {this.pendingPump, this.pendingDelay});

  final TestWidgetsFlutterBinding real;
  final int? pendingPump;
  final int? pendingDelay;
  final pending = Completer<void>();
  final events = <PointerEvent>[];
  final sources = <TestBindingEventSource>[];
  var pumps = 0;
  var delays = 0;

  @override
  get clock => real.clock;

  @override
  Future<void> pump([
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  ]) async {
    pumps++;
    if (pumps == pendingPump) await pending.future;
  }

  @override
  Future<void> delayed(Duration duration) async {
    delays++;
    if (delays == pendingDelay) await pending.future;
  }

  @override
  void handlePointerEventForSource(
    PointerEvent event, {
    TestBindingEventSource source = TestBindingEventSource.device,
  }) {
    events.add(event);
    sources.add(source);
  }
}

void main() {
  for (final pendingPump in <int>[1, 3]) {
    testWidgets(
      'timed drag cannot dispatch after pump $pendingPump times out',
      (tester) async {
        await tester.runAsync(() async {
          final binding = _PointerBinding(
            tester.binding,
            pendingPump: pendingPump,
          );
          final guard = ProfileAsyncGuard(
            frameTimeout: const Duration(seconds: 1),
          );
          final controller = ProfilePointerController(binding, guard);
          Object? failure;
          try {
            await guard.wait(
              'drag.pointer_sequence',
              () => controller.timedDragFrom(
                const Offset(10, 20),
                const Offset(120, 0),
                const Duration(milliseconds: 100),
              ),
              timeout: const Duration(milliseconds: 30),
            );
          } catch (error) {
            failure = error;
          }
          final eventsAtTimeout = List<PointerEvent>.of(binding.events);
          final pumpsAtTimeout = binding.pumps;
          final delaysAtTimeout = binding.delays;
          binding.pending.complete();
          await Future<void>.delayed(const Duration(milliseconds: 10));
          expect(failure, isA<ProfileAsyncTimeout>());
          expect(eventsAtTimeout, hasLength(pendingPump == 1 ? 0 : 3));
          expect(binding.events, eventsAtTimeout);
          expect(binding.pumps, pumpsAtTimeout);
          expect(binding.delays, delaysAtTimeout);
          expect(guard.terminalFailure!.operation, 'drag.pointer_sequence');
        });
      },
    );
  }

  testWidgets('timed drag cannot dispatch after its delayed record times out', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final binding = _PointerBinding(tester.binding, pendingDelay: 1);
      final guard = ProfileAsyncGuard(frameTimeout: const Duration(seconds: 1));
      final controller = ProfilePointerController(binding, guard);
      Object? failure;
      try {
        await guard.wait(
          'drag.pointer_sequence',
          () => controller.timedDragFrom(
            Offset.zero,
            const Offset(120, 0),
            const Duration(milliseconds: 100),
          ),
          timeout: const Duration(milliseconds: 30),
        );
      } catch (error) {
        failure = error;
      }
      binding.pending.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(failure, isA<ProfileAsyncTimeout>());
      expect(binding.events, isEmpty);
      expect(binding.pumps, 1);
      expect(binding.delays, 1);
      expect(guard.terminalFailure!.operation, 'drag.pointer_sequence');
    });
  });

  testWidgets(
    'successful timed drag retains SDK 60Hz sequence and end position',
    (tester) async {
      final binding = _PointerBinding(tester.binding);
      final controller = ProfilePointerController(binding, ProfileAsyncGuard());
      await controller.timedDragFrom(
        const Offset(10, 20),
        const Offset(120, 0),
        const Duration(milliseconds: 100),
      );
      expect(binding.events, hasLength(10));
      expect(binding.events.first, isA<PointerAddedEvent>());
      expect(binding.events[1], isA<PointerDownEvent>());
      expect(binding.events.whereType<PointerMoveEvent>(), hasLength(7));
      expect(binding.events.last, isA<PointerUpEvent>());
      expect(binding.events.last.position, const Offset(130, 20));
      expect(binding.events.last.timeStamp, const Duration(milliseconds: 100));
      expect(binding.pumps, 10);
      expect(binding.delays, 9);
      expect(binding.sources.toSet(), <TestBindingEventSource>{
        TestBindingEventSource.test,
      });
    },
  );
}
