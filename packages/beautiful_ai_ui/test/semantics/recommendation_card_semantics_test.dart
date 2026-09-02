import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _options = <BeautifulRecommendationOption>[
  BeautifulRecommendationOption(
    id: 'high',
    body: 'Reorder waffle cones from Cone King.',
    shortLabel: 'Reorder from Cone King',
    signal: 3,
    tone: BeautifulRecommendationTone.success,
    confidenceLabel: 'High confidence',
    actionLabel: 'Accept',
  ),
  BeautifulRecommendationOption(
    id: 'review',
    body: 'Switch to Vanilla Madagascar.',
    shortLabel: 'Switch to Vanilla Madagascar',
    signal: 2,
    tone: BeautifulRecommendationTone.warning,
    confidenceLabel: 'Needs review',
    actionLabel: 'Configure',
  ),
];

void main() {
  testWidgets('exposes heading, confidence value, and collapsed button state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulRecommendationCard(
          title: 'Want me to place this order?',
          options: _options,
          onAccept: (_) {},
        ),
      ),
    );

    final heading = tester
        .getSemantics(find.bySemanticsLabel('Want me to place this order?'))
        .getSemanticsData();
    final confidence = tester
        .getSemantics(find.bySemanticsLabel('High confidence'))
        .getSemanticsData();
    final disclosure = tester
        .getSemantics(find.bySemanticsLabel('Alternatives'))
        .getSemanticsData();
    final action = tester
        .getSemantics(find.bySemanticsLabel('Accept'))
        .getSemanticsData();

    expect(heading.flagsCollection.isHeader, isTrue);
    expect(confidence.value, '3/3');
    expect(disclosure.flagsCollection.isButton, isTrue);
    expect(disclosure.flagsCollection.isExpanded, Tristate.isFalse);
    expect(action.flagsCollection.isButton, isTrue);
    expect(action.flagsCollection.isEnabled, Tristate.isTrue);
    expect(
      find.bySemanticsLabel('Switch to Vanilla Madagascar, Needs review'),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets(
    'expanded alternatives are named buttons and disappear on collapse',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulRecommendationCard(
            title: 'Recommendation',
            options: _options,
            onAccept: (_) {},
          ),
        ),
      );

      await tester.tap(find.bySemanticsLabel('Alternatives'));
      await tester.pump();

      final disclosure = tester
          .getSemantics(find.bySemanticsLabel('Alternatives'))
          .getSemanticsData();
      final alternative = tester
          .getSemantics(
            find.bySemanticsLabel('Switch to Vanilla Madagascar, Needs review'),
          )
          .getSemanticsData();
      expect(disclosure.flagsCollection.isExpanded, Tristate.isTrue);
      expect(alternative.flagsCollection.isButton, isTrue);
      expect(alternative.flagsCollection.isEnabled, Tristate.isTrue);

      await tester.tap(find.bySemanticsLabel('Alternatives'));
      await tester.pump();
      expect(
        find.bySemanticsLabel('Switch to Vanilla Madagascar, Needs review'),
        findsNothing,
      );
      semantics.dispose();
    },
  );

  testWidgets('pending action is disabled and success exposes accepted label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final completion = Completer<void>();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulRecommendationCard(
          title: 'Recommendation',
          options: _options,
          onAccept: (_) => completion.future,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Accept'));
    await tester.pump();

    final pending = tester
        .getSemantics(find.bySemanticsLabel('Accepting…'))
        .getSemanticsData();
    expect(pending.flagsCollection.isButton, isTrue);
    expect(pending.flagsCollection.isEnabled, Tristate.isFalse);

    completion.complete();
    await tester.pump();

    final accepted = tester
        .getSemantics(find.bySemanticsLabel('Accepted'))
        .getSemanticsData();
    expect(accepted.flagsCollection.isButton, isTrue);
    expect(accepted.flagsCollection.isEnabled, Tristate.isTrue);
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('interactive targets meet guidance in ${brightness.name}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(390, 700),
          brightness: brightness,
          highContrast: true,
          disableAnimations: true,
          child: BeautifulRecommendationCard(
            title: 'Recommendation',
            options: _options,
            onAccept: (_) {},
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });
  }
}
