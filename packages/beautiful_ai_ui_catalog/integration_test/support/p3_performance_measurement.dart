import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'interactions.dart';
import 'native_performance_environment.dart';

const p3PerformanceSurfaceKey = Key('p3-performance-surface');
const p3PerformanceOuterScrollKey = Key('p3-performance-outer-scroll');

/// One independent native workload. Data and host callbacks live in the harness.
final class P3PerformanceWorkload {
  P3PerformanceWorkload({
    required this.id,
    required this.description,
    required this.dataset,
    required this.child,
    required this.exercise,
    required this.outcomes,
  });

  final String id;
  final String description;
  final Map<String, Object?> dataset;
  final Widget child;
  final Future<void> Function(P3PerformanceActions actions) exercise;
  final Map<String, Object?> Function() outcomes;
}

/// Executes real input and keeps wall time separate from engine frame timings.
final class P3PerformanceActions {
  P3PerformanceActions(
    this.tester, {
    required this.record,
    required this.round,
  });

  final WidgetTester tester;
  final bool record;
  final int round;
  final steps = <Map<String, Object?>>[];

  Future<void> step(String name, Future<void> Function() action) async {
    final startedAtEpochUs = DateTime.now().microsecondsSinceEpoch;
    final clock = Stopwatch()..start();
    await action();
    await settle();
    clock.stop();
    final exception = tester.takeException();
    if (exception != null) throw TestFailure('$name: $exception');
    if (record) {
      steps.add(<String, Object?>{
        'name': name,
        'round': round,
        'wall_time_us': clock.elapsedMicroseconds,
        'start_epoch_us': startedAtEpochUs,
        'end_epoch_us': DateTime.now().microsecondsSinceEpoch,
      });
    }
  }

  Future<void> settle() => tester.pumpAndSettle(
    const Duration(milliseconds: 16),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 8),
  );

  Future<void> tap(Finder finder) async {
    await tapCatalogTarget(tester, finder);
    await tester.pump();
  }

  Future<void> drag(
    Finder finder,
    Offset offset, {
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.timedDrag(finder, offset, duration);
  }

  Future<void> enter(Finder finder, String value) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    final editable = tester.state<EditableTextState>(finder);
    editable.widget.focusNode.requestFocus();
    await tester.pump();
    // TestTextInput's unregistered client -1 shortcut is debug-only. Use the
    // public editing path in profile, including formatting and onChanged.
    editable.userUpdateTextEditingValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    expect(editable.textEditingValue.text, value);
  }

  Future<void> key(
    LogicalKeyboardKey logical,
    PhysicalKeyboardKey physical,
  ) async {
    // KeyEventSimulator cannot infer physical keys from stripped debug names
    // in profile builds. Supply the actual mapping explicitly.
    await tester.sendKeyEvent(logical, physicalKey: physical);
  }
}

