import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'profile_async_guard.dart';

/// Uses Flutter's timed-drag event generator and WidgetTester's replay cadence,
/// guarding the replay's internal awaits as well as its outer Future. An outer
/// timeout alone cannot stop a late native pump from dispatching more input.
final class ProfilePointerController extends LiveWidgetController {
  ProfilePointerController(this.testBinding, this.guard) : super(testBinding);

  final TestWidgetsFlutterBinding testBinding;
  final ProfileAsyncGuard guard;

  @override
  Future<List<Duration>> handlePointerEventRecord(
    List<PointerEventRecord> records,
  ) => TestAsyncUtils.guard<List<Duration>>(() async {
    assert(records.isNotEmpty);
    final differences = <Duration>[];
    DateTime? startTime;
    for (final record in records) {
      guard.checkActive();
      final now = testBinding.clock.now();
      startTime ??= now;
      final timeDiff = record.timeDelay - now.difference(startTime);
      if (timeDiff.isNegative) {
        differences.add(-timeDiff);
      } else {
        // Keep the pinned SDK WidgetTester order: pump, delay, then dispatch.
        // LiveWidgetController's default replay does not include this pump.
        await guard.wait('pointer.pump', () => testBinding.pump());
        await guard.wait('pointer.delay', () => testBinding.delayed(timeDiff));
        differences.add(
          testBinding.clock.now().difference(startTime) - record.timeDelay,
        );
      }
      for (final PointerEvent event in record.events) {
        guard.checkActive();
        testBinding.handlePointerEventForSource(
          event,
          source: TestBindingEventSource.test,
        );
      }
    }
    await guard.wait('pointer.final_pump', () => testBinding.pump());
    return differences;
  });
}
