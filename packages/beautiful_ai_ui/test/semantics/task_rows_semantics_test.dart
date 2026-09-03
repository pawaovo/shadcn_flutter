import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

BeautifulTaskRow _task({
  BeautifulTaskStatus status = BeautifulTaskStatus.running,
}) => BeautifulTaskRow(
  id: 'index',
  label: 'Build task list',
  amountLabel: '7 items',
  status: status,
  step: 2,
  progress: status == BeautifulTaskStatus.running ? 0.68 : null,
  details: const [
    BeautifulTaskDetail(id: 'read', label: 'Read export', meta: '3 files'),
  ],
);

void main() {
  testWidgets(
    'announces status, progress, step and disclosure without duplicate descendants',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulTaskRows(rows: [_task()], stepLabel: '步骤'),
        ),
      );
      final task = tester
          .getSemantics(find.bySemanticsIdentifier('beautiful-task-index'))
          .getSemanticsData();
      expect(task.label, 'Build task list, 7 items');
      expect(task.value, 'Running, 68%, 步骤 2');
      expect(task.flagsCollection.isButton, isTrue);
      expect(task.flagsCollection.isExpanded, Tristate.isFalse);
      expect(task.flagsCollection.isLiveRegion, isTrue);
      expect(find.bySemanticsLabel('Read export, 3 files'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('task-toggle-index')));
      await tester.pump();
      expect(find.bySemanticsLabel('Read export, 3 files'), findsOneWidget);
      final open = tester
          .getSemantics(find.bySemanticsIdentifier('beautiful-task-index'))
          .getSemanticsData();
      expect(open.flagsCollection.isExpanded, Tristate.isTrue);
      await tester.tap(find.byKey(const ValueKey<String>('task-toggle-index')));
      await tester.pump();
      expect(find.bySemanticsLabel('Read export, 3 files'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'a task without details is status text rather than a dead disclosure',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulTaskRows(
            rows: [
              BeautifulTaskRow(
                id: 'done',
                label: 'Verified records',
                amountLabel: '12 suppliers',
                status: BeautifulTaskStatus.completed,
                statusLabel: '已完成',
              ),
            ],
          ),
        ),
      );
      final task = tester
          .getSemantics(find.bySemanticsIdentifier('beautiful-task-done'))
          .getSemanticsData();
      expect(task.value, '已完成');
      expect(task.flagsCollection.isButton, isFalse);
      expect(task.flagsCollection.isExpanded, Tristate.none);
      semantics.dispose();
    },
  );

  testWidgets(
    'retry has a unique task label and disables while awaiting the host',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final completion = Completer<void>();
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulTaskRows(
            rows: [_task(status: BeautifulTaskStatus.failed)],
            onRetry: (_) => completion.future,
          ),
        ),
      );
      final retry = tester
          .getSemantics(find.bySemanticsLabel('Retry: Build task list'))
          .getSemanticsData();
      expect(retry.flagsCollection.isButton, isTrue);
      expect(retry.flagsCollection.isEnabled, Tristate.isTrue);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      final pending = tester
          .getSemantics(find.bySemanticsLabel('Retrying…: Build task list'))
          .getSemanticsData();
      expect(pending.flagsCollection.isEnabled, Tristate.isFalse);
      completion.complete();
      await tester.pump();
      expect(find.bySemanticsLabel('Retry: Build task list'), findsOneWidget);
      semantics.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'disclosure and retry meet tap-target and contrast guidance in ${brightness.name}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          beautifulTestApp(
            brightness: brightness,
            highContrast: true,
            disableAnimations: true,
            child: BeautifulTaskRows(
              rows: [_task(status: BeautifulTaskStatus.failed)],
              onRetry: (_) {},
            ),
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      },
    );
  }
}
