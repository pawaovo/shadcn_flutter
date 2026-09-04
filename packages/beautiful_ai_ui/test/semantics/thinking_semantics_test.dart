import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
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

List<SemanticsNode> _semanticSubtree(SemanticsNode root) {
  final nodes = <SemanticsNode>[root];
  root.visitChildren((child) {
    nodes.addAll(_semanticSubtree(child));
    return true;
  });
  return nodes;
}

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
  testWidgets('Tab and Space keep focus on the named disclosure button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final previousHighlight = FocusManager.instance.highlightStrategy;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    try {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xffffffff),
          onGenerateRoute: (settings) => PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (context, animation, secondaryAnimation) =>
                beautifulTestApp(
                  disableAnimations: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Focus(
                        autofocus: true,
                        child: Text('Before thinking'),
                      ),
                      _thinking(initiallyExpanded: true),
                    ],
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text('Before thinking'))
            .getSemanticsData()
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      final headerId = tester.getSemantics(_headerWidget).id;

      void expectDisclosure({required bool expanded}) {
        final header = tester.getSemantics(_headerWidget);
        final data = header.getSemanticsData();
        expect(header.id, headerId);
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, Tristate.isTrue);
        final nodes = _semanticSubtree(header);
        expect(
          nodes.where(
            (node) =>
                node.getSemanticsData().flagsCollection.isFocused ==
                Tristate.isTrue,
          ),
          hasLength(1),
          reason: 'Tab must establish actual focus inside the disclosure.',
        );
        expect(data.flagsCollection.isFocused, Tristate.isTrue);
        expect(
          data.flagsCollection.isExpanded,
          expanded ? Tristate.isTrue : Tristate.isFalse,
        );
        expect(
          data.label,
          expanded ? 'Hide thinking details' : 'Show thinking details',
        );

        expect(
          nodes.where(
            (node) =>
                node.getSemanticsData().flagsCollection.isFocused !=
                Tristate.none,
          ),
          <SemanticsNode>[header],
          reason: 'Only the named button may publish input focus semantics.',
        );
        expect(
          nodes.where((node) {
            final data = node.getSemanticsData();
            return data.label.isEmpty &&
                (data.flagsCollection.isFocused != Tristate.none ||
                    data.actions != 0);
          }),
          isEmpty,
          reason: 'No unnamed focusable or actionable child may shadow it.',
        );
        final status = tester.getSemantics(_statusWidget);
        expect(nodes, contains(status));
        expect(status.id, isNot(headerId));
        expect(status.getSemanticsData().role, SemanticsRole.status);
        expect(status.getSemanticsData().label, 'Thinking');
        expect(
          status.getSemanticsData().flagsCollection.isFocused,
          Tristate.none,
        );
        expect(status.getSemanticsData().actions, 0);
      }

      await tester.sendKeyEvent(
        LogicalKeyboardKey.tab,
        physicalKey: PhysicalKeyboardKey.tab,
      );
      await tester.pump();
      expectDisclosure(expanded: true);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.pump();
      expectDisclosure(expanded: false);
      expect(find.semantics.byLabel('Read, flavors.dart'), findsNothing);

      await tester.sendKeyEvent(
        LogicalKeyboardKey.space,
        physicalKey: PhysicalKeyboardKey.space,
      );
      await tester.pump();
      expectDisclosure(expanded: true);
      expect(find.semantics.byLabel('Read, flavors.dart'), findsOne);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      semantics.dispose();
      FocusManager.instance.highlightStrategy = previousHighlight;
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.linux,
    TargetPlatform.iOS,
  ]) {
    testWidgets(
      'semantic focus action preserves disclosure on ${platform.name}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        debugDefaultTargetPlatformOverride = platform;
        try {
          await tester.pumpWidget(
            beautifulTestApp(disableAnimations: true, child: _thinking()),
          );
          final header = tester.getSemantics(_headerWidget);
          expect(
            header.getSemanticsData().hasAction(SemanticsAction.focus),
            platform != TargetPlatform.iOS,
          );
          expect(
            header.getSemanticsData().flagsCollection.isFocused,
            Tristate.isFalse,
          );
          if (platform == TargetPlatform.iOS) return;

          header.owner!.performAction(header.id, SemanticsAction.focus);
          await tester.pumpAndSettle();
          expect(
            tester
                .getSemantics(_headerWidget)
                .getSemanticsData()
                .flagsCollection
                .isFocused,
            Tristate.isTrue,
          );
          expect(
            tester
                .getSemantics(_headerWidget)
                .getSemanticsData()
                .flagsCollection
                .isExpanded,
            Tristate.isFalse,
          );

          await tester.sendKeyEvent(
            LogicalKeyboardKey.space,
            physicalKey: PhysicalKeyboardKey.space,
          );
          await tester.pump();
          final activated = tester.getSemantics(_headerWidget);
          expect(activated.id, header.id);
          expect(
            activated.getSemanticsData().flagsCollection.isFocused,
            Tristate.isTrue,
          );
          expect(
            activated.getSemanticsData().flagsCollection.isExpanded,
            Tristate.isTrue,
          );
          expect(
            tester.getSemantics(_statusWidget).getSemanticsData().role,
            SemanticsRole.status,
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          semantics.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets('header exposes unique status and disclosure semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(disableAnimations: true, child: _thinking()),
    );

    var header = tester.getSemantics(_headerWidget).getSemanticsData();
    expect(header.flagsCollection.isButton, isTrue);
    expect(header.flagsCollection.isEnabled, Tristate.isTrue);
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
    expect(header.flagsCollection.isEnabled, Tristate.isTrue);
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
    expect(row.flagsCollection.isEnabled, Tristate.isTrue);
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
    expect(row.flagsCollection.isEnabled, Tristate.none);
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
    expect(row.flagsCollection.isEnabled, Tristate.isTrue);
    expect(row.flagsCollection.isSelected, Tristate.isFalse);

    tester.semantics.tap(find.semantics.byLabel('Read, flavors.dart'));
    await tester.pump();
    row = tester
        .getSemantics(find.bySemanticsLabel('Read, flavors.dart'))
        .getSemanticsData();
    expect(row.flagsCollection.isEnabled, Tristate.isTrue);
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
