part of 'workbench.dart';

class _ChatPage extends StatelessWidget {
  const _ChatPage({required this.controller, required this.onTools});
  final WorkbenchController controller;
  final void Function([ToolPanel?]) onTools;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (controller.current.id.isEmpty)
        _Empty(
          title: '开始一个新任务',
          detail: '选择工作区，创建会话并预览任务输入。',
          action: FilledButton(
            onPressed: controller.newSession,
            child: const Text('新建会话'),
          ),
        ),
      for (final s in controller.sessions)
        Offstage(
          key: ValueKey(s.id),
          offstage: s.id != controller.selectedSessionId,
          child: TickerMode(
            enabled: s.id == controller.selectedSessionId,
            child: ExcludeFocus(
              excluding: s.id != controller.selectedSessionId,
              child: _Conversation(
                session: s,
                controller: controller,
                onTools: onTools,
              ),
            ),
          ),
        ),
    ],
  );
}

class _Conversation extends StatefulWidget {
  const _Conversation({
    required this.session,
    required this.controller,
    required this.onTools,
  });
  final WorkSession session;
  final WorkbenchController controller;
  final void Function([ToolPanel?]) onTools;
  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  void Function()? _stopDrops;
  final _scroll = ScrollController();
  bool _following = true;
  int _length = 0;
  List<BeautifulPromptAttachment> _dropped = [];
  WorkbenchController get c => widget.controller;
  WorkSession get s => widget.session;
  @override
  void initState() {
    super.initState();
    _stopDrops = listenDrops((name, size) {
      if (c.selectedSessionId != s.id ||
          c.page != WorkspacePage.chat ||
          s.archived) {
        return;
      }
      if (size > 25 * 1024 * 1024) {
        c.storageError = '附件不能超过 25 MiB。';
        c.changed();
        return;
      }
      setState(
        () => _dropped.add(
          BeautifulPromptAttachment(id: c.nextId('attachment'), label: name),
        ),
      );
    });
    _scroll.addListener(() {
      if (_scroll.hasClients) _following = _scroll.position.extentAfter < 100;
    });
  }

