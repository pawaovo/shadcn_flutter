import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../integration_test/support/p3_performance_measurement.dart';
import '../integration_test/support/profile_async_guard.dart';

/// Real recorder, fake VM transport and explicit synthetic unit-test timings.
/// No files are written and this debug fixture is not performance evidence.
final class _TraceBinding extends Fake
    implements IntegrationTestWidgetsFlutterBinding {
  _TraceBinding(this.real, this.traceFailure);
  final TestWidgetsFlutterBinding real;
  final Object traceFailure;
  final timingCallbacks = <TimingsCallback>{};
  final observers = <WidgetsBindingObserver>{};
  final semanticsListeners = <VoidCallback>{};
  var tracing = false;
  var failFinalEnvironmentRead = false;

  @override
  Map<String, dynamic>? reportData = <String, dynamic>{};
  @override
  TestPlatformDispatcher get platformDispatcher => real.platformDispatcher;
  @override
  AppLifecycleState get lifecycleState {
    if (failFinalEnvironmentRead) throw StateError('environment read failed');
    return AppLifecycleState.resumed;
  }

  @override
  bool get framesEnabled => real.framesEnabled;
  @override
  bool get semanticsEnabled => real.semanticsEnabled;
  @override
  bool get hasScheduledFrame => real.hasScheduledFrame;
  @override
  SchedulerPhase get schedulerPhase => real.schedulerPhase;
  @override
  int get transientCallbackCount => real.transientCallbackCount;
  @override
  void addTimingsCallback(TimingsCallback callback) =>
      timingCallbacks.add(callback);
  @override
  void removeTimingsCallback(TimingsCallback callback) =>
      timingCallbacks.remove(callback);
  @override
  void addObserver(WidgetsBindingObserver observer) => observers.add(observer);
  @override
  bool removeObserver(WidgetsBindingObserver observer) =>
      observers.remove(observer);
  @override
  void addSemanticsEnabledListener(VoidCallback listener) =>
      semanticsListeners.add(listener);
  @override
  void removeSemanticsEnabledListener(VoidCallback listener) =>
      semanticsListeners.remove(listener);

  @override
  Future<void> traceAction(
    Future<dynamic> Function() action, {
    List<String> streams = const <String>['all'],
    bool retainPriorEvents = false,
    String reportKey = 'timeline',
  }) async {
    tracing = true;
    try {
      await action();
    } finally {
      tracing = false;
    }
    throw traceFailure;
  }
}

