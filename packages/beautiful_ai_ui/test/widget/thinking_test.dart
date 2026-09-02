import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _steps = <BeautifulThinkingItem>[
  BeautifulThinkingItem(id: 'read', label: 'Reading flavor briefs'),
  BeautifulThinkingItem(
    id: 'compare',
    label: 'Comparing notes',
    detail: '6 flavors',
  ),
];

BeautifulThinking _thinking({
  Key? key,
  BeautifulThinkingVariant variant = BeautifulThinkingVariant.steps,
  BeautifulThinkingStatus status = BeautifulThinkingStatus.working,
  Iterable<BeautifulThinkingItem> items = _steps,
  String workingLabel = 'Thinking',
  String completedLabel = 'Thought for 4 seconds',
  String? query,
  bool initiallyExpanded = false,
  ValueChanged<bool>? onExpandedChanged,
  ValueChanged<BeautifulThinkingItem>? onItemPressed,
}) {
  return BeautifulThinking(
    key: key,
    variant: variant,
    status: status,
    workingLabel: workingLabel,
    completedLabel: completedLabel,
    items: items,
    query: query,
    initiallyExpanded: initiallyExpanded,
    onExpandedChanged: onExpandedChanged,
    onItemPressed: onItemPressed,
  );
}

void main() {
  test('rejects blank and duplicate item IDs and defensively copies items', () {
    expect(
      () => _thinking(
        items: const <BeautifulThinkingItem>[
          BeautifulThinkingItem(id: ' ', label: 'Blank'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => _thinking(
        items: const <BeautifulThinkingItem>[
          BeautifulThinkingItem(id: 'same', label: 'One'),
          BeautifulThinkingItem(id: 'same', label: 'Two'),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => BeautifulThinking(
        variant: BeautifulThinkingVariant.steps,
        status: BeautifulThinkingStatus.working,
        workingLabel: ' ',
        completedLabel: 'Done',
        items: _steps,
      ),
      throwsArgumentError,
    );

    final source = <BeautifulThinkingItem>[..._steps];
    final thinking = _thinking(items: source);
    source.clear();
    expect(thinking.items, hasLength(2));
    expect(() => thinking.items.clear(), throwsUnsupportedError);
  });

  testWidgets('renders all four variants from caller-owned snapshots', (
    tester,
  ) async {
    final cases =
        <
          (
            BeautifulThinkingVariant,
            List<BeautifulThinkingItem>,
            String?,
            String,
          )
        >[
          (BeautifulThinkingVariant.steps, _steps, null, 'Comparing notes'),
          (
            BeautifulThinkingVariant.reasoning,
            const <BeautifulThinkingItem>[
              BeautifulThinkingItem(
                id: 'reason',
                label: 'Demand rises for stone-fruit flavors.',
              ),
            ],
            null,
            'Demand rises for stone-fruit flavors.',
          ),
          (
            BeautifulThinkingVariant.search,
            const <BeautifulThinkingItem>[
              BeautifulThinkingItem(
                id: 'joy-cone',
                label: 'Joy Cone',
                detail: 'joycone.com',
              ),
            ],
            'best waffle cone supplier',
            'Joy Cone',
          ),
          (
            BeautifulThinkingVariant.coding,
            const <BeautifulThinkingItem>[
              BeautifulThinkingItem(
                id: 'edit',
                label: 'Edit',
                detail: 'ChurnSchedule.dart',
                additions: 74,
                deletions: 41,
              ),
            ],
            null,
            'ChurnSchedule.dart',
          ),
        ];

    for (final (variant, items, query, expected) in cases) {
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: _thinking(
            variant: variant,
            items: items,
            query: query,
            initiallyExpanded: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Thinking'), findsOneWidget, reason: variant.name);
      expect(find.text(expected), findsOneWidget, reason: variant.name);
      expect(tester.takeException(), isNull, reason: variant.name);
    }
  });

  testWidgets('status and items remain caller-owned without a demo timer', (
    tester,
  ) async {
    const thinkingKey = Key('declarative-thinking');

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(key: thinkingKey, items: _steps.take(1)),
      ),
    );
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Thinking'), findsOneWidget);
    expect(find.text('Thought for 4 seconds'), findsNothing);

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(
          key: thinkingKey,
          status: BeautifulThinkingStatus.complete,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Thought for 4 seconds'), findsOneWidget);
    expect(find.text('Comparing notes'), findsOneWidget);
  });

  testWidgets('tap and keyboard toggle disclosure and report changes', (
    tester,
  ) async {
    final changes = <bool>[];
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(onExpandedChanged: changes.add),
      ),
    );

    await tester.tap(find.text('Thinking'));
    await tester.pump();
    expect(changes, <bool>[true]);

    await tester.tap(find.text('Thinking'));
    await tester.pump();
    expect(changes, <bool>[true, false]);

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(
          key: const Key('keyboard-thinking'),
          onExpandedChanged: changes.add,
        ),
      ),
    );
    await tester.pump();
    final headerControl = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('beautiful-thinking-header')),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    headerControl.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(changes, <bool>[true, false, true]);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(changes, <bool>[true, false, true, false]);
  });

  testWidgets('search activation and coding selection use one item callback', (
    tester,
  ) async {
    final pressed = <String>[];
    const searchItem = BeautifulThinkingItem(
      id: 'joy-cone',
      label: 'Joy Cone',
      detail: 'joycone.com',
    );
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(
          variant: BeautifulThinkingVariant.search,
          items: const <BeautifulThinkingItem>[searchItem],
          initiallyExpanded: true,
          onItemPressed: (item) => pressed.add(item.id),
        ),
      ),
    );
    await tester.tap(find.text('Joy Cone'));
    await tester.pump();
    expect(pressed, <String>['joy-cone']);

    const codingKey = Key('coding-thinking');
    const codingItem = BeautifulThinkingItem(
      id: 'read',
      label: 'Read',
      detail: 'flavors.dart',
    );
    Widget coding(double width) => beautifulTestApp(
      size: Size(width, 900),
      disableAnimations: true,
      child: _thinking(
        key: codingKey,
        variant: BeautifulThinkingVariant.coding,
        items: const <BeautifulThinkingItem>[codingItem],
        initiallyExpanded: true,
        onItemPressed: (item) => pressed.add(item.id),
      ),
    );

    await tester.pumpWidget(coding(599));
    await tester.tap(find.text('Read'));
    await tester.pump();
    var row = tester
        .getSemantics(find.bySemanticsLabel('Read, flavors.dart'))
        .getSemanticsData();
    expect(row.flagsCollection.isSelected, Tristate.isTrue);
    expect(pressed, <String>['joy-cone', 'read']);

    await tester.pumpWidget(coding(1024));
    await tester.pump();
    row = tester
        .getSemantics(find.bySemanticsLabel('Read, flavors.dart'))
        .getSemanticsData();
    expect(row.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('preserves disclosure across all breakpoint boundaries', (
    tester,
  ) async {
    const thinkingKey = Key('resizable-thinking');
    Widget app(double width) => beautifulTestApp(
      size: Size(width, 900),
      disableAnimations: true,
      child: _thinking(key: thinkingKey),
    );

    await tester.pumpWidget(app(599));
    await tester.tap(find.text('Thinking'));
    await tester.pump();

    for (final width in <double>[600, 1023, 1024, 599]) {
      await tester.pumpWidget(app(width));
      await tester.pump();
      final header = tester
          .getSemantics(find.bySemanticsIdentifier('beautiful-thinking-header'))
          .getSemanticsData();
      expect(
        header.flagsCollection.isExpanded,
        Tristate.isTrue,
        reason: 'width $width',
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('supports RTL, 200 percent text, and compact long content', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(320, 700),
        disableAnimations: true,
        textDirection: TextDirection.rtl,
        textScaler: const TextScaler.linear(2),
        child: _thinking(
          variant: BeautifulThinkingVariant.search,
          workingLabel: 'جارٍ البحث في الويب',
          completedLabel: 'اكتمل البحث',
          query: 'أفضل مورد لمخاريط الوافل في المنطقة',
          items: const <BeautifulThinkingItem>[
            BeautifulThinkingItem(
              id: 'arabic-result',
              label: 'نتيجة بحث طويلة للغاية لاختبار الالتفاف',
              detail: 'example.com',
            ),
          ],
          initiallyExpanded: true,
          onItemPressed: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('جارٍ البحث في الويب'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  });

  testWidgets('platform, reduced, and none policies stop continuous motion', (
    tester,
  ) async {
    for (final (disableAnimations, policy) in <(bool, BeautifulMotionPolicy)>[
      (true, BeautifulMotionPolicy.system),
      (false, BeautifulMotionPolicy.reduced),
      (false, BeautifulMotionPolicy.none),
    ]) {
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: disableAnimations,
          motion: policy,
          child: _thinking(
            key: ValueKey<(bool, BeautifulMotionPolicy)>((
              disableAnimations,
              policy,
            )),
            initiallyExpanded: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: '$disableAnimations/${policy.name}',
      );
      expect(tester.takeException(), isNull);
    }
  });
}
