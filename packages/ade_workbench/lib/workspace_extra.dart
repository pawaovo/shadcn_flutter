part of 'workbench.dart';

String _date(dynamic seconds) => seconds == null
    ? '—'
    : DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round())
          .toLocal()
          .toString()
          .substring(0, 16);
String _status(dynamic status) => switch (status) {
  'preview' => '交互预览',
  'queued' => '排队中',
  'running' => '运行中',
  'awaitingApproval' => '等待审批',
  'completed' => '已完成',
  'failed' => '失败',
  'interrupted' => '已停止',
  null => '—',
  _ => status.toString(),
};

class _RunCard extends StatefulWidget {
  const _RunCard({
    super.key,
    required this.run,
    required this.controller,
    this.inline = false,
  });
  final bool inline;
  final Json run;
  final WorkbenchController controller;

  @override
  State<_RunCard> createState() => _RunCardState();
}

class _RunCardState extends State<_RunCard> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final controller = widget.controller;
    final colors = _colors(context);
    final isActive = controller.active(run);
    final failed = run['status'] == 'failed';
    final plan = (run['plan'] as List?) ?? const [];
    final changes = <Json>[
      for (final item in run['items'] ?? [])
        for (final change in item['changes'] ?? [])
          Map<String, dynamic>.from(change as Map),
    ];
    final output = (run['output'] as String?) ?? '';
    final command = run['command'] as String?;
    final statusColor = failed
        ? colors.destructive
        : run['status'] == 'completed'
        ? colors.success
        : colors.inkMuted;
    if (widget.inline) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BeautifulToolChips(
          density: BeautifulUiDensity.compact,
          surfaceVariant: BeautifulSurfaceVariant.embedded,
          maxWidth: null,
          headerLabel:
              '${_status(run['status'])} · ${plan.length} 个步骤${changes.isEmpty ? '' : ' · ${changes.length} 个文件'}',
          initiallyExpanded: isActive || failed,
          steps: [
            if (failed && command == null && run['error'] != null)
              BeautifulToolStep(
                id: '${run['id']}-error',
                label: '运行未完成',
                chip: run['error'],
                mono: false,
                status: BeautifulToolStatus.failed,
                statusLabel: '失败',
                details: [BeautifulToolDetailLine(text: output)],
              ),
            for (var i = 0; i < plan.length; i++)
              BeautifulToolStep(
                id: '${run['id']}-plan-$i',
                label: plan[i]['step'],
                chip: '步骤 ${i + 1}',
                kind: BeautifulToolKind.think,
                mono: false,
                status: switch (plan[i]['status']) {
                  'running' => BeautifulToolStatus.running,
                  'failed' => BeautifulToolStatus.failed,
                  'pending' => BeautifulToolStatus.pending,
                  _ => BeautifulToolStatus.complete,
                },
                statusLabel: _status(plan[i]['status']),
              ),
            for (var i = 0; i < changes.length; i++)
              BeautifulToolStep(
                id: '${run['id']}-file-$i',
                label: '更新文件',
                chip: changes[i]['path'],
                kind: BeautifulToolKind.write,
                statusLabel: '已完成',
              ),
            if (command != null)
              BeautifulToolStep(
                id: '${run['id']}-output',
                label: '运行命令',
                chip: command,
                status: failed
                    ? BeautifulToolStatus.failed
                    : isActive
                    ? BeautifulToolStatus.running
                    : BeautifulToolStatus.complete,
                statusLabel: _status(run['status']),
                details: [
                  for (final line in output.split('\n'))
                    BeautifulToolDetailLine(text: line),
                ],
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.inset,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : run['status'] == 'completed'
                        ? Icons.check_rounded
                        : Icons.bolt_rounded,
                    color: statusColor,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        run['title'] ?? '任务',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_status(run['status'])}  ·  ${_date(run['created'])}',
                        style: _muted(context),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: expanded ? '收起任务' : '展开任务',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => expanded = !expanded),
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              if (run['error'] != null) ...[
                const SizedBox(height: 14),
                _Notice(text: run['error'], icon: Icons.error_outline_rounded),
              ],
              if (plan.isNotEmpty) ...[
                const SizedBox(height: 16),
                BeautifulTaskRows(
                  density: BeautifulUiDensity.compact,
                  surfaceVariant: BeautifulSurfaceVariant.embedded,
                  maxWidth: null,
                  variant: BeautifulTaskRowsVariant.list,
                  rows: [
                    for (var i = 0; i < plan.length; i++)
                      BeautifulTaskRow(
                        id: '${run['id']}-plan-$i',
                        step: i + 1,
                        amountLabel: '',
                        label: plan[i]['step'],
                        status: switch (plan[i]['status']) {
                          'completed' => BeautifulTaskStatus.completed,
                          'running' => BeautifulTaskStatus.running,
                          'failed' => BeautifulTaskStatus.failed,
                          _ => BeautifulTaskStatus.pending,
                        },
                        statusLabel: _status(plan[i]['status']),
                      ),
                  ],
                  pendingLabel: '待处理',
                  runningLabel: '进行中',
                  completedLabel: '已完成',
                  failedLabel: '失败',
                  retryLabel: '重试',
                  retryingLabel: '重试中',
                  stepLabel: '步骤',
                ),
              ],
              if (changes.isNotEmpty || command != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: double.infinity,
                    child: BeautifulToolChips(
                      density: BeautifulUiDensity.compact,
                      surfaceVariant: BeautifulSurfaceVariant.embedded,
                      maxWidth: null,
                      headerLabel: changes.isEmpty
                          ? '运行详情'
                          : '${changes.length} 个文件变更',
                      showMoreLabel: '展开更多文件',
                      showLessLabel: '收起文件',
                      steps: [
                        for (var i = 0; i < changes.length; i++)
                          BeautifulToolStep(
                            id: '${run['id']}-file-$i',
                            label: '更新文件',
                            chip: changes[i]['path'],
                            kind: BeautifulToolKind.write,
                            statusLabel: '已完成',
                          ),
                        if (command != null)
                          BeautifulToolStep(
                            id: '${run['id']}-output',
                            label: '运行命令',
                            chip: command,
                            mono: true,
                            status: failed
                                ? BeautifulToolStatus.failed
                                : isActive
                                ? BeautifulToolStatus.running
                                : BeautifulToolStatus.complete,
                            statusLabel: _status(run['status']),
                            details: [
                              for (final line in output.split('\n'))
                                BeautifulToolDetailLine(text: line),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (output.isNotEmpty && command == null) ...[
                const SizedBox(height: 12),
                Text(output, style: _muted(context)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (run['sessionId'] != null)
                    TextButton.icon(
                      onPressed: () =>
                          controller.selectSession(run['sessionId']),
                      icon: const Icon(Icons.arrow_outward_rounded, size: 14),
                      label: const Text('打开会话'),
                    ),
                  for (final change in changes)
                    TextButton.icon(
                      onPressed: () => controller.selectFile(change['path']),
                      icon: const Icon(Icons.description_outlined, size: 14),
                      label: const Text('查看文件'),
                    ),
                  TextButton.icon(
                    onPressed: isActive
                        ? () => controller.stopRun(run['id'])
                        : () => controller.previewRun(
                            run['title'],
                            sessionId: run['sessionId'],
                          ),
                    icon: Icon(
                      isActive ? Icons.stop_rounded : Icons.replay_rounded,
                      size: 14,
                    ),
                    label: Text(isActive ? '停止运行' : '重新运行'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Approval extends StatelessWidget {
  const _Approval({
    super.key,
    required this.approval,
    required this.controller,
  });
  final Json approval;
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeading(
            title: '需要你的确认',
            subtitle: '检查操作范围后，选择是否继续。',
            trailing: Icon(Icons.shield_outlined, size: 18),
          ),
          const SizedBox(height: 16),
          BeautifulCodeBlock.code(
            density: BeautifulUiDensity.compact,
            surfaceVariant: BeautifulSurfaceVariant.embedded,
            maxWidth: null,
            filename: approval['cwd'] ?? '工作区',
            code: approval['command'] ?? '等待操作信息',
            copyLabel: '复制',
            copyingLabel: '复制中',
            copiedLabel: '已复制',
            copyFailedLabel: '重试复制',
          ),
          if (approval['reason'] != null) ...[
            const SizedBox(height: 10),
            Text(approval['reason'], style: _muted(context)),
          ],
          const SizedBox(height: 16),
          BeautifulApprovalCard(
            id: approval['id'],
            autoAdvance: false,
            questions: [
              BeautifulApprovalQuestion(
                id: 'decision',
                title: '允许此操作吗？',
                allowCustomAnswer: false,
                options: const [
                  BeautifulApprovalOption(id: 'accept', label: '本次允许'),
                  BeautifulApprovalOption(id: 'decline', label: '拒绝'),
                  BeautifulApprovalOption(id: 'cancel', label: '取消当前任务'),
                ],
              ),
            ],
            onSubmit: (answers) async => controller.answerApproval(
              approval['id'],
              answers.single.optionIds.single,
            ),
            sendLabel: '提交',
            sentLabel: '已处理',
            skipLabel: '稍后',
            resetLabel: '重新选择',
            continueLabel: '继续',
            previousLabel: '上一项',
            nextLabel: '下一项',
            openLabel: '打开审批',
            dismissLabel: '收起审批',
          ),
        ],
      ),
    ),
  );
}

class _RunsPage extends StatelessWidget {
  const _RunsPage({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: '运行记录',
    subtitle: '计划、执行过程与任务结果，都有迹可循。',
    children: [
      for (final a
          in controller
              .rows('approvals')
              .where(
                (a) =>
                    a['status'] == 'pending' &&
                    controller.sessions.any(
                      (s) =>
                          s.id == a['sessionId'] &&
                          s.workspaceId == controller.workspace,
                    ),
              ))
        _Approval(key: ValueKey(a['id']), approval: a, controller: controller),
      if (controller
          .rows('runs')
          .where((r) => r['workspaceId'] == controller.workspace)
          .isEmpty)
        const _Empty(title: '暂无运行记录', detail: '接入内核后，在这里查看任务进度与执行结果。'),
      for (final r
          in controller
              .rows('runs')
              .where((r) => r['workspaceId'] == controller.workspace))
        _RunCard(key: ValueKey(r['id']), run: r, controller: controller),
    ],
  );
}

class _ActivityPage extends StatelessWidget {
  const _ActivityPage({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: '通知与活动',
    subtitle: '${controller.unread} 条未读通知',
    action: TextButton(
      onPressed: controller.markRead,
      child: const Text('全部标为已读'),
    ),
    children: [
      if (controller.rows('notifications').isEmpty)
        const _Empty(title: '暂无通知', detail: '任务完成、失败或需要审批时会显示通知。'),
      for (final n in controller.rows('notifications'))
        ListTile(
          leading: Icon(
            n['read'] == true
                ? Icons.notifications_none
                : Icons.notifications_active_outlined,
            size: 20,
          ),
          title: Text(n['title']),
          subtitle: Text('${n['detail']}\n${_date(n['created'])}'),
          onTap: () {
            controller.markRead(n['id']);
            if (n['sessionId'] != null) {
              controller.selectSession(n['sessionId']);
            }
          },
        ),
    ],
  );
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: '账户与权限',
    subtitle: '管理你的偏好、用量和工作区权限。',
    children: [
      const _Surface(
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              child: Icon(Icons.person_outline_rounded, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _PanelHeading(title: '预览用户', subtitle: '连接账户后同步个人信息'),
            ),
            _Badge(label: '未连接'),
          ],
        ),
      ),
      const _SectionLabel('执行权限'),
      DropdownButtonFormField<String>(
        key: ValueKey(controller.executionMode),
        initialValue: controller.executionMode,
        decoration: const InputDecoration(labelText: '操作权限'),
        items: const [
          DropdownMenuItem(value: 'read-only', child: Text('只读 · 分析与审阅')),
          DropdownMenuItem(
            value: 'workspace-write',
            child: Text('工作区写入 · 修改项目'),
          ),
        ],
        onChanged: (v) => controller.updatePreferences(mode: v),
      ),
      const _SectionLabel('默认模型'),
      DropdownButtonFormField<String>(
        key: ValueKey(controller.model),
        initialValue: controller.model,
        items: [
          for (final m in controller.models)
            DropdownMenuItem(
              value: m['model'] as String,
              child: Text(m['displayName']),
            ),
        ],
        onChanged: (v) {
          if (v != null) controller.setModel(v);
        },
      ),
      const _SectionLabel('账户额度'),
      const _Surface(
        child: _PanelHeading(title: '暂无用量数据', subtitle: '连接账户后查看额度与重置时间。'),
      ),
      const _SectionLabel('工作区规则与 Skills'),
      const _Empty(
        title: '规则展示区域',
        detail: '连接项目后，在这里查看工作区规则和可用技能。',
        icon: Icons.extension_outlined,
      ),
    ],
  );
}

class _WorkspacesPage extends StatelessWidget {
  const _WorkspacesPage({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: '工作区',
    subtitle: '选择一个项目，开始你的下一项工作。',
    action: FilledButton.icon(
      onPressed: () async {
        final path = await _editText(context, '连接现有项目 · 路径预览', '');
        if (path != null) controller.addWorkspace(path);
      },
      icon: const Icon(Icons.add, size: 18),
      label: const Text('连接目录'),
    ),
    children: [
      for (final w in controller.workspaces)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Surface(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_open_outlined, size: 20),
              title: Text(w['name']),
              subtitle: Text(
                w['path'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () => controller.selectWorkspace(w['id']),
                child: Text(controller.workspace == w['id'] ? '当前工作区' : '打开'),
              ),
            ),
          ),
        ),
      const _SectionLabel('导入仓库'),
      OutlinedButton(
        onPressed: () async {
          final url = await _editText(
            context,
            'GitHub 仓库地址',
            'https://github.com/',
          );
          if (url == null || !context.mounted) return;
          final parsed = Uri.tryParse(url);
          if (parsed == null ||
              parsed.scheme != 'https' ||
              parsed.host != 'github.com' ||
              parsed.pathSegments.where((s) => s.isNotEmpty).length != 2) {
            controller.storageError = '请输入完整的 GitHub 仓库地址。';
            controller.changed();
            return;
          }
          final name = await _editText(
            context,
            '项目名称',
            parsed.pathSegments.last.replaceFirst(RegExp(r'\.git$'), ''),
          );
          if (name != null) controller.addWorkspace(url, name: name);
        },
        child: const Text('克隆 GitHub 仓库'),
      ),
      const SizedBox(height: 12),
      const _Notice(text: '当前为页面预览，导入操作会保存在此工作区列表。'),
      const _SectionLabel('初始化检查'),
      const ListTile(
        leading: Icon(Icons.hourglass_empty, size: 20),
        title: Text('等待连接内核'),
        subtitle: Text('连接后检查项目、Git 和运行环境。'),
      ),
      TextButton.icon(
        onPressed: () => controller.selectPanel(ToolPanel.terminal),
        icon: const Icon(Icons.terminal, size: 18),
        label: const Text('打开终端'),
      ),
    ],
  );
}

class _ConnectionPage extends StatelessWidget {
  const _ConnectionPage({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) => _PageFrame(
    title: '连接与恢复',
    subtitle: '切换查看连接状态的页面效果。',
    action: FilledButton.icon(
      onPressed: () {
        controller.connectionPreview = '等待连接';
        controller.changed();
      },
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('重新连接'),
    ),
    children: [
      _Notice(text: '${controller.connectionPreview} · 页面预览'),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final status in ['未连接', '等待连接', '连接中断', '已连接'])
            ChoiceChip(
              label: Text(status),
              selected: controller.connectionPreview == status,
              onSelected: (_) {
                controller.connectionPreview = status;
                controller.changed();
              },
            ),
        ],
      ),
      const _SectionLabel('恢复提示'),
      Text(
        controller.connectionPreview == '连接中断'
            ? '连接已中断。草稿仍保留，可重新连接后继续。'
            : '会话、草稿和工具面板可以在当前页面中继续切换。',
      ),
    ],
  );
}

class _ArchivePage extends StatelessWidget {
  const _ArchivePage({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final archived = c.sessions.where(
      (s) => s.archived && s.workspaceId == c.workspace,
    );
    return _PageFrame(
      title: '归档与恢复',
      subtitle: '收好已完成的讨论，也能随时继续。',
      children: [
        if (archived.isEmpty)
          const _Empty(title: '没有归档会话', detail: '从会话菜单归档后，会显示在这里。'),
        for (final s in archived)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Surface(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _SessionTile(session: s, controller: c),
                  OverflowBar(
                    children: [
                      TextButton(
                        onPressed: () => c.archiveSession(s.id, false),
                        child: const Text('恢复会话'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final confirm = await _editText(
                            context,
                            '输入 DELETE 永久删除',
                            '',
                          );
                          if (confirm != null) {
                            await c.deleteSession(s.id, confirm);
                          }
                        },
                        child: const Text('永久删除'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const _SectionLabel('文件快照'),
        Text('保存当前变更，之后可以回到这个状态。', style: _muted(context)),
        TextButton(onPressed: c.saveSnapshot, child: const Text('保存当前变更快照')),
        for (final cp
            in c
                .rows('checkpoints')
                .where((p) => p['workspaceId'] == c.workspace))
          ListTile(
            title: Text(cp['label']),
            subtitle: Text('${_date(cp['created'])} · ${cp['count']} 个文件'),
            onTap: () async {
              if (await _confirm(
                    context,
                    '恢复文件快照？',
                    '确认流程预览，不会覆盖项目文件。',
                    '恢复',
                  ) &&
                  context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('恢复操作已预览，等待接入内核。')),
                );
              }
            },
          ),
      ],
    );
  }
}

class _CollaborationPage extends StatefulWidget {
  const _CollaborationPage({required this.controller});
  final WorkbenchController controller;
  @override
  State<_CollaborationPage> createState() => _CollaborationPageState();
}

class _CollaborationPageState extends State<_CollaborationPage> {
  String scope = '可查看';
  int days = 7;
  final comment = TextEditingController();
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final session = c.current;
    if (session.id.isEmpty) {
      return const _Empty(title: '先选择一条会话', detail: '选择会话后，可以预览分享、导出和讨论。');
    }
    return _PageFrame(
      title: '分享、导出与协作',
      subtitle: session.title,
      children: [
        const _Notice(text: '分享链接和评论仅作页面预览。'),
        const _SectionLabel('生成共享链接'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in ['可查看', '可评论', '可编辑笔记'])
              ChoiceChip(
                label: Text(s),
                selected: scope == s,
                onSelected: (_) => setState(() => scope = s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: days,
          decoration: const InputDecoration(labelText: '链接有效期'),
          items: [
            for (final d in [1, 7, 30])
              DropdownMenuItem(value: d, child: Text('$d 天')),
          ],
          onChanged: (v) => setState(() => days = v ?? 7),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () {
              c.rows('shares').add({
                'id': c.nextId('preview'),
                'sessionId': session.id,
                'scope': scope,
                'expiresAt':
                    DateTime.now().millisecondsSinceEpoch / 1000 + days * 86400,
                'revoked': false,
              });
              c.changed();
            },
            child: const Text('创建链接'),
          ),
        ),
        for (final share
            in c.rows('shares').where((s) => s['sessionId'] == session.id))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: SelectableText(
              'https://ade.example/share/${share['id']}',
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(
              '${share['scope']} · ${_date(share['expiresAt'])} 到期${share['revoked'] == true ? ' · 已撤销' : ''}',
            ),
            trailing: share['revoked'] == true
                ? null
                : PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'copy') {
                        await Clipboard.setData(
                          ClipboardData(
                            text: 'https://ade.example/share/${share['id']}',
                          ),
                        );
                      } else if (v == 'open') {
                        if (context.mounted) {
                          await _openLink(
                            context,
                            c,
                            'https://ade.example/share/${share['id']}',
                          );
                        }
                      } else {
                        share['revoked'] = true;
                        c.changed();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'copy', child: Text('复制链接')),
                      PopupMenuItem(value: 'open', child: Text('打开')),
                      PopupMenuItem(value: 'revoke', child: Text('撤销链接')),
                    ],
                  ),
          ),
        const _SectionLabel('导出会话'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _ExportImageDialog(session: session),
              ),
              child: const Text('PNG 长图'),
            ),
            for (final fmt in ['json', 'txt', 'html'])
              OutlinedButton(
                onPressed: () => c.perform(() async {
                  downloadBytes(
                    _exportSession(session, fmt),
                    'ade-session.$fmt',
                    fmt == 'html'
                        ? 'text/html'
                        : fmt == 'json'
                        ? 'application/json'
                        : 'text/plain',
                  );
                }),
                child: Text(fmt.toUpperCase()),
              ),
            OutlinedButton(
              onPressed: () => c.perform(() async {
                openHtmlDocument(
                  _exportSession(session, 'html', forPrinting: true),
                );
              }),
              child: const Text('打印 / 保存 PDF'),
            ),
          ],
        ),
        const _SectionLabel('讨论'),
        if (c
            .rows('comments')
            .where((i) => i['sessionId'] == session.id)
            .isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('暂无讨论。'),
          ),
        for (final item
            in c.rows('comments').where((i) => i['sessionId'] == session.id))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item['resolved'] == true
                  ? Icons.check_circle_outline
                  : Icons.chat_bubble_outline,
              size: 18,
            ),
            title: Text(item['text']),
            subtitle: Text(
              '${item['author']} · ${_date(item['created'])}${item['path'] == null ? '' : ' · ${item['path']}:${item['line'] ?? ''}'}',
            ),
            trailing: IconButton(
              tooltip: item['resolved'] == true ? '重新打开讨论' : '标记已解决',
              icon: Icon(
                item['resolved'] == true ? Icons.undo : Icons.done,
                size: 18,
              ),
              onPressed: () {
                item['resolved'] = item['resolved'] != true;
                c.changed();
              },
            ),
          ),
        TextField(
          controller: comment,
          maxLines: 3,
          decoration: const InputDecoration(labelText: '添加评论'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              c.addComment(comment.text);
              comment.clear();
            },
            child: const Text('发表评论'),
          ),
        ),
        const _SectionLabel('协作活动'),
        const Text('连接协作服务后显示成员与访问记录。'),
      ],
    );
  }
}

