import 'package:flutter/widgets.dart';

/// Actual platform state; this helper never changes native rendering metrics.
typedef NativePerformanceEnvironment = ({
  Size physicalSize,
  double pixelRatio,
  AppLifecycleState? lifecycle,
  bool framesEnabled,
  bool platformSemantics,
  bool frameworkSemantics,
});

NativePerformanceEnvironment nativePerformanceEnvironment(
  WidgetsBinding binding,
) {
  final view = binding.platformDispatcher.views.single;
  return (
    physicalSize: view.physicalSize,
    pixelRatio: view.devicePixelRatio,
    lifecycle: binding.lifecycleState,
    framesEnabled: binding.framesEnabled,
    platformSemantics: binding.platformDispatcher.semanticsEnabled,
    frameworkSemantics: binding.semanticsEnabled,
  );
}

bool nativePerformanceEnvironmentReady(NativePerformanceEnvironment value) =>
    value.lifecycle == AppLifecycleState.resumed &&
    value.framesEnabled &&
    value.pixelRatio > 0 &&
    value.physicalSize.width / value.pixelRatio >= 1120 &&
    value.physicalSize.height / value.pixelRatio >= 720;

Map<String, Object?> nativePerformanceEnvironmentData(
  NativePerformanceEnvironment value,
) => <String, Object?>{
  'native_view_physical_px': <String, double>{
    'width': value.physicalSize.width,
    'height': value.physicalSize.height,
  },
  'native_view_logical_dp': <String, double>{
    'width': value.physicalSize.width / value.pixelRatio,
    'height': value.physicalSize.height / value.pixelRatio,
  },
  'device_pixel_ratio': value.pixelRatio,
  'application_lifecycle_state': value.lifecycle?.name,
  'frames_enabled': value.framesEnabled,
  'platform_semantics_enabled': value.platformSemantics,
  'framework_semantics_enabled': value.frameworkSemantics,
};

/// Records environment transitions without dropping affected frame samples.
/// Lifecycle/metrics changes use binding callbacks. Platform semantics is also
/// polled with the 100ms RSS samples because Flutter exposes no separate public
/// listener when platform semantics changes while a test handle is held.
final class NativePerformanceEnvironmentMonitor with WidgetsBindingObserver {
  NativePerformanceEnvironmentMonitor(this.binding);

  final WidgetsBinding binding;
  NativePerformanceEnvironment? _initial;
  NativePerformanceEnvironment? _latest;
  var _started = false;
  var _valid = true;
  int? _startEpochUs;
  final _changes = <Map<String, Object?>>[];

  void start() {
    _initial = _latest = nativePerformanceEnvironment(binding);
    _startEpochUs = DateTime.now().microsecondsSinceEpoch;
    _valid = nativePerformanceEnvironmentReady(_initial!);
    _started = true;
    binding.addObserver(this);
    binding.addSemanticsEnabledListener(_onSemantics);
  }

  bool get isValid => _valid;

  void check(String phase) {
    if (!_started) return;
    final value = nativePerformanceEnvironment(binding);
    if (value != _latest) {
      _valid = false;
      _changes.add(<String, Object?>{
        'epoch_us': DateTime.now().microsecondsSinceEpoch,
        'phase': phase,
        ...nativePerformanceEnvironmentData(value),
      });
      _latest = value;
    }
    if (!nativePerformanceEnvironmentReady(value)) _valid = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      check('lifecycle_callback');

  @override
  void didChangeMetrics() => check('metrics_callback');

  void _onSemantics() => check('framework_semantics_callback');

  Map<String, Object?> finish() {
    try {
      check('after_interactions');
      return <String, Object?>{
        'status': _valid ? 'verified_stable' : 'invalid_environment_changed',
        'start_epoch_us': _startEpochUs,
        'end_epoch_us': DateTime.now().microsecondsSinceEpoch,
        'initial': nativePerformanceEnvironmentData(_initial!),
        'final': nativePerformanceEnvironmentData(_latest!),
        'changes': _changes,
        'observation_note': 'Lifecycle and metrics use native binding events. Both semantics flags are checked at the boundaries and with 100ms RSS samples; framework semantics also uses its binding listener. The original frame and memory samples are retained when any observation invalidates the run.',
      };
    } finally {
      // A final platform read can fail independently of the interaction. It
      // must not leave either observer attached after sampling has closed.
      try {
        binding.removeObserver(this);
      } finally {
        _started = false;
        binding.removeSemanticsEnabledListener(_onSemantics);
      }
    }
  }
}
