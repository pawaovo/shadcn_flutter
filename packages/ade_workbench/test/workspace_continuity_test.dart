import 'package:ade_workbench/workbench.dart';
import 'package:ade_workbench/workbench_controller.dart';
import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _mount(WidgetTester tester, WorkbenchController controller) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(WorkbenchApp(controller: controller));
  await tester.pumpAndSettle();
}

Finder _icon(String label, {Finder? within}) {
  final icon = find.byWidgetPredicate(
    (widget) => widget is BeautifulIconButton && widget.label == label,
  );
  return within == null ? icon : find.descendant(of: within, matching: icon);
}

Finder _userMessage(String text) => find.byWidgetPredicate(
  (widget) => widget is SelectableText && widget.data == text,
);

void main() {
  testWidgets(
    'switching from settings drawer to a task tool closes the drawer',
    (tester) async {
      final controller = WorkbenchController();
      addTearDown(controller.dispose);
      await _mount(tester, controller);
      controller.selectPanel(ToolPanel.settings);
      await tester.pumpAndSettle();
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      expect(scaffold.isEndDrawerOpen, isTrue);

      await tester.tap(find.byKey(const ValueKey('tool-tab-changes')).last);
      await tester.pumpAndSettle();

      expect(controller.panel, ToolPanel.changes);
      expect(scaffold.isEndDrawerOpen, isFalse);
      expect(find.byKey(const Key('desktop-inspector')), findsOneWidget);
      expect(find.byKey(const ValueKey('tool-tab-changes')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Git selection survives expanding and restoring the work surface',
    (tester) async {
      final controller = WorkbenchController();
      addTearDown(controller.dispose);
      await _mount(tester, controller);
      final inspector = find.byKey(const Key('desktop-inspector'));
      await tester.tap(
        find
            .descendant(of: inspector, matching: find.text('lib/composer.dart'))
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: inspector, matching: find.text('分支')),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: inspector, matching: find.text('本地分支')),
        findsOneWidget,
      );

      await tester.tap(_icon('放大工具面板', within: inspector));
      await tester.pumpAndSettle();
      final dialog = find.byType(Dialog);
      expect(
        find.descendant(of: dialog, matching: find.text('本地分支')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('变更')).last,
      );
      await tester.pumpAndSettle();
      final expandedCode = tester.widget<BeautifulCodeBlock>(
        find.descendant(of: dialog, matching: find.byType(BeautifulCodeBlock)),
      );
      expect(expandedCode.filename, 'lib/composer.dart');

      await tester.tap(_icon('关闭工具面板', within: dialog));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
      final restoredCode = tester.widget<BeautifulCodeBlock>(
        find.descendant(
          of: inspector,
          matching: find.byType(BeautifulCodeBlock),
        ),
      );
      expect(restoredCode.filename, 'lib/composer.dart');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'stopping a waiting run cancels its approval and rejects a stale answer',
    () async {
      final controller = WorkbenchController();
      addTearDown(controller.dispose);
      controller.selectSession('approval');
      final approval = controller.rows('approvals').single;
      final run = controller
          .rows('runs')
          .firstWhere((run) => run['id'] == approval['runId']);
      expect(controller.running, isTrue);

      await controller.stopRun(run['id']);

      expect(controller.running, isFalse);
      expect(controller.current.status, '已停止');
      expect(approval['status'], isNot('pending'));
      controller.answerApproval(approval['id'], 'accept');
      expect(run['status'], 'interrupted');
      expect(controller.current.status, '已停止');
    },
  );

  testWidgets(
    'visiting an empty workspace retains the original composer state',
    (tester) async {
      final controller = WorkbenchController();
      addTearDown(controller.dispose);
      await _mount(tester, controller);
      final composer = find.byKey(const ValueKey('composer-thread'));
      final originalState = tester.state<State<BeautifulPromptBar>>(composer);
      await tester.enterText(
        find.descendant(of: composer, matching: find.byType(EditableText)),
        '保留这份未发送内容',
      );
      controller.selectWorkspace('cometixy');
      await tester.pumpAndSettle();
      expect(controller.current.id, isEmpty);
      controller.selectSession('thread');
      await tester.pumpAndSettle();

      // Retaining the editor also retains its local attachment and menu drafts,
      // which are intentionally not represented by the controller's text cache.
      expect(
        tester.state<State<BeautifulPromptBar>>(composer),
        same(originalState),
      );
      expect(find.text('保留这份未发送内容'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resizing and reopening tools preserve the draft and review selection',
    (tester) async {
      final controller = WorkbenchController();
      addTearDown(controller.dispose);
      await _mount(tester, controller);
      final composer = find.byKey(const ValueKey('composer-thread'));
      final composerState = tester.state<State<BeautifulPromptBar>>(composer);
      await tester.enterText(
        find.descendant(of: composer, matching: find.byType(EditableText)),
        '调整工作面时保留这份草稿',
      );
      final inspector = find.byKey(const Key('desktop-inspector'));
      final resizer = find.byKey(const Key('workspace-resizer'));
      final initialWidth = tester.getSize(inspector).width;
      await tester.drag(resizer, const Offset(-100, 0));
      await tester.pumpAndSettle();
      final draggedWidth = tester.getSize(inspector).width;
      expect(draggedWidth, greaterThan(initialWidth));

      Focus.of(tester.element(resizer)).requestFocus();
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      final resizedWidth = tester.getSize(inspector).width;
      expect(resizedWidth, greaterThan(draggedWidth));

      await tester.tap(
        find
            .descendant(of: inspector, matching: find.text('lib/composer.dart'))
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: inspector, matching: find.text('分支')),
      );
      await tester.pumpAndSettle();
      await tester.tap(_icon('关闭工具面板', within: inspector));
      await tester.pumpAndSettle();
      final panelFrame = find
          .ancestor(of: inspector, matching: find.byType(AnimatedAlign))
          .first;
      expect(tester.getSize(panelFrame).width, closeTo(0, 0.1));
      expect(resizer.hitTestable(), findsNothing);
      expect(find.text('调整工作面时保留这份草稿'), findsOneWidget);
      expect(
        tester.state<State<BeautifulPromptBar>>(composer),
        same(composerState),
      );

      await tester.tap(_icon('打开工具面板'));
      await tester.pumpAndSettle();
      expect(tester.getSize(inspector).width, closeTo(resizedWidth, 0.1));
      expect(resizer.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: inspector, matching: find.text('本地分支')),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(of: inspector, matching: find.text('变更')).last,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<BeautifulCodeBlock>(
              find.descendant(
                of: inspector,
                matching: find.byType(BeautifulCodeBlock),
              ),
            )
            .filename,
        'lib/composer.dart',
      );
      expect(find.text('调整工作面时保留这份草稿'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a new preview run stays after the message that triggered it', (
    tester,
  ) async {
    final controller = WorkbenchController();
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    const trigger = '继续第二轮审查';
    await controller.send(
      BeautifulPromptSubmission(text: trigger, attachments: []),
    );
    controller.previewRun('重新运行的检查', sessionId: 'thread');
    final runId = controller.rows('runs').first['id'] as String;
    await tester.pumpAndSettle();
    final run = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey && (widget.key as ValueKey).value == runId,
    );
    expect(run, findsOneWidget);
    expect(
      tester.getTopLeft(run).dy,
      greaterThan(tester.getTopLeft(_userMessage(trigger)).dy),
    );

    const following = '随后补充的要求';
    await controller.send(
      BeautifulPromptSubmission(text: following, attachments: []),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(run).dy,
      lessThan(tester.getTopLeft(_userMessage(following)).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
