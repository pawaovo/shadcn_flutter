import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reveals [target] and taps once its center can be hit at a stable position.
///
/// A mounted widget can still be clipped or moving after a disclosure changes
/// scroll geometry. Repeated reveals are safe; repeated taps could submit twice.
/// This deliberately avoids pumpAndSettle because Catalog contains live timers.
Future<void> tapCatalogTarget(
  WidgetTester tester,
  Finder target, {
  Duration timeout = const Duration(seconds: 2),
  Duration frameInterval = const Duration(milliseconds: 16),
}) async {
  assert(timeout > Duration.zero);
  assert(frameInterval > Duration.zero);
  final attempts = (timeout.inMicroseconds / frameInterval.inMicroseconds)
      .ceil();
  Rect? previousRect;
  var stableFrames = 0;
  var lastState = 'not found';

  for (var attempt = 0; attempt < attempts; attempt++) {
    final matches = target.evaluate().toList();
    if (matches.length != 1) {
      throw TestFailure(
        'Cannot tap $target: expected exactly one mounted target, '
        'found ${matches.length}.',
      );
    }
    await Scrollable.ensureVisible(matches.single, alignment: 0.5);
    await tester.pump(frameInterval);

    if (target.evaluate().length != 1) {
      previousRect = null;
      stableFrames = 0;
      lastState = 'target changed during reveal';
      continue;
    }
    final rect = tester.getRect(target);
    final hitTestable = target.hitTestable().evaluate().length == 1;
    // Fractional device-pixel ratios can leave harmless floating-point drift
    // after a scroll offset is resolved. Actual hit testing remains mandatory.
    final stationary =
        previousRect != null &&
        (rect.topLeft - previousRect.topLeft).distance <= 0.25 &&
        (rect.bottomRight - previousRect.bottomRight).distance <= 0.25;
    stableFrames = hitTestable ? (stationary ? stableFrames + 1 : 1) : 0;
    previousRect = rect;
    lastState = hitTestable
        ? 'position has not remained stable across three frames ($rect)'
        : 'center is not hit-testable ($rect)';

    if (stableFrames >= 3) {
      // Keep normal missed-hit diagnostics enabled. There is no pointer event
      // until this point, and no retry after this single activation.
      await tester.tap(target);
      return;
    }
  }
  throw TestFailure(
    'Cannot tap $target after ${timeout.inMilliseconds} ms: $lastState.',
  );
}
