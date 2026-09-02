import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _options = <BeautifulRecommendationOption>[
  BeautifulRecommendationOption(
    id: 'high',
    body: 'Reorder waffle cones from Cone King with a seven day lead.',
    shortLabel: 'Reorder from Cone King',
    signal: 3,
    tone: BeautifulRecommendationTone.success,
    confidenceLabel: 'High confidence',
    actionLabel: 'Accept',
  ),
  BeautifulRecommendationOption(
    id: 'review',
    body: 'Switch vanilla to Vanilla Madagascar for peak season.',
    shortLabel: 'Switch to Vanilla Madagascar',
    signal: 2,
    tone: BeautifulRecommendationTone.warning,
    confidenceLabel: 'Needs review',
    actionLabel: 'Configure',
  ),
  BeautifulRecommendationOption(
    id: 'none',
    body: 'Fall back to a full restock across every SKU.',
    shortLabel: 'Full restock across every SKU',
    signal: 0,
    tone: BeautifulRecommendationTone.neutral,
    confidenceLabel: 'No signal',
    actionLabel: 'Accept full restock',
  ),
];

const _replacementOptions = <BeautifulRecommendationOption>[
  BeautifulRecommendationOption(
    id: 'high',
    body: 'Use the replacement recommendation with the same stable option ID.',
    shortLabel: 'Use the replacement recommendation',
    signal: 2,
    tone: BeautifulRecommendationTone.warning,
    confidenceLabel: 'Replacement confidence',
    actionLabel: 'Apply replacement',
  ),
];

