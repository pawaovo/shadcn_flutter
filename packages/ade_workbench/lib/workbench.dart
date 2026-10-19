import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'dart:math' as math;

import 'platform_host.dart';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'workbench_controller.dart';

part 'workspace_pages.dart';
part 'tool_panel.dart';
part 'workspace_widgets.dart';
part 'workspace_extra.dart';

class WorkbenchApp extends StatelessWidget {
  WorkbenchApp({super.key, required this.controller});
  final WorkbenchController controller;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: 'ADE · 智能工作台',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      themeAnimationDuration: Duration.zero,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: _materialTheme(Brightness.light),
      darkTheme: _materialTheme(Brightness.dark),
      themeMode: switch (controller.themeMode) {
        BeautifulUiThemeMode.light => ThemeMode.light,
        BeautifulUiThemeMode.dark => ThemeMode.dark,
        BeautifulUiThemeMode.system => ThemeMode.system,
      },
      builder: (context, child) => _FirstFrameFocusGate(
        child: BeautifulUiScope(
          themeMode: controller.themeMode,
          onFailure: (failure) {
            _messenger.currentState?.showSnackBar(
              SnackBar(
                content: Text(
                  failure.cause is FormatException
                      ? (failure.cause as FormatException).message
                      : '操作未完成，请重试。',
                ),
              ),
            );
          },
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: controller.largeText
                  ? TextScaler.linear(
                      MediaQuery.textScalerOf(context).scale(1) * 1.15,
                    )
                  : MediaQuery.textScalerOf(context),
            ),
            child: child!,
          ),
        ),
      ),
      home: _Workbench(controller: controller),
    ),
  );

  ThemeData _materialTheme(Brightness brightness) {
    final foundation = brightness == Brightness.dark
        ? const BeautifulUiThemeData.dark()
        : const BeautifulUiThemeData.light();
    final colors = foundation.colors;
    final type = foundation.typography;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(foundation.radii.control),
    );
    final text = TextTheme(
      bodyLarge: type.body,
      bodyMedium: type.body,
      bodySmall: type.caption,
      labelLarge: type.label,
      labelMedium: type.label,
      labelSmall: type.caption,
      titleLarge: type.label.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: type.label.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: type.label,
      headlineSmall: type.body.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
      ),
    ).apply(bodyColor: colors.ink, displayColor: colors.ink);
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'packages/shadcn_flutter/GeistSans',
      textTheme: text,
      scaffoldBackgroundColor: colors.surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.ink,
        onPrimary: colors.surface,
        secondary: colors.inset,
        onSecondary: colors.ink,
        error: colors.destructive,
        onError: colors.destructiveForeground,
        surface: colors.surface,
        onSurface: colors.ink,
        surfaceContainerHighest: colors.inset,
        surfaceTint: Colors.transparent,
        outline: colors.lineStrong,
        outlineVariant: colors.line,
      ),
      splashFactory: NoSplash.splashFactory,
      dividerTheme: DividerThemeData(
        color: colors.line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: IconThemeData(color: colors.inkMuted, size: 18),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(foundation.radii.card),
          side: BorderSide(color: colors.line),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: colors.surface,
        collapsedBackgroundColor: colors.surface,
        iconColor: colors.inkMuted,
        collapsedIconColor: colors.inkMuted,
        textColor: colors.ink,
        collapsedTextColor: colors.ink,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: colors.surface,
          textStyle: type.label,
          shape: shape,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          backgroundColor: colors.surface,
          textStyle: type.label,
          side: BorderSide(color: colors.lineStrong),
          shape: shape,
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.inkMuted,
          textStyle: type.label,
          shape: shape,
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colors.inkMuted,
          shape: shape,
          iconSize: 18,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.inkMuted,
        textColor: colors.ink,
        minLeadingWidth: 16,
        horizontalTitleGap: 12,
        titleTextStyle: type.label.copyWith(color: colors.ink),
        subtitleTextStyle: type.caption.copyWith(color: colors.inkMuted),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: shape,
        textStyle: type.label.copyWith(color: colors.ink),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(foundation.radii.window),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surface,
        selectedColor: colors.hoverStrong,
        secondarySelectedColor: colors.hoverStrong,
        labelStyle: type.caption.copyWith(color: colors.ink),
        secondaryLabelStyle: type.caption.copyWith(color: colors.ink),
        side: BorderSide(color: colors.lineStrong),
        shape: shape,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: colors.inkSubtle),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.ink
              : colors.surface,
        ),
        checkColor: WidgetStatePropertyAll(colors.surface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        isDense: true,
        labelStyle: type.label.copyWith(color: colors.inkMuted),
        hintStyle: type.body.copyWith(color: colors.inkMuted),
        helperStyle: type.caption.copyWith(color: colors.inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(foundation.radii.control),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(foundation.radii.control),
          borderSide: BorderSide(color: colors.lineStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(foundation.radii.control),
          borderSide: BorderSide(color: colors.inkMuted),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 16,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        textStyle: type.caption.copyWith(color: colors.tooltipForeground),
        decoration: BoxDecoration(
          color: colors.tooltipBackground,
          borderRadius: BorderRadius.circular(foundation.radii.chip),
        ),
      ),
    );
  }
}

