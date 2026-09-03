import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'browser_input_bridge.dart';
import 'interactions.dart';

const useTrustedBrowserCopy =
    kIsWeb && bool.fromEnvironment('CATALOG_TRUSTED_BROWSER_COPY');

/// Only clipboard activation needs a trusted browser gesture. All assertions
/// remain in the original full journey; no operation is retried or mocked.
Future<void> activateCatalogCopy(
  WidgetTester tester,
  Finder target,
  String id, {
  required Finder completed,
}) async {
  Future<void> waitForCompletion() async {
    final elapsed = Stopwatch()..start();
    while (completed.evaluate().isEmpty) {
      if (elapsed.elapsed > const Duration(seconds: 3)) {
        fail('Real clipboard action did not report successful completion: $id');
      }
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  if (!useTrustedBrowserCopy) {
    await tapCatalogTarget(tester, target);
    await waitForCompletion();
    return;
  }
  await tester.ensureVisible(target);
  await tester.pump(const Duration(milliseconds: 150));
  expect(target.hitTestable(), findsOneWidget);
  final point = tester.getCenter(target);
  final elapsed = Stopwatch()..start();
  try {
    publishBrowserInputState(<String, Object?>{
      'stage': id,
      'x': point.dx,
      'y': point.dy,
    });
    while (browserInputAcknowledgement() != id) {
      if (elapsed.elapsed > const Duration(seconds: 30)) {
        fail('Trusted browser clipboard click did not arrive: $id');
      }
      await tester.pump(const Duration(milliseconds: 30));
    }
    await waitForCompletion();
  } finally {
    resetBrowserInputState();
  }
}
