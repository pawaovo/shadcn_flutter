import 'dart:async';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _body = '收到片段 👋\nKeep punctuation, spacing.';
const _sources = <BeautifulStreamingSource>[
  BeautifulStreamingSource(
    id: 'handbook',
    title: 'Data handbook',
    detail: 'docs/data.md',
  ),
  BeautifulStreamingSource(
    id: 'notes',
    title: 'Research notes',
    detail: 'notes.txt',
  ),
];
const _followUp = BeautifulStreamingFollowUp(
  id: 'examples',
  label: 'Show practical examples',
);

void main() {
  testWidgets('only localized status announces streamed lifecycle updates', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    const labels = BeautifulStreamingLabels(
      streaming: '正在生成回答',
      complete: '回答已完成',
      failed: '回答已中断',
    );
    const states = <BeautifulStreamingStatus, String>{
      BeautifulStreamingStatus.streaming: '正在生成回答',
      BeautifulStreamingStatus.complete: '回答已完成',
      BeautifulStreamingStatus.failed: '回答已中断',
    };

    for (final state in states.entries) {
      final body = '$_body ${state.key.name}';
      await tester.pumpWidget(
        _app(status: state.key, labels: labels, body: body),
      );

      final status = tester
          .getSemantics(find.bySemanticsLabel(state.value))
          .getSemanticsData();
      expect(status.flagsCollection.isLiveRegion, isTrue);
      final data = _semanticsData(tester);
      final bodyNodes = data.where((node) => node.label.contains(body));
      expect(bodyNodes, isNotEmpty);
      for (final node in bodyNodes) {
        expect(node.flagsCollection.isLiveRegion, isFalse);
      }
      expect(
        data
            .where((node) => node.flagsCollection.isLiveRegion)
            .map((node) => node.label),
        [state.value],
      );
    }
    handle.dispose();
  });

  testWidgets('streaming hides source follow-up and completion action nodes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(onSourcePressed: (_) {}));
    tester.semantics.tap(find.semantics.byLabel('Sources (2)'));
    await tester.pump();
    expect(
      find.bySemanticsLabel('[1] Data handbook · docs/data.md'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      _app(
        status: BeautifulStreamingStatus.streaming,
        onSourcePressed: (_) {},
        onFollowUp: (_) {},
        onFeedback: (_) {},
        onCopy: (_) {},
        onRetry: () {},
      ),
    );

    for (final label in <String>[
      'Sources (2)',
      '[1] Data handbook · docs/data.md',
      '[2] Research notes · notes.txt',
      'Follow-ups',
      _followUp.label,
      'Copy answer',
      'Retry answer',
      'Helpful answer',
      'Unhelpful answer',
    ]) {
      expect(find.bySemanticsLabel(label), findsNothing);
    }
    expect(
      _semanticsData(tester)
          .where((node) => node.hasAction(SemanticsAction.tap)),
      isEmpty,
    );
    expect(find.bySemanticsLabel(_body), findsOneWidget);
    handle.dispose();
  });

  testWidgets('source disclosure exposes expansion and source activation', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final opened = <BeautifulStreamingSource>[];
    await tester.pumpWidget(_app(onSourcePressed: opened.add));

    final disclosure = find.bySemanticsLabel('Sources (2)');
    var data = tester.getSemantics(disclosure).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isExpanded, ui.Tristate.isFalse);
    expect(
      find.bySemanticsLabel('[2] Research notes · notes.txt'),
      findsNothing,
    );

    tester.semantics.tap(find.semantics.byLabel('Sources (2)'));
    await tester.pump();
    data = tester.getSemantics(disclosure).getSemanticsData();
    expect(data.flagsCollection.isExpanded, ui.Tristate.isTrue);
    final source = tester
        .getSemantics(find.bySemanticsLabel('[2] Research notes · notes.txt'))
        .getSemanticsData();
    expect(source.flagsCollection.isButton, isTrue);
    expect(source.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(source.hasAction(SemanticsAction.tap), isTrue);
    expect(source.flagsCollection.isLiveRegion, isFalse);
    tester.semantics.tap(
      find.semantics.byLabel('[2] Research notes · notes.txt'),
    );
    await tester.pump();
    expect(opened, [_sources[1]]);

    tester.semantics.tap(find.semantics.byLabel('Sources (2)'));
    await tester.pump();
    expect(
      tester
          .getSemantics(disclosure)
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      ui.Tristate.isFalse,
    );
    expect(
      find.bySemanticsLabel('[2] Research notes · notes.txt'),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('sources and follow-ups remain descriptive without callbacks', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    tester.semantics.tap(find.semantics.byLabel('Sources (2)'));
    await tester.pump();

    for (final label in <String>[
      '[1] Data handbook · docs/data.md',
      '[2] Research notes · notes.txt',
      _followUp.label,
    ]) {
      final matches = _semanticsData(tester)
          .where((node) => node.label.contains(label));
      expect(matches, isNotEmpty);
      for (final data in matches) {
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        expect(data.flagsCollection.isLiveRegion, isFalse);
      }
    }
    expect(find.bySemanticsLabel('Helpful answer'), findsNothing);
    expect(find.bySemanticsLabel('Unhelpful answer'), findsNothing);
    handle.dispose();
  });

  testWidgets('feedback exposes caller-controlled selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final feedback = <BeautifulStreamingFeedback>[];
    await tester.pumpWidget(
      _app(
        feedback: BeautifulStreamingFeedback.positive,
        onFeedback: feedback.add,
      ),
    );

    SemanticsData positive() => tester
        .getSemantics(find.bySemanticsLabel('Helpful answer'))
        .getSemanticsData();
    SemanticsData negative() => tester
        .getSemantics(find.bySemanticsLabel('Unhelpful answer'))
        .getSemanticsData();
    expect(positive().flagsCollection.isButton, isTrue);
    expect(positive().flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(negative().flagsCollection.isSelected, ui.Tristate.isFalse);

    tester.semantics.tap(find.semantics.byLabel('Unhelpful answer'));
    await tester.pump();
    expect(feedback, [BeautifulStreamingFeedback.negative]);
    expect(positive().flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(negative().flagsCollection.isSelected, ui.Tristate.isFalse);

    await tester.pumpWidget(
      _app(
        feedback: BeautifulStreamingFeedback.negative,
        onFeedback: feedback.add,
      ),
    );
    expect(positive().flagsCollection.isSelected, ui.Tristate.isFalse);
    expect(negative().flagsCollection.isSelected, ui.Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('copy disables while pending and announces successful status', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final pending = Completer<void>();
    final copied = <String>[];
    await tester.pumpWidget(
      _app(
        onCopy: (text) {
          copied.add(text);
          return pending.future;
        },
      ),
    );
    final idle = tester
        .getSemantics(find.bySemanticsLabel('Copy answer'))
        .getSemanticsData();
    expect(idle.flagsCollection.isButton, isTrue);
    expect(idle.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(idle.flagsCollection.isLiveRegion, isFalse);
    tester.semantics.tap(find.semantics.byLabel('Copy answer'));
    await tester.pump();

    final copying = tester
        .getSemantics(find.bySemanticsLabel('Copying answer'))
        .getSemanticsData();
    expect(copying.flagsCollection.isButton, isTrue);
    expect(copying.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(copying.hasAction(SemanticsAction.tap), isFalse);
    expect(copied, [_body]);

    pending.complete();
    await tester.pump();
    await tester.pump();
    final completed = _semanticsData(tester)
        .where((node) => node.label.contains('Answer copied'));
    final announcement = completed.where(
      (node) => node.flagsCollection.isLiveRegion,
    );
    expect(
      announcement,
      hasLength(1),
      reason: _semanticsData(tester)
          .map(
            (node) =>
                'live=${node.flagsCollection.isLiveRegion}: ${node.label}',
          )
          .join('\n'),
    );
    expect(announcement.single.flagsCollection.isLiveRegion, isTrue);
    final button = completed.where((node) => node.flagsCollection.isButton);
    expect(button, hasLength(1));
    expect(button.single.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(button.single.hasAction(SemanticsAction.tap), isTrue);
    expect(
      _semanticsData(tester)
          .where((node) => node.label.contains(_body))
          .every((node) => !node.flagsCollection.isLiveRegion),
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('all completion actions meet labeled 48 dp touch targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        onSourcePressed: (_) {},
        onFollowUp: (_) {},
        onFeedback: (_) {},
        onCopy: (_) {},
        onRetry: () {},
      ),
    );
    tester.semantics.tap(find.semantics.byLabel('Sources (2)'));
    await tester.pump();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}

Widget _app({
  BeautifulStreamingStatus status = BeautifulStreamingStatus.complete,
  BeautifulStreamingLabels labels = const BeautifulStreamingLabels(),
  String body = _body,
  BeautifulStreamingFeedback? feedback,
  ValueChanged<BeautifulStreamingSource>? onSourcePressed,
  ValueChanged<BeautifulStreamingFollowUp>? onFollowUp,
  ValueChanged<BeautifulStreamingFeedback>? onFeedback,
  FutureOr<void> Function(String)? onCopy,
  FutureOr<void> Function()? onRetry,
}) => beautifulTestApp(
  disableAnimations: true,
  child: BeautifulStreamingText(
    id: 'answer-semantics',
    status: status,
    labels: labels,
    content: [BeautifulStreamingPart.text(body)],
    sources: _sources,
    followUps: const [_followUp],
    feedback: feedback,
    onSourcePressed: onSourcePressed,
    onFollowUp: onFollowUp,
    onFeedback: onFeedback,
    onCopy: onCopy,
    onRetry: onRetry,
  ),
);

List<SemanticsData> _semanticsData(WidgetTester tester) {
  final data = <SemanticsData>[];
  void visit(SemanticsNode node) {
    data.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return data;
}
