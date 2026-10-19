part of 'workbench.dart';

class _ToolPanel extends StatelessWidget {
  const _ToolPanel({required this.controller, this.onClose, this.onExpand});
  final WorkbenchController controller;
  final VoidCallback? onClose;
  final VoidCallback? onExpand;
  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final item in [
                        (ToolPanel.files, Icons.folder_open_outlined, '文件'),
                        (ToolPanel.changes, Icons.difference_outlined, '变更'),
                        (ToolPanel.terminal, Icons.terminal, '终端'),
                        (ToolPanel.browser, Icons.language, '浏览器'),
                        (ToolPanel.settings, Icons.tune, '设置'),
                      ])
                        if (controller.panel == item.$1)
                          BeautifulButton(
                            key: ValueKey('tool-tab-${item.$1.name}'),
                            label: item.$3,
                            leading: Icon(item.$2),
                            selected: true,
                            tone: BeautifulButtonTone.quiet,
                            density: BeautifulUiDensity.compact,
                            onPressed: () => controller.selectPanel(item.$1),
                          )
                        else
                          BeautifulIconButton(
                            key: ValueKey('tool-tab-${item.$1.name}'),
                            label: item.$3,
                            icon: item.$2,
                            density: BeautifulUiDensity.compact,
                            onPressed: () => controller.selectPanel(item.$1),
                          ),
                    ],
                  ),
                ),
              ),
              if (onExpand != null)
                BeautifulIconButton(
                  label: '放大工具面板',
                  icon: Icons.open_in_full,
                  density: BeautifulUiDensity.compact,
                  onPressed: onExpand,
                ),
              BeautifulIconButton(
                label: '分离当前工具窗口',
                icon: Icons.open_in_new,
                density: BeautifulUiDensity.compact,
                onPressed: () => openUrl(
                  Uri.base
                      .replace(queryParameters: {'tool': controller.panel.name})
                      .toString(),
                ),
              ),
              if (onClose != null)
                BeautifulIconButton(
                  label: '关闭工具面板',
                  icon: Icons.close,
                  density: BeautifulUiDensity.compact,
                  onPressed: onClose,
                ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.line),
        Expanded(
          child: switch (controller.panel) {
            ToolPanel.files => _FilesPanel(controller: controller),
            ToolPanel.changes => _GitPanel(controller: controller),
            ToolPanel.terminal => _TerminalPanel(controller: controller),
            ToolPanel.browser => _BrowserPanel(controller: controller),
            ToolPanel.settings => _SettingsPanel(controller: controller),
          },
        ),
      ],
    );
  }
}

class _FilesPanel extends StatefulWidget {
  const _FilesPanel({required this.controller});
  final WorkbenchController controller;
  @override
  State<_FilesPanel> createState() => _FilesPanelState();
}