  @override
  void didUpdateWidget(_Conversation old) {
    super.didUpdateWidget(old);
    final len = s.messages.fold<int>(0, (a, m) => a + m.text.length);
    if (len != _length) {
      _length = len;
      if (_following) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _stopDrops?.call();
    _scroll.dispose();
    super.dispose();
  }

  Future<List<BeautifulPromptAttachment>> _upload() async {
    final files = await openFiles();
    final result = <BeautifulPromptAttachment>[];
    for (final f in files) {
      if (await f.length() > 25 * 1024 * 1024) {
        throw const FormatException('附件不能超过 25 MiB。');
      }
      result.add(
        BeautifulPromptAttachment(id: c.nextId('attachment'), label: f.name),
      );
    }
    return result;
  }

  List<Widget> _transcript(BuildContext context) {
    final runs = c
        .rows('runs')
        .where((r) => r['sessionId'] == s.id)
        .toList()
        .reversed
        .toList();
    final pending = c
        .rows('approvals')
        .where((a) => a['sessionId'] == s.id && a['status'] == 'pending')
        .toList();
    final placedRuns = <String>{};
    final placedApprovals = <String>{};
    final result = <Widget>[];
    for (final message in s.messages) {
      final attached = runs.where((r) => r['messageId'] == message.id).toList();
      placedRuns.addAll(attached.map((r) => r['id'] as String));
      final approvals = pending
          .where((a) => attached.any((r) => r['id'] == a['runId']))
          .toList();
      placedApprovals.addAll(approvals.map((a) => a['id'] as String));
      final changes = <String>{
        for (final record in attached)
          for (final item in record['items'] ?? [])
            for (final change in item['changes'] ?? [])
              change['path'] as String,
      };
      result.add(
        Padding(
          key: ValueKey('turn-${message.id}'),
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (message.isUser)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 560),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _colors(context).inset,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      message.text,
                      style: BeautifulUiTheme.of(context).typography.body
                          .copyWith(height: 1.7),
                    ),
                  ),
                )
              else
                const _AgentSignature(),
              const SizedBox(height: 12),
              for (final record in attached)
                _RunCard(
                  key: ValueKey(record['id']),
                  run: record,
                  controller: c,
                  inline: true,
                ),
              if (!message.isUser)
                BeautifulStreamingText(
                  id: message.id,
                  quiet: true,
                  density: BeautifulUiDensity.compact,
                  content: [BeautifulStreamingPart.text(message.text)],
                  status: message.streaming
                      ? BeautifulStreamingStatus.streaming
                      : BeautifulStreamingStatus.complete,
                  labels: const BeautifulStreamingLabels(
                    copy: '复制回复',
                    copied: '已复制',
                    copying: '复制中',
                    complete: '回复完成',
                    streaming: '正在回复',
                    failed: '回复中断',
                  ),
                ),
              if (changes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BeautifulButton(
                    label: '查看 ${changes.length} 个文件变更',
                    leading: const Icon(Icons.difference_outlined, size: 14),
                    trailing: const Icon(Icons.arrow_outward_rounded, size: 14),
                    density: BeautifulUiDensity.compact,
                    tone: BeautifulButtonTone.quiet,
                    onPressed: () => widget.onTools(ToolPanel.changes),
                  ),
                ),
              ],
              for (final approval in approvals)
                _Approval(
                  key: ValueKey(approval['id']),
                  approval: approval,
                  controller: c,
                ),
            ],
          ),
        ),
      );
    }
    for (final record in runs.where((r) => !placedRuns.contains(r['id']))) {
      result.add(
        _RunCard(
          key: ValueKey(record['id']),
          run: record,
          controller: c,
          inline: true,
        ),
      );
    }
    for (final approval in pending.where(
      (a) => !placedApprovals.contains(a['id']),
    )) {
      result.add(
        _Approval(
          key: ValueKey(approval['id']),
          approval: approval,
          controller: c,
        ),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final run = c
        .rows('runs')
        .where((r) => r['sessionId'] == s.id && c.active(r))
        .firstOrNull;
    final narrow = MediaQuery.sizeOf(context).width < 800;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 16 : 32, 12, 16, 4),
          child: Row(
            children: [
              Icon(
                Icons.call_split_rounded,
                size: 14,
                color: _colors(context).inkMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.branch.isEmpty ? c.workspaceName : s.branch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _muted(context),
                ),
              ),
              Text(s.status, style: _muted(context)),
              const SizedBox(width: 8),
              _IconAction(
                icon: Icons.ios_share_outlined,
                label: '分享与导出',
                onPressed: () => c.navigate(WorkspacePage.collaboration),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(
              narrow ? 16 : 32,
              24,
              narrow ? 16 : 32,
              24,
            ),
            children:
                [
                      if (s.messages.isEmpty)
                        const _Empty(
                          title: '下一个任务是什么？',
                          detail: '从一个想法、一段代码，或一个待解决的问题开始。',
                          icon: Icons.auto_awesome_outlined,
                        ),
                      ..._transcript(context),
                    ]
                    .map(
                      (child) => Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: SizedBox(width: double.infinity, child: child),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        if (s.archived)
          const Padding(
            padding: EdgeInsets.all(16),
            child: _Notice(text: '此会话已归档，恢复后可继续发送消息。'),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (run != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _status(run['status']),
                              style: _muted(context),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => c.stopRun(run['id']),
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 16,
                            ),
                            label: const Text('停止'),
                          ),
                        ],
                      ),
                    if (_dropped.isNotEmpty)
                      Wrap(
                        children: [
                          for (final a in _dropped)
                            InputChip(
                              label: Text(a.label),
                              onDeleted: () =>
                                  setState(() => _dropped.remove(a)),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.send_outlined, size: 16),
                            label: const Text('发送这些附件'),
                            onPressed: run != null
                                ? null
                                : () async {
                                    await c.send(
                                      BeautifulPromptSubmission(
                                        text: '',
                                        attachments: List.of(_dropped),
                                      ),
                                    );
                                    if (mounted) setState(() => _dropped = []);
                                  },
                          ),
                        ],
                      ),
                    BeautifulPromptBar(
                      key: ValueKey('composer-${s.id}'),
                      density: BeautifulUiDensity.compact,
                      contextHeader: _ComposerContext(
                        controller: c,
                        session: s,
                      ),
                      footerLeading: _PermissionPicker(controller: c),
                      composerId: s.id,
                      initialDraft: c.composerDrafts[s.id] ?? '',
                      onDraftChanged: (text) => c.rememberDraft(s.id, text),
                      placeholder: '继续描述你的想法，@ 添加上下文，/ 选择指令',
                      composerLabel: '会话输入',
                      sendLabel: '发送',
                      sendingLabel: '发送中',
                      addLabel: '添加上下文',
                      attachLabel: '选择本地文件',
                      sourcesLabel: '上下文与文件',
                      removeLabel: '移除',
                      modelsLabel: '选择模型',
                      commandsLabel: '快捷指令',
                      enabled: run == null,
                      onSend: (submission) async {
                        await c.send(
                          BeautifulPromptSubmission(
                            text: submission.text,
                            attachments: [
                              ...submission.attachments,
                              ..._dropped,
                            ],
                          ),
                        );
                        if (mounted) setState(() => _dropped = []);
                      },
                      onAttach: _upload,
                      sources: [
                        for (final entry in c.entries.take(40))
                          BeautifulPromptSource(
                            id: entry['path'],
                            label: entry['path'],
                            description: entry['directory'] ? '工作区目录' : '工作区文件',
                          ),
                      ],
                      commands: const [
                        BeautifulPromptCommand(
                          id: 'plan',
                          label: 'plan',
                          description: '先整理任务计划',
                        ),
                        BeautifulPromptCommand(
                          id: 'review',
                          label: 'review',
                          description: '审阅当前工作区变更',
                        ),
                      ],
                      dictateLabel: '语音',
                      dictatingLabel: '正在聆听',
                      stopDictationLabel: '停止语音输入',
                      models: [
                        for (final m in c.models)
                          BeautifulPromptModel(
                            id: m['model'],
                            label: m['displayName'] ?? m['model'],
                            description: m['description'] ?? '',
                          ),
                      ],
                      selectedModelId: c.model.isEmpty ? null : c.model,
                      onModelChanged: c.setModel,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 12,
                          color: _colors(context).inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text('本地交互预览', style: _muted(context))),
                        if (!narrow)
                          Text(
                            'Enter 发送 · Shift Enter 换行',
                            style: _muted(context),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AgentSignature extends StatelessWidget {
  const _AgentSignature();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(Icons.auto_awesome_rounded, size: 16, color: _colors(context).ink),
      const SizedBox(width: 8),
      Text(
        'ADE',
        style: BeautifulUiTheme.of(context).typography.caption
            .copyWith(fontWeight: FontWeight.w600, color: _colors(context).ink),
      ),
    ],
  );
}

