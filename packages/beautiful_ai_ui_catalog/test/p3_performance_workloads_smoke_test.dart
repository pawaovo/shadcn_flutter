import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/p3_performance_measurement.dart';
import '../integration_test/support/p3_performance_workloads.dart';

// Functional checks for the profile script only. This debug test creates no
// frame or memory evidence and does not stand in for a native profile run.
void main() {
  for (var index = 0; index < p3PerformanceWorkloadFactories.length; index++) {
    testWidgets('profile workload $index completes its scripted input', (
      tester,
    ) async {
      final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(
        () => WidgetController.hitTestWarningShouldBeFatal = previousFatal,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final fixture = p3PerformanceWorkloadFactories[index]();
      await tester.pumpWidget(p3PerformanceApp(fixture.id, fixture.child));
      final actions = P3PerformanceActions(tester, record: false, round: -1);
      await actions.settle();
      await fixture.exercise(actions);
      // A second round catches warmup state that would invalidate measurement.
      await fixture.exercise(actions);
      expect(tester.takeException(), isNull);
    });
  }
}
