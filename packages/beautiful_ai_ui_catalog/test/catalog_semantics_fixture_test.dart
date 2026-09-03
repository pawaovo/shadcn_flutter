import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/catalog_semantics_fixture.dart';

void main() {
  testWidgets(
    'platform handle is distinct from a finally-disposed test handle',
    (tester) async {
      final binding = tester.binding;
      final baseline = binding.debugOutstandingSemanticsHandles;
      final local = tester.ensureSemantics();
      try {
        // Minimal replay of the CI failure: a platform notification after the
        // test baseline leaves its own handle even though the local one closes.
        tester.platformDispatcher.semanticsEnabledTestValue = true;
      } finally {
        local.dispose();
      }
      try {
        expect(binding.debugOutstandingSemanticsHandles, baseline + 1);
      } finally {
        tester.platformDispatcher.clearSemanticsEnabledTestValue();
      }
    },
  );

  testWidgets(
    'suite warmup absorbs native activation before per-test baseline',
    (tester) async {
      final binding = tester.binding;
      final initial = binding.debugOutstandingSemanticsHandles;
      final fixture = CatalogSemanticsFixture(binding);
      try {
        await fixture.prepare(() async {
          // This is the same real SDK platform callback as the failing replay,
          // but it now arrives while setUpAll is establishing the native view.
          tester.platformDispatcher.semanticsEnabledTestValue = true;
        });
        final baseline = binding.debugOutstandingSemanticsHandles;
        expect(baseline, initial + 2); // Suite lease plus platform lease.
        final local = tester.ensureSemantics();
        tester.platformDispatcher.semanticsEnabledTestValue = true;
        local.dispose();
        expect(
          binding.debugOutstandingSemanticsHandles,
          baseline,
          reason: 'A SemanticsHandle was active at the end of the test.',
        );
        fixture.dispose();
        expect(binding.debugOutstandingSemanticsHandles, initial + 1);
        // Disposing this fixture does not disable the system-owned bridge.
        expect(tester.platformDispatcher.semanticsEnabled, isTrue);
      } finally {
        fixture.dispose();
        tester.platformDispatcher.clearSemanticsEnabledTestValue();
      }
      expect(binding.debugOutstandingSemanticsHandles, initial);
    },
  );

  testWidgets('an extra component handle still exceeds a prepared baseline', (
    tester,
  ) async {
    final binding = tester.binding;
    final fixture = CatalogSemanticsFixture(binding);
    try {
      await fixture.prepare(() async {
        tester.platformDispatcher.semanticsEnabledTestValue = true;
      });
      final baseline = binding.debugOutstandingSemanticsHandles;
      final leakedComponent = binding.ensureSemantics();
      final local = tester.ensureSemantics();
      local.dispose();
      try {
        // The same count comparison used by WidgetTester remains sensitive
        // to a new component leak; no native exception is subtracted.
        expect(binding.debugOutstandingSemanticsHandles, greaterThan(baseline));
      } finally {
        leakedComponent.dispose();
      }
      expect(binding.debugOutstandingSemanticsHandles, baseline);
    } finally {
      fixture.dispose();
      tester.platformDispatcher.clearSemanticsEnabledTestValue();
    }
  });

  testWidgets(
    'failed warmup releases its owned lease and can be disposed again',
    (tester) async {
      final binding = tester.binding;
      final baseline = binding.debugOutstandingSemanticsHandles;
      final fixture = CatalogSemanticsFixture(binding);
      await expectLater(
        fixture.prepare(() async {
          throw StateError('native view failed');
        }),
        throwsStateError,
      );
      expect(binding.debugOutstandingSemanticsHandles, baseline);
      fixture.dispose();
      expect(binding.debugOutstandingSemanticsHandles, baseline);
    },
  );

  test(
    'readiness observes platform changes even with aggregate semantics held on',
    () async {
      var enabled = false;
      var state = AppLifecycleState.inactive;
      final activation = Timer(const Duration(milliseconds: 10), () {
        enabled = true;
        state = AppLifecycleState.resumed;
      });
      try {
        await waitForStableCatalogPlatform(
          platformEnabled: () => enabled,
          lifecycle: () => state,
          requireResumed: true,
          quietPeriod: const Duration(milliseconds: 10),
          pollInterval: const Duration(milliseconds: 2),
          timeout: const Duration(seconds: 1),
        );
        expect(enabled, isTrue);
        expect(state, AppLifecycleState.resumed);
      } finally {
        activation.cancel();
      }
    },
  );

  test('a real device may resume with its platform bridge off', () async {
    await waitForStableCatalogPlatform(
      platformEnabled: () => false,
      lifecycle: () => AppLifecycleState.resumed,
      requireResumed: true,
      quietPeriod: Duration.zero,
      pollInterval: Duration.zero,
      timeout: const Duration(seconds: 1),
    );
  });

  test(
    'missing native view readiness fails instead of accepting a baseline',
    () async {
      await expectLater(
        waitForStableCatalogPlatform(
          platformEnabled: () => true,
          lifecycle: () => AppLifecycleState.inactive,
          requireResumed: true,
          quietPeriod: Duration.zero,
          pollInterval: const Duration(milliseconds: 1),
          timeout: const Duration(milliseconds: 5),
        ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
