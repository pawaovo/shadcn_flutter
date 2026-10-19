part of 'workbench.dart';

BeautifulUiColors _colors(BuildContext context) =>
    BeautifulUiTheme.of(context).colors;
TextStyle _muted(BuildContext context) =>
    BeautifulUiTheme.of(context).typography.caption
        .copyWith(color: _colors(context).inkMuted);

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.size = 28});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _colors(context).ink,
      borderRadius: BorderRadius.circular(8),
    ),
    alignment: Alignment.center,
    child: Icon(
      Icons.auto_awesome_rounded,
      size: size * .6,
      color: _colors(context).surface,
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border.all(color: theme.colors.line),
        borderRadius: BorderRadius.circular(theme.radii.card),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.typography.label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: _muted(context)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => BeautifulIconButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    density: BeautifulUiDensity.compact,
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon});
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colors.inset,
        border: Border.all(color: theme.colors.line),
        borderRadius: BorderRadius.circular(theme.radii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: theme.colors.inkMuted),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: theme.typography.caption.copyWith(
                color: theme.colors.inkMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.icon = Icons.info_outline_rounded});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _colors(context).inset,
      border: Border.all(color: _colors(context).line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _colors(context).inkMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: _muted(context))),
      ],
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _colors(context).inkMuted,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.detail,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title;
  final String detail;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _colors(context).inset,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: _colors(context).inkMuted),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center, style: _muted(context)),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      padding: EdgeInsets.all(constraints.maxWidth < 500 ? 16 : 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.6,
                      ),
                    ),
                    ?action,
                  ],
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: _muted(context)),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.controller});
  final WorkSession session;
  final WorkbenchController controller;
  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: controller.selectedSessionId == session.id
            ? colors.inset
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.only(
            left: 12,
            right: 4,
            top: 4,
            bottom: 4,
          ),
          leading: Icon(
            session.pinned
                ? Icons.push_pin_outlined
                : Icons.chat_bubble_outline_rounded,
            size: 18,
            color: colors.inkMuted,
          ),
          title: Text(
            session.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${session.branch} · ${session.status}',
              style: _muted(context),
            ),
          ),
          onTap: () => controller.selectSession(session.id),
          trailing: PopupMenuButton<String>(
            tooltip: '管理会话：${session.title}',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 20,
              color: colors.inkMuted,
            ),
            onSelected: (value) async {
              if (value == 'pin') controller.pinSession(session.id);
              if (value == 'rename') {
                final title = await _editText(context, '重命名会话', session.title);
                if (title != null) controller.renameSession(session.id, title);
              }
              if (value == 'archive') {
                if (context.mounted) {
                  await _archiveSession(context, controller, session);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pin',
                child: Text(session.pinned ? '取消置顶' : '置顶会话'),
              ),
              const PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(
                value: 'archive',
                child: Text(session.archived ? '恢复会话' : '归档会话'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _editText(BuildContext context, String title, String initial) =>
    showDialog<String>(
      context: context,
      builder: (_) => _NameEditor(title: title, initial: initial),
    );

class _NameEditor extends StatefulWidget {
  const _NameEditor({required this.title, required this.initial});
  final String title;
  final String initial;
  @override
  State<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends State<_NameEditor> {
  late final _field = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _field,
      autofocus: true,
      maxLength: 100,
      decoration: const InputDecoration(labelText: '名称'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_field.text.trim().isNotEmpty) {
            Navigator.pop(context, _field.text.trim());
          }
        },
        child: const Text('保存'),
      ),
    ],
  );
}

Future<bool> _confirm(
  BuildContext context,
  String title,
  String detail,
  String action,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
Future<void> _archiveSession(
  BuildContext context,
  WorkbenchController c,
  WorkSession session,
) async {
  if (session.archived) {
    await c.archiveSession(session.id, false);
    return;
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('归档会话'),
      content: const Text('会话将变为只读。可先保存当前工作区变更的文件快照。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'archive'),
          child: const Text('直接归档'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'snapshot'),
          child: const Text('保存快照并归档'),
        ),
      ],
    ),
  );
  if (choice == null) return;
  if (choice == 'snapshot') c.saveSnapshot();
  await c.archiveSession(session.id, true);
}

Future<void> _openLink(
  BuildContext context,
  WorkbenchController c,
  String url,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('链接预览'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(url),
          const SizedBox(height: 12),
          const Text('当前为示例链接，后续由内核提供实际地址。'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}
