import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/native_performance_environment.dart';
import '../integration_test/support/performance_preparation.dart';

void _lifecycle(WidgetsBinding binding, AppLifecycleState value) {
  // Replay the same binding callback delivered by the native lifecycle channel.
  // ignore: invalid_use_of_protected_member
  binding.handleAppLifecycleStateChanged(value);
}

void _prepare(WidgetTester tester) {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(2560, 1800);
  _lifecycle(tester.binding, AppLifecycleState.resumed);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(() => _lifecycle(tester.binding, AppLifecycleState.resumed));
}

void main() {
  testWidgets('native monitor accepts an unchanged resumed environment', (
    tester,
  ) async {
    _prepare(tester);
    final monitor = NativePerformanceEnvironmentMonitor(tester.binding)
      ..start();
    monitor.check('during_interactions');
    final result = monitor.finish();
    expect(result['status'], 'verified_stable');
    expect(result['changes'], isEmpty);
    expect(result['initial'], result['final']);
  });

  testWidgets(
    'native monitor rejects inactive even after resumed is restored',
    (tester) async {
      _prepare(tester);
      final monitor = NativePerformanceEnvironmentMonitor(tester.binding)
        ..start();
      _lifecycle(tester.binding, AppLifecycleState.inactive);
      _lifecycle(tester.binding, AppLifecycleState.resumed);
      final result = monitor.finish();
      expect(result['status'], 'invalid_environment_changed');
      expect(result['changes'], hasLength(2));
      expect(result['initial'], result['final']);
      expect(monitor.isValid, isFalse);
    },
  );

  testWidgets(
    'native monitor rejects resize even after original size returns',
    (tester) async {
      _prepare(tester);
      final monitor = NativePerformanceEnvironmentMonitor(tester.binding)
        ..start();
      tester.view.physicalSize = const Size(2800, 1800);
      tester.view.physicalSize = const Size(2560, 1800);
      final result = monitor.finish();
      expect(result['status'], 'invalid_environment_changed');
      expect(result['changes'], hasLength(2));
      expect(result['initial'], result['final']);
    },
  );

  testWidgets('native monitor observes platform semantics under a test lease', (
    tester,
  ) async {
    _prepare(tester);
    tester.platformDispatcher.semanticsEnabledTestValue = false;
    addTearDown(tester.platformDispatcher.clearSemanticsEnabledTestValue);
    expect(tester.binding.semanticsEnabled, isTrue);
    final monitor = NativePerformanceEnvironmentMonitor(tester.binding)
      ..start();
    tester.platformDispatcher.semanticsEnabledTestValue = true;
    monitor.check('during_interactions');
    tester.platformDispatcher.semanticsEnabledTestValue = false;
    monitor.check('during_interactions');
    final result = monitor.finish();
    expect(result['status'], 'invalid_environment_changed');
    expect(result['changes'], hasLength(2));
    expect(result['initial'], result['final']);
  });

  testWidgets('native monitor rejects inactive starting state', (tester) async {
    _prepare(tester);
    _lifecycle(tester.binding, AppLifecycleState.inactive);
    final monitor = NativePerformanceEnvironmentMonitor(tester.binding)
      ..start();
    expect(monitor.finish()['status'], 'invalid_environment_changed');
  });

  testWidgets('native Start needs actual lifecycle and native logical size', (
    tester,
  ) async {
    _prepare(tester);
    var starts = 0;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xff000000),
        builder: (context, child) => NativePerformanceStartControl(
          workloadCount: 8,
          onStart: () => starts++,
        ),
      ),
    );
    final start = find.text('Start native measurements');
    _lifecycle(tester.binding, AppLifecycleState.inactive);
    await tester.pump();
    await tester.tap(start);
    expect(starts, 0);
    _lifecycle(tester.binding, AppLifecycleState.resumed);
    tester.view.physicalSize = const Size(1800, 1400);
    await tester.pump();
    await tester.tap(start);
    expect(starts, 0);
    tester.view.physicalSize = const Size(2560, 1800);
    await tester.pump();
    await tester.tap(start);
    expect(starts, 1);
  });
}
