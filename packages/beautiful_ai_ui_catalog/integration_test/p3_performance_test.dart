import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/p3_performance_measurement.dart';
import 'support/performance_preparation.dart';
import 'support/profile_checkpoint.dart';
import 'support/p3_performance_workloads.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  final report = <String, Object?>{
    'schema_version': 1,
    'suite': 'beautiful_ai_ui_p3_native_profile',
    'started_at_utc': DateTime.now().toUtc().toIso8601String(),
    'status': 'started',
    'measurement_notes': <String>[
      'Native profile mode only. Debug widget-test durations are not accepted as frame evidence.',
      'Preparation and first-mount durations are wall time, not frame time.',
      'Frame samples come from SchedulerBinding.addTimingsCallback during integration_test.traceAction.',
      'Frame sample inclusion uses rasterFinishWallTime within the recorded sampling window; timings are flushed for two seconds before and after that window.',
      'Raw engine FrameTiming samples and raw VM timelines are retained by the driver.',
      'Frame percentiles describe the sampled interaction workload; no invented pass/fail frame threshold or all-platform claim is made.',
      'ProcessInfo.currentRss includes the whole app, fixtures, harness, engine and trace overhead. It is not isolated Dart heap or per-component memory.',
      'ProcessInfo.maxRss is the peak since this process started, never a resettable per-workload peak. rss_observed_peak_bytes is the peak of 100ms currentRss samples.',
      'Warmup is one full interaction round; measured rounds repeat the same operations. Callback totals include warmup and are reported before and after measurement.',
      'Data snapshots and fixture callbacks are harness-owned deterministic test input; no network or model latency is represented.',
      'Text edits use EditableTextState.userUpdateTextEditingValue; key events use Flutter KeyEventSimulator with explicit PhysicalKeyboardKey mappings. These are programmatic Flutter interaction workloads, not OS IME or physical-keyboard acceptance tests. Selection uses an injected pointer drag through the native Flutter selection widget.',
      'Native view dimensions are observed. The harness does not resize or override Flutter rendering metrics.',
      'No garbage collection is forced between workloads. RSS after unmount is observed after a two-second delay and does not prove a leak or reclamation.',
    ],
    'scenarios': <Map<String, Object?>>[],
  };
  binding.reportData = <String, dynamic>{'p3_performance': report};
  final checkpoints = ProfileCheckpointPublisher(
    reportData: () => binding.reportData!,
  )..register();

  group('P3 native profile suite', () {
    // Native accessibility inspection and window resizing happen before the
    // widget-test SemanticsHandle baseline. Platform-owned accessibility
    // handles must not be confused with leaked component-owned handles.
    // flutter_test's setUpAll inherits a 30s timeout and cannot override it.
    // A separate test retains the full 120s preparation deadline while still
    // running before testWidgets records its normal semantics-handle baseline.
    test('prepare native capture', () async {
      if (!kProfileMode) {
        report['status'] = 'rejected_non_profile_mode';
        throw TestFailure('Run this target with flutter drive --profile.');
      }
      if (P3PerformanceRecorder.measuredRounds < 1 ||
          P3PerformanceRecorder.measuredRounds > 20) {
        throw TestFailure('P3_MEASURED_ROUNDS must be between 1 and 20.');
      }
      await prepareNativePerformanceViewport(
        binding,
        report,
        p3PerformanceWorkloadFactories.length,
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('P3 native profile frame and memory workloads', (tester) async {
      expect(
        report['viewport_prepared_before_widget_test'],
        isTrue,
        reason: 'Native preparation must finish before running workloads.',
      );
      final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal = previousFatal,
      );
      final failures = await runNativeProfileWorkloads(
        binding,
        tester,
        report,
        p3PerformanceWorkloadFactories,
        checkpoints,
      );
      expect(failures, isEmpty, reason: failures.join('\n\n'));
    }, timeout: const Timeout(Duration(minutes: 20)));
  });
}
