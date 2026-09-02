import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _chunk = BeautifulContextChunk(
  id: 'vendor-rule',
  title: 'Vendor onboarding rule',
  characterCountLabel: '290 characters',
  body: 'Cold-chain certification must be verified before a new dairy can be added.',
  sourceLabel: 'Dairy Onboarding SOP.pdf',
  sourceBadge: 'PDF',
  tone: BeautifulContextTone.destructive,
);

void main() {
  testWidgets('exposes a localized heading and list/list-item roles', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulContextCards(
          chunks: <BeautifulContextChunk>[_chunk],
          headerLabel: '所有片段',
          countLabel: '共 32 个',
        ),
      ),
    );

    final heading = tester
        .getSemantics(find.bySemanticsLabel('所有片段, 共 32 个'))
        .getSemanticsData();
    expect(heading.flagsCollection.isHeader, isTrue);
    expect(heading.flagsCollection.isLiveRegion, isFalse);

    final roles = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.role)
        .whereType<SemanticsRole>();
    expect(roles, contains(SemanticsRole.list));
    expect(roles, contains(SemanticsRole.listItem));
    semantics.dispose();
  });

  testWidgets('keeps a source descriptive when no callback is supplied', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulContextCards(
          chunks: <BeautifulContextChunk>[_chunk],
        ),
      ),
    );

    final source = tester
        .getSemantics(find.bySemanticsLabel('PDF, Dairy Onboarding SOP.pdf'))
        .getSemanticsData();
    expect(source.flagsCollection.isButton, isFalse);
    expect(source.hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  testWidgets('exposes an actionable source as one labeled button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var activations = 0;
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulContextCards(
          chunks: const <BeautifulContextChunk>[_chunk],
          openSourceLabel: '打开来源',
          onSourcePressed: (_) => activations += 1,
        ),
      ),
    );

    final sourceFinder = find.bySemanticsLabel(
      '打开来源: Dairy Onboarding SOP.pdf',
    );
    final source = tester.getSemantics(sourceFinder).getSemanticsData();
    expect(source.flagsCollection.isButton, isTrue);
    expect(source.flagsCollection.isEnabled, Tristate.isTrue);
    expect(source.hasAction(SemanticsAction.tap), isTrue);
    expect(source.flagsCollection.isLiveRegion, isFalse);

    tester.semantics.tap(
      find.semantics.byLabel('打开来源: Dairy Onboarding SOP.pdf'),
    );
    await tester.pump();
    expect(activations, 1);
    expect(find.bySemanticsLabel('PDF'), findsNothing);
    semantics.dispose();
  });

  testWidgets('disclosure reports its collapsed and expanded state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final longBody = List<String>.filled(
      12,
      'A long retrieved sentence that wraps within the compact card.',
    ).join(' ');
    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(320, 900),
        disableAnimations: true,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: BeautifulContextCards(
              chunks: <BeautifulContextChunk>[
                BeautifulContextChunk(
                  id: 'long',
                  title: 'Long context',
                  characterCountLabel: '720 characters',
                  body: longBody,
                  sourceLabel: 'Long source.txt',
                  sourceBadge: 'TXT',
                ),
              ],
              expandLabel: '展开',
              collapseLabel: '收起',
            ),
          ),
        ),
      ),
    );

    final collapsedFinder = find.bySemanticsLabel('展开: Long context');
    final collapsed = tester.getSemantics(collapsedFinder).getSemanticsData();
    final collapsedBody = tester
        .getSemantics(find.bySemanticsIdentifier('beautiful-context-body-long'))
        .getSemanticsData();
    expect(collapsed.flagsCollection.isButton, isTrue);
    expect(collapsed.flagsCollection.isExpanded, Tristate.isFalse);
    expect(collapsedBody.label, isNot(longBody));
    expect(collapsedBody.label, endsWith('…'));

    await tester.tap(find.text('展开'));
    await tester.pump();
    final expanded = tester
        .getSemantics(find.bySemanticsLabel('收起: Long context'))
        .getSemanticsData();
    expect(expanded.flagsCollection.isButton, isTrue);
    expect(expanded.flagsCollection.isExpanded, Tristate.isTrue);
    final expandedBody = tester
        .getSemantics(find.bySemanticsIdentifier('beautiful-context-body-long'))
        .getSemanticsData();
    expect(expandedBody.label, longBody);
    semantics.dispose();
  });
}