void main() {
  test('validates option and card invariants', () {
    expect(
      () => BeautifulRecommendationOption(
        id: 'invalid',
        body: 'Invalid',
        shortLabel: 'Invalid',
        signal: 4,
        tone: BeautifulRecommendationTone.neutral,
        confidenceLabel: 'Invalid',
        actionLabel: 'Accept',
      ),
      throwsAssertionError,
    );
    expect(
      () => BeautifulRecommendationCard(
        title: 'Recommendation',
        options: const <BeautifulRecommendationOption>[],
        onAccept: (_) {},
      ),
      throwsAssertionError,
    );
    expect(
      () => BeautifulRecommendationCard(
        title: 'Recommendation',
        options: <BeautifulRecommendationOption>[_options[0], _options[0]],
        onAccept: (_) {},
      ),
      throwsAssertionError,
    );
    expect(
      () => BeautifulRecommendationCard(
        title: 'Recommendation',
        options: _options,
        initialOptionId: 'missing',
        onAccept: (_) {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets(
    'selects an alternative and accepts the promoted option by pointer',
    (tester) async {
      BeautifulRecommendationOption? accepted;
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(800, 700),
          disableAnimations: true,
          child: BeautifulRecommendationCard(
            title: 'Want me to place this order?',
            options: _options,
            initialOptionId: 'review',
            onAccept: (option) => accepted = option,
          ),
        ),
      );

      expect(
        find.text('Switch vanilla to Vanilla Madagascar for peak season.'),
        findsOneWidget,
      );
      expect(find.text('Other options'), findsNothing);

      await tester.tap(find.text('Alternatives'));
      await tester.pump();
      expect(find.text('Other options'), findsOneWidget);
      expect(find.text('Reorder from Cone King'), findsOneWidget);

      await tester.tap(find.text('Reorder from Cone King'));
      await tester.pump();
      expect(
        find.text('Reorder waffle cones from Cone King with a seven day lead.'),
        findsOneWidget,
      );
      expect(find.text('Other options'), findsOneWidget);

      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(accepted?.id, 'high');
      expect(find.text('Accepted'), findsOneWidget);
    },
  );

  testWidgets('suppresses repeated activation while acceptance is pending', (
    tester,
  ) async {
    final completion = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulRecommendationCard(
          title: 'Recommendation',
          options: _options,
          onAccept: (_) {
            calls++;
            return completion.future;
          },
        ),
      ),
    );

    final accept = find.byKey(const ValueKey<String>('recommendation-accept'));
    await tester.tap(accept);
    await tester.tap(accept);
    await tester.pump();

    expect(calls, 1);
    expect(find.text('Accepting…'), findsOneWidget);

    completion.complete();
    await tester.pump();
    expect(find.text('Accepted'), findsOneWidget);
  });

  testWidgets('ignores stale success after the recommendation model changes', (
    tester,
  ) async {
    final staleCompletion = Completer<void>();
    late StateSetter updateHost;
    var replacement = false;
    var replacementAccepts = 0;

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return BeautifulRecommendationCard(
              title: replacement
                  ? 'Replacement recommendation'
                  : 'Original recommendation',
              options: replacement ? _replacementOptions : _options,
              onAccept: replacement
                  ? (_) => replacementAccepts++
                  : (_) => staleCompletion.future,
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Accept'));
    await tester.pump();
    expect(find.text('Accepting…'), findsOneWidget);

    updateHost(() => replacement = true);
    await tester.pump();
    expect(find.text('Apply replacement'), findsOneWidget);
    expect(find.text('Accepted'), findsNothing);

    staleCompletion.complete();
    await tester.pump();
    expect(find.text('Apply replacement'), findsOneWidget);
    expect(find.text('Accepted'), findsNothing);

    await tester.tap(find.text('Apply replacement'));
    await tester.pump();
    expect(replacementAccepts, 1);
    expect(find.text('Accepted'), findsOneWidget);
  });

  testWidgets('ignores stale failure after the recommendation model changes', (
    tester,
  ) async {
    final staleCompletion = Completer<void>();
    final failures = <BeautifulUiFailure>[];
    late StateSetter updateHost;
    var replacement = false;

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulUiScope(
          onFailure: failures.add,
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return BeautifulRecommendationCard(
                title: replacement
                    ? 'Replacement recommendation'
                    : 'Original recommendation',
                options: replacement ? _replacementOptions : _options,
                onAccept: replacement ? (_) {} : (_) => staleCompletion.future,
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Accept'));
    await tester.pump();
    updateHost(() => replacement = true);
    await tester.pump();

    staleCompletion.completeError(StateError('stale failure'));
    await tester.pump();

    expect(failures, isEmpty);
    expect(find.text('Apply replacement'), findsOneWidget);
    expect(find.text('Accepted'), findsNothing);
  });

  testWidgets(
    'reports a failed action and preserves selection and disclosure',
    (tester) async {
      BeautifulUiFailure? failure;
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulUiScope(
            onFailure: (value) => failure = value,
            child: BeautifulRecommendationCard(
              title: 'Recommendation',
              options: _options,
              onAccept: (_) => throw StateError('offline'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Alternatives'));
      await tester.pump();
      await tester.tap(find.text('Switch to Vanilla Madagascar'));
      await tester.pump();
      await tester.tap(find.text('Configure'));
      await tester.pump();

      expect(failure?.operation, BeautifulUiOperation.recommendation);
      expect(failure?.cause, isA<StateError>());
      expect(
        find.text('Switch vanilla to Vanilla Madagascar for peak season.'),
        findsOneWidget,
      );
      expect(find.text('Other options'), findsOneWidget);
      expect(find.text('Configure'), findsOneWidget);
      expect(find.text('Accepted'), findsNothing);
    },
  );

  testWidgets('supports keyboard disclosure, escape, and activation', (
    tester,
  ) async {
    var accepts = 0;
    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(800, 700),
        disableAnimations: true,
        child: BeautifulRecommendationCard(
          title: 'Recommendation',
          options: _options,
          onAccept: (_) => accepts++,
        ),
      ),
    );

    _focusControl(tester, 'recommendation-alternatives');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Other options'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Other options'), findsNothing);

    _focusControl(tester, 'recommendation-accept');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(accepts, 1);
    expect(find.text('Accepted'), findsOneWidget);
  });

  testWidgets(
    'compact RTL layout supports 200 percent text and a full-width action',
    (tester) async {
      const arabicOptions = <BeautifulRecommendationOption>[
        BeautifulRecommendationOption(
          id: 'first',
          body: 'إعادة طلب المخزون من المورد مع وصف طويل قابل للالتفاف',
          shortLabel: 'إعادة الطلب من المورد الرئيسي',
          signal: 3,
          tone: BeautifulRecommendationTone.success,
          confidenceLabel: 'ثقة عالية',
          actionLabel: 'قبول هذا الاقتراح الطويل',
        ),
        BeautifulRecommendationOption(
          id: 'second',
          body: 'استخدام الخيار البديل خلال الموسم',
          shortLabel: 'استخدام الخيار البديل خلال الموسم',
          signal: 2,
          tone: BeautifulRecommendationTone.warning,
          confidenceLabel: 'يحتاج إلى مراجعة',
          actionLabel: 'تهيئة',
        ),
      ];
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(320, 700),
          textDirection: TextDirection.rtl,
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
          child: SingleChildScrollView(
            child: SizedBox(
              width: 280,
              child: BeautifulRecommendationCard(
                title: 'هل تريد تنفيذ هذا الاقتراح الآن؟',
                options: arabicOptions,
                alternativesLabel: 'الخيارات البديلة',
                otherOptionsLabel: 'خيارات أخرى',
                pendingLabel: 'جارٍ القبول…',
                acceptedLabel: 'تم القبول',
                onAccept: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final surfaceWidth = tester
          .getSize(
            find.byKey(const ValueKey<String>('recommendation-card-surface')),
          )
          .width;
      final actionWidth = tester
          .getSize(find.byKey(const ValueKey<String>('recommendation-accept')))
          .width;
      expect(surfaceWidth, 280);
      expect(actionWidth, surfaceWidth - 22);

      await tester.tap(find.text('الخيارات البديلة'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('خيارات أخرى'), findsOneWidget);
    },
  );

  testWidgets('preserves selected option and disclosure across resize', (
    tester,
  ) async {
    Widget app(double width) {
      return beautifulTestApp(
        size: Size(width, 800),
        disableAnimations: true,
        child: BeautifulRecommendationCard(
          key: const ValueKey<String>('persistent-recommendation'),
          title: 'Recommendation',
          options: _options,
          onAccept: (_) {},
        ),
      );
    }

    await tester.pumpWidget(app(599));
    await tester.tap(find.text('Alternatives'));
    await tester.pump();
    await tester.tap(find.text('Switch to Vanilla Madagascar'));
    await tester.pump();

    await tester.pumpWidget(app(1024));
    await tester.pump();

    expect(
      find.text('Switch vanilla to Vanilla Madagascar for peak season.'),
      findsOneWidget,
    );
    expect(find.text('Other options'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders at every adaptive boundary without overflow', (
    tester,
  ) async {
    for (final width in <double>[599, 600, 1023, 1024]) {
      await tester.pumpWidget(
        beautifulTestApp(
          size: Size(width, 800),
          disableAnimations: true,
          child: SingleChildScrollView(
            child: BeautifulRecommendationCard(
              key: ValueKey<double>(width),
              title: 'Recommendation at $width',
              options: _options,
              onAccept: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}

void _focusControl(WidgetTester tester, String key) {
  final gesture = find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(GestureDetector),
  );
  Focus.of(tester.element(gesture.first)).requestFocus();
}
