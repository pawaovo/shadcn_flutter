import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('renders every loading variant without exceptions', (
    tester,
  ) async {
    for (final variant in BeautifulLoadingVariant.values) {
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulLoadingState(
            label: 'Preparing workspace',
            variant: variant,
            elapsed: const Duration(milliseconds: 12300),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: variant.name);
      expect(find.text('Preparing workspace'), findsOneWidget);
    }
  });

  testWidgets('formats elapsed time below and above one minute', (
    tester,
  ) async {
    for (final (elapsed, expected) in <(Duration, String)>[
      (Duration.zero, '0.0s'),
      (const Duration(milliseconds: 12300), '12.3s'),
      (const Duration(milliseconds: 59900), '59.9s'),
      (const Duration(milliseconds: 59950), '59.9s'),
      (const Duration(milliseconds: 60000), '1m 0.0s'),
      (const Duration(milliseconds: 61200), '1m 1.2s'),
      (const Duration(milliseconds: 119950), '1m 59.9s'),
    ]) {
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulLoadingState(label: 'Loading', elapsed: elapsed),
        ),
      );
      expect(find.text(expected), findsOneWidget);
    }
  });

  testWidgets('supports compact width, 200 percent text, and long content', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(320, 568),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
        child: const SizedBox(
          width: 280,
          child: BeautifulLoadingState(
            label: 'Preparing an unusually long workspace description without overflow',
            elapsed: Duration(milliseconds: 12300),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.text(
        'Preparing an unusually long workspace description without overflow',
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses caller-owned surfer media when supplied', (tester) async {
    const mediaKey = Key('licensed-media');
    await tester.pumpWidget(
      beautifulTestApp(
        child: const BeautifulLoadingState(
          label: 'Processing',
          variant: BeautifulLoadingVariant.surfer,
          surferMedia: ColoredBox(key: mediaKey, color: Color(0xff0285ff)),
        ),
      ),
    );
    expect(find.byKey(mediaKey), findsOneWidget);
    expect(find.text('Media unavailable'), findsNothing);
  });

  testWidgets('preserves caller media and disables its ticker subtree', (
    tester,
  ) async {
    const mediaKey = Key('animated-media');
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulLoadingState(
          label: 'Processing',
          variant: BeautifulLoadingVariant.surfer,
          surferMedia: ColoredBox(key: mediaKey, color: Color(0xff0285ff)),
        ),
      ),
    );

    expect(find.byKey(mediaKey), findsOneWidget);
    expect(find.text('Media unavailable'), findsNothing);
    final tickerMode = tester.widget<TickerMode>(
      find
          .ancestor(of: find.byKey(mediaKey), matching: find.byType(TickerMode))
          .first,
    );
    expect(tickerMode.enabled, isFalse);
  });

  testWidgets('supports localized elapsed formatting and semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulLoadingState(
          label: 'Arbeitsbereich wird vorbereitet',
          elapsed: const Duration(milliseconds: 12300),
          elapsedSemanticLabel: 'Verstrichene Zeit',
          elapsedFormatter: (_) => '12,3 Sekunden',
        ),
      ),
    );

    expect(find.text('12,3 Sekunden'), findsOneWidget);
    expect(find.bySemanticsLabel('Verstrichene Zeit'), findsOneWidget);
  });

  testWidgets('shows a license-safe surfer fallback without bundled media', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulLoadingState(
          label: 'Processing',
          variant: BeautifulLoadingVariant.surfer,
          surferFallbackLabel: 'Bring licensed media',
        ),
      ),
    );
    expect(find.text('Bring licensed media'), findsOneWidget);
  });

  testWidgets('surfer stage uses the source-derived 200ms entrance', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        child: const BeautifulLoadingState(
          label: 'Processing',
          variant: BeautifulLoadingVariant.surfer,
        ),
      ),
    );

    Opacity entranceOpacity() {
      return tester
          .widgetList<Opacity>(
            find.descendant(
              of: find.byType(BeautifulLoadingState),
              matching: find.byType(Opacity),
            ),
          )
          .single;
    }

    expect(entranceOpacity().opacity, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(entranceOpacity().opacity, greaterThan(0));
    expect(entranceOpacity().opacity, lessThan(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(entranceOpacity().opacity, 1);
  });

  testWidgets('continues to render at medium and expanded breakpoints', (
    tester,
  ) async {
    for (final width in <double>[599, 600, 1023, 1024, 1440]) {
      await tester.pumpWidget(
        beautifulTestApp(
          size: Size(width, 900),
          disableAnimations: true,
          child: const BeautifulLoadingState(
            label: 'Preparing workspace',
            elapsed: Duration(milliseconds: 500),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('supports RTL, 200 percent text, and compact Surfer layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(320, 568),
        disableAnimations: true,
        textDirection: TextDirection.rtl,
        textScaler: const TextScaler.linear(2),
        child: const BeautifulLoadingState(
          label: 'جارٍ تجهيز مساحة العمل الطويلة',
          variant: BeautifulLoadingVariant.surfer,
          elapsed: Duration(milliseconds: 59950),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('جارٍ تجهيز مساحة العمل الطويلة'), findsOneWidget);
    expect(find.text('59.9s'), findsOneWidget);
  });

  testWidgets('preserves Surfer entrance state across constraint changes', (
    tester,
  ) async {
    const loadingKey = Key('resizable-surfer');
    Widget app(double width) {
      return beautifulTestApp(
        size: Size(width, 900),
        child: const BeautifulLoadingState(
          key: loadingKey,
          label: 'Processing',
          variant: BeautifulLoadingVariant.surfer,
        ),
      );
    }

    await tester.pumpWidget(app(599));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(app(1024));

    final opacity = tester
        .widgetList<Opacity>(
          find.descendant(
            of: find.byKey(loadingKey),
            matching: find.byType(Opacity),
          ),
        )
        .single;
    expect(opacity.opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stops continuous module motion when the platform requests it', (
    tester,
  ) async {
    const loadingKey = Key('loading');
    await tester.pumpWidget(
      beautifulTestApp(
        child: const BeautifulLoadingState(
          key: loadingKey,
          label: 'Preparing workspace',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulLoadingState(
          key: loadingKey,
          label: 'Preparing workspace',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced and none package policies stop continuous motion', (
    tester,
  ) async {
    for (final policy in <BeautifulMotionPolicy>[
      BeautifulMotionPolicy.reduced,
      BeautifulMotionPolicy.none,
    ]) {
      await tester.pumpWidget(
        beautifulTestApp(
          motion: policy,
          child: BeautifulLoadingState(
            key: ValueKey<BeautifulMotionPolicy>(policy),
            label: 'Preparing workspace',
            variant: BeautifulLoadingVariant.surfer,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0, reason: policy.name);
      expect(tester.takeException(), isNull, reason: policy.name);
    }
  });
}