/// A native-sized app; no synthetic surface size or scaled screenshot is used.
Widget p3PerformanceApp(String title, Widget child) => WidgetsApp(
  color: const Color(0xfffafafb),
  builder: (context, _) => Overlay.wrap(
    child: BeautifulUiScope(
      themeMode: BeautifulUiThemeMode.light,
      motion: BeautifulMotionPolicy.system,
      child: Builder(
        builder: (context) => ColoredBox(
          color: BeautifulUiTheme.of(context).colors.page,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Native profile workload · $title',
                    style: BeautifulUiTheme.of(context).typography.label,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    key: p3PerformanceOuterScrollKey,
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      key: p3PerformanceSurfaceKey,
                      width: double.infinity,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

/// Runtime metadata contains observed values and explicitly identified requests.
Map<String, Object?> p3RuntimeMetadata(WidgetTester tester) {
  final view = tester.view;
  final media = MediaQuery.of(
    tester.element(find.byKey(p3PerformanceSurfaceKey)),
  );
  final size = tester.getSize(find.byKey(p3PerformanceSurfaceKey));
  return <String, Object?>{
    'operating_system': Platform.operatingSystem,
    'operating_system_version': Platform.operatingSystemVersion,
    'dart_vm_version': Platform.version,
    'logical_processor_count': Platform.numberOfProcessors,
    'build_mode': kProfileMode
        ? 'profile'
        : (kReleaseMode ? 'release' : 'debug'),
    'application_lifecycle_state': tester.binding.lifecycleState?.name,
    'frames_enabled': tester.binding.framesEnabled,
    'native_view_physical_px': <String, double>{
      'width': view.physicalSize.width,
      'height': view.physicalSize.height,
    },
    'native_view_logical_dp': <String, double>{
      'width': view.physicalSize.width / view.devicePixelRatio,
      'height': view.physicalSize.height / view.devicePixelRatio,
    },
    'device_pixel_ratio': view.devicePixelRatio,
    'display_refresh_rate_hz': view.display.refreshRate,
    'surface_width_dp': size.width,
    'platform_text_scale_at_14dp': media.textScaler.scale(14),
    'platform_disable_animations': media.disableAnimations,
    'platform_high_contrast': media.highContrast,
    'semantics_enabled': tester.binding.platformDispatcher.semanticsEnabled,
    'platform_semantics_enabled':
        tester.binding.platformDispatcher.semanticsEnabled,
    'framework_semantics_enabled': tester.binding.semanticsEnabled,
    'locale': tester.binding.platformDispatcher.locale.toLanguageTag(),
    'platform_locale': tester.binding.platformDispatcher.locale.toLanguageTag(),
    'widget_locale': Localizations.maybeLocaleOf(
      tester.element(find.byKey(p3PerformanceSurfaceKey)),
    )?.toLanguageTag(),
    'legacy_metadata_note': 'locale and semantics_enabled retain the historical platform-dispatcher meaning; widget locale and framework Semantics are recorded independently.',
    'theme': 'light',
    'motion_policy': 'system',
    'renderer': <String, Object?>{
      'observed_backend': null,
      'requested_backend': const String.fromEnvironment(
        'P3_RENDERER_REQUESTED',
        defaultValue: 'platform default',
      ),
      'observation_status': 'Not exposed by the Flutter public runtime API; inspect the saved engine launch log.',
    },
    'device_label': const String.fromEnvironment(
      'P3_DEVICE_LABEL',
      defaultValue: 'unspecified; see platform and driver metadata',
    ),
  };
}

Map<String, Object?> p3ProcessMemory() {
  try {
    return <String, Object?>{
      'current_rss_bytes': ProcessInfo.currentRss,
      'process_lifetime_max_rss_bytes': ProcessInfo.maxRss,
    };
  } on UnsupportedError catch (error) {
    return <String, Object?>{'unavailable': error.toString()};
  }
}

/// Records native frame samples while integration_test records its VM timeline.
///
/// Engine timings can arrive in batches. Two-second flushes precede and follow
/// sampling; raster-finish wall timestamps exclude warmup and trailing frames.
final class P3PerformanceRecorder {
  P3PerformanceRecorder(this.binding, this.tester, this.report);

  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final Map<String, Object?> report;

  static const warmupRounds = 1;
  static const measuredRounds = int.fromEnvironment(
    'P3_MEASURED_ROUNDS',
    defaultValue: 3,
  );
  static const memorySampleInterval = Duration(milliseconds: 100);
  static const timingFlush = Duration(seconds: 2);

  Future<void> run(P3PerformanceWorkload Function() create) async {
    final beforeFixture = p3ProcessMemory();
    final preparation = Stopwatch()..start();
    final workload = create();
    preparation.stop();
    final result = <String, Object?>{
      'id': workload.id,
      'description': workload.description,
      'dataset': workload.dataset,
      'status': 'started',
      'preparation_wall_time_us': preparation.elapsedMicroseconds,
      'rss_before_fixture': beforeFixture,
      'rss_after_fixture': p3ProcessMemory(),
      'warmup_rounds': warmupRounds,
      'measured_rounds': measuredRounds,
      'memory_sample_interval_ms': memorySampleInterval.inMilliseconds,
      'timing_batch_flush_ms': timingFlush.inMilliseconds,
      'trace_report_key': 'p3_trace_${workload.id}',
    };
    (report['scenarios']! as List<Map<String, Object?>>).add(result);
    final timings = <ui.FrameTiming>[];
    final memory = <Map<String, Object?>>[];
    final actions = <Map<String, Object?>>[];
    final rounds = <Map<String, Object?>>[];
    Timer? sampler;
    NativePerformanceEnvironmentMonitor? environment;
    void collect(List<ui.FrameTiming> values) => timings.addAll(values);
    var collecting = false;
    try {
      final mountClock = Stopwatch()..start();
      await tester.pumpWidget(p3PerformanceApp(workload.id, workload.child));
      await P3PerformanceActions(tester, record: false, round: -1).settle();
      mountClock.stop();
      result['mount_wall_time_us'] = mountClock.elapsedMicroseconds;
      result['rss_after_mount'] = p3ProcessMemory();
      result['runtime'] = p3RuntimeMetadata(tester);
      for (var round = 0; round < warmupRounds; round++) {
        await workload.exercise(
          P3PerformanceActions(tester, record: false, round: -1),
        );
      }
      result['outcomes_after_warmup'] = workload.outcomes();
      await Future<void>.delayed(timingFlush);
      final sampleViewSize = tester.view.physicalSize;
      final samplePixelRatio = tester.view.devicePixelRatio;
      result['runtime_before_measurement'] = p3RuntimeMetadata(tester);
      if (!nativePerformanceEnvironmentReady(
        nativePerformanceEnvironment(binding),
      )) {
        throw TestFailure(
          'The native environment is not ready before measuring ${workload.id}; require the resumed app and a >=1120 x 720 dp viewport.',
        );
      }
      binding.addTimingsCallback(collect);
      collecting = true;
      var startWallUs = 0;
      var endWallUs = 0;
      Object? interactionError;
      StackTrace? interactionStack;
      final actionClock = Stopwatch();
      await binding.traceAction(
        () async {
          startWallUs = DateTime.now().microsecondsSinceEpoch;
          environment = NativePerformanceEnvironmentMonitor(binding)..start();
          actionClock.start();
          void sample(String phase) {
            environment!.check(phase);
            memory.add(<String, Object?>{
              'phase': phase,
              'elapsed_us': actionClock.elapsedMicroseconds,
              ...p3ProcessMemory(),
            });
          }

          sample('before_interactions');
          sampler = Timer.periodic(
            memorySampleInterval,
            (_) => sample('during_interactions'),
          );
          try {
            for (var round = 0; round < measuredRounds; round++) {
              final roundStart = DateTime.now().microsecondsSinceEpoch;
              final runner = P3PerformanceActions(
                tester,
                record: true,
                round: round,
              );
              try {
                await workload.exercise(runner);
              } finally {
                actions.addAll(runner.steps);
                rounds.add(<String, Object?>{
                  'round': round,
                  'start_epoch_us': roundStart,
                  'end_epoch_us': DateTime.now().microsecondsSinceEpoch,
                });
              }
            }
          } catch (error, stack) {
            // Let traceAction close and preserve the partial trace before
            // reporting the failed interaction to the surrounding test.
            interactionError = error;
            interactionStack = stack;
          } finally {
            sampler?.cancel();
            sampler = null;
            sample('after_interactions');
            actionClock.stop();
            endWallUs = DateTime.now().microsecondsSinceEpoch;
            result['native_environment_during_measurement'] = environment!
                .finish();
          }
        },
        streams: const <String>['Dart', 'Embedder', 'GC'],
        reportKey: 'p3_trace_${workload.id}',
      );
      await Future<void>.delayed(timingFlush);
      binding.removeTimingsCallback(collect);
      collecting = false;
      final samples = timings
          .where((frame) {
            final finish = frame.timestampInMicroseconds(
              ui.FramePhase.rasterFinishWallTime,
            );
            return finish >= startWallUs && finish <= endWallUs;
          })
          .map(_frameData)
          .toList();
      result.addAll(<String, Object?>{
        'runtime_after_measurement': p3RuntimeMetadata(tester),
        'interaction_wall_time_us': actionClock.elapsedMicroseconds,
        'sampling_start_epoch_us': startWallUs,
        'sampling_end_epoch_us': endWallUs,
        'received_frame_count': timings.length,
        'sampled_frame_count': samples.length,
        'excluded_outside_window_frame_count': timings.length - samples.length,
        'frame_timing_summary_us': <String, Object?>{
          for (final field in <String>[
            'build_us',
            'raster_us',
            'total_span_us',
            'vsync_overhead_us',
          ])
            field: _distribution(
              samples.map((frame) => frame[field]! as int).toList(),
            ),
        },
        'raw_frame_timings': samples,
        'interaction_steps': actions,
        'interaction_rounds': rounds,
        'rss_samples': memory,
        'rss_sample_count': memory.length,
        'rss_observed_peak_bytes': memory
            .map((sample) => sample['current_rss_bytes'])
            .whereType<int>()
            .fold<int?>(
              null,
              (peak, value) => peak == null ? value : math.max(peak, value),
            ),
        'outcomes_after_measurement': workload.outcomes(),
        'status': samples.isEmpty
            ? 'failed_no_engine_frame_samples'
            : 'complete',
      });
      if (interactionError != null) {
        Error.throwWithStackTrace(interactionError!, interactionStack!);
      }
      if (!environment!.isValid) {
        throw TestFailure(
          'The native lifecycle, viewport or semantics state changed while sampling ${workload.id}; raw frames and RSS remain preserved, and this workload is invalid.',
        );
      }
      if (tester.view.physicalSize != sampleViewSize ||
          tester.view.devicePixelRatio != samplePixelRatio) {
        throw TestFailure(
          'The native viewport changed while sampling ${workload.id}; rerun with a fixed visible window.',
        );
      }
      if (samples.isEmpty) {
        throw TestFailure(
          'No engine FrameTiming samples for ${workload.id}; this is not valid profile evidence.',
        );
      }
      debugPrint(
        'P3_PROFILE_SCENARIO ${workload.id}: ${samples.length} engine frames, ${memory.length} RSS samples.',
      );
    } catch (error, stack) {
      result['status'] = 'failed';
      result['failure'] = error.toString();
      result['stack'] = stack.toString();
      rethrow;
    } finally {
      sampler?.cancel();
      if (collecting) binding.removeTimingsCallback(collect);
      result.putIfAbsent('interaction_steps', () => actions);
      result.putIfAbsent('interaction_rounds', () => rounds);
      result.putIfAbsent('rss_samples', () => memory);
      result.putIfAbsent('rss_sample_count', () => memory.length);
      result['rss_after_workload'] = p3ProcessMemory();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpWidget(
        p3PerformanceApp('Between workloads', const SizedBox(height: 48)),
      );
      await Future<void>.delayed(timingFlush);
      result['rss_after_unmount'] = p3ProcessMemory();
    }
  }
}

Map<String, Object?> _frameData(ui.FrameTiming frame) => <String, Object?>{
  'frame_number': frame.frameNumber,
  'build_us': frame.buildDuration.inMicroseconds,
  'raster_us': frame.rasterDuration.inMicroseconds,
  'vsync_overhead_us': frame.vsyncOverhead.inMicroseconds,
  'total_span_us': frame.totalSpan.inMicroseconds,
  'raster_finish_epoch_us': frame.timestampInMicroseconds(
    ui.FramePhase.rasterFinishWallTime,
  ),
  'layer_cache_bytes': frame.layerCacheBytes,
  'picture_cache_bytes': frame.pictureCacheBytes,
};

Map<String, Object?> _distribution(List<int> values) {
  if (values.isEmpty) return <String, Object?>{'sample_count': 0};
  values.sort();
  int percentile(double fraction) =>
      values[(values.length * fraction).ceil().clamp(1, values.length) - 1];
  return <String, Object?>{
    'sample_count': values.length,
    'min': values.first,
    'p50': percentile(0.5),
    'p90': percentile(0.9),
    'p95': percentile(0.95),
    'p99': percentile(0.99),
    'max': values.last,
    'mean': values.fold<int>(0, (sum, value) => sum + value) / values.length,
    'percentile_method': 'nearest rank',
  };
}
