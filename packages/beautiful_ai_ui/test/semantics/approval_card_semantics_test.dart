import 'dart:async';
import 'dart:ui' show CheckedState, Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

List<BeautifulApprovalQuestion> _questions() => [
  BeautifulApprovalQuestion(
    id: 'single',
    title: 'Select a market',
    options: const [
      BeautifulApprovalOption(id: 'shops', label: 'Scoop shops'),
      BeautifulApprovalOption(id: 'trucks', label: 'Food trucks'),
    ],
  ),
  BeautifulApprovalQuestion(
    id: 'multiple',
    title: 'Select mix-ins',
    type: BeautifulApprovalQuestionType.multipleChoice,
    options: const [BeautifulApprovalOption(id: 'chips', label: 'Chips')],
  ),
];

void main() {
  testWidgets(
    'active heading, checked choice, field and navigation have roles',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulApprovalCard(
            id: 'launch',
            questions: _questions(),
            autoAdvance: false,
            onSubmit: (_) {},
          ),
        ),
      );
      final heading = tester
          .getSemantics(find.bySemanticsLabel('Select a market'))
          .getSemanticsData();
      expect(heading.flagsCollection.isHeader, isTrue);
      expect(heading.flagsCollection.isLiveRegion, isTrue);
      var choice = tester
          .getSemantics(find.bySemanticsLabel('Scoop shops'))
          .getSemanticsData();
      expect(choice.flagsCollection.isChecked, CheckedState.isFalse);
      expect(choice.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      await tester.tap(find.text('Scoop shops'));
      await tester.pump();
      choice = tester
          .getSemantics(find.bySemanticsLabel('Scoop shops'))
          .getSemanticsData();
      expect(choice.flagsCollection.isChecked, CheckedState.isTrue);
      final custom = tester
          .getSemantics(find.bySemanticsLabel('Custom answer'))
          .getSemanticsData();
      expect(custom.flagsCollection.isTextField, isTrue);
      final previous = tester
          .getSemantics(find.bySemanticsLabel('Previous question'))
          .getSemanticsData();
      expect(previous.flagsCollection.isEnabled, Tristate.isFalse);
      expect(find.bySemanticsLabel('Chips'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      final multiple = tester
          .getSemantics(find.bySemanticsLabel('Chips'))
          .getSemanticsData();
      expect(multiple.flagsCollection.isInMutuallyExclusiveGroup, isFalse);
      expect(find.bySemanticsLabel('Scoop shops'), findsNothing);
      expect(find.bySemanticsLabel('Select a market'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'dismissed question exits semantics and pending controls disable',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final pending = Completer<void>();
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulApprovalCard(
            id: 'launch',
            questions: [_questions().first],
            onSubmit: (_) => pending.future,
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pump();
      expect(find.bySemanticsLabel('Scoop shops'), findsNothing);
      expect(find.bySemanticsLabel('Custom answer'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Open approval'));
      await tester.pump();
      await tester.tap(find.text('Scoop shops'));
      await tester.pump();
      final action = tester
          .getSemantics(find.bySemanticsLabel('Sending…'))
          .getSemanticsData();
      expect(action.flagsCollection.isEnabled, Tristate.isFalse);
      expect(action.flagsCollection.isLiveRegion, isTrue);
      final choice = tester
          .getSemantics(find.bySemanticsLabel('Food trucks'))
          .getSemanticsData();
      expect(choice.flagsCollection.isEnabled, Tristate.isFalse);
      pending.complete();
      await tester.pump();
      final success = tester
          .getSemantics(find.bySemanticsLabel('✓ Answers sent'))
          .getSemanticsData();
      expect(success.flagsCollection.isLiveRegion, isTrue);
      expect(find.bySemanticsLabel('Scoop shops'), findsNothing);
      semantics.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      '48dp interaction targets at ${brightness.name} high contrast',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          beautifulTestApp(
            size: const Size(390, 844),
            brightness: brightness,
            highContrast: true,
            disableAnimations: true,
            child: BeautifulApprovalCard(
              id: 'launch',
              questions: _questions(),
              autoAdvance: false,
              onSubmit: (_) {},
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        semantics.dispose();
      },
    );
  }
}