// Flutter Web can echo Navigator's startup focus request before the first
// render pass. Keep the entire hosted layer out of traversal until it has size.
class _FirstFrameFocusGate extends StatefulWidget {
  const _FirstFrameFocusGate({required this.child});
  final Widget child;
  @override
  State<_FirstFrameFocusGate> createState() => _FirstFrameFocusGateState();
}

class _FirstFrameFocusGateState extends State<_FirstFrameFocusGate> {
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) =>
      ExcludeFocus(excluding: !_ready, child: widget.child);
}

class _Workbench extends StatefulWidget {
  const _Workbench({required this.controller});
  final WorkbenchController controller;
  @override
  State<_Workbench> createState() => _WorkbenchState();
}

class _WorkbenchState extends State<_Workbench> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _keyboardFocus = FocusNode(
    debugLabel: 'ADE workspace',
    skipTraversal: true,
  );
  WorkbenchController get c => widget.controller;
  void Function()? _removeUnloadGuard;
  WorkspacePage? _lastPage;
  double _width = 1440;
  bool get _wide => _width >= 1100 && !c.focusMode;
  bool get _compact => _width < 800;
  bool _showInspector = true;
  bool _resizing = false;
  bool _resizeFocused = false;
  double _inspectorWidth = 420;
  bool get _dockable =>
      _wide && c.page == WorkspacePage.chat && c.panel != ToolPanel.settings;
  bool get _hasInspector => _dockable && _showInspector;

  @override
  void initState() {
    super.initState();
    c.addListener(_controllerUpdated);
    _removeUnloadGuard = listenBeforeUnload(() => c.fileDrafts.isNotEmpty);
    final detached = Uri.base.queryParameters['tool'];
    if (ToolPanel.values.any((v) => v.name == detached)) {
      c.panel = ToolPanel.values.byName(detached!);
    }
    _lastPage = c.page;
    // The host gate opens after frame one. Initialize keyboard focus after
    // that update is laid out, preserving any editor the user already focused.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_keyboardFocus.hasFocus) _keyboardFocus.requestFocus();
      });
    });
  }

  void _controllerUpdated() {
    final pageChanged = _lastPage != c.page;
    _lastPage = c.page;
    final tools = c.toolsRequested;
    c.toolsRequested = false;
    if (!pageChanged && !tools) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (pageChanged && (_scaffold.currentState?.isEndDrawerOpen ?? false)) {
        Navigator.of(context).pop();
      }
      if (tools) {
        if (_dockable) {
          _scaffold.currentState?.closeEndDrawer();
          if (!_showInspector) setState(() => _showInspector = true);
        } else if (!(_scaffold.currentState?.isEndDrawerOpen ?? false)) {
          _scaffold.currentState?.openEndDrawer();
        }
      }
    });
  }

  @override
  void dispose() {
    _removeUnloadGuard?.call();
    c.removeListener(_controllerUpdated);
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _tools([ToolPanel? panel]) {
    if (panel != null) c.selectPanel(panel);
    if (_dockable) {
      setState(() => _showInspector = true);
    } else {
      _scaffold.currentState?.openEndDrawer();
    }
  }

  Future<void> _expandTools() => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      child: SafeArea(
        child: _ToolPanel(
          controller: c,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    ),
  );

  void _navigate(WorkspacePage page) {
    c.navigate(page);
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _select(String id) {
    c.selectSession(id);
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  void _new() {
    c.newSession();
    if (_scaffold.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ToolPanel.values.any(
      (v) => v.name == Uri.base.queryParameters['tool'],
    )) {
      return Scaffold(
        appBar: AppBar(title: Text('ADE · ${c.panel.name}')),
        body: SafeArea(child: _ToolPanel(controller: c)),
      );
    }
    final colors = _colors(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            c.navigate(WorkspacePage.search),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            c.navigate(WorkspacePage.search),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): _new,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _new,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_scaffold.currentState?.isEndDrawerOpen ?? false) {
            Navigator.of(context).pop();
          } else if (_scaffold.currentState?.isDrawerOpen ?? false) {
            Navigator.of(context).pop();
          }
        },
      },
      child: Focus(
        focusNode: _keyboardFocus,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;
            final desktopInset = _width >= 1280 ? 8.0 : 0.0;
            return ColoredBox(
              color: colors.canvas,
              child: Padding(
                padding: EdgeInsets.all(desktopInset),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(desktopInset),
                  child: Scaffold(
                    key: _scaffold,
                    drawer: Drawer(
                      width: math.min(_width - 32, 320),
                      backgroundColor: colors.inset,
                      child: SafeArea(
                        child: _navigation(
                          BeautifulSidebarPresentation.expanded,
                        ),
                      ),
                    ),
                    endDrawer: Drawer(
                      width: math.min(_width, 480),
                      backgroundColor: colors.surface,
                      child: SafeArea(
                        child: _ToolPanel(
                          controller: c,
                          onClose: () => Navigator.of(context).pop(),
                          onExpand: _compact ? null : _expandTools,
                        ),
                      ),
                    ),
                    body: SafeArea(
                      child: Column(
                        children: [
                          _topBar(),
                          Divider(height: 1, color: colors.line),
                          if (c.storageError != null)
                            Row(
                              children: [
                                Expanded(
                                  child: _Notice(
                                    text: c.storageError!,
                                    icon: Icons.warning_amber_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: '关闭提示',
                                  onPressed: c.clearError,
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                              ],
                            ),
                          Expanded(child: _workspaceBody()),
                          if (_compact &&
                              MediaQuery.viewInsetsOf(context).bottom == 0)
                            _mobileNavigation(),
                          if (!_compact) _statusBar(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _workspaceBody() {
    final content = Expanded(
      key: const ValueKey('workspace-content'),
      child: IndexedStack(
        index: c.page.index,
        children: [
          _HomePage(controller: c, onTools: _tools),
          _SessionsPage(controller: c),
          _SearchPage(controller: c, onTools: _tools),
          _AutomationsPage(controller: c),
          _ChatPage(controller: c, onTools: _tools),
          _RunsPage(controller: c),
          _ReviewPage(controller: c),
          _ActivityPage(controller: c),
          _AccountPage(controller: c),
          _WorkspacesPage(controller: c),
          _ConnectionPage(controller: c),
          _CollaborationPage(controller: c),
          _ArchivePage(controller: c),
        ],
      ),
    );
    final panelWidth = _inspectorWidth
        .clamp(320.0, math.max(320.0, math.min(640.0, _width - 640)))
        .toDouble();
    Widget inspector() => AnimatedContainer(
      key: const Key('desktop-inspector'),
      duration: _resizing || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : BeautifulUiTheme.of(context).motion.standard,
      curve: BeautifulUiTheme.of(context).motion.outCurve,
      width: c.dock == 'bottom' ? null : panelWidth,
      color: _colors(context).surface,
      child: Material(
        color: _colors(context).surface,
        child: _ToolPanel(
          controller: c,
          onClose: () => setState(() => _showInspector = false),
          onExpand: _expandTools,
        ),
      ),
    );
    void resizeBy(double delta) => setState(() {
      _inspectorWidth = (panelWidth + delta)
          .clamp(320.0, math.max(320.0, math.min(640.0, _width - 640)))
          .toDouble();
    });
    Widget separator() => Semantics(
      label: '调整工具面板宽度',
      value: '${panelWidth.round()} 像素',
      increasedValue:
          '${(panelWidth + 16).clamp(320.0, math.max(320.0, math.min(640.0, _width - 640))).round()} 像素',
      decreasedValue:
          '${(panelWidth - 16).clamp(320.0, math.max(320.0, math.min(640.0, _width - 640))).round()} 像素',
      onIncrease: () => resizeBy(16),
      onDecrease: () => resizeBy(-16),
      child: Focus(
        onFocusChange: (value) => setState(() => _resizeFocused = value),
        onKeyEvent: (_, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          final direction = c.dock == 'left' ? 1.0 : -1.0;
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            resizeBy(-16 * direction);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            resizeBy(16 * direction);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            key: const Key('workspace-resizer'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => setState(() => _resizing = true),
            onHorizontalDragUpdate: (event) =>
                resizeBy(event.delta.dx * (c.dock == 'left' ? 1 : -1)),
            onHorizontalDragEnd: (_) => setState(() => _resizing = false),
            onHorizontalDragCancel: () => setState(() => _resizing = false),
            child: Container(
              width: 5,
              color: _colors(context).page,
              child: Center(
                child: Container(
                  width: _resizeFocused ? 2 : 1,
                  color: _resizeFocused
                      ? _colors(context).accent
                      : _colors(context).line,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final duration = _resizing || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : BeautifulUiTheme.of(context).motion.standard;
    Widget sidePanel() => ClipRect(
      child: AnimatedAlign(
        alignment: c.dock == 'left'
            ? Alignment.centerLeft
            : Alignment.centerRight,
        widthFactor: _showInspector ? 1 : 0,
        duration: duration,
        curve: BeautifulUiTheme.of(context).motion.outCurve,
        child: ExcludeFocus(
          excluding: !_showInspector,
          child: ExcludeSemantics(
            excluding: !_showInspector,
            child: IgnorePointer(
              ignoring: !_showInspector,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.dock == 'right') separator(),
                  inspector(),
                  if (c.dock == 'left') separator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_compact && !c.focusMode)
          Container(
            key: const Key('desktop-navigation'),
            width: _wide ? 240 : 64,
            color: _colors(context).page,
            child: _navigation(
              _wide
                  ? BeautifulSidebarPresentation.expanded
                  : BeautifulSidebarPresentation.rail,
            ),
          ),
        if (_dockable && c.dock == 'left') sidePanel(),
        content,
        if (_dockable && c.dock == 'right') sidePanel(),
      ],
    );
    return Column(
      children: [
        Expanded(child: row),
        if (_dockable && c.dock == 'bottom')
          ClipRect(
            child: AnimatedAlign(
              alignment: Alignment.bottomCenter,
              heightFactor: _showInspector ? 1 : 0,
              duration: duration,
              curve: BeautifulUiTheme.of(context).motion.outCurve,
              child: ExcludeFocus(
                excluding: !_showInspector,
                child: ExcludeSemantics(
                  excluding: !_showInspector,
                  child: SizedBox(height: 256, child: inspector()),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _navigation(
    BeautifulSidebarPresentation presentation,
  ) => LayoutBuilder(
    builder: (context, constraints) => BeautifulSidebarNav(
      key: ValueKey('navigation-${presentation.name}'),
      density: BeautifulUiDensity.compact,
      surfaceVariant: BeautifulSurfaceVariant.embedded,
      workspaces: [
        for (final w in c.workspaces)
          BeautifulSidebarWorkspace(id: w['id'], label: w['name']),
      ],
      selectedWorkspaceId: c.workspace,
      onWorkspaceSelected: (w) => c.selectWorkspace(w.id),
      items: [
        BeautifulSidebarItem(
          id: 'home',
          icon: Icons.space_dashboard_outlined,
          label: '工作台',
        ),
        BeautifulSidebarItem(
          id: 'search',
          icon: Icons.search_rounded,
          label: '全局搜索',
        ),
        BeautifulSidebarItem(
          id: 'automations',
          icon: Icons.bolt_outlined,
          label: '自动化',
          count:
              '${c.automations.where((a) => a.data['workspaceId'] == c.workspace).length}',
        ),
        BeautifulSidebarItem(
          id: 'activity',
          icon: Icons.notifications_none_rounded,
          label: '通知与活动',
          count: c.unread == 0 ? null : '${c.unread}',
        ),
      ],
      selectedItemId:
          const [
            WorkspacePage.home,
            WorkspacePage.search,
            WorkspacePage.automations,
            WorkspacePage.activity,
          ].contains(c.page)
          ? c.page.name
          : null,
      selectedRecentId: c.page == WorkspacePage.chat && c.current.id.isNotEmpty
          ? c.selectedSessionId
          : null,
      recents: [
        for (final session in [
          ...c.visibleSessions.where((s) => s.pinned),
          ...c.visibleSessions.where((s) => !s.pinned),
        ])
          BeautifulSidebarRecent(
            id: session.id,
            label: session.title,
            prompt: session.workspace,
          ),
      ],
      onItemSelected: (item) {
        if (item.id == 'settings') {
          if (_scaffold.currentState?.isDrawerOpen ?? false) {
            Navigator.of(context).pop();
          }
          _tools(ToolPanel.settings);
        } else {
          _navigate(WorkspacePage.values.byName(item.id));
        }
      },
      onRecentSelected: (recent) => _select(recent.id),
      onNewChat: _new,
      onWorkspaceAction: (_) => _navigate(WorkspacePage.workspaces),
      footer: presentation == BeautifulSidebarPresentation.rail
          ? _IconAction(
              icon: Icons.more_horiz,
              label: '更多工作区页面',
              onPressed: () => _navigate(WorkspacePage.home),
            )
          : PopupMenuButton<WorkspacePage>(
              tooltip: '更多工作区页面',
              onSelected: _navigate,
              itemBuilder: (_) => [
                for (final page in [
                  WorkspacePage.sessions,
                  WorkspacePage.runs,
                  WorkspacePage.review,
                  WorkspacePage.workspaces,
                  WorkspacePage.collaboration,
                  WorkspacePage.archive,
                  WorkspacePage.account,
                  WorkspacePage.connection,
                ])
                  PopupMenuItem(value: page, child: Text(_pageTitle(page))),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.more_horiz,
                      size: 16,
                      color: _colors(context).inkMuted,
                    ),
                    const SizedBox(width: 8),
                    Text('更多', style: _muted(context)),
                    const Spacer(),
                    Icon(
                      Icons.unfold_more,
                      size: 14,
                      color: _colors(context).inkMuted,
                    ),
                  ],
                ),
              ),
            ),
      footerLabel: '设置',
      onFooterPressed: () => _tools(ToolPanel.settings),
      presentation: presentation,
      expandedWidth: math.max(240, constraints.maxWidth),
      height: math.max(96, constraints.maxHeight),
      labels: const BeautifulSidebarLabels(
        navigation: '工作区导航',
        open: '打开导航',
        close: '关闭导航',
        expand: '展开导航',
        collapse: '折叠导航',
        workspace: '切换工作区',
        newChat: '新建会话',
        chats: '项目任务',
        search: '搜索会话',
        closeSearch: '关闭会话搜索',
        empty: '没有匹配的会话',
        createWorkspace: '新建工作区',
        workspaceSettings: '工作区设置',
        invite: '成员与协作',
        signOut: '账户设置',
        closeWorkspaceMenu: '关闭工作区菜单',
      ),
    ),
  );

  Widget _topBar() {
    final colors = _colors(context);
    final type = BeautifulUiTheme.of(context).typography;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: _compact ? 4 : 16),
        child: Row(
          children: [
            if (_compact)
              _IconAction(
                icon: Icons.menu_rounded,
                label: '打开导航',
                onPressed: () => _scaffold.currentState?.openDrawer(),
              )
            else ...[
              const _BrandMark(size: 24),
              const SizedBox(width: 8),
              Text(
                'ADE',
                style: type.body.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(width: 24),
              Text(
                c.workspaceName,
                style: type.caption.copyWith(color: colors.inkMuted),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: colors.inkSubtle,
                ),
              ),
            ],
            Expanded(
              child: Text(
                c.page == WorkspacePage.chat
                    ? c.current.title
                    : _pageTitle(c.page),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.label.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (!_compact) ...[
              const Tooltip(
                message: '本地交互预览，尚未连接执行内核',
                child: _Badge(label: '预览', icon: Icons.circle_outlined),
              ),
              const SizedBox(width: 8),
            ],
            _IconAction(
              icon: Icons.search_rounded,
              label: '全局搜索',
              onPressed: () => c.navigate(WorkspacePage.search),
            ),
            if (!_compact)
              _IconAction(
                icon: Icons.brightness_6_outlined,
                label: '切换深浅主题',
                onPressed: () => c.setTheme(
                  colors.brightness == Brightness.dark
                      ? BeautifulUiThemeMode.light
                      : BeautifulUiThemeMode.dark,
                ),
              ),
            _IconAction(
              icon: Icons.view_sidebar_outlined,
              label: _hasInspector ? '收起工具面板' : '打开工具面板',
              onPressed: _hasInspector
                  ? () => setState(() => _showInspector = false)
                  : () => _tools(
                      c.panel == ToolPanel.settings ? ToolPanel.changes : null,
                    ),
            ),
            if (!_compact)
              _IconAction(
                icon: Icons.ios_share_rounded,
                label: '分享会话',
                onPressed: () => c.navigate(WorkspacePage.collaboration),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mobileNavigation() {
    final colors = _colors(context);
    return Container(
      key: const Key('mobile-navigation'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          _bottomItem(
            Icons.space_dashboard_outlined,
            '工作台',
            c.page == WorkspacePage.home,
            () => c.navigate(WorkspacePage.home),
          ),
          _bottomItem(
            Icons.chat_bubble_outline_rounded,
            '会话',
            c.page == WorkspacePage.chat || c.page == WorkspacePage.sessions,
            () => c.navigate(WorkspacePage.sessions),
          ),
          _bottomItem(Icons.folder_open_rounded, '工具', false, () => _tools()),
          _bottomItem(
            Icons.settings_outlined,
            '设置',
            false,
            () => _tools(ToolPanel.settings),
          ),
        ],
      ),
    );
  }

  Widget _bottomItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback action,
  ) => Expanded(
    child: Semantics(
      selected: active,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: active
              ? _colors(context).accentInk
              : _colors(context).inkMuted,
          padding: const EdgeInsets.symmetric(vertical: 8),
          minimumSize: const Size(48, 56),
          shape: const RoundedRectangleBorder(),
        ),
        onPressed: action,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );

  Widget _statusBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: _colors(context).line)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.call_split_rounded,
          size: 14,
          color: _colors(context).inkMuted,
        ),
        const SizedBox(width: 4),
        Text(c.current.branch, style: _muted(context)),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            c.workspaceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _muted(context),
          ),
        ),
        const Spacer(),
        Text('本地交互预览', style: _muted(context)),
        const SizedBox(width: 16),
        Icon(
          Icons.check_circle_outline_rounded,
          size: 14,
          color: _colors(context).success,
        ),
      ],
    ),
  );
}

String _pageTitle(WorkspacePage page) => switch (page) {
  WorkspacePage.home => '工作台',
  WorkspacePage.sessions => '所有会话',
  WorkspacePage.search => '全局搜索',
  WorkspacePage.automations => '自动化',
  WorkspacePage.chat => '会话',
  WorkspacePage.runs => '运行记录',
  WorkspacePage.review => 'Git 审阅',
  WorkspacePage.activity => '通知与活动',
  WorkspacePage.account => '账户、用量与权限',
  WorkspacePage.workspaces => '工作区初始化',
  WorkspacePage.connection => '连接与恢复',
  WorkspacePage.collaboration => '分享、导出与协作',
  WorkspacePage.archive => '归档与恢复',
};
