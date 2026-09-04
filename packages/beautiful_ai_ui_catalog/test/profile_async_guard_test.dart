import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/profile_async_guard.dart';

void main() {
  test(
    'unreturned pump has a real deadline and late completion cannot repump',
    () async {
      final pending = Completer<void>();
      final guard = ProfileAsyncGuard(
        frameTimeout: const Duration(milliseconds: 30),
      );
      var pumps = 0;
      final future = guard.settle(
        pump: (_) {
          pumps++;
          return pending.future;
        },
        hasScheduledFrame: () => true,
      );
      await expectLater(future, throwsA(isA<ProfileAsyncTimeout>()));
      expect(guard.isTerminal, isTrue);
      expect(pumps, 1);
      pending.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(pumps, 1, reason: 'The timed-out settle loop must never resume.');
      var nextStarted = false;
      await expectLater(
        guard.wait('next workload', () async => nextStarted = true),
        throwsA(same(guard.terminalFailure)),
      );
      expect(nextStarted, isFalse);
    },
  );

  test(
    'outer tap deadline prevents input after an inner pump completes late',
    () async {
      final pending = Completer<void>();
      final guard = ProfileAsyncGuard(frameTimeout: const Duration(seconds: 1));
      var activations = 0;
      final future = guard.wait('tap.reveal', () async {
        await guard.wait('inner pump', () => pending.future);
        activations++;
      }, timeout: const Duration(milliseconds: 30));
      await expectLater(future, throwsA(isA<ProfileAsyncTimeout>()));
      pending.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(activations, 0);
      expect(guard.terminalFailure!.operation, 'tap.reveal');
    },
  );

  test(
    'late synchronous completion is rejected even before the timer runs',
    () async {
      final guard = ProfileAsyncGuard(
        frameTimeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        guard.wait('blocked action', () {
          final clock = Stopwatch()..start();
          while (clock.elapsed < const Duration(milliseconds: 15)) {}
          return Future<void>.value();
        }),
        throwsA(isA<ProfileAsyncTimeout>()),
      );
      expect(
        guard.terminalFailure!.observation['completion_arrived_after_deadline'],
        isTrue,
      );
    },
  );

  test(
    'diagnostic errors cannot replace the original deadline failure',
    () async {
      final guard = ProfileAsyncGuard(
        frameTimeout: const Duration(milliseconds: 20),
        observation: () => throw StateError('observation unavailable'),
        onOperation: (_) => throw StateError('diagnostic writer unavailable'),
      );
      await expectLater(
        guard.wait('native pump', () => Completer<void>().future),
        throwsA(isA<ProfileAsyncTimeout>()),
      );
      expect(guard.isTerminal, isTrue);
      expect(guard.terminalFailure!.operation, 'native pump');
      expect(
        guard.terminalFailure!.observation['diagnostic_observation_error'],
        contains('observation unavailable'),
      );
    },
  );

  test('a completed assertion failure does not prohibit the next independent operation', () async {
    final original = StateError('completed workload assertion');
    final guard = ProfileAsyncGuard();
    await expectLater(
      guard.wait('completed failure', () => Future<void>.error(original)),
      throwsA(same(original)),
    );
    expect(guard.isTerminal, isFalse);
    expect(await guard.wait('next independent workload', () async => 42), 42);
  });

  test('raw evidence survives metadata/outcome/cleanup failures and retains first error', () async {
    final primary = StateError('original frame error');
    final ledger = ProfileFailureLedger()
      ..add('interaction', primary, StackTrace.fromString('original stack'));
    final result = <String, Object?>{};
    final order = <String>[];
    await finalizeProfileEvidence(
      failures: ledger,
      result: result,
      preserveRaw: () {
        order.add('raw');
        result['raw_frame_timings'] = <Object?>[
          {'frame_number': 7},
        ];
        result['rss_samples'] = <Object?>[
          {'current_rss_bytes': 123},
        ];
      },
      runtime: () {
        order.add('metadata');
        throw StateError('metadata failed');
      },
      outcomes: () {
        order.add('outcomes');
        throw StateError('outcomes failed');
      },
      cleanup: () async {
        order.add('cleanup');
        throw StateError('cleanup failed');
      },
    );
    expect(order, ['raw', 'metadata', 'outcomes', 'cleanup']);
    expect(result['raw_frame_timings'], [
      {'frame_number': 7},
    ]);
    expect(result['rss_samples'], [
      {'current_rss_bytes': 123},
    ]);
    expect(result['status'], 'failed');
    expect(result['failure'], contains('original frame error'));
    expect(result['stack'], 'original stack');
    expect(ledger.records.map((e) => e['primary']), [
      true,
      false,
      false,
      false,
    ]);
    expect(ledger.rethrowFirst, throwsA(same(primary)));
  });

  test(
    'pending frame timeout skips cleanup without losing independent evidence',
    () async {
      final guard = ProfileAsyncGuard(
        frameTimeout: const Duration(milliseconds: 20),
      );
      final pending = Completer<void>();
      final ledger = ProfileFailureLedger();
      try {
        await guard.wait('pump', () => pending.future);
      } catch (error, stack) {
        ledger.add('interaction', error, stack);
      }
      var cleanupPumps = 0;
      final result = <String, Object?>{};
      await finalizeProfileEvidence(
        failures: ledger,
        result: result,
        preserveRaw: () => result['raw_frame_timings'] = <int>[1, 2],
        runtime: () {},
        outcomes: () {},
        cleanup: guard.isTerminal ? null : () async => cleanupPumps++,
      );
      pending.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(cleanupPumps, 0);
      expect(result['raw_frame_timings'], [1, 2]);
      expect(result['status'], 'failed');
    },
  );
}
