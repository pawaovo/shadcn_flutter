import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _items = <BeautifulThinkingItem>[
  BeautifulThinkingItem(id: 'read', label: 'Read', detail: 'flavors.dart'),
  BeautifulThinkingItem(id: 'edit', label: 'Edit', detail: 'schedule.dart'),
];

Finder get _headerWidget =>
    find.bySemanticsIdentifier('beautiful-thinking-header');

Finder get _statusWidget =>
    find.bySemanticsIdentifier('beautiful-thinking-status');

SemanticsFinder get _headerSemantics => find.semantics.byPredicate(
  (node) => node.identifier == 'beautiful-thinking-header',
  describeMatch: (_) => 'Thinking disclosure button',
);

BeautifulThinking _thinking({
  Key? key,
  BeautifulThinkingVariant variant = BeautifulThinkingVariant.steps,
  BeautifulThinkingStatus status = BeautifulThinkingStatus.working,
  Iterable<BeautifulThinkingItem> items = _items,
  bool initiallyExpanded = false,
  String expandLabel = 'Show thinking details',
  String collapseLabel = 'Hide thinking details',
  ValueChanged<BeautifulThinkingItem>? onItemPressed,
}) {
  return BeautifulThinking(
    key: key,
    variant: variant,
    status: status,
    workingLabel: 'Thinking',
    completedLabel: 'Thought for 4 seconds',
    items: items,
    initiallyExpanded: initiallyExpanded,
    expandLabel: expandLabel,
    collapseLabel: collapseLabel,
    onItemPressed: onItemPressed,
  );
}

void main() {
  testWidgets('header exposes unique status and disclosure semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(disableAnimations: true, child: _thinking()),
    );

    var header = tester.getSemantics(_headerWidget).getSemanticsData();
    expect(header.flagsCollection.isButton, isTrue);
    expect(header.flagsCollection.isExpanded, Tristate.isFalse);
    expect(header.hasAction(SemanticsAction.tap), isTrue);
    expect(header.hasAction(SemanticsAction.expand), isTrue);
    expect(header.label, 'Show thinking details');
    final status = tester.getSemantics(_statusWidget).getSemanticsData();
    expect(status.role, SemanticsRole.status);
    expect(status.flagsCollection.isButton, isFalse);
    expect(status.label, 'Thinking');
    expect(find.bySemanticsLabel('Thinking'), findsOneWidget);
    expect(find.bySemanticsLabel('Show thinking details'), findsOneWidget);

    tester.semantics.tap(_headerSemantics);
    await tester.pump();

    header = tester.getSemantics(_headerWidget).getSemanticsData();
    expect(header.flagsCollection.isExpanded, Tristate.isTrue);
    expect(header.hasAction(SemanticsAction.collapse), isTrue);
    expect(header.label, 'Hide thinking details');
    expect(find.bySemanticsLabel('Thinking'), findsOneWidget);
    expect(find.bySemanticsLabel('Hide thinking details'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('disclosure operation labels are independently localizable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(expandLabel: '展开思考详情', collapseLabel: '收起思考详情'),
      ),
    );

    var header = tester.getSemantics(_headerWidget).getSemanticsData();
    expect(header.label, '展开思考详情');
    expect(find.bySemanticsLabel('展开思考详情'), findsOneWidget);
    expect(find.bySemanticsLabel('Thinking'), findsOneWidget);

    tester.semantics.tap(_headerSemantics);
    await tester.pump();

    header = tester.getSemantics(_headerWidget).getSemanticsData();
    expect(header.label, '收起思考详情');
    expect(find.bySemanticsLabel('收起思考详情'), findsOneWidget);
    expect(find.bySemanticsLabel('Thinking'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('collapsed descendants leave the focus and semantics trees', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var pressed = false;
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(
          variant: BeautifulThinkingVariant.search,
          onItemPressed: (_) => pressed = true,
        ),
      ),
    );

    expect(find.semantics.byLabel('Read, flavors.dart'), findsNothing);

    tester.semantics.tap(_headerSemantics);
    await tester.pump();
    expect(find.semantics.byLabel('Read, flavors.dart'), findsOne);

    tester.semantics.tap(find.semantics.byLabel('Read, flavors.dart'));
    await tester.pump();
    expect(pressed, isTrue);

    tester.semantics.tap(_headerSemantics);
    await tester.pump();
    expect(find.semantics.byLabel('Read, flavors.dart'), findsNothing);
    semantics.dispose();
  });

  testWidgets('search rows are links only when the host supplies an action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(
          variant: BeautifulThinkingVariant.search,
          initiallyExpanded: true,
          onItemPressed: (_) {},
        ),
      ),
    );

    var row = tester
        .getSemantics(find.bySemanticsLabel('Read, flavors.dart'))
        .getSemanticsData();
    expect(row.flagsCollection.isLink, isTrue);
    expect(row.flagsCollection.isButton, isFalse);
    expect(row.hasAction(SemanticsAction.tap), isTrue);

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(
          variant: BeautifulThinkingVariant.search,
          initiallyExpanded: true,
        ),
      ),
    );
    row = tester
        .getSemantics(find.bySemanticsLabel('Read, flavors.dart'))
        .getSemanticsData();
    expect(row.flagsCollection.isLink, isFalse);
    expect(row.hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('coding rows expose and toggle selection semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(
          variant: BeautifulThinkingVariant.coding,
          initiallyExpanded: true,
        ),
      ),
    );

    final rowFinder = find.bySemanticsLabel('Read, flavors.dart');
    var row = tester.getSemantics(rowFinder).getSemanticsData();
    expect(row.flagsCollection.isButton, isTrue);
    expect(row.flagsCollection.isSelected, Tristate.isFalse);

    tester.semantics.tap(find.semantics.byLabel('Read, flavors.dart'));
    await tester.pump();
    row = tester
        .getSemantics(find.bySemanticsLabel('Read, flavors.dart'))
        .getSemanticsData();
    expect(row.flagsCollection.isSelected, Tristate.isTrue);
    semantics.dispose();
  });

  testWidgets('steps expose non-color working and completed values', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const thinkingKey = Key('status-thinking');
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(key: thinkingKey, initiallyExpanded: true),
      ),
    );

    var first = tester
        .getSemantics(find.bySemanticsLabel('Read, flavors.dart'))
        .getSemanticsData();
    var last = tester
        .getSemantics(find.bySemanticsLabel('Edit, schedule.dart'))
        .getSemanticsData();
    expect(first.value, 'Thought for 4 seconds');
    expect(last.value, 'Thinking');

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: _thinking(
          key: thinkingKey,
          status: BeautifulThinkingStatus.complete,
          initiallyExpanded: true,
        ),
      ),
    );
    await tester.pump();

    final status = tester.getSemantics(_statusWidget).getSemanticsData();
    expect(status.role, SemanticsRole.status);
    expect(status.label, 'Thought for 4 seconds');
    final header = tester.getSemantics(_headerWidget).getSemanticsData();
    expect(header.flagsCollection.isExpanded, Tristate.isTrue);
    expect(header.label, 'Hide thinking details');
    expect(find.bySemanticsLabel('Thought for 4 seconds'), findsOneWidget);
    first = tester
        .getSemantics(find.bySemanticsLabel('Read, flavors.dart'))
        .getSemanticsData();
    last = tester
        .getSemantics(find.bySemanticsLabel('Edit, schedule.dart'))
        .getSemanticsData();
    expect(first.value, 'Thought for 4 seconds');
    expect(last.value, 'Thought for 4 seconds');
    semantics.dispose();
  });
}
