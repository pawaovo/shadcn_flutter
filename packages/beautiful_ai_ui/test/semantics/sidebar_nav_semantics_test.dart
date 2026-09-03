import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

Widget _app({
  BeautifulSidebarPresentation presentation =
      BeautifulSidebarPresentation.expanded,
  bool enabled = true,
}) => beautifulTestApp(
  disableAnimations: true,
  child: BeautifulSidebarNav(
    workspaces: [BeautifulSidebarWorkspace(id: 'w', label: '研发工作区')],
    selectedWorkspaceId: 'w',
    items: [BeautifulSidebarItem(id: 'home', label: '首页')],
    recents: [BeautifulSidebarRecent(id: 'chat', label: '发布计划')],
    selectedItemId: 'home',
    selectedRecentId: 'chat',
    onItemSelected: enabled ? (_) {} : null,
    onRecentSelected: enabled ? (_) {} : null,
    onWorkspaceSelected: enabled ? (_) {} : null,
    onWorkspaceAction: enabled ? (_) {} : null,
    onNewChat: enabled ? () {} : null,
    presentation: presentation,
    labels: const BeautifulSidebarLabels(
      navigation: '工作区导航',
      workspace: '切换工作区',
      newChat: '新建对话',
      search: '搜索聊天记录',
      chats: '对话',
    ),
  ),
);

void main() {
  testWidgets('navigation exposes selected destinations and complete labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    final roles = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((widget) => widget.properties.role);
    expect(roles, contains(SemanticsRole.navigation));
    for (final label in ['首页', '发布计划']) {
      final node = tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData();
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.hasAction(SemanticsAction.tap), isTrue);
    }
    final workspace = tester
        .getSemantics(find.bySemanticsLabel('切换工作区: 研发工作区'))
        .getSemanticsData();
    expect(workspace.flagsCollection.isExpanded, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets('workspace menu excludes obscured navigation semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    tester.semantics.tap(find.semantics.byLabel('切换工作区: 研发工作区'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('首页'), findsNothing);
    expect(find.bySemanticsLabel('发布计划'), findsNothing);
    final workspace = tester
        .getSemantics(find.bySemanticsLabel('切换工作区: 研发工作区'))
        .getSemanticsData();
    expect(workspace.flagsCollection.isExpanded, Tristate.isTrue);
    final choice = tester
        .getSemantics(find.bySemanticsLabel('研发工作区'))
        .getSemanticsData();
    expect(choice.flagsCollection.isSelected, Tristate.isTrue);
    tester.semantics.tap(find.semantics.byLabel('Close workspace menu'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('发布计划'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'rail keeps complete action labels and removes recent descendants',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(presentation: BeautifulSidebarPresentation.rail),
      );
      expect(find.text('首页'), findsNothing);
      expect(find.bySemanticsLabel('首页'), findsOneWidget);
      expect(find.bySemanticsLabel('发布计划'), findsNothing);
      final toggle = tester
          .getSemantics(find.bySemanticsLabel('Expand sidebar'))
          .getSemanticsData();
      expect(toggle.flagsCollection.isExpanded, Tristate.isFalse);
      tester.semantics.tap(find.semantics.byLabel('Expand sidebar'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('发布计划'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('absent host callbacks expose disabled non-actionable controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(enabled: false));
    for (final label in ['首页', '发布计划', '新建对话']) {
      final node = tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData();
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.hasAction(SemanticsAction.tap), isFalse);
      expect(node.hasAction(SemanticsAction.focus), isFalse);
    }
    semantics.dispose();
  });

  testWidgets(
    'search has a localized editable label and empty results announce',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      tester.semantics.tap(find.semantics.byLabel('搜索聊天记录'));
      await tester.pumpAndSettle();
      final field = tester
          .getSemantics(find.bySemanticsLabel('搜索聊天记录'))
          .getSemanticsData();
      expect(field.flagsCollection.isTextField, isTrue);
      await tester.enterText(find.byType(EditableText), 'missing');
      await tester.pumpAndSettle();
      final empty = tester
          .getSemantics(find.bySemanticsLabel('No chats found'))
          .getSemanticsData();
      expect(empty.flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('all visible navigation actions meet platform tap targets', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final presentation in [
      BeautifulSidebarPresentation.expanded,
      BeautifulSidebarPresentation.rail,
      BeautifulSidebarPresentation.drawer,
    ]) {
      await tester.pumpWidget(_app(presentation: presentation));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    }
    semantics.dispose();
  });
}