void main() {
  testWidgets(
    'real recorder keeps frames and first failure when trace/outcomes/cleanup fail',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final primary = StateError('original interaction failed');
      final traceFailure = StateError('trace harvest failed');
      final binding = _TraceBinding(tester.binding, traceFailure);
      final report = <String, Object?>{'scenarios': <Map<String, Object?>>[]};
      binding.reportData!['p3_performance'] = report;
      var outcomeCalls = 0;
      var pumps = 0;
      final delays = <Duration>[];
      final recorder = P3PerformanceRecorder.forTesting(
        binding,
        tester,
        report,
        delay: (duration) async => delays.add(duration),
        pumpWidget: (widget) async {
          pumps++;
          if (pumps > 1) throw StateError('cleanup failed');
          await tester.pumpWidget(widget);
        },
      );
      final workload = P3PerformanceWorkload(
        id: 'unit_failure',
        description: 'synthetic unit-test transport failure',
        dataset: const <String, Object?>{'unit_test_only': true},
        child: const Text('Fixture'),
        exercise: (actions) => actions.step('actual_guarded_step', () async {
          await actions.pump(const Duration(milliseconds: 150));
          if (binding.tracing) {
            final frame = ui.FrameTiming(
              vsyncStart: 10,
              buildStart: 11,
              buildFinish: 13,
              rasterStart: 13,
              rasterFinish: 16,
              rasterFinishWallTime: DateTime.now().microsecondsSinceEpoch,
              frameNumber: 7,
            );
            for (final callback in binding.timingCallbacks) {
              callback(<ui.FrameTiming>[frame]);
            }
            binding.failFinalEnvironmentRead = true;
            throw primary;
          }
        }),
        outcomes: () {
          outcomeCalls++;
          if (outcomeCalls > 1) throw StateError('outcomes failed');
          return <String, Object?>{'warmup_observed': true};
        },
      );
      Object? caught;
      try {
        await recorder.run(() => workload);
      } catch (error) {
        caught = error;
      }
      expect(caught, same(primary));
      final result = (report['scenarios']! as List).single as Map;
      expect(result['status'], 'failed');
      expect(result['failure'], contains('original interaction failed'));
      expect(result['sampled_frame_count'], 1);
      expect((result['raw_frame_timings'] as List).single['frame_number'], 7);
      expect(
        (result['rss_samples'] as List).map(
          (dynamic sample) => sample['phase'],
        ),
        <String>['before_interactions', 'during_interactions'],
      );
      expect(result['sampling_window_closed'], isTrue);
      expect(result['timing_flush_completed'], isTrue);
      expect(result['trace_stop_status'], 'awaiting_host_checkpoint_stop');
      final failures = result['failures'] as List;
      expect(failures.first['phase'], 'interaction');
      expect(
        failures.any(
          (dynamic row) =>
              row['error'].toString().contains('trace harvest failed'),
        ),
        isTrue,
      );
      expect(
        failures.any(
          (dynamic row) => row['error'].toString().contains('outcomes failed'),
        ),
        isTrue,
      );
      expect(failures.last['error'], contains('cleanup failed'));
      expect(
        failures.any((dynamic row) => row['phase'] == 'environment_finish'),
        isTrue,
      );
      expect(binding.timingCallbacks, isEmpty);
      expect(binding.observers, isEmpty);
      expect(binding.semanticsListeners, isEmpty);
      expect(binding.tracing, isFalse);
      expect(
        delays.every((duration) => duration == const Duration(seconds: 2)),
        isTrue,
      );
      // Flutter's end-of-test timer check also rejects a leaked RSS sampler.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'terminal recorder preserves partial evidence and cannot resume inputs or cleanup',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final binding = _TraceBinding(tester.binding, StateError('trace failed'));
      final report = <String, Object?>{'scenarios': <Map<String, Object?>>[]};
      binding.reportData!['p3_performance'] = report;
      var mounts = 0;
      var inputsAfterPendingFrame = 0;
      var outcomes = 0;
      final pendingFrame = Completer<void>();
      final recorder = P3PerformanceRecorder.forTesting(
        binding,
        tester,
        report,
        delay: (_) async {},
        pumpWidget: (widget) async {
          mounts++;
          await tester.pumpWidget(widget);
        },
      );
      final workload = P3PerformanceWorkload(
        id: 'unit_terminal',
        description: 'synthetic unit-test pending frame',
        dataset: const <String, Object?>{'unit_test_only': true},
        child: const Text('Fixture'),
        exercise: (actions) => actions.step('pending_frame', () async {
          await actions.pump(const Duration(milliseconds: 150));
          if (!binding.tracing) return;
          for (final callback in binding.timingCallbacks) {
            callback(<ui.FrameTiming>[
              ui.FrameTiming(
                vsyncStart: 10,
                buildStart: 11,
                buildFinish: 13,
                rasterStart: 13,
                rasterFinish: 16,
                rasterFinishWallTime: DateTime.now().microsecondsSinceEpoch,
                frameNumber: 9,
              ),
            ]);
          }
          // Only the deliberately stalled wait uses real time. Mount, widgets,
          // timers and recorder finalization remain the actual headless paths.
          final failure = await tester.runAsync<Object?>(() async {
            try {
              await actions.guard.wait('native.pending_frame', () async {
                await actions.guard.wait(
                  'nested.frame',
                  () => pendingFrame.future,
                );
                inputsAfterPendingFrame++;
              }, timeout: const Duration(milliseconds: 30));
            } catch (error) {
              return error;
            }
            return null;
          });
          if (failure != null) throw failure;
        }),
        outcomes: () {
          if (outcomes++ > 0) throw StateError('diagnostic outcomes failed');
          return <String, Object?>{};
        },
      );
      Object? caught;
      try {
        await recorder.run(() => workload);
      } catch (error) {
        caught = error;
      }
      expect(caught, same(recorder.guard.terminalFailure));
      expect(caught, isA<ProfileAsyncTimeout>());
      final result = (report['scenarios']! as List).single as Map;
      expect(result['status'], 'failed');
      expect(result['sampled_frame_count'], 1);
      expect((result['raw_frame_timings'] as List).single['frame_number'], 9);
      expect((result['rss_samples'] as List).length, 3);
      expect(result['timing_flush_completed'], isTrue);
      expect(
        result['cleanup_status'],
        'skipped_frame_operations_after_terminal_timeout',
      );
      expect(result['failure'], contains('native.pending_frame'));
      expect(
        (result['failures'] as List).last['error'],
        contains('diagnostic outcomes failed'),
      );
      expect(binding.timingCallbacks, isEmpty);
      expect(binding.observers, isEmpty);
      expect(binding.semanticsListeners, isEmpty);
      expect(binding.tracing, isFalse);
      expect(mounts, 1);
      var nextFactories = 0;
      try {
        await recorder.run(() {
          nextFactories++;
          return workload;
        });
      } catch (error) {
        expect(error, same(caught));
      }
      expect(nextFactories, 0);
      await tester.runAsync(() async {
        pendingFrame.complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });
      await tester.pump(const Duration(milliseconds: 500));
      expect(inputsAfterPendingFrame, 0);
      expect(mounts, 1);
      expect(
        (result['rss_samples'] as List).length,
        3,
        reason: 'The periodic sampler must be cancelled after terminal finalization.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
