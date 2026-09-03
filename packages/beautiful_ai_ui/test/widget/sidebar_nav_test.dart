import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

BeautifulSidebarNav _sidebar({
  BeautifulSidebarPresentation presentation =
      BeautifulSidebarPresentation.expanded,
  Iterable<BeautifulSidebarRecent>? recents,
  ValueChanged<BeautifulSidebarItem>? onItem,
  ValueChanged<BeautifulSidebarRecent>? onRecent,
  ValueChanged<BeautifulSidebarWorkspace>? onWorkspace,
  ValueChanged<BeautifulSidebarWorkspaceAction>? onAction,
  VoidCallback? onNewChat,
  VoidCallback? onFooter,
  String? selectedRecentId,
  String selectedItemId = 'home',
  String workspaceLabel = 'Research workspace',
  BeautifulSidebarLabels labels = const BeautifulSidebarLabels(),
}) => BeautifulSidebarNav(
  key: const ValueKey('sidebar'),
  workspaces: [
    BeautifulSidebarWorkspace(id: 'research', label: workspaceLabel),
    BeautifulSidebarWorkspace(id: 'product', label: 'Product workspace'),
  ],
  selectedWorkspaceId: 'research',
  items: [
    BeautifulSidebarItem(id: 'home', label: 'Home'),
    BeautifulSidebarItem(id: 'invite', label: 'Invite users', count: '3/10'),
  ],
  recents:
      recents ??
      [
        BeautifulSidebarRecent(
          id: 'alpha',
          label: 'Alpha project',
          prompt: 'A',
        ),
        BeautifulSidebarRecent(id: 'beta', label: 'Beta project', prompt: 'B'),
      ],
  selectedItemId: selectedItemId,
  selectedRecentId: selectedRecentId,
  onItemSelected: onItem ?? (_) {},
  onRecentSelected: onRecent ?? (_) {},
  onWorkspaceSelected: onWorkspace ?? (_) {},
  onWorkspaceAction: onAction ?? (_) {},
  onNewChat: onNewChat ?? () {},
  footerLabel: 'Upgrade',
  onFooterPressed: onFooter ?? () {},
  presentation: presentation,
  labels: labels,
);

Widget _app(
  Widget child, {
  double width = 1100,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection direction = TextDirection.ltr,
  bool highContrast = false,
}) => beautifulTestApp(
  size: Size(width, 1000),
  disableAnimations: true,
  textScaler: textScaler,
  textDirection: direction,
  highContrast: highContrast,
  child: SizedBox(width: width, child: child),
);

