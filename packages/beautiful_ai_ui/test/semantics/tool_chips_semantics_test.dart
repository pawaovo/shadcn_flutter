import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

BeautifulToolChips _chips() => BeautifulToolChips(
  headerLabel: '工具活动',
  steps: [
    BeautifulToolStep(
      id: 'read',
      label: '读取配置',
      chip: 'config.dart',
      status: BeautifulToolStatus.running,
      statusLabel: '正在读取',
      details: const [BeautifulToolDetailLine(text: 'Configuration output')],
    ),
  ],
  diffs: [
    BeautifulToolDiff(
      id: 'config',
      file: 'config.dart',
      additions: 1,
      lines: const [
        BeautifulToolDetailLine(
          text: 'enabled = true',
          tone: BeautifulToolLineTone.addition,
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('localized disclosures expose actions and expanded state once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: ColoredBox(color: const Color(0xffffffff), child: _chips()),
      ),
    );
    final header = tester
        .getSemantics(find.bySemanticsLabel('工具活动'))
        .getSemanticsData();
    expect(header.flagsCollection.isButton, isTrue);
    expect(header.flagsCollection.isExpanded, Tristate.isTrue);
    final rowFinder = find.bySemanticsLabel('读取配置, config.dart');
    final row = tester.getSemantics(rowFinder).getSemanticsData();
    expect(row.flagsCollection.isButton, isTrue);
    expect(row.flagsCollection.isExpanded, Tristate.isFalse);
    expect(row.hasAction(SemanticsAction.tap), isTrue);
    expect(find.bySemanticsLabel('Configuration output'), findsNothing);
    tester.semantics.tap(find.semantics.byLabel('读取配置, config.dart'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(rowFinder)
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isTrue,
    );
    expect(find.bySemanticsLabel('Configuration output'), findsOneWidget);
    final roles = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.role)
        .whereType<SemanticsRole>();
    expect(roles, contains(SemanticsRole.list));
    expect(roles, contains(SemanticsRole.listItem));
    semantics.dispose();
  });

  testWidgets(
    'execution status is a localized live region separate from action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: ColoredBox(color: const Color(0xffffffff), child: _chips()),
        ),
      );
      final status = tester
          .getSemantics(
            find.bySemanticsIdentifier('beautiful-tool-status-read'),
          )
          .getSemanticsData();
      expect(status.label, '读取配置: 正在读取');
      expect(status.flagsCollection.isLiveRegion, isTrue);
      expect(status.flagsCollection.isButton, isFalse);
      expect(find.bySemanticsLabel('读取配置: 正在读取'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('file preview is operable through semantics without hover', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: ColoredBox(color: const Color(0xffffffff), child: _chips()),
      ),
    );
    final finder = find.bySemanticsLabel('config.dart, +1  −0');
    expect(
      tester
          .getSemantics(finder)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    tester.semantics.tap(find.semantics.byLabel('config.dart, +1  −0'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('+ enabled = true'), findsOneWidget);
    expect(
      tester.getSemantics(finder).getSemanticsData().flagsCollection.isExpanded,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('collapsed run removes all details and status announcements', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: ColoredBox(color: const Color(0xffffffff), child: _chips()),
      ),
    );
    await tester.tap(find.text('读取配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工具活动'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Configuration output'), findsNothing);
    expect(
      find.bySemanticsIdentifier('beautiful-tool-status-read'),
      findsNothing,
    );
    expect(find.bySemanticsLabel('读取配置, config.dart'), findsNothing);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('工具活动'))
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      Tristate.isFalse,
    );
    semantics.dispose();
  });

  testWidgets(
    'rows with no details are descriptive rather than inert buttons',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulToolChips(
            steps: [
              BeautifulToolStep(id: 'read', label: 'Read', chip: 'read.txt'),
            ],
            diffs: [
              BeautifulToolDiff(id: 'read', file: 'read.txt', additions: 0),
            ],
          ),
        ),
      );
      for (final label in ['Read, read.txt', 'read.txt, +0  −0']) {
        final node = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(node.flagsCollection.isButton, isFalse);
        expect(node.hasAction(SemanticsAction.tap), isFalse);
      }
      semantics.dispose();
    },
  );

  testWidgets('every disclosure meets Android and Apple target guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: ColoredBox(color: const Color(0xffffffff), child: _chips()),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });
}