class _ComposerContext extends StatelessWidget {
  const _ComposerContext({required this.controller, this.session});
  final WorkbenchController controller;
  final WorkSession? session;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '切换当前项目',
    onSelected: controller.selectWorkspace,
    itemBuilder: (_) => [
      for (final workspace in controller.workspaces)
        PopupMenuItem(value: workspace['id'], child: Text(workspace['name'])),
    ],
    child: Row(
      children: [
        Icon(
          Icons.folder_open_outlined,
          size: 16,
          color: _colors(context).inkMuted,
        ),
        const SizedBox(width: 8),
        Text(controller.workspaceName, style: _muted(context)),
        Icon(
          Icons.keyboard_arrow_down,
          size: 14,
          color: _colors(context).inkMuted,
        ),
        const Spacer(),
        if (MediaQuery.sizeOf(context).width >= 800 && session != null)
          Flexible(
            child: Text(
              session!.branch,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _muted(context),
            ),
          ),
      ],
    ),
  );
}

class _PermissionPicker extends StatelessWidget {
  const _PermissionPicker({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: '操作权限',
    initialValue: controller.executionMode,
    onSelected: (value) => controller.updatePreferences(mode: value),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'read-only', child: Text('只读 · 查看与分析')),
      PopupMenuItem(value: 'workspace-write', child: Text('工作区写入 · 操作前确认')),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 14,
            color: _colors(context).inkMuted,
          ),
          const SizedBox(width: 4),
          Text(
            controller.executionMode == 'read-only' ? '只读' : '工作区写入',
            style: _muted(context),
          ),
          Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: _colors(context).inkMuted,
          ),
        ],
      ),
    ),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.controller, required this.onTools});
  final WorkbenchController controller;
  final void Function([ToolPanel?]) onTools;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = BeautifulUiTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.symmetric(
          horizontal: constraints.maxWidth < 500 ? 24 : 48,
          vertical: 48,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _BrandMark(size: 32),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '今天，想完成什么？',
                    style: theme.typography.body.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('从一个想法开始，让下一步更清晰。', style: _muted(context)),
                  const SizedBox(height: 32),
                  BeautifulPromptBar(
                    composerId: 'home-draft',
                    density: BeautifulUiDensity.compact,
                    contextHeader: _ComposerContext(controller: c),
                    footerLeading: _PermissionPicker(controller: c),
                    initialDraft: c.composerDrafts['home-draft'] ?? '',
                    onDraftChanged: (text) =>
                        c.rememberDraft('home-draft', text),
                    placeholder: '描述一个任务，@ 添加上下文，/ 选择指令',
                    composerLabel: '新任务输入',
                    sendLabel: '开始',
                    addLabel: '添加上下文',
                    tall: true,
                    onSend: (submission) async {
                      await c.newSession();
                      await c.send(submission);
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      BeautifulButton(
                        label: '构思新任务',
                        leading: const Icon(
                          Icons.auto_awesome_outlined,
                          size: 14,
                        ),
                        density: BeautifulUiDensity.compact,
                        tone: BeautifulButtonTone.quiet,
                        onPressed: c.newSession,
                      ),
                      BeautifulButton(
                        label: '审阅项目',
                        leading: const Icon(
                          Icons.difference_outlined,
                          size: 14,
                        ),
                        density: BeautifulUiDensity.compact,
                        tone: BeautifulButtonTone.quiet,
                        onPressed: () => c.navigate(WorkspacePage.review),
                      ),
                      BeautifulButton(
                        label: '浏览文件',
                        leading: const Icon(
                          Icons.folder_open_outlined,
                          size: 14,
                        ),
                        density: BeautifulUiDensity.compact,
                        tone: BeautifulButtonTone.quiet,
                        onPressed: () => onTools(ToolPanel.files),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _SectionLabel(
                    '最近任务',
                    trailing: BeautifulButton(
                      label: '查看全部',
                      density: BeautifulUiDensity.compact,
                      tone: BeautifulButtonTone.quiet,
                      onPressed: () => c.navigate(WorkspacePage.sessions),
                    ),
                  ),
                  if (c.visibleSessions.isEmpty)
                    const _Empty(title: '你的第一个任务', detail: '任务会保留在这里，随时回来继续。'),
                  for (final session in c.visibleSessions.take(5))
                    _SessionTile(session: session, controller: c),
                  const _SectionLabel('工作区'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final page in [
                        WorkspacePage.runs,
                        WorkspacePage.activity,
                        WorkspacePage.workspaces,
                        WorkspacePage.account,
                        WorkspacePage.connection,
                        WorkspacePage.archive,
                      ])
                        BeautifulButton(
                          label: _pageTitle(page),
                          density: BeautifulUiDensity.compact,
                          tone: BeautifulButtonTone.quiet,
                          onPressed: () => c.navigate(page),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsPage extends StatefulWidget {
  const _SessionsPage({required this.controller});
  final WorkbenchController controller;
  @override
  State<_SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<_SessionsPage> {
  String filter = '全部';
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final list = c.visibleSessions.where(
      (s) => filter == '全部' || s.status == filter,
    );
    return _PageFrame(
      title: '所有会话',
      subtitle: '继续最近的灵感，或开始一段新的对话。',
      action: FilledButton(onPressed: c.newSession, child: const Text('新建会话')),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in ['全部', '运行中', '等待审批', '已完成', '失败', '已暂停'])
              ChoiceChip(
                label: Text(f),
                selected: filter == f,
                onSelected: (_) => setState(() => filter = f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          const _Empty(title: '没有匹配的会话', detail: '更换筛选条件，或开始一个任务。'),
        for (final s in list) _SessionTile(session: s, controller: c),
      ],
    );
  }
}

class _SearchPage extends StatefulWidget {
  const _SearchPage({required this.controller, required this.onTools});
  final WorkbenchController controller;
  final void Function([ToolPanel?]) onTools;
  @override
  State<_SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<_SearchPage> {
  final field = TextEditingController();
  @override
  void dispose() {
    field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final query = field.text.trim().toLowerCase();
    final results = <Json>[
      if (query.length >= 2 && c.workspace == 'design')
        for (final file in c.files.entries)
          if (file.key.toLowerCase().contains(query) ||
              file.value.toString().toLowerCase().contains(query))
            {'path': file.key, 'line': 1, 'text': file.value.toString()},
    ];
    final local = c.sessions.where(
      (s) =>
          query.length >= 2 &&
          s.workspaceId == c.workspace &&
          (s.title.toLowerCase().contains(query) ||
              s.messages.any((m) => m.text.toLowerCase().contains(query))),
    );
    return _PageFrame(
      title: '全局搜索',
      subtitle: '搜索会话、消息和工作区文件。',
      children: [
        TextField(
          controller: field,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: '输入至少两个字符',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        if (query.length >= 2 && local.isEmpty && results.isEmpty)
          const _Empty(title: '没有搜索结果', detail: '尝试其他关键词，或切换工作区。'),
        if (query.length < 2)
          const _Empty(
            title: '找到需要的上下文',
            detail: '按文件路径和内容查看搜索结果示例。',
            icon: Icons.search,
          ),
        for (final s in local) _SessionTile(session: s, controller: c),
        for (final r in results)
          ListTile(
            leading: const Icon(Icons.description_outlined, size: 18),
            title: Text(
              '${r['path']}:${r['line']}',
              style: const TextStyle(fontSize: 13),
            ),
            subtitle: Text(
              r['text'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () async {
              await c.selectFile(r['path']);
              widget.onTools(ToolPanel.files);
            },
          ),
      ],
    );
  }
}

class _AutomationsPage extends StatelessWidget {
  const _AutomationsPage({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final automations = c.automations.where(
      (a) => a.data['workspaceId'] == c.workspace,
    );
    return _PageFrame(
      title: '自动化',
      subtitle: '为重复工作安排一个固定的节奏。',
      action: FilledButton.icon(
        onPressed: () => _automationEditor(context, c),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('新建自动化'),
      ),
      children: [
        if (automations.isEmpty)
          const _Empty(
            title: '让重复工作自动推进',
            detail: '支持每天、每周、间隔、Git 提交后和手动触发。',
            icon: Icons.bolt_outlined,
          ),
        for (final a in automations)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Switch.adaptive(
                        value: a.enabled,
                        onChanged: (v) => c.toggleAutomation(a.id, v),
                      ),
                    ],
                  ),
                  Text(a.schedule, style: _muted(context)),
                  const SizedBox(height: 8),
                  Text(a.prompt),
                  const SizedBox(height: 12),
                  Text(
                    '下次：${_date(a.data['nextAt'])} · 最近：${_status(a.data['lastResult'])}',
                    style: _muted(context),
                  ),
                  if (a.data['lastError'] != null)
                    _Notice(text: a.data['lastError']),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => c.previewAutomation(a),
                        child: const Text('立即运行'),
                      ),
                      TextButton(
                        onPressed: () => _automationEditor(context, c, a),
                        child: const Text('编辑'),
                      ),
                      TextButton(
                        onPressed: () async {
                          if (await _confirm(
                            context,
                            '删除自动化？',
                            '已产生的运行记录会保留。',
                            '删除',
                          )) {
                            await c.deleteAutomation(a.id);
                          }
                        },
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _automationEditor(
  BuildContext context,
  WorkbenchController c, [
  WorkAutomation? automation,
]) => showDialog<void>(
  context: context,
  builder: (_) => _AutomationEditor(controller: c, automation: automation),
);

class _AutomationEditor extends StatefulWidget {
  const _AutomationEditor({required this.controller, this.automation});
  final WorkbenchController controller;
  final WorkAutomation? automation;
  @override
  State<_AutomationEditor> createState() => _AutomationEditorState();
}

class _AutomationEditorState extends State<_AutomationEditor> {
  late final title = TextEditingController(
    text: widget.automation?.title ?? '',
  );
  late final schedule = TextEditingController(
    text: widget.automation?.schedule ?? '每天 09:00',
  );
  late final prompt = TextEditingController(
    text: widget.automation?.prompt ?? '',
  );
  late String execution = widget.automation?.data['execution'] ?? 'auto';
  bool saving = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    schedule.dispose();
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.automation == null ? '新建自动化' : '编辑自动化'),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: '任务名称'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: schedule,
              decoration: const InputDecoration(
                labelText: '触发计划',
                helperText: '每天 09:00 / 周五 17:30 / 每隔 5 分钟\nGit 提交后 / 手动触发',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: prompt,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '任务说明'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: execution,
              decoration: const InputDecoration(
                labelText: '执行权限',
                helperText: '预览执行权限的配置，当前不会执行任务。',
              ),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('只读自动运行')),
                DropdownMenuItem(value: 'review', child: Text('只读逐项审批')),
                DropdownMenuItem(value: 'write', child: Text('工作区写入并审批命令')),
              ],
              onChanged: (v) => setState(() => execution = v ?? 'auto'),
            ),
            if (error != null) _Notice(text: error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  final a = widget.automation;
                  await widget.controller.saveAutomation(
                    id: a?.id,
                    title: title.text,
                    schedule: schedule.text,
                    prompt: prompt.text,
                    execution: execution,
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) setState(() => error = e.toString());
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
        child: Text(saving ? '保存中' : '保存'),
      ),
    ],
  );
}
