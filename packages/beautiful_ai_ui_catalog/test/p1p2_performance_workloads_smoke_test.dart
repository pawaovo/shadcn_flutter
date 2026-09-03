import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/p1p2_performance_workloads.dart';
import '../integration_test/support/p3_performance_measurement.dart';

// Debug functional validation only. This creates no frame/RSS evidence.
void main() {
  for (
    var index = 0;
    index < p1p2PerformanceWorkloadFactories.length;
    index++
  ) {
    testWidgets('P1/P2 profile workload $index repeats correctly', (
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
      final workload = p1p2PerformanceWorkloadFactories[index]();
      await tester.pumpWidget(p3PerformanceApp(workload.id, workload.child));
      final actions = P3PerformanceActions(tester, record: false, round: -1);
      await actions.settle();
      await workload.exercise(actions);
      await workload.exercise(actions);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
