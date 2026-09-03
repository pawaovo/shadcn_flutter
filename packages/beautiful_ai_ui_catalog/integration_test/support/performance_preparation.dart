import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'native_performance_environment.dart';
import 'p3_performance_measurement.dart';

/// An explicit preparation boundary before testWidgets establishes Semantics.
/// Restored dimensions alone do not mean a desktop app is active or drawing.
Future<void> prepareNativePerformanceViewport(
  WidgetsBinding binding,
  Map<String, Object?> report,
  int workloadCount,
) async {
  var confirmed = false;
  var active = true;
  NativePerformanceEnvironment? stableEnvironment;
  Duration? stableSince;
  int? startEpochUs;
  var completedFrames = 0;
  var framePending = false;
  final clock = Stopwatch()..start();
  void resetConfirmation() {
    confirmed = false;
    stableEnvironment = null;
    stableSince = null;
    completedFrames = 0;
  }

  final observer = _PreparationObserver(resetConfirmation);
  binding.addObserver(observer);
  binding.addSemanticsEnabledListener(resetConfirmation);
  runApp(
    p3PerformanceApp(
      'Prepare native capture',
      NativePerformanceStartControl(
        workloadCount: workloadCount,
        onStart: () {
          final value = nativePerformanceEnvironment(binding);
          if (!nativePerformanceEnvironmentReady(value)) return;
          confirmed = true;
          stableEnvironment = value;
          stableSince = clock.elapsed;
          startEpochUs = DateTime.now().microsecondsSinceEpoch;
          completedFrames = 0;
        },
      ),
    ),
  );
  debugPrint(
    'P3_PROFILE_WAITING_VIEWPORT: activate this native app, set >=1120 x 720 dp and click Start native measurements; timeout 120 seconds.',
  );
  try {
    while (true) {
      final value = nativePerformanceEnvironment(binding);
      // The 120s deadline includes the entire post-click stability interval.
      if (clock.elapsed >= const Duration(minutes: 2)) {
        report['status'] = 'failed_native_preparation';
        report['native_preparation'] = <String, Object?>{
          'status': 'timed_out',
          'wall_time_us': clock.elapsedMicroseconds,
          'explicit_start_control_activated': confirmed,
          'completed_framework_frames_since_start': completedFrames,
          ...nativePerformanceEnvironmentData(value),
        };
        throw TestFailure(
          'Native preparation did not complete within 120 seconds: require >=1120 x 720 dp, actual resumed lifecycle, explicit Start activation, and one stable second with progressing frames and unchanged semantics flags.',
        );
      }
      if (!nativePerformanceEnvironmentReady(value) ||
          (confirmed && value != stableEnvironment)) {
        resetConfirmation();
      }
      if (confirmed) {
        if (clock.elapsed - stableSince! >= const Duration(seconds: 1) &&
            completedFrames >= 2) {
          report['viewport_prepared_before_widget_test'] = true;
          report['explicit_start_control_activated'] = true;
          report['application_lifecycle_at_start'] = value.lifecycle?.name;
          report['native_preparation'] = <String, Object?>{
            'status': 'ready',
            'wall_time_us': clock.elapsedMicroseconds,
            'explicit_start_epoch_us': startEpochUs,
            'ready_epoch_us': DateTime.now().microsecondsSinceEpoch,
            'stable_duration_us': (clock.elapsed - stableSince!).inMicroseconds,
            'completed_framework_frames_since_start': completedFrames,
            ...nativePerformanceEnvironmentData(value),
            'observation_note': 'Readiness requires observed resumed lifecycle, frame progression and stable geometry/semantics flags after explicit Start. It is preparation evidence, not measured frame timing or independent proof of window visibility.',
          };
          debugPrint(
            'P3_PROFILE_VIEWPORT_READY: ${value.physicalSize.width / value.pixelRatio} x ${value.physicalSize.height / value.pixelRatio} dp; actual lifecycle resumed, frames progressing and semantics stable for one second; measuring starts now.',
          );
          return;
        }
        if (!framePending) {
          framePending = true;
          final expected = stableEnvironment;
          final expectedStart = startEpochUs;
          binding.addPostFrameCallback((_) {
            framePending = false;
            if (active &&
                confirmed &&
                expectedStart == startEpochUs &&
                nativePerformanceEnvironment(binding) == expected) {
              completedFrames++;
            }
          });
          binding.scheduleFrame();
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  } finally {
    active = false;
    binding.removeObserver(observer);
    binding.removeSemanticsEnabledListener(resetConfirmation);
  }
}

final class _PreparationObserver with WidgetsBindingObserver {
  _PreparationObserver(this.invalidate);
  final VoidCallback invalidate;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => invalidate();

  @override
  void didChangeMetrics() => invalidate();
}

/// Preparation UI only; never present in a timed workload.
final class NativePerformanceStartControl extends StatefulWidget {
  const NativePerformanceStartControl({
    super.key,
    required this.workloadCount,
    required this.onStart,
  });
  final int workloadCount;
  final VoidCallback onStart;

  @override
  State<NativePerformanceStartControl> createState() =>
      _NativePerformanceStartControlState();
}

final class _NativePerformanceStartControlState
    extends State<NativePerformanceStartControl>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final active =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    final ready = size.width >= 1120 && size.height >= 720 && active;
    void start() {
      if (ready) widget.onStart();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Activate and resize this native window to at least 1120 × 720 logical pixels. Then click Start native measurements to run ${widget.workloadCount} workloads. Keep this window visible and active; stop interacting once measurement starts.',
        ),
        const SizedBox(height: 12),
        Text(
          'Observed: ${size.width} × ${size.height} dp; lifecycle: ${WidgetsBinding.instance.lifecycleState?.name ?? 'unknown'}.',
        ),
        const SizedBox(height: 16),
        Semantics(
          key: const Key('native-performance-start'),
          button: true,
          enabled: ready,
          label: 'Start native measurements',
          onTap: ready ? start : null,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTap: ready ? start : null,
              behavior: HitTestBehavior.opaque,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ready
                      ? const Color(0xff0067cb)
                      : const Color(0xff66696f),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    'Start native measurements',
                    style: TextStyle(color: Color(0xffffffff), fontSize: 18),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