Uint8List _exportSession(
  WorkSession session,
  String format, {
  bool forPrinting = false,
}) {
  final messages = [
    for (final m in session.messages)
      {'author': m.isUser ? '你' : 'ADE', 'text': m.text},
  ];
  if (format == 'json') {
    return Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent('  ')
            .convert({'title': session.title, 'messages': messages}),
      ),
    );
  }
  if (format == 'txt') {
    return Uint8List.fromList(
      utf8.encode(
        '${session.title}\n\n${messages.map((m) => '${m['author']}\n${m['text']}').join('\n\n')}',
      ),
    );
  }
  const escape = HtmlEscape();
  return Uint8List.fromList(
    utf8.encode(
      '<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>${escape.convert(session.title)}</title><style>body{max-width:800px;margin:40px auto;padding:24px;font:16px/1.7 sans-serif}pre{white-space:pre-wrap;overflow-wrap:anywhere}</style><h1>${escape.convert(session.title)}</h1>${messages.map((m) => '<h2>${m['author']}</h2><pre>${escape.convert(m['text']!)}</pre>').join()}${forPrinting ? '<script>window.onload=()=>window.print()</script>' : ''}</html>',
    ),
  );
}

class _ReviewPage extends StatelessWidget {
  const _ReviewPage({required this.controller});
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) =>
      _GitPanel(controller: controller, full: true);
}

