import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  for (final (name, targetPolicy, platformDisabled) in [
    ('reduced', BeautifulMotionPolicy.reduced, false),
    ('none', BeautifulMotionPolicy.none, false),
    ('platform-disabled', BeautifulMotionPolicy.system, true),
  ]) {
    testWidgets(
      'copy pending, failure, and retry survive $name motion change',
      (tester) async {
        var policy = BeautifulMotionPolicy.system;
        var disabled = false;
        late StateSetter update;
        var pending = Completer<void>();
        final copied = <String>[];
        final failures = <BeautifulUiFailure>[];
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _motionApp(
                policy: policy,
                disabled: disabled,
                onFailure: failures.add,
                child: BeautifulCodeBlock.code(
                  filename: 'stock.dart',
                  code: 'return stock;',
                  onCopy: (text) {
                    copied.add(text);
                    return pending.future;
                  },
                ),
              );
            },
          ),
        );
        Focus.of(tester.element(find.text('Copy'))).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(find.text('Copying'), findsOneWidget);
        update(() {
          policy = targetPolicy;
          disabled = platformDisabled;
        });
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Copying'), findsOneWidget);
        await tester.tap(find.text('Copying'));
        expect(copied, ['return stock;']);
        pending.completeError(StateError('clipboard busy'));
        await tester.pump();
        expect(find.text('Copy failed'), findsOneWidget);
        expect(failures.single.operation, BeautifulUiOperation.clipboard);
        await tester.pump(const Duration(milliseconds: 1499));
        expect(find.text('Copy failed'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        expect(find.text('Copy'), findsOneWidget);
        pending = Completer<void>();
        await tester.tap(find.text('Copy'));
        await tester.pump();
        pending.complete();
        await tester.pump();
        await tester.pump();
        expect(find.text('Copied'), findsOneWidget);
        expect(copied, ['return stock;', 'return stock;']);
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.hasRunningAnimations, isFalse);
        // Disposal must cancel the separate feedback timer under every policy.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'recommendation switching and acceptance survive $name motion change',
      (tester) async {
        var policy = BeautifulMotionPolicy.system;
        var disabled = false;
        late StateSetter update;
        var pending = Completer<void>();
        final accepted = <String>[];
        final failures = <BeautifulUiFailure>[];
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _motionApp(
                policy: policy,
                disabled: disabled,
                onFailure: failures.add,
                child: BeautifulRecommendationCard(
                  title: 'Choose a supplier',
                  options: const [
                    BeautifulRecommendationOption(
                      id: 'stock',
                      body: 'Reorder existing stock.',
                      shortLabel: 'Keep current supplier',
                      signal: 3,
                      tone: BeautifulRecommendationTone.success,
                      confidenceLabel: 'Verified',
                      actionLabel: 'Accept stock',
                    ),
                    BeautifulRecommendationOption(
                      id: 'lead',
                      body: 'Review supplier lead times and receiving windows.',
                      shortLabel: 'Review lead times',
                      signal: 2,
                      tone: BeautifulRecommendationTone.warning,
                      confidenceLabel: 'Review required',
                      actionLabel: 'Apply reviewed choice',
                    ),
                  ],
                  onAccept: (option) {
                    accepted.add(option.id);
                    return pending.future;
                  },
                ),
              );
            },
          ),
        );
        await tester.tap(find.text('Alternatives'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Review lead times'));
        await tester.pump();
        // Change policy while the selected-body switch is still in flight.
        update(() {
          policy = targetPolicy;
          disabled = platformDisabled;
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Reorder existing stock.'), findsNothing);
        expect(
          find.text('Review supplier lead times and receiving windows.'),
          findsOneWidget,
        );
        expect(tester.hasRunningAnimations, isFalse);
        await tester.tap(find.text('Apply reviewed choice'));
        await tester.pump();
        expect(find.text('Accepting…'), findsOneWidget);
        await tester.tap(find.text('Accepting…'));
        expect(accepted, ['lead']);
        pending.completeError(StateError('supplier unavailable'));
        await tester.pump();
        expect(failures.single.operation, BeautifulUiOperation.recommendation);
        expect(find.text('Apply reviewed choice'), findsOneWidget);
        pending = Completer<void>();
        await tester.tap(find.text('Apply reviewed choice'));
        await tester.pump();
        pending.complete();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Accepted'), findsOneWidget);
        expect(accepted, ['lead', 'lead']);
        expect(tester.hasRunningAnimations, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('RTL approval progress keeps current before total visually', (
    tester,
  ) async {
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xffffffff),
        builder: (context, _) => Overlay.wrap(
          child: beautifulTestApp(
            textDirection: TextDirection.rtl,
            disableAnimations: true,
            child: BeautifulApprovalCard(
              id: 'review',
              questions: [
                for (var i = 0; i < 12; i++)
                  BeautifulApprovalQuestion(
                    id: 'q$i',
                    title: 'Question $i',
                    options: const [
                      BeautifulApprovalOption(id: 'yes', label: 'Yes'),
                    ],
                  ),
              ],
              onSubmit: (_) {},
            ),
          ),
        ),
      ),
    );
    _expectLeftToRightGlyphs(tester, '1 / 12', [0, 2, 4, 5]);
    expect(
      Directionality.of(tester.element(find.text('Question 0'))),
      TextDirection.rtl,
    );
  });

  testWidgets('RTL matching count keeps filtered rows before total rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        textDirection: TextDirection.rtl,
        disableAnimations: true,
        child: SingleChildScrollView(
          child: BeautifulFilterTable(
            labels: const BeautifulFilterTableLabels(results: 'نتائج'),
            initialStatus: BeautifulFilterTableStatus.completed,
            rows: [
              for (var i = 0; i < 12; i++)
                BeautifulFilterTableRow(
                  id: '$i',
                  task: 'Task $i',
                  date: 'Sep 3',
                  status: i == 0
                      ? BeautifulFilterTableStatus.completed
                      : BeautifulFilterTableStatus.todo,
                  owner: 'Review team',
                ),
            ],
          ),
        ),
      ),
    );
    final text = tester
        .widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText &&
                widget.text.toPlainText().contains('1 / 12'),
          ),
        )
        .text
        .toPlainText();
    final start = text.indexOf('1 / 12');
    _expectLeftToRightGlyphs(tester, text, [
      for (final i in [0, 2, 4, 5]) start + i,
    ]);
  });

  testWidgets('RTL tool diff keeps signs before their numeric counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        textDirection: TextDirection.rtl,
        disableAnimations: true,
        child: BeautifulToolChips(
          steps: const [],
          diffs: [
            BeautifulToolDiff(
              id: 'patch',
              file: 'stock.dart',
              additions: 12,
              deletions: 3,
            ),
          ],
        ),
      ),
    );
    _expectLeftToRightGlyphs(tester, '+12', [0, 1, 2]);
    _expectLeftToRightGlyphs(tester, '−3', [0, 1]);
  });

  testWidgets('RTL thinking coding counts preserve signed-number order', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        textDirection: TextDirection.rtl,
        disableAnimations: true,
        child: BeautifulThinking(
          variant: BeautifulThinkingVariant.coding,
          status: BeautifulThinkingStatus.complete,
          workingLabel: 'Reviewing',
          completedLabel: 'Reviewed',
          initiallyExpanded: true,
          items: const [
            BeautifulThinkingItem(
              id: 'edit',
              label: 'stock.dart',
              additions: 12,
              deletions: 3,
            ),
          ],
        ),
      ),
    );
    _expectLeftToRightGlyphs(tester, '+12 −3', [0, 1, 2, 4, 5]);
  });
}

Widget _motionApp({
  required BeautifulMotionPolicy policy,
  required bool disabled,
  required ValueChanged<BeautifulUiFailure> onFailure,
  required Widget child,
}) => MediaQuery(
  data: MediaQueryData(size: const Size(390, 844), disableAnimations: disabled),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: BeautifulUiScope(
      motion: policy,
      onFailure: onFailure,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 390, child: child),
      ),
    ),
  ),
);

void _expectLeftToRightGlyphs(
  WidgetTester tester,
  String text,
  List<int> offsets,
) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == text,
  );
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final lefts = [
    for (final offset in offsets)
      paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: offset + 1),
          )
          .single
          .left,
  ];
  for (var index = 1; index < lefts.length; index++) {
    expect(
      lefts[index],
      greaterThan(lefts[index - 1]),
      reason: 'The rendered glyphs of "$text" must retain numeric order.',
    );
  }
}
