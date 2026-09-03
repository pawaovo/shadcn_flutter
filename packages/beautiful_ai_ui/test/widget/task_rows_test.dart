import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

BeautifulTaskRow _task({
  String id = 'index',
  String label = 'Build task list',
  BeautifulTaskStatus status = BeautifulTaskStatus.running,
  double? progress,
  List<BeautifulTaskDetail>? details,
}) => BeautifulTaskRow(
  id: id,
  label: label,
  amountLabel: '7 items',
  status: status,
  step: 2,
  progress: progress,
  details:
      details ??
      const <BeautifulTaskDetail>[
        BeautifulTaskDetail(id: 'read', label: 'Read export', meta: '3 files'),
        BeautifulTaskDetail(id: 'score', label: 'Score risk', meta: '68%'),
      ],
);

void main() {
  test(
    'models defensively copy collections and validate identity and progress',
    () {
      final details = <BeautifulTaskDetail>[
        const BeautifulTaskDetail(
          id: 'read',
          label: 'Read export',
          meta: '3 files',
        ),
      ];
      final task = _task(details: details);
      final rows = <BeautifulTaskRow>[task];
      final list = BeautifulTaskRows(rows: rows);
      details.clear();
      rows.clear();
      expect(task.details, hasLength(1));
      expect(list.rows, hasLength(1));
      expect(() => task.details.clear(), throwsUnsupportedError);
      expect(() => list.rows.clear(), throwsUnsupportedError);
      expect(() => _task(id: ''), throwsAssertionError);
      expect(() => _task(progress: -0.1), throwsAssertionError);
      expect(() => _task(progress: double.nan), throwsAssertionError);
      expect(() => _task(progress: 1.1), throwsAssertionError);
      expect(
        () => BeautifulTaskRows(rows: [_task(), _task()]),
        throwsAssertionError,
      );
      expect(
        () => _task(details: [task.details.first, task.details.first]),
        throwsAssertionError,
      );
    },
  );

  for (final variant in BeautifulTaskRowsVariant.values) {
    testWidgets('${variant.name} renders only the supplied workflow snapshot', (
      tester,
    ) async {
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulTaskRows(
            variant: variant,
            rows: [
              _task(id: 'pending', status: BeautifulTaskStatus.pending),
              _task(id: 'running', progress: 0.68),
              _task(id: 'done', status: BeautifulTaskStatus.completed),
              _task(id: 'failed', status: BeautifulTaskStatus.failed),
            ],
          ),
        ),
      );
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Running, 68%'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Read export'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Running, 68%'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Read export'), findsNothing);
    });
  }

  testWidgets('opens by pointer, closes by Escape, and activates by keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulTaskRows(rows: [_task()]),
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('task-toggle-index')));
    await tester.pump();
    expect(find.text('Read export'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Read export'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('Read export'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('Read export'), findsNothing);
  });

  testWidgets(
    'disclosure and focus follow stable IDs across reorder, resize, and variant',
    (tester) async {
      late StateSetter updateHost;
      var reverse = false;
      var wide = false;
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(800, 800),
          disableAnimations: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              final rows = [
                _task(),
                _task(
                  id: 'verify',
                  label: 'Verify records',
                  details: const [
                    BeautifulTaskDetail(
                      id: 'match',
                      label: 'Matched records',
                      meta: '12',
                    ),
                  ],
                ),
              ];
              return SizedBox(
                width: wide ? 700 : 320,
                child: BeautifulTaskRows(
                  variant: wide
                      ? BeautifulTaskRowsVariant.list
                      : BeautifulTaskRowsVariant.capsules,
                  rows: reverse ? rows.reversed.toList() : rows,
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('task-toggle-index')));
      await tester.pump();
      updateHost(() {
        reverse = true;
        wide = true;
      });
      await tester.pump();
      expect(find.text('Read export'), findsOneWidget);
      expect(find.text('Matched records'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Read export'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.text('Read export'), findsOneWidget);
    },
  );

  testWidgets(
    'retry is de-duplicated and never invents a workflow transition',
    (tester) async {
      final completion = Completer<void>();
      final row = _task(status: BeautifulTaskStatus.failed);
      BeautifulTaskRow? activated;
      var calls = 0;
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulTaskRows(
            rows: [row],
            onRetry: (task) {
              activated = task;
              calls++;
              return completion.future;
            },
          ),
        ),
      );
      final retry = find.byKey(const ValueKey<String>('task-retry-index'));
      await tester.tap(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(calls, 1);
      expect(identical(activated, row), isTrue);
      expect(find.text('Retrying…'), findsOneWidget);
      completion.complete();
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
    },
  );

  testWidgets(
    'variant changes are safe during animated border and radius changes',
    (tester) async {
      late StateSetter updateHost;
      var list = false;
      await tester.pumpWidget(
        beautifulTestApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return BeautifulTaskRows(
                variant: list
                    ? BeautifulTaskRowsVariant.list
                    : BeautifulTaskRowsVariant.capsules,
                rows: [
                  _task(id: 'first', status: BeautifulTaskStatus.completed),
                  _task(id: 'second', status: BeautifulTaskStatus.completed),
                ],
              );
            },
          ),
        ),
      );
      for (final next in [true, false, true]) {
        updateHost(() => list = next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 110));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('task-toggle-first')));
      await tester.pump(const Duration(milliseconds: 110));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reports a current retry failure through the root seam', (
    tester,
  ) async {
    final failures = <BeautifulUiFailure>[];
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulUiScope(
          onFailure: failures.add,
          child: BeautifulTaskRows(
            rows: [_task(status: BeautifulTaskStatus.failed)],
            onRetry: (_) => throw StateError('Offline'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(failures.single.operation, BeautifulUiOperation.taskRetry);
    expect(failures.single.cause, isA<StateError>());
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'equal snapshots preserve a pending retry while changed data invalidates it',
    (tester) async {
      final completion = Completer<void>();
      final failures = <BeautifulUiFailure>[];
      late StateSetter updateHost;
      var label = 'Original task';
      var replacementCalls = 0;
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulUiScope(
            onFailure: failures.add,
            child: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return BeautifulTaskRows(
                  rows: [
                    _task(label: label, status: BeautifulTaskStatus.failed),
                  ],
                  onRetry: (_) {
                    if (label == 'Original task') return completion.future;
                    replacementCalls++;
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Retry'));
      await tester.pump();
      updateHost(() {});
      await tester.pump();
      expect(find.text('Retrying…'), findsOneWidget);
      updateHost(() => label = 'Replacement task');
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      completion.completeError(StateError('Old failure'));
      await tester.pump();
      expect(failures, isEmpty);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(replacementCalls, 1);
    },
  );

  testWidgets(
    'removing and reinserting a task resets disclosure and ignores old callbacks',
    (tester) async {
      final completion = Completer<void>();
      late StateSetter updateHost;
      var visible = true;
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return BeautifulTaskRows(
                rows: visible
                    ? [_task(status: BeautifulTaskStatus.failed)]
                    : [],
                onRetry: (_) => completion.future,
              );
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('task-toggle-index')));
      await tester.tap(find.text('Retry'));
      await tester.pump();
      updateHost(() => visible = false);
      await tester.pump();
      expect(find.text('No tasks'), findsOneWidget);
      completion.completeError(StateError('Stale removed task'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      updateHost(() => visible = true);
      await tester.pump();
      expect(find.text('Read export'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  for (final policy in [
    BeautifulMotionPolicy.reduced,
    BeautifulMotionPolicy.none,
  ]) {
    testWidgets('${policy.name} leaves running rows static and readable', (
      tester,
    ) async {
      await tester.pumpWidget(
        beautifulTestApp(
          motion: policy,
          child: BeautifulTaskRows(rows: [_task()]),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(find.text('Running'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('task-toggle-index')));
      await tester.pumpAndSettle();
      expect(find.text('Read export'), findsOneWidget);
    });
  }

  testWidgets(
    'platform disabled animations stop an active indeterminate ring',
    (tester) async {
      await tester.pumpWidget(
        beautifulTestApp(child: BeautifulTaskRows(rows: [_task()])),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: BeautifulTaskRows(rows: [_task()]),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  testWidgets(
    'long localized content fits boundary widths, RTL, dark and 200% text',
    (tester) async {
      const longLabel = '核对供应商的税号与联系方式并生成需要人工确认的记录 القائمة التفصيلية للموردين';
      tester.view.physicalSize = const Size(1440, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [320.0, 599.0, 600.0, 1023.0, 1024.0, 1440.0]) {
        for (final variant in BeautifulTaskRowsVariant.values) {
          await tester.pumpWidget(
            beautifulTestApp(
              size: Size(width, 1600),
              textScaler: TextScaler.linear(2),
              textDirection: TextDirection.rtl,
              brightness: Brightness.dark,
              highContrast: true,
              disableAnimations: true,
              child: BeautifulTaskRows(
                variant: variant,
                rows: [
                  BeautifulTaskRow(
                    id: 'long',
                    label: longLabel,
                    amountLabel: '供应商的数据清单及审核详情 القائمة التفصيلية',
                    status: BeautifulTaskStatus.failed,
                    statusLabel: '需要重新执行任务后才能继续 التالي',
                    details: const [
                      BeautifulTaskDetail(
                        id: 'long-detail',
                        label: longLabel,
                        meta: '这是一段很长的详细信息字段 ينبغي التحقق من بيانات الموردين',
                      ),
                    ],
                  ),
                ],
                onRetry: (_) {},
                retryLabel: '重新执行此任务并获取最新数据',
              ),
            ),
          );
          await tester.tap(
            find.byKey(const ValueKey<String>('task-toggle-long')),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '$width ${variant.name}',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );
}