class _FilesPanelState extends State<_FilesPanel> {
  final editor = TextEditingController();
  String? loadedPath, loadedWorkspace;
  String? lastStashedText;
  bool editing = false, dirty = false;
  WorkbenchController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    editor.addListener(() {
      if (editing) {
        dirty = true;
        stash();
      }
    });
  }

  @override
  void didUpdateWidget(_FilesPanel old) {
    super.didUpdateWidget(old);
    sync();
  }

  void stash() {
    if (dirty && loadedPath != null && editor.text != lastStashedText) {
      c.fileDrafts['$loadedWorkspace:$loadedPath'] = {'text': editor.text};
      lastStashedText = editor.text;
    }
  }

  void sync() {
    if (c.file['path'] != loadedPath || loadedWorkspace != c.workspace) {
      stash();
      editing = false;
      dirty = false;
      loadedPath = c.file['path'];
      loadedWorkspace = c.workspace;
      final draft = c.fileDrafts['$loadedWorkspace:$loadedPath'];
      editor.text = draft?['text'] ?? c.file['text'] ?? '';
      lastStashedText = draft?['text'];
      if (draft != null) {
        editing = true;
        dirty = true;
      }
    } else if (ModalRoute.isCurrentOf(context) ?? true) {
      // A fullscreen work surface can edit the same file while this route is
      // covered. On return, accept its shared draft instead of reviving the
      // hidden editor's older buffer. Unchanged buffers must not overwrite it.
      final draft = c.fileDrafts['$loadedWorkspace:$loadedPath'];
      final text = draft?['text'] as String?;
      if (text != null && text != lastStashedText) {
        editing = false;
        editor.text = text;
        lastStashedText = text;
        editing = true;
        dirty = true;
      } else if (draft == null && dirty) {
        editing = false;
        dirty = false;
        lastStashedText = null;
        editor.text = c.file['text'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    stash();
    editor.dispose();
    super.dispose();
  }

  Future<void> open(String path) async {
    stash();
    await c.selectFile(path);
    if (mounted) setState(sync);
  }

  @override
  Widget build(BuildContext context) {
    // Register for route visibility changes even when the controller snapshot
    // is unchanged after closing an expanded work surface.
    ModalRoute.isCurrentOf(context);
    sync();
    final theme = BeautifulUiTheme.of(context);
    final colors = theme.colors;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Icon(Icons.folder_open_outlined, size: 14, color: colors.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.directory.isEmpty ? c.workspaceName : c.directory,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.caption.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ),
            Text(
              '${c.entries.length}',
              style: theme.typography.caption.copyWith(color: colors.inkSubtle),
            ),
            const SizedBox(width: 4),
            _IconAction(
              label: '刷新文件',
              onPressed: () => c.perform(() => c.loadFiles(c.directory)),
              icon: Icons.refresh,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (c.directory.isNotEmpty)
          _FileTreeRow(
            icon: Icons.arrow_upward,
            name: '上一级',
            onTap: () => c.perform(
              () => c.loadFiles(
                c.directory.contains('/')
                    ? c.directory.substring(0, c.directory.lastIndexOf('/'))
                    : '',
              ),
            ),
          ),
        for (final entry in c.entries)
          _FileTreeRow(
            icon: entry['directory']
                ? Icons.folder_outlined
                : Icons.code_rounded,
            name: entry['name'],
            selected: !entry['directory'] && c.file['path'] == entry['path'],
            directory: entry['directory'],
            onTap: () => entry['directory']
                ? c.perform(() => c.loadFiles(entry['path']))
                : open(entry['path']),
          ),
        if (c.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('此目录中还没有文件', style: _muted(context)),
          ),
        if (c.file.isNotEmpty) ...[
          const SizedBox(height: 24),
          if (c.file['binary'] == true)
            const _Notice(text: '二进制文件无法在文本编辑器中显示。')
          else ...[
            if (editing) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.file['path'],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.label,
                    ),
                  ),
                  const _Badge(label: '编辑中'),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: editor,
                minLines: 12,
                maxLines: 35,
                style: theme.typography.mono.copyWith(color: colors.ink),
                decoration: const InputDecoration(labelText: '编辑文件'),
              ),
            ] else
              BeautifulCodeBlock.code(
                surfaceVariant: BeautifulSurfaceVariant.embedded,
                maxWidth: null,
                density: BeautifulUiDensity.compact,
                filename: c.file['path'],
                code: c.file['text'] ?? '',
                copyLabel: '复制',
                copyingLabel: '复制中',
                copiedLabel: '已复制',
                copyFailedLabel: '复制失败',
                onCopy: (text) => Clipboard.setData(ClipboardData(text: text)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!editing)
                  BeautifulButton(
                    label: '编辑',
                    leading: const Icon(Icons.edit_outlined),
                    density: BeautifulUiDensity.compact,
                    tone: BeautifulButtonTone.quiet,
                    onPressed: () => setState(() {
                      final draft =
                          c.fileDrafts['$loadedWorkspace:$loadedPath'];
                      editor.text = draft?['text'] ?? c.file['text'];
                      lastStashedText = draft?['text'];
                      editing = true;
                      dirty = draft != null;
                    }),
                  )
                else
                  BeautifulButton(
                    label: '保存文件',
                    density: BeautifulUiDensity.compact,
                    tone: BeautifulButtonTone.primary,
                    onPressed: () {
                      c.saveFile(loadedPath!, editor.text);
                      dirty = false;
                      lastStashedText = null;
                      c.fileDrafts.remove('$loadedWorkspace:$loadedPath');
                      setState(() => editing = false);
                    },
                  ),
                BeautifulButton(
                  label: '重新载入',
                  leading: const Icon(Icons.refresh),
                  density: BeautifulUiDensity.compact,
                  tone: BeautifulButtonTone.quiet,
                  onPressed: () async {
                    if (dirty &&
                        !await _confirm(
                          context,
                          '重新载入文件？',
                          '将放弃尚未保存的修改。',
                          '重新载入',
                        )) {
                      return;
                    }
                    dirty = false;
                    lastStashedText = null;
                    c.fileDrafts.remove('$loadedWorkspace:$loadedPath');
                    editing = false;
                    await c.selectFile(loadedPath!);
                    editor.text = c.file['text'] ?? '';
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _FileTreeRow extends StatelessWidget {
  const _FileTreeRow({
    required this.icon,
    required this.name,
    required this.onTap,
    this.selected = false,
    this.directory = false,
  });
  final IconData icon;
  final String name;
  final VoidCallback onTap;
  final bool selected, directory;
  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final colors = theme.colors;
    return BeautifulButton(
      label: name,
      leading: Icon(icon, color: selected ? colors.ink : colors.inkMuted),
      trailing: directory
          ? Icon(Icons.chevron_right, color: colors.inkSubtle)
          : null,
      fullWidth: true,
      alignment: TextAlign.start,
      selected: selected,
      density: BeautifulUiDensity.compact,
      tone: BeautifulButtonTone.quiet,
      onPressed: onTap,
    );
  }
}

class _TerminalPanel extends StatefulWidget {
  const _TerminalPanel({required this.controller});
  final WorkbenchController controller;
  @override
  State<_TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<_TerminalPanel> {
  final input = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final text = input.text;
    if (text.isEmpty) return;
    await widget.controller.terminal('$text\n');
    input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = BeautifulUiTheme.of(context);
    final colors = theme.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(
                c.terminalRunning ? Icons.circle : Icons.circle_outlined,
                size: 8,
                color: c.terminalRunning ? colors.success : colors.inkSubtle,
              ),
              const SizedBox(width: 8),
              Text('终端 · 预览', style: theme.typography.caption),
              const SizedBox(width: 8),
              BeautifulButton(
                label: '新建',
                leading: const Icon(Icons.add),
                tone: BeautifulButtonTone.quiet,
                density: BeautifulUiDensity.compact,
                onPressed: c.openTerminal,
              ),
              _IconAction(
                label: 'Ctrl+C',
                onPressed: c.terminalRunning ? () => c.terminal('\x03') : null,
                icon: Icons.stop_rounded,
              ),
              _IconAction(
                label: '关闭终端',
                onPressed: c.terminalRunning ? c.closeTerminal : null,
                icon: Icons.close,
              ),
              _IconAction(
                label: '记录执行',
                icon: Icons.playlist_add,
                onPressed: () async {
                  final cmd = await _editText(context, '运行并记录命令 · 预览', '');
                  if (cmd != null) {
                    c.previewRun(
                      cmd,
                      sessionId: c.current.id.isEmpty ? null : c.current.id,
                    );
                  }
                },
              ),
              _IconAction(
                label: '运行记录',
                onPressed: () => c.navigate(WorkspacePage.runs),
                icon: Icons.history,
              ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: colors.inset,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              controller: scroll,
              reverse: true,
              child: Align(
                alignment: Alignment.topLeft,
                child: SelectableText(
                  c.terminalOutput.isEmpty
                      ? '点击「新建」开始终端预览。\n命令仅展示在当前页面。'
                      : c.terminalOutput,
                  style: theme.typography.mono.copyWith(
                    color: c.terminalOutput.isEmpty
                        ? colors.inkMuted
                        : colors.ink,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: input,
            onSubmitted: (_) => submit(),
            style: theme.typography.mono,
            decoration: InputDecoration(
              hintText: '输入命令…',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  r'$',
                  style: theme.typography.mono.copyWith(color: colors.inkMuted),
                ),
              ),
              suffixIcon: _IconAction(
                label: '发送终端输入',
                onPressed: submit,
                icon: Icons.keyboard_return,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrowserPanel extends StatefulWidget {
  const _BrowserPanel({required this.controller});
  final WorkbenchController controller;
  @override
  State<_BrowserPanel> createState() => _BrowserPanelState();
}

class _BrowserPanelState extends State<_BrowserPanel> {
  late final input = TextEditingController(text: 'https://example.com');
  String? url;
  String? error;
  bool mobile = true;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void go() {
    final parsed = Uri.tryParse(input.text);
    setState(() {
      if (parsed == null ||
          !['http', 'https'].contains(parsed.scheme) ||
          parsed.host.isEmpty) {
        error = '请输入有效的 HTTP 或 HTTPS 地址。';
        return;
      }
      url = parsed.toString();
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    final colors = theme.colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: input,
          onSubmitted: (_) => go(),
          style: theme.typography.caption,
          decoration: InputDecoration(
            hintText: '输入预览地址',
            prefixIcon: Icon(
              Icons.lock_outline,
              size: 14,
              color: colors.inkMuted,
            ),
            suffixIcon: _IconAction(
              label: '打开预览',
              onPressed: go,
              icon: Icons.arrow_forward,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          _Notice(text: error!, icon: Icons.error_outline),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _DeviceChoice(
              icon: Icons.smartphone_outlined,
              label: '手机',
              selected: mobile,
              onTap: () => setState(() => mobile = true),
            ),
            const SizedBox(width: 4),
            _DeviceChoice(
              icon: Icons.desktop_windows_outlined,
              label: '电脑',
              selected: !mobile,
              onTap: () => setState(() => mobile = false),
            ),
            const Spacer(),
            _IconAction(
              label: '刷新预览',
              onPressed: url == null
                  ? null
                  : () => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('预览已刷新（示例）'))),
              icon: Icons.refresh,
            ),
            _IconAction(
              label: '在独立窗口打开',
              onPressed: url == null ? null : () => openUrl(url!),
              icon: Icons.open_in_new,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: colors.inset,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: mobile ? 240 : 640),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(mobile ? 16 : 8),
                  border: Border.all(color: colors.lineStrong),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: colors.line)),
                      ),
                      child: mobile
                          ? Center(
                              child: Container(
                                width: 48,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colors.lineStrong,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                for (var i = 0; i < 3; i++)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 4),
                                    child: Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: colors.lineStrong,
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    url == null ? '页面预览' : Uri.parse(url!).host,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.typography.caption.copyWith(
                                      color: colors.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    SizedBox(
                      height: mobile ? 320 : 208,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colors.inset,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.language,
                                size: 24,
                                color: colors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              url == null ? '你的页面将在这里呈现' : '页面预览区域',
                              textAlign: TextAlign.center,
                              style: theme.typography.label,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              url == null ? '输入地址，开始检查布局' : '页面内容等待接入',
                              textAlign: TextAlign.center,
                              style: theme.typography.caption.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          mobile ? '移动设备视窗' : '桌面设备视窗',
          textAlign: TextAlign.center,
          style: theme.typography.caption.copyWith(color: colors.inkSubtle),
        ),
      ],
    );
  }
}

class _DeviceChoice extends StatelessWidget {
  const _DeviceChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return BeautifulButton(
      label: label,
      leading: Icon(icon),
      selected: selected,
      density: BeautifulUiDensity.compact,
      tone: BeautifulButtonTone.quiet,
      onPressed: onTap,
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = BeautifulUiTheme.of(context);
    final colors = theme.colors;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SettingsLabel(icon: Icons.contrast, title: '外观'),
        _ToolSettingRow(
          title: '主题',
          control: Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              for (final e in [
                (BeautifulUiThemeMode.light, Icons.light_mode_outlined, '浅色'),
                (BeautifulUiThemeMode.dark, Icons.dark_mode_outlined, '深色'),
                (
                  BeautifulUiThemeMode.system,
                  Icons.settings_brightness_outlined,
                  '系统',
                ),
              ])
                _AppearanceChoice(
                  icon: e.$2,
                  label: e.$3,
                  selected: c.themeMode == e.$1,
                  onTap: () => c.setTheme(e.$1),
                ),
            ],
          ),
        ),
        _SettingToggle(
          title: '较大字号',
          value: c.largeText,
          onChanged: (v) => c.updatePreferences(bigText: v),
        ),
        Divider(height: 20, color: colors.line),
        const _SettingsLabel(icon: Icons.notifications_none, title: '通知'),
        _SettingToggle(
          title: '任务通知',
          detail: '在通知列表保留任务动态',
          value: c.notifications,
          onChanged: (v) => c.updatePreferences(notify: v),
        ),
        Divider(height: 20, color: colors.line),
        const _SettingsLabel(
          icon: Icons.space_dashboard_outlined,
          title: '窗口布局',
        ),
        _SettingToggle(
          title: '专注模式',
          detail: '收起侧栏，让对话保持在中心',
          value: c.focusMode,
          onChanged: (v) => c.setLayout(focus: v),
        ),
        _ToolSettingRow(
          title: '工具面板位置',
          control: Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              for (final d in [
                ('right', Icons.view_sidebar_outlined, '右侧'),
                ('left', Icons.vertical_split_outlined, '左侧'),
                ('bottom', Icons.view_agenda_outlined, '底部'),
              ])
                _DeviceChoice(
                  icon: d.$2,
                  label: d.$3,
                  selected: c.dock == d.$1,
                  onTap: () => c.setLayout(position: d.$1),
                ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BeautifulButton(
            label: '在新窗口打开工作台',
            leading: const Icon(Icons.open_in_new),
            tone: BeautifulButtonTone.quiet,
            density: BeautifulUiDensity.compact,
            onPressed: () => openUrl(Uri.base.replace(query: '').toString()),
          ),
        ),
        Divider(height: 24, color: colors.line),
        const _SettingsLabel(icon: Icons.grid_view_outlined, title: '工作台管理'),
        const SizedBox(height: 8),
        for (final p in [
          (WorkspacePage.account, Icons.person_outline),
          (WorkspacePage.workspaces, Icons.folder_open_outlined),
          (WorkspacePage.connection, Icons.link),
          (WorkspacePage.activity, Icons.notifications_none),
          (WorkspacePage.archive, Icons.archive_outlined),
          (WorkspacePage.collaboration, Icons.people_outline),
        ])
          BeautifulButton(
            label: _pageTitle(p.$1),
            leading: Icon(p.$2, color: colors.inkMuted),
            trailing: Icon(Icons.chevron_right, color: colors.inkSubtle),
            fullWidth: true,
            alignment: TextAlign.start,
            density: BeautifulUiDensity.compact,
            tone: BeautifulButtonTone.quiet,
            onPressed: () => c.navigate(p.$1),
          ),
        Divider(height: 24, color: colors.line),
        const _SettingsLabel(icon: Icons.keyboard_outlined, title: '快捷键'),
        const SizedBox(height: 8),
        for (final shortcut in [
          ('全局搜索', '⌘ / Ctrl K'),
          ('新建会话', '⌘ / Ctrl N'),
          ('发送消息', 'Enter'),
          ('换行', 'Shift Enter'),
          ('关闭面板', 'Esc'),
        ])
          _ToolSettingRow(
            title: shortcut.$1,
            control: Text(
              shortcut.$2,
              textAlign: TextAlign.end,
              style: theme.typography.mono.copyWith(color: colors.inkMuted),
            ),
          ),
        Divider(height: 24, color: colors.line),
        Text('ADE Workbench', style: theme.typography.label),
        const SizedBox(height: 4),
        Text(
          'Beautiful AI UI · 前端预览 0.2.0',
          style: theme.typography.caption.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ToolSettingRow extends StatelessWidget {
  const _ToolSettingRow({required this.title, required this.control});
  final String title;
  final Widget control;
  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: theme.typography.label)),
          const SizedBox(width: 12),
          Flexible(flex: 2, child: control),
        ],
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colors.inkMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.typography.caption.copyWith(
            color: theme.colors.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return BeautifulButton(
      label: label,
      leading: Icon(icon),
      selected: selected,
      density: BeautifulUiDensity.compact,
      tone: BeautifulButtonTone.quiet,
      onPressed: onTap,
    );
  }
}

class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.title,
    required this.value,
    required this.onChanged,
    this.detail,
  });
  final String title;
  final String? detail;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.label),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  style: theme.typography.caption.copyWith(
                    color: theme.colors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}
