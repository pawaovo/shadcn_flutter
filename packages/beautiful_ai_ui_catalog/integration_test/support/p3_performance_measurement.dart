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
import 'profile_async_guard.dart';
import 'profile_checkpoint.dart';
import 'profile_pointer_controller.dart';
import 'profile_timeline_codec.dart';

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
    ProfileAsyncGuard? guard,
    this.progress,
  }) : guard = guard ?? ProfileAsyncGuard();

  final WidgetTester tester;
  final bool record;
  final int round;
  final ProfileAsyncGuard guard;
  final Map<String, Object?>? progress;
  final steps = <Map<String, Object?>>[];
  late final _pointer = ProfilePointerController(tester.binding, guard);

  Future<void> step(String name, Future<void> Function() action) async {
    guard.checkActive();
    final startedAtEpochUs = DateTime.now().microsecondsSinceEpoch;
    final clock = Stopwatch()..start();
    final step = <String, Object?>{
      'name': name,
      'round': round,
      'status': 'started',
      'start_epoch_us': startedAtEpochUs,
    };
    progress?['active_step'] = step;
    try {
      await action();
      await settle();
      final exception = tester.takeException();
      if (exception != null) throw TestFailure('$name: $exception');
      step['status'] = 'complete';
    } catch (error) {
      step['status'] = 'failed';
      step['error'] = error.toString();
      rethrow;
    } finally {
      clock.stop();
      step['wall_time_us'] = clock.elapsedMicroseconds;
      step['end_epoch_us'] = DateTime.now().microsecondsSinceEpoch;
      if (record) steps.add(step);
    }
  }

  Future<void> pump([Duration? duration]) =>
      guard.wait('pump', () => tester.pump(duration));

  Future<void> settle() => guard.settle(
    pump: (duration) => tester.pump(duration, EnginePhase.sendSemanticsUpdate),
    hasScheduledFrame: () => tester.binding.hasScheduledFrame,
  );

  Future<void> tap(Finder finder) async {
    await guard.wait(
      'tap.reveal_and_activate',
      () => tapCatalogTarget(tester, finder, pump: pump),
      timeout: const Duration(seconds: 2),
    );
    await pump();
  }

  Future<void> drag(
    Finder finder,
    Offset offset, {
    Duration duration = const Duration(milliseconds: 400),
  }) async {
    await guard.wait('drag.ensureVisible', () => tester.ensureVisible(finder));
    await pump();
    await guard.wait(
      'drag.pointer_sequence',
      () => _pointer.timedDrag(finder, offset, duration),
    );
  }

  Future<void> enter(Finder finder, String value) async {
    await guard.wait('enter.ensureVisible', () => tester.ensureVisible(finder));
    await pump();
    final editable = tester.state<EditableTextState>(finder);
    editable.widget.focusNode.requestFocus();
    await pump();
    // TestTextInput's unregistered client -1 shortcut is debug-only. Use the
    // public editing path in profile, including formatting and onChanged.
    editable.userUpdateTextEditingValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await pump();
    expect(editable.textEditingValue.text, value);
  }

  Future<void> key(
    LogicalKeyboardKey logical,
    PhysicalKeyboardKey physical,
  ) async {
    // KeyEventSimulator cannot infer physical keys from stripped debug names
    // in profile builds. Supply the actual mapping explicitly.
    await guard.wait(
      'key',
      () => tester.sendKeyEvent(logical, physicalKey: physical),
    );
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

/// Complete-workload failures remain independently recordable. A real await
/// deadline is different: its original Future is not cancelled, so no next
/// workload or frame-dependent cleanup may start in that binding.
Future<List<String>> runNativeProfileWorkloads(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  Map<String, Object?> report,
  Iterable<P3PerformanceWorkload Function()> factories,
  ProfileCheckpointPublisher checkpoints,
) async {
  final recorder = P3PerformanceRecorder(binding, tester, report);
  final failures = <String>[];
  var checkpointFailed = false;
  var terminalCheckpointSent = false;
  Future<void> publish({required bool terminal}) async {
    if (terminal) terminalCheckpointSent = true;
    try {
      await checkpoints.publish(terminal: terminal);
    } catch (error) {
      checkpointFailed = true;
      failures.add('Checkpoint failed: $error');
      report['checkpoint_failure'] = error.toString();
    }
  }

  try {
    await recorder.guard.wait(
      'suite.mount',
      () => tester.pumpWidget(
        p3PerformanceApp('Starting measurements', const SizedBox(height: 48)),
      ),
    );
    report['runtime'] = p3RuntimeMetadata(tester);
    report['status'] = 'measuring';
    for (final create in factories) {
      try {
        await recorder.run(create);
      } catch (error) {
        failures.add(error.toString());
        debugPrint('P3_PROFILE_FAILURE: $error');
      }
      if (recorder.isTerminal) {
        report['status'] = 'failed_terminal_wait';
        report['failure_count'] = failures.length;
        report['finished_at_utc'] = DateTime.now().toUtc().toIso8601String();
      }
      await publish(terminal: recorder.isTerminal);
      if (recorder.isTerminal || checkpointFailed) break;
    }
  } catch (error) {
    failures.add(error.toString());
  }
  if (!recorder.isTerminal) {
    try {
      await recorder.guard.wait(
        'suite.cleanup',
        () => tester.pumpWidget(const SizedBox.shrink()),
      );
    } catch (error) {
      failures.add(error.toString());
    }
  }
  report['finished_at_utc'] = DateTime.now().toUtc().toIso8601String();
  report['status'] = failures.isEmpty ? 'workloads_complete' : 'failed';
  report['failure_count'] = failures.length;
  if (recorder.guard.terminalFailure case final failure?) {
    report['terminal_timeout'] = failure.toJson();
  }
  // The last ordinary checkpoint carries the final workload status. A terminal
  // checkpoint already sent the failure state and the host may now be closing.
  if (!checkpointFailed && !terminalCheckpointSent) {
    await publish(terminal: recorder.isTerminal);
    if (checkpointFailed) {
      report['status'] = 'failed';
      report['failure_count'] = failures.length;
    }
  }
  return failures;
}

/// Records native frame samples while integration_test records its VM timeline.
///
/// Engine timings can arrive in batches. Two-second flushes precede and follow
/// sampling; raster-finish wall timestamps exclude warmup and trailing frames.
final class P3PerformanceRecorder {
  P3PerformanceRecorder(this.binding, this.tester, this.report) {
    _delay = (duration) => Future<void>.delayed(duration);
    _pumpWidget = (widget) => tester.pumpWidget(widget);
    guard = ProfileAsyncGuard(
      observation: () => <String, Object?>{
        ...nativePerformanceEnvironmentData(
          nativePerformanceEnvironment(binding),
        ),
        'has_scheduled_frame': binding.hasScheduledFrame,
        'scheduler_phase': binding.schedulerPhase.name,
        'transient_callback_count': binding.transientCallbackCount,
        'active_scenario_id': report['active_scenario_id'],
        'active_phase': _activeResult?['phase'],
        'active_step': _activeResult?['active_step'],
      },
      onOperation: (operation) {
        report['active_await'] = operation;
        if (_activeResult case final result?) {
          result['active_await'] = operation;
        }
      },
    );
  }

  /// Unit-test scheduling seam; never usable for a profile/release capture.
  @visibleForTesting
  factory P3PerformanceRecorder.forTesting(
    IntegrationTestWidgetsFlutterBinding binding,
    WidgetTester tester,
    Map<String, Object?> report, {
    required Future<void> Function(Duration) delay,
    required Future<void> Function(Widget) pumpWidget,
  }) {
    if (!kDebugMode) throw StateError('Testing recorder requires debug mode.');
    return P3PerformanceRecorder(binding, tester, report)
      .._delay = delay
      .._pumpWidget = pumpWidget;
  }

  final IntegrationTestWidgetsFlutterBinding binding;
  final WidgetTester tester;
  final Map<String, Object?> report;
  late final ProfileAsyncGuard guard;
  late Future<void> Function(Duration) _delay;
  late Future<void> Function(Widget) _pumpWidget;
  Map<String, Object?>? _activeResult;

  bool get isTerminal => guard.isTerminal;

  static const warmupRounds = 1;
  static const measuredRounds = int.fromEnvironment(
    'P3_MEASURED_ROUNDS',
    defaultValue: 3,
  );
  static const memorySampleInterval = Duration(milliseconds: 100);
  static const timingFlush = Duration(seconds: 2);

  Future<void> run(P3PerformanceWorkload Function() create) async {
    guard.checkActive();
    final beforeFixture = p3ProcessMemory();
    final preparation = Stopwatch()..start();
    final workload = create();
    preparation.stop();
    final result = <String, Object?>{
      'id': workload.id,
      'description': workload.description,
      'dataset': workload.dataset,
      'status': 'started',
      'phase': 'mount',
      'preparation_wall_time_us': preparation.elapsedMicroseconds,
      'rss_before_fixture': beforeFixture,
      'rss_after_fixture': p3ProcessMemory(),
      'warmup_rounds': warmupRounds,
      'measured_rounds': measuredRounds,
      'memory_sample_interval_ms': memorySampleInterval.inMilliseconds,
      'timing_batch_flush_ms': timingFlush.inMilliseconds,
      'trace_report_key': 'p3_trace_${workload.id}',
    };
    _activeResult = result;
    report['active_scenario_id'] = workload.id;
    (report['scenarios']! as List<Map<String, Object?>>).add(result);
    final failures = ProfileFailureLedger();
    final timings = <ui.FrameTiming>[];
    final memory = <Map<String, Object?>>[];
    final actions = <Map<String, Object?>>[];
    final rounds = <Map<String, Object?>>[];
    final actionClock = Stopwatch();
    Timer? sampler;
    NativePerformanceEnvironmentMonitor? environment;
    var collecting = false;
    var flushed = false;
    var traceObtained = false;
    var startWallUs = 0;
    var endWallUs = 0;
    Size? sampleViewSize;
    double? samplePixelRatio;
    void collect(List<ui.FrameTiming> values) => timings.addAll(values);
    void sample(String phase) {
      environment?.check(phase);
      memory.add(<String, Object?>{
        'phase': phase,
        'elapsed_us': actionClock.elapsedMicroseconds,
        ...p3ProcessMemory(),
      });
    }

    void closeSampling() {
      sampler?.cancel();
      sampler = null;
      if (startWallUs == 0 || endWallUs != 0) return;
      failures.attempt('last_rss_sample', () => sample('after_interactions'));
      actionClock.stop();
      endWallUs = DateTime.now().microsecondsSinceEpoch;
      failures.attempt('environment_finish', () {
        result['native_environment_during_measurement'] = environment!.finish();
      });
    }

    void preserveRaw() {
      // Attach independent evidence first, without calling widget metadata,
      // host outcomes, the VM service or another frame-dependent operation.
      result['interaction_steps'] = actions;
      result['interaction_rounds'] = rounds;
      result['rss_samples'] = memory;
      result['rss_sample_count'] = memory.length;
      result['interaction_wall_time_us'] = actionClock.elapsedMicroseconds;
      result['sampling_window_closed'] = startWallUs > 0 && endWallUs > 0;
      result['timing_flush_completed'] = flushed;
      if (startWallUs > 0) result['sampling_start_epoch_us'] = startWallUs;
      if (endWallUs > 0) result['sampling_end_epoch_us'] = endWallUs;
      final cutoff = endWallUs > 0
          ? endWallUs
          : DateTime.now().microsecondsSinceEpoch;
      final frames = startWallUs == 0
          ? <Map<String, Object?>>[]
          : timings
                .where((frame) {
                  final finish = frame.timestampInMicroseconds(
                    ui.FramePhase.rasterFinishWallTime,
                  );
                  return finish >= startWallUs && finish <= cutoff;
                })
                .map(_frameData)
                .toList();
      result['raw_frame_timings'] = frames;
      result['received_frame_count'] = timings.length;
      result['sampled_frame_count'] = frames.length;
      result['excluded_outside_window_frame_count'] =
          timings.length - frames.length;
      result['evidence_state'] = startWallUs == 0
          ? 'measurement_not_started'
          : endWallUs > 0 && flushed
          ? 'sampling_window_closed_and_flushed'
          : 'partial_sampling_or_unflushed_timings';
      result['rss_observed_peak_bytes'] = memory
          .map((row) => row['current_rss_bytes'])
          .whereType<int>()
          .fold<int?>(
            null,
            (peak, value) => peak == null ? value : math.max(peak, value),
          );
      result['frame_timing_summary_us'] = <String, Object?>{
        for (final field in <String>[
          'build_us',
          'raster_us',
          'total_span_us',
          'vsync_overhead_us',
        ])
          field: _distribution(
            frames.map((frame) => frame[field]! as int).toList(),
          ),
      };
    }

    try {
      final mountClock = Stopwatch()..start();
      await guard.wait(
        'mount.pumpWidget',
        () => _pumpWidget(p3PerformanceApp(workload.id, workload.child)),
      );
      await P3PerformanceActions(
        tester,
        record: false,
        round: -1,
        guard: guard,
        progress: result,
      ).settle();
      mountClock.stop();
      result['mount_wall_time_us'] = mountClock.elapsedMicroseconds;
      result['rss_after_mount'] = p3ProcessMemory();
      result['runtime'] = p3RuntimeMetadata(tester);
      result['phase'] = 'warmup';
      for (var round = 0; round < warmupRounds; round++) {
        await workload.exercise(
          P3PerformanceActions(
            tester,
            record: false,
            round: -1,
            guard: guard,
            progress: result,
          ),
        );
      }
      result['outcomes_after_warmup'] = workload.outcomes();
      await _delay(timingFlush);
      sampleViewSize = tester.view.physicalSize;
      samplePixelRatio = tester.view.devicePixelRatio;
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
      result['phase'] = 'trace_setup';
      final entered = Completer<void>();
      final interactionsClosed = Completer<void>();
      final trace = binding.traceAction(
        () async {
          // A late VM setup completion must not start input after its deadline.
          guard.checkActive();
          result['phase'] = 'measuring';
          startWallUs = DateTime.now().microsecondsSinceEpoch;
          environment = NativePerformanceEnvironmentMonitor(binding)..start();
          actionClock.start();
          entered.complete();
          sample('before_interactions');
          sampler = Timer.periodic(
            memorySampleInterval,
            (_) => failures.attempt('rss_sample', () {
              sample('during_interactions');
            }),
          );
          try {
            for (var round = 0; round < measuredRounds; round++) {
              guard.checkActive();
              final roundStart = DateTime.now().microsecondsSinceEpoch;
              final runner = P3PerformanceActions(
                tester,
                record: true,
                round: round,
                guard: guard,
                progress: result,
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
            failures.add('interaction', error, stack);
          } finally {
            closeSampling();
            result['phase'] = 'trace_harvest';
            interactionsClosed.complete();
          }
        },
        streams: const <String>['Dart', 'Embedder', 'GC'],
        reportKey: 'p3_trace_${workload.id}',
      );
      // Bound VM setup and harvest separately; the interaction window retains
      // its original operations and individually bounded frame waits.
      await guard.wait(
        'trace.setup',
        () => Future.any<void>([entered.future, trace]),
        timeout: const Duration(seconds: 15),
      );
      if (!entered.isCompleted) {
        throw StateError('Timeline action did not start.');
      }
      await Future.any<void>([interactionsClosed.future, trace]);
      await guard.wait(
        'trace.harvest',
        () => trace,
        timeout: const Duration(seconds: 15),
        allowAfterTerminal: true,
      );
      traceObtained = true;
    } catch (error, stack) {
      failures.add(result['phase']?.toString() ?? 'capture', error, stack);
    } finally {
      closeSampling();
      if (collecting) {
        // The binding exposes no supported stop API. At the next durable
        // checkpoint the host stops VM timeline streams before acknowledging
        // this workload; its transport report records the actual RPC result.
        result['trace_stop_status'] = 'awaiting_host_checkpoint_stop';
      }
      if (collecting) {
        await failures.attemptAsync('timing_flush', () async {
          await guard.wait(
            'timing.flush',
            () => _delay(timingFlush),
            allowAfterTerminal: true,
          );
          flushed = true;
        });
        failures.attempt(
          'timings_listener_remove',
          () => binding.removeTimingsCallback(collect),
        );
        collecting = false;
      }
      if (startWallUs > 0 && environment != null && !environment!.isValid) {
        failures.add(
          'native_environment',
          TestFailure(
            'The native lifecycle, viewport or semantics state changed while sampling ${workload.id}; raw samples are preserved.',
          ),
          StackTrace.current,
        );
      }
      if (sampleViewSize != null &&
          (tester.view.physicalSize != sampleViewSize ||
              tester.view.devicePixelRatio != samplePixelRatio)) {
        failures.add(
          'native_viewport',
          TestFailure(
            'The native viewport changed while sampling ${workload.id}.',
          ),
          StackTrace.current,
        );
      }
      await finalizeProfileEvidence(
        failures: failures,
        result: result,
        preserveRaw: preserveRaw,
        runtime: () {
          if (startWallUs > 0) {
            result['runtime_after_measurement'] = p3RuntimeMetadata(tester);
          }
        },
        outcomes: () {
          result[startWallUs > 0
              ? 'outcomes_after_measurement'
              : 'outcomes_at_failure'] = workload
              .outcomes();
          if (traceObtained) {
            failures.attempt('trace_transport', () {
              result['timeline_transport'] = compressProfileTimelineReport(
                binding.reportData!,
                'p3_trace_${workload.id}',
              );
            });
          }
        },
        cleanup: () async {
          result['rss_after_workload'] = p3ProcessMemory();
          if (guard.isTerminal) {
            result['cleanup_status'] =
                'skipped_frame_operations_after_terminal_timeout';
            return;
          }
          result['cleanup_status'] = 'started';
          try {
            FocusManager.instance.primaryFocus?.unfocus();
            await guard.wait(
              'cleanup.pumpWidget',
              () => _pumpWidget(
                p3PerformanceApp(
                  'Between workloads',
                  const SizedBox(height: 48),
                ),
              ),
            );
            await _delay(timingFlush);
            result['rss_after_unmount'] = p3ProcessMemory();
            result['cleanup_status'] = 'complete';
          } catch (_) {
            result['cleanup_status'] = 'failed';
            rethrow;
          }
        },
      );
      if (!failures.hasFailure &&
          (result['sampled_frame_count'] as int? ?? 0) == 0) {
        failures.add(
          'frame_samples',
          TestFailure(
            'No engine FrameTiming samples for ${workload.id}; this is not valid profile evidence.',
          ),
          StackTrace.current,
        );
      }
      result['status'] = failures.hasFailure ? 'failed' : 'complete';
      result['phase'] = result['status'];
      if (failures.hasFailure) {
        result['failures'] = failures.records;
        result['failure'] = failures.records.first['error'];
        result['stack'] = failures.records.first['stack'];
      }
      if (guard.terminalFailure case final failure?) {
        result['terminal_timeout'] = failure.toJson();
        report['terminal_timeout'] = failure.toJson();
      }
    }
    failures.rethrowFirst();
    debugPrint(
      'P3_PROFILE_SCENARIO ${workload.id}: ${result['sampled_frame_count']} engine frames, ${memory.length} RSS samples.',
    );
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