void main() {
  test(
    'snapshots reject invalid identities and keep immutable collections',
    () {
      final workspaces = [
        BeautifulSidebarWorkspace(id: 'w', label: 'Workspace'),
      ];
      final items = [BeautifulSidebarItem(id: 'home', label: 'Home')];
      final recents = [BeautifulSidebarRecent(id: 'chat', label: 'Chat')];
      final nav = BeautifulSidebarNav(
        workspaces: workspaces,
        selectedWorkspaceId: 'w',
        items: items,
        recents: recents,
      );
      workspaces.clear();
      items.clear();
      recents.clear();
      expect(nav.workspaces.single.id, 'w');
      expect(nav.items.single.id, 'home');
      expect(nav.recents.single.id, 'chat');
      expect(() => nav.items.clear(), throwsUnsupportedError);
      expect(
        () => BeautifulSidebarWorkspace(id: ' ', label: 'Valid'),
        throwsArgumentError,
      );
      expect(
        () => BeautifulSidebarRecent(id: 'valid', label: ''),
        throwsArgumentError,
      );
      expect(
        () => BeautifulSidebarItem(id: 'valid', label: 'Valid', count: ' '),
        throwsArgumentError,
      );
      for (final extra in ['duplicate', 'selection', 'height', 'width']) {
        expect(
          () => BeautifulSidebarNav(
            workspaces: nav.workspaces,
            selectedWorkspaceId: 'w',
            items: extra == 'duplicate'
                ? [nav.items.single, nav.items.single]
                : [],
            selectedItemId: extra == 'selection' ? 'unknown' : null,
            height: extra == 'height' ? 0 : 600,
            expandedWidth: extra == 'width' ? double.infinity : 288,
          ),
          throwsArgumentError,
        );
      }
    },
  );

  testWidgets(
    'navigation dispatches exact snapshots with controlled selection',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final events = <String>[];
      await tester.pumpWidget(
        _app(
          _sidebar(
            onItem: (item) => events.add(item.id),
            onRecent: (item) => events.add('${item.id}:${item.prompt}'),
            onNewChat: () => events.add('new'),
            onFooter: () => events.add('footer'),
          ),
        ),
      );
      await tester.tap(find.text('Invite users  3/10'));
      await tester.tap(find.text('Beta project'));
      await tester.tap(find.text('New chat'));
      await tester.tap(find.text('Upgrade'));
      await tester.pumpAndSettle();
      expect(events, ['invite', 'beta:B', 'new', 'footer']);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Home'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Invite users, 3/10'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );
      await tester.pumpWidget(_app(_sidebar(selectedItemId: 'invite')));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Invite users, 3/10'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets(
    'workspace menu dispatches typed actions and selected workspace',
    (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        _app(
          _sidebar(
            onWorkspace: (workspace) => events.add(workspace.id),
            onAction: (action) => events.add(action.name),
          ),
        ),
      );
      Future<void> open() async {
        await tester.tap(
          find.byKey(const ValueKey('beautiful-sidebar-workspace')),
        );
        await tester.pumpAndSettle();
      }

      await open();
      await tester.tap(find.text('Product workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Product workspace'), findsNothing);
      for (final label in [
        'New workspace',
        'Workspace settings',
        'Invite team members',
        'Sign out',
      ]) {
        await open();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(events, ['product', 'create', 'settings', 'invite', 'signOut']);
    },
  );

  testWidgets(
    'keyboard activates menu, moves focus and Escape restores trigger',
    (tester) async {
      await tester.pumpWidget(_app(_sidebar()));
      final trigger = find.byKey(const ValueKey('beautiful-sidebar-workspace'));
      final focus = tester
          .widget<FocusableActionDetector>(
            find.descendant(
              of: trigger,
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!;
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Product workspace'), findsOneWidget);
      final originalFocus = FocusManager.instance.primaryFocus;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNot(originalFocus));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Product workspace'), findsNothing);
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('Product workspace'), findsOneWidget);
    },
  );

  testWidgets('search filters Unicode names, supports empty state and Escape', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _sidebar(
          recents: [
            BeautifulSidebarRecent(id: 'zh', label: '研发计划'),
            BeautifulSidebarRecent(id: 'en', label: 'Alpha release'),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Search chat history'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '  研发 ');
    await tester.pump();
    expect(find.text('研发计划'), findsOneWidget);
    expect(find.text('Alpha release'), findsNothing);
    await tester.enterText(find.byType(EditableText), 'MISSING');
    await tester.pump();
    expect(find.text('No chats found'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsNothing);
    expect(find.text('研发计划'), findsOneWidget);
    final trigger = tester.widget<FocusableActionDetector>(
      find.descendant(
        of: find.byKey(const ValueKey('beautiful-sidebar-search-trigger')),
        matching: find.byType(FocusableActionDetector),
      ),
    );
    expect(trigger.focusNode!.hasFocus, isTrue);
  });

  testWidgets('adaptive breakpoints preserve search, selection and focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget app(double width) => _app(
      _sidebar(presentation: BeautifulSidebarPresentation.adaptive),
      width: width,
    );
    await tester.pumpWidget(app(1024));
    await tester.tap(find.text('Search chat history'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Alpha');
    final editor = tester.widget<EditableText>(find.byType(EditableText));
    editor.controller.selection = const TextSelection(
      baseOffset: 1,
      extentOffset: 4,
    );
    await tester.pump();
    for (final width in [1023.0, 600.0, 599.0, 390.0]) {
      await tester.pumpWidget(app(width));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(EditableText), findsNothing);
    }
    await tester.pumpWidget(app(1024));
    await tester.pumpAndSettle();
    final restored = tester.widget<EditableText>(find.byType(EditableText));
    expect(restored.controller.text, 'Alpha');
    expect(restored.controller.selection.baseOffset, 1);
    expect(restored.controller.selection.extentOffset, 4);
    expect(restored.focusNode.hasFocus, isTrue);
    expect(find.text('Beta project'), findsNothing);
  });

  testWidgets('compact drawer opens without Navigator and closes with Escape', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _sidebar(presentation: BeautifulSidebarPresentation.drawer),
        width: 320,
      ),
    );
    expect(find.text('Alpha project'), findsNothing);
    await tester.tap(find.text('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Alpha project'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Alpha project'), findsNothing);
    expect(find.text('Open navigation'), findsOneWidget);
  });

  testWidgets(
    'closed drawer trigger grows with RTL text scaling and wrapping',
    (tester) async {
      final trigger = find.byKey(const ValueKey('beautiful-sidebar-toggle'));
      Widget app({double scale = 1, BeautifulSidebarLabels? labels}) => _app(
        _sidebar(
          presentation: BeautifulSidebarPresentation.drawer,
          labels: labels ?? const BeautifulSidebarLabels(),
        ),
        width: 390,
        textScaler: TextScaler.linear(scale),
        direction: TextDirection.rtl,
        highContrast: true,
      );
      await tester.pumpWidget(app());
      final normalHeight = tester.getSize(trigger).height;
      await tester.pumpWidget(app(scale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scaledHeight = tester.getSize(trigger).height;
      expect(scaledHeight, greaterThan(normalHeight));
      expect(scaledHeight, greaterThanOrEqualTo(48));
      expect(find.text('Alpha project'), findsNothing);
      expect(
        tester.getBottomLeft(trigger).dy,
        lessThanOrEqualTo(
          tester.getBottomLeft(find.byType(BeautifulSidebarNav)).dy,
        ),
      );
      const open = 'افتح لوحة التنقل الكاملة الخاصة بمساحة العمل الحالية';
      await tester.pumpWidget(
        app(scale: 2, labels: const BeautifulSidebarLabels(open: open)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(trigger).height, greaterThan(scaledHeight));
      expect(find.text(open), findsOneWidget);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.text('Close navigation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final label in ['Invite users  3/10', 'New chat', 'Upgrade']) {
    testWidgets('$label retains keyboard activation across panel and rail', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final events = <String>[];
      Widget app(double width) => WidgetsApp(
        color: const Color(0xffffffff),
        builder: (context, child) => _app(
          _sidebar(
            presentation: BeautifulSidebarPresentation.adaptive,
            onItem: (item) => events.add(item.id),
            onNewChat: () => events.add('new'),
            onFooter: () => events.add('footer'),
          ),
          width: width,
        ),
      );
      await tester.pumpWidget(app(1024));
      tester
          .widget<FocusableActionDetector>(
            find.descendant(
              of: find.byKey(const ValueKey('beautiful-sidebar-workspace')),
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      final control = tester.widget<FocusableActionDetector>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(FocusableActionDetector),
        ),
      );
      final node = control.focusNode!;
      for (var count = 0; count < 12 && !node.hasFocus; count++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(node.hasFocus, isTrue);
      for (final width in [1023.0, 1024.0]) {
        await tester.pumpWidget(app(width));
        await tester.pumpAndSettle();
        expect(node.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
      }
      final expected = switch (label) {
        'New chat' => 'new',
        'Upgrade' => 'footer',
        _ => 'invite',
      };
      expect(events, [expected, expected]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'hidden focused destination falls back to compact drawer trigger',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selections = 0;
      Widget app(double width) => WidgetsApp(
        color: const Color(0xffffffff),
        builder: (context, child) => _app(
          _sidebar(
            presentation: BeautifulSidebarPresentation.adaptive,
            onItem: (_) => selections++,
          ),
          width: width,
        ),
      );
      await tester.pumpWidget(app(1024));
      tester
          .widget<FocusableActionDetector>(
            find.descendant(
              of: find.byKey(const ValueKey('beautiful-sidebar-workspace')),
              matching: find.byType(FocusableActionDetector),
            ),
          )
          .focusNode!
          .requestFocus();
      await tester.pump();
      final control = tester.widget<FocusableActionDetector>(
        find.descendant(
          of: find.byKey(const ValueKey('beautiful-sidebar-item-home')),
          matching: find.byType(FocusableActionDetector),
        ),
      );
      for (var count = 0; count < 12 && !control.focusNode!.hasFocus; count++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(control.focusNode!.hasFocus, isTrue);
      await tester.pumpWidget(app(599));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);
      final trigger = tester.widget<FocusableActionDetector>(
        find.descendant(
          of: find.byKey(const ValueKey('beautiful-sidebar-toggle')),
          matching: find.byType(FocusableActionDetector),
        ),
      );
      expect(trigger.focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(selections, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact selection closes the panel while the host receives ID', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      _app(
        _sidebar(
          presentation: BeautifulSidebarPresentation.drawer,
          onRecent: (recent) => selected = recent.id,
        ),
        width: 320,
      ),
    );
    await tester.tap(find.text('Open navigation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta project'));
    await tester.pumpAndSettle();
    expect(selected, 'beta');
    expect(find.text('Open navigation'), findsOneWidget);
    expect(find.text('Beta project'), findsNothing);
  });

  testWidgets(
    'outside menu dismissal preserves focus on the external control',
    (tester) async {
      final outsideFocus = FocusNode();
      addTearDown(outsideFocus.dispose);
      await tester.pumpWidget(
        TapRegionSurface(
          child: _app(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sidebar(),
                Focus(
                  focusNode: outsideFocus,
                  child: GestureDetector(
                    onTap: outsideFocus.requestFocus,
                    child: const SizedBox(
                      width: 120,
                      height: 80,
                      child: Text('Outside control'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('beautiful-sidebar-workspace')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Product workspace'), findsOneWidget);
      await tester.tap(find.text('Outside control'));
      await tester.pumpAndSettle();
      expect(find.text('Product workspace'), findsNothing);
      expect(outsideFocus.hasFocus, isTrue);
    },
  );

  testWidgets('1000 recent rows stay lazy and scroll survives rail expansion', (
    tester,
  ) async {
    final recents = List.generate(
      1000,
      (index) =>
          BeautifulSidebarRecent(id: '$index', label: 'History item $index'),
    );
    await tester.pumpWidget(_app(_sidebar(recents: recents)));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key == const ValueKey('beautiful-sidebar-recent-999'),
      ),
      findsNothing,
    );
    expect(find.byType(Text).evaluate().length, lessThan(50));
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    scroll.jumpTo(16000);
    await tester.pumpAndSettle();
    final offset = scroll.offset;
    final visible = find
        .byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'beautiful-sidebar-recent-',
              ),
        )
        .evaluate()
        .map((element) => element.widget.key)
        .toList();
    expect(visible.length, lessThan(40));
    await tester.tap(find.byKey(const ValueKey('beautiful-sidebar-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('beautiful-sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(scroll.offset, offset);
    expect(find.byKey(visible.first!), findsOneWidget);
  });

  testWidgets(
    '200 percent RTL long labels and high contrast remain reachable',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const longName = 'مساحة العمل الطويلة 研发计划 Full workspace name';
      await tester.pumpWidget(
        _app(
          _sidebar(workspaceLabel: longName),
          width: 320,
          textScaler: TextScaler.linear(2),
          direction: TextDirection.rtl,
          highContrast: true,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('beautiful-sidebar-workspace')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final fullName = tester.widget<Text>(
        find.descendant(
          of: find.byKey(
            const ValueKey('beautiful-sidebar-workspace-research'),
          ),
          matching: find.byType(Text),
        ),
      );
      expect(fullName.maxLines, isNull);
      expect(fullName.data, longName);
    },
  );
}
