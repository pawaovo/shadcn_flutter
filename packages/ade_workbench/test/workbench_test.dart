import 'dart:convert';

import 'package:ade_workbench/workbench.dart';
import 'package:ade_workbench/workbench_controller.dart';
import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> mount(
  WidgetTester tester,
  WorkbenchController c,
  Size size,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(WorkbenchApp(controller: c));
  await tester.pumpAndSettle();
}

void reset(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
  tester.view.resetViewInsets();
}

void main() {
  test('shell interactions update local view state', () async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    final before = c.current.messages.length;
    await c.send(BeautifulPromptSubmission(text: '前端输入', attachments: []));
    expect(c.current.messages.length, before + 1);
    expect(c.current.messages.last.text, '前端输入');
    expect(c.current.messages.last.isUser, isTrue);
    await c.openTerminal();
    await c.terminal('pwd\n');
    expect(c.terminalOutput, contains('命令未执行'));
    c.previewAutomation(c.automations.first);
    expect(c.rows('runs').first['status'], 'preview');
    expect(c.automations.first.data['lastResult'], 'preview');
  });
  test(
    'appearance and unsent drafts restore with valid workspace selection',
    () async {
      SharedPreferences.setMockInitialValues({
        WorkbenchController.storageKey: jsonEncode({
          'theme': 'dark',
          'largeText': true,
          'workspace': 'removed',
          'selected': 'archived',
        }),
        WorkbenchController.draftKey: jsonEncode({'thread': '未发送的草稿'}),
      });
      final c = WorkbenchController(
        preferences: await SharedPreferences.getInstance(),
      );
      addTearDown(c.dispose);
      expect(c.themeMode, BeautifulUiThemeMode.dark);
      expect(c.composerDrafts['thread'], '未发送的草稿');
      expect(c.largeText, isTrue);
      expect(c.current.archived, isFalse);
      expect(c.current.workspaceId, c.workspace);
    },
  );
  test('archive and delete select a valid remaining conversation', () async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    c.selectSession('thread');
    await c.archiveSession('thread', true);
    expect(c.selectedSessionId, isNot('thread'));
    await c.deleteSession(c.selectedSessionId, 'DELETE');
    expect(c.current.id, isNotEmpty);
    c.selectWorkspace('cometixy');
    expect(c.current.id, isEmpty);
    expect(c.entries, isEmpty);
    await c.selectFile('lib/workbench.dart');
    expect(c.file, isEmpty);
    await c.newSession();
    expect(c.current.workspaceId, 'cometixy');
  });
  test('attachment-only preview preserves the separate text draft', () async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    c.rememberDraft('thread', '继续编辑的内容');
    await c.send(
      BeautifulPromptSubmission(
        text: '',
        attachments: [
          const BeautifulPromptAttachment(
            id: 'local-file',
            label: 'design.png',
          ),
        ],
      ),
    );
    expect(c.current.messages.last.text, '附件：design.png');
    expect(c.composerDrafts['thread'], '继续编辑的内容');
  });
  test('automation form rejects incomplete input', () async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    await expectLater(
      c.saveAutomation(title: '', schedule: '', prompt: ''),
      throwsFormatException,
    );
    expect(c.automations, hasLength(1));
  });
  testWidgets('keyboard search works after startup', (tester) async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    addTearDown(() => reset(tester));
    await mount(tester, c, const Size(1440, 1000));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(c.page, WorkspacePage.search);
    expect(tester.takeException(), isNull);
  });
  testWidgets('all shell pages render at four widths in both themes', (
    tester,
  ) async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    addTearDown(() => reset(tester));
    await mount(tester, c, const Size(1440, 1000));
    for (final size in [
      const Size(1440, 1000),
      const Size(1024, 900),
      const Size(768, 1024),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      for (final theme in [
        BeautifulUiThemeMode.light,
        BeautifulUiThemeMode.dark,
      ]) {
        c.setTheme(theme);
        for (final page in WorkspacePage.values) {
          c.navigate(page);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size $theme $page');
        }
      }
    }
  });
  testWidgets('composer draft survives resizing, switching and remounting', (
    tester,
  ) async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    addTearDown(() => reset(tester));
    await mount(tester, c, const Size(1440, 1000));
    c.selectSession('thread');
    await tester.pumpAndSettle();
    final composer = find.byKey(const ValueKey('composer-thread'));
    await tester.enterText(
      find.descendant(of: composer, matching: find.byType(EditableText)),
      '保留输入中的草稿',
    );
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    c.selectSession('mobile');
    await tester.pumpAndSettle();
    c.selectSession('thread');
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(WorkbenchApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('保留输入中的草稿'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('mobile composer stays above keyboard', (tester) async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    addTearDown(() => reset(tester));
    await mount(tester, c, const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('composer-thread'))).dy,
      lessThan(544),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('file edit drafts survive changing tools and docking', (
    tester,
  ) async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    addTearDown(() => reset(tester));
    await mount(tester, c, const Size(1440, 1000));
    await c.selectFile('lib/workbench.dart');
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '编辑文件'),
      'unsaved edit',
    );
    c.selectPanel(ToolPanel.terminal);
    await tester.pumpAndSettle();
    c.selectPanel(ToolPanel.files);
    await tester.pumpAndSettle();
    c.setLayout(position: 'bottom');
    await tester.pumpAndSettle();
    c.setLayout(position: 'right');
    await tester.pumpAndSettle();
    expect(find.text('unsaved edit'), findsOneWidget);
    expect(c.fileDrafts['design:lib/workbench.dart']?['text'], 'unsaved edit');
    await tester.ensureVisible(find.text('保存文件'));
    await tester.tap(find.text('保存文件'));
    await tester.pumpAndSettle();
    expect(c.files['lib/workbench.dart'], 'unsaved edit');
    expect(c.fileDrafts, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('expanded tools update tabs and hand file drafts back', (
    tester,
  ) async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    addTearDown(() => reset(tester));
    await mount(tester, c, const Size(1440, 1000));
    await c.selectFile('lib/workbench.dart');
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '编辑文件'),
      'docked unsaved draft',
    );
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is BeautifulIconButton && widget.label == '放大工具面板',
      ),
    );
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('docked unsaved draft')),
      findsOneWidget,
    );
    await tester.enterText(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextField, '编辑文件'),
      ),
      'expanded unsaved draft',
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.byKey(const ValueKey('tool-tab-terminal')),
      ),
    );
    await tester.pumpAndSettle();
    expect(c.panel, ToolPanel.terminal);
    expect(
      find.descendant(of: dialog, matching: find.text('终端 · 预览')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.byKey(const ValueKey('tool-tab-files')),
      ),
    );
    await tester.pumpAndSettle();
    expect(c.panel, ToolPanel.files);
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('expanded unsaved draft'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: dialog,
        matching: find.byWidgetPredicate(
          (widget) => widget is BeautifulIconButton && widget.label == '关闭工具面板',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(c.panel, ToolPanel.files);
    expect(find.text('expanded unsaved draft'), findsOneWidget);
    expect(
      c.fileDrafts['design:lib/workbench.dart']?['text'],
      'expanded unsaved draft',
    );
    await tester.ensureVisible(find.text('保存文件'));
    await tester.tap(find.text('保存文件'));
    await tester.pumpAndSettle();
    expect(c.files['lib/workbench.dart'], 'expanded unsaved draft');
    expect(c.fileDrafts, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('approval choice updates the card and run state', (tester) async {
    final c = WorkbenchController();
    addTearDown(c.dispose);
    addTearDown(() => reset(tester));
    await mount(tester, c, const Size(1440, 1100));
    c.selectSession('approval');
    await tester.pumpAndSettle();
    await tester.tap(find.text('本次允许').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('提交').first);
    await tester.tap(find.text('提交').first);
    await tester.pumpAndSettle();
    expect(c.rows('approvals').first['decision'], 'accept');
    expect(c.rows('approvals').first['status'], 'answered');
    expect(
      c.rows('runs').firstWhere((r) => r['id'] == 'preview-approval')['status'],
      'preview',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('tools fit compact and docked layouts with larger text', (
    tester,
  ) async {
    final c = WorkbenchController()..largeText = true;
    addTearDown(c.dispose);
    addTearDown(() => reset(tester));
    await mount(tester, c, const Size(1440, 1000));
    for (final size in [
      const Size(1440, 1000),
      const Size(1024, 900),
      const Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      for (final panel in ToolPanel.values) {
        c.selectPanel(panel);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size $panel');
      }
    }
    tester.view.physicalSize = const Size(1440, 1000);
    c.setLayout(position: 'bottom');
    for (final panel in ToolPanel.values) {
      c.selectPanel(panel);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'bottom $panel');
    }
  });
  testWidgets(
    'Git, share and comment forms update the shell without services',
    (tester) async {
      final c = WorkbenchController();
      addTearDown(c.dispose);
      addTearDown(() => reset(tester));
      await mount(tester, c, const Size(1440, 1100));
      c.navigate(WorkspacePage.review);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, '提交 1 个文件'));
      await tester.tap(find.widgetWithText(FilledButton, '提交 1 个文件'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '前端提交示例');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(c.rows('previewCommits').first['subject'], '前端提交示例');
      c.navigate(WorkspacePage.collaboration);
      await tester.pumpAndSettle();
      await tester.tap(find.text('创建链接'));
      await tester.pumpAndSettle();
      expect(c.rows('shares'), hasLength(1));
      await tester.ensureVisible(find.widgetWithText(TextField, '添加评论'));
      await tester.enterText(find.widgetWithText(TextField, '添加评论'), '一条预览讨论');
      await tester.ensureVisible(find.text('发表评论'));
      await tester.tap(find.text('发表评论'));
      await tester.pumpAndSettle();
      expect(c.rows('comments').single['text'], '一条预览讨论');
      c.navigate(WorkspacePage.archive);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存当前变更快照'));
      await tester.tap(find.text('保存当前变更快照'));
      await tester.pumpAndSettle();
      expect(c.rows('checkpoints'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