class _GitPanel extends StatefulWidget {
  const _GitPanel({required this.controller, this.full = false});
  final WorkbenchController controller;
  final bool full;
  @override
  State<_GitPanel> createState() => _GitPanelState();
}

class _GitPanelState extends State<_GitPanel> {
  WorkbenchController get c => widget.controller;
  Json get _view => c.reviewViews.putIfAbsent(c.workspace, () => {});
  String? get path => _view['path'] as String?;
  set path(String? value) => _view['path'] = value;
  String get tab => _view['tab'] as String? ?? '变更';
  set tab(String value) => _view['tab'] = value;

  void notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> commit(List files, List<Json> commits) async {
    final message = await _editText(context, '提交已暂存的更改 · 预览', '');
    if (message == null || message.trim().isEmpty) return;
    commits.insert(0, {
      'sha': 'preview',
      'subject': message,
      'author': '预览用户',
      'date': '当前预览',
    });
    for (final file in files) {
      file['staged'] = false;
    }
    c.changed();
    if (mounted) notice('提交已加入页面预览。');
  }

  Future<void> addLineComment(String selected) async {
    final line = await _editText(context, '评论的行号', '1');
    if (line == null || !mounted) return;
    final number = int.tryParse(line);
    if (number == null || number < 1) {
      notice('请输入有效行号。');
      return;
    }
    final text = await _editText(context, '添加行评论', '');
    if (text != null) c.addComment(text, path: selected, line: number);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final files = c.workspace == 'design' ? c.git['files'] as List : const [];
    final branches = c.workspace == 'design'
        ? c.rows('previewBranches')
        : <Json>[];
    final commits = c.workspace == 'design'
        ? c.rows('previewCommits')
        : <Json>[];
    final prs = c.workspace == 'design' ? c.rows('previewPrs') : <Json>[];
    final selected = files.isEmpty
        ? null
        : files.any((file) => file['path'] == path)
        ? path
        : files.first['path'] as String;
    final staged = files.where((file) => file['staged'] == true).length;
    final content = <Widget>[
      _Surface(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.account_tree_outlined, size: 16, color: colors.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                c.workspace == 'design' ? c.git['branch'] : '等待项目连接',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _Badge(label: '${files.length} 个变更'),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final name in ['变更', '分支', '提交', 'PR / 检查'])
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: tab == name
                    ? colors.inset
                    : Colors.transparent,
                foregroundColor: tab == name ? colors.ink : colors.inkMuted,
                textStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: tab == name ? FontWeight.w600 : FontWeight.w400,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                tab = name;
                c.changed();
              },
              child: Text(name),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (tab == '变更') ...[
        if (files.isEmpty)
          const _Empty(
            title: '工作区没有变更',
            detail: '连接项目后查看文件差异。',
            icon: Icons.check_circle_outline,
          ),
        if (files.isNotEmpty) ...[
          _PanelHeading(
            title: '工作区文件',
            subtitle: '$staged 个已暂存',
            trailing: TextButton(
              onPressed: () {
                for (final file in files) {
                  file['staged'] = staged != files.length;
                }
                c.changed();
              },
              child: Text(staged == files.length ? '取消暂存' : '全部暂存'),
            ),
          ),
          const SizedBox(height: 8),
          _Surface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < files.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.lineSoft),
                  _GitFileRow(
                    path: files[i]['path'],
                    selected: selected == files[i]['path'],
                    staged: files[i]['staged'] == true,
                    onSelected: () {
                      path = files[i]['path'];
                      c.changed();
                    },
                    onStaged: (value) {
                      files[i]['staged'] = value;
                      c.changed();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (selected != null) ...[
            BeautifulCodeBlock.diff(
              density: BeautifulUiDensity.compact,
              surfaceVariant: BeautifulSurfaceVariant.embedded,
              maxWidth: null,
              key: ValueKey(selected),
              filename: selected,
              lines: _previewDiff(selected),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => c.selectFile(selected),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('打开文件编辑'),
                ),
                TextButton.icon(
                  onPressed: c.current.id.isEmpty
                      ? null
                      : () => addLineComment(selected),
                  icon: const Icon(Icons.add_comment_outlined, size: 14),
                  label: const Text('添加行评论'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Divider(height: 1, color: colors.line),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: staged == 0 ? null : () => commit(files, commits),
                icon: const Icon(Icons.check_rounded, size: 15),
                label: Text(staged == 0 ? '提交更改' : '提交 $staged 个文件'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  if (await _confirm(
                        context,
                        '推送当前分支？',
                        '预览确认流程，等待连接 Git。',
                        '推送',
                      ) &&
                      mounted) {
                    notice('推送操作已预览。');
                  }
                },
                icon: const Icon(Icons.north_rounded, size: 15),
                label: const Text('推送'),
              ),
              TextButton(
                onPressed: () => c.navigate(WorkspacePage.archive),
                child: const Text('文件快照'),
              ),
            ],
          ),
        ],
      ] else if (tab == '分支') ...[
        _PanelHeading(
          title: '本地分支',
          subtitle: '${branches.length} 个分支',
          trailing: IconButton(
            tooltip: '新建分支',
            icon: const Icon(Icons.add_rounded, size: 18),
            onPressed: c.workspace != 'design'
                ? null
                : () async {
                    final name = await _editText(context, '新建分支', 'codex/');
                    if (name != null &&
                        name.trim().isNotEmpty &&
                        !branches.any((branch) => branch['name'] == name)) {
                      branches.add({'name': name, 'current': false});
                      c.changed();
                    }
                  },
          ),
        ),
        const SizedBox(height: 12),
        if (branches.isEmpty) const _Empty(title: '暂无分支', detail: '连接项目后查看分支。'),
        if (branches.isNotEmpty)
          _Surface(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < branches.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.lineSoft),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.account_tree_outlined,
                      size: 16,
                      color: colors.inkMuted,
                    ),
                    title: Text(
                      branches[i]['name'],
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: branches[i]['current'] == true
                        ? Text('当前分支', style: _muted(context))
                        : null,
                    trailing: branches[i]['current'] == true
                        ? Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: colors.success,
                          )
                        : PopupMenuButton<String>(
                            tooltip: '分支操作',
                            onSelected: (value) async {
                              final branch = branches[i];
                              if (await _confirm(
                                context,
                                '${value == 'switch' ? '切换到' : '合并'} ${branch['name']}？',
                                '分支操作的页面预览。',
                                '继续',
                              )) {
                                if (value == 'switch') {
                                  for (final item in branches) {
                                    item['current'] = item == branch;
                                  }
                                  c.git['branch'] = branch['name'];
                                  c.changed();
                                }
                                if (mounted) notice('分支操作已预览。');
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'switch', child: Text('切换')),
                              PopupMenuItem(
                                value: 'merge',
                                child: Text('合并到当前分支'),
                              ),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
      ] else if (tab == '提交') ...[
        _PanelHeading(title: '提交历史', subtitle: '${commits.length} 条记录'),
        const SizedBox(height: 12),
        if (commits.isEmpty)
          const _Empty(title: '暂无提交记录', detail: '暂存文件后，可以预览提交流程。'),
        for (final item in commits)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Surface(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.commit_rounded, size: 18, color: colors.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['subject'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${item['author']} · ${item['date']}',
                          style: _muted(context),
                        ),
                        const SizedBox(height: 6),
                        _Badge(label: item['sha'], icon: Icons.tag_rounded),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ] else ...[
        _PanelHeading(
          title: 'Pull requests',
          subtitle: '${prs.length} 个请求',
          trailing: IconButton(
            tooltip: '创建草稿 PR',
            icon: const Icon(Icons.add_rounded, size: 18),
            onPressed: c.workspace != 'design'
                ? null
                : () async {
                    final title = await _editText(context, '新建草稿 PR · 标题', '');
                    if (title == null ||
                        title.trim().isEmpty ||
                        !context.mounted) {
                      return;
                    }
                    final base = await _editText(context, '目标分支', 'main');
                    if (base == null || base.trim().isEmpty) return;
                    prs.add({
                      'number': prs.length + 1,
                      'title': title,
                      'headRefName': c.git['branch'],
                      'mergeable': '等待检查',
                      'base': base,
                      'isDraft': true,
                      'url': 'https://ade.example/pr',
                    });
                    c.changed();
                  },
          ),
        ),
        const SizedBox(height: 12),
        if (prs.isEmpty)
          const _Empty(title: '暂无 Pull request', detail: '为当前分支创建一个草稿请求。'),
        for (final pr in prs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Surface(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.merge_rounded,
                        size: 18,
                        color: colors.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '#${pr['number']} ${pr['title']}',
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (pr['isDraft'] == true) const _Badge(label: '草稿'),
                      _Badge(label: pr['headRefName']),
                      const Icon(Icons.arrow_forward_rounded, size: 14),
                      _Badge(label: pr['base'] ?? 'main'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: colors.lineSoft),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 15,
                        color: colors.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(child: Text('检查结果等待接入', style: _muted(context))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openLink(context, c, pr['url']),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('在 GitHub 打开'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ];
    return widget.full
        ? _PageFrame(
            title: 'Git 审阅',
            subtitle: '查看文件差异，整理每一次更改。',
            children: content,
          )
        : ListView(padding: const EdgeInsets.all(16), children: content);
  }
}

class _GitFileRow extends StatelessWidget {
  const _GitFileRow({
    required this.path,
    required this.selected,
    required this.staged,
    required this.onSelected,
    required this.onStaged,
  });
  final String path;
  final bool selected;
  final bool staged;
  final VoidCallback onSelected;
  final ValueChanged<bool> onStaged;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    return Material(
      color: selected ? colors.inset : colors.surface,
      child: InkWell(
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.only(left: 2, right: 10),
          child: Row(
            children: [
              Checkbox(
                value: staged,
                semanticLabel: '暂存 $path',
                onChanged: (value) => onStaged(value ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        path.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: colors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'M',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.warning,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<BeautifulDiffLine> _previewDiff(String path) {
  final composer = path.endsWith('composer.dart');
  return [
    BeautifulDiffLine(
      oldLineNumber: 1,
      newLineNumber: 1,
      kind: BeautifulDiffLineKind.context,
      pieces: [
        BeautifulCodePiece(
          text: composer ? '// 消息输入区示例' : 'Widget buildWorkspace() {',
        ),
      ],
    ),
    BeautifulDiffLine(
      oldLineNumber: 2,
      kind: BeautifulDiffLineKind.removed,
      pieces: [
        BeautifulCodePiece(
          text: composer ? '// 输入和发送状态' : '  return Workspace();',
        ),
      ],
    ),
    BeautifulDiffLine(
      newLineNumber: 2,
      kind: BeautifulDiffLineKind.added,
      pieces: [
        BeautifulCodePiece(
          text: composer
              ? '// 输入、附件和发送状态的展示区域。'
              : '  return ResponsiveWorkbench();',
        ),
      ],
    ),
    if (!composer)
      const BeautifulDiffLine(
        oldLineNumber: 3,
        newLineNumber: 3,
        kind: BeautifulDiffLineKind.context,
        pieces: [BeautifulCodePiece(text: '}')],
      ),
  ];
}

class _ExportImageDialog extends StatefulWidget {
  const _ExportImageDialog({required this.session});
  final WorkSession session;
  @override
  State<_ExportImageDialog> createState() => _ExportImageDialogState();
}

class _ExportImageDialogState extends State<_ExportImageDialog> {
  final boundary = GlobalKey();
  String? error;
  bool busy = false;
  Future<void> save() async {
    setState(() => busy = true);
    try {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      if (render.size.height > 16000) {
        throw StateError('会话过长，请改用 HTML 或 JSON 导出。');
      }
      final image = await render.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        downloadBytes(
          bytes!.buffer.asUint8List(),
          'ade-session.png',
          'image/png',
        );
      } finally {
        image.dispose();
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('会话长图'),
    content: SizedBox(
      width: 700,
      child: SingleChildScrollView(
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: _colors(context).surface,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.session.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.session.workspace} · ${widget.session.branch}',
                    style: _muted(context),
                  ),
                  for (final m in widget.session.messages)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.isUser ? '你' : 'ADE',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.text,
                            style: const TextStyle(fontSize: 14, height: 1.7),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    actions: [
      if (error != null) Text(error!, style: const TextStyle(fontSize: 12)),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('关闭'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(busy ? '生成中' : '下载 PNG'),
      ),
    ],
  );
}
