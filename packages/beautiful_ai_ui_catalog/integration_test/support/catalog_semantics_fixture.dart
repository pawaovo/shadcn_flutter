import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owns only the suite's semantics lease, established before test baselines.
///
/// The platform may independently enable its native accessibility bridge while
/// the first view appears. That handle belongs to Flutter's SemanticsBinding,
/// and disposing a per-test handle must not attempt to release it.
final class CatalogSemanticsFixture {
  CatalogSemanticsFixture(this.binding);

  final SemanticsBinding binding;
  SemanticsHandle? _handle;

  Future<void> prepare(Future<void> Function() preparePlatform) async {
    if (_handle != null) {
      throw StateError('Catalog semantics fixture is already prepared.');
    }
    _handle = binding.ensureSemantics();
    try {
      await preparePlatform();
    } catch (_) {
      dispose();
      rethrow;
    }
  }

  void dispose() {
    _handle?.dispose();
    _handle = null;
  }
}

/// Draws and settles native view accessibility before testWidgets records its
/// normal handle baseline. No handle counts or verification hooks are changed.
Future<void> prepareCatalogNativeSemantics(
  LiveTestWidgetsFlutterBinding binding,
) async {
  final previousPolicy = binding.framePolicy;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  try {
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Semantics(
          container: true,
          label: 'Preparing native catalog semantics',
          child: const SizedBox.expand(),
        ),
      ),
    );
    await binding.waitUntilFirstFrameRasterized.timeout(
      const Duration(seconds: 15),
    );
    await waitForStableCatalogPlatform(
      platformEnabled: () => binding.platformDispatcher.semanticsEnabled,
      lifecycle: () => binding.lifecycleState,
      // On iOS, viewDidAppear enables the simulator bridge before sending the
      // resumed lifecycle message. Real devices may legitimately remain false.
      requireResumed: defaultTargetPlatform == TargetPlatform.iOS,
    );
    debugPrint(
      'CATALOG_NATIVE_SEMANTICS_READY: '
      'platform=${binding.platformDispatcher.semanticsEnabled}, '
      'lifecycle=${binding.lifecycleState?.name}, '
      'handles=${binding.debugOutstandingSemanticsHandles}',
    );
  } finally {
    binding.framePolicy = previousPolicy;
  }
}

/// Waits on the platform flag itself, not the aggregate framework flag (which
/// remains true throughout the suite-owned lease).
Future<void> waitForStableCatalogPlatform({
  required bool Function() platformEnabled,
  required AppLifecycleState? Function() lifecycle,
  required bool requireResumed,
  Duration quietPeriod = const Duration(milliseconds: 500),
  Duration timeout = const Duration(seconds: 15),
  Duration pollInterval = const Duration(milliseconds: 50),
}) async {
  final elapsed = Stopwatch()..start();
  final quiet = Stopwatch()..start();
  var previous = (platformEnabled(), lifecycle());
  while (elapsed.elapsed < timeout) {
    await Future<void>.delayed(pollInterval);
    final current = (platformEnabled(), lifecycle());
    if (current != previous) {
      previous = current;
      quiet.reset();
    }
    final viewReady =
        !requireResumed || current.$2 == AppLifecycleState.resumed;
    if (viewReady && quiet.elapsed >= quietPeriod) return;
  }
  throw TimeoutException(
    'Native catalog view did not stabilize before the test baseline: '
    'platform=${previous.$1}, lifecycle=${previous.$2?.name}.',
    timeout,
  );
}
