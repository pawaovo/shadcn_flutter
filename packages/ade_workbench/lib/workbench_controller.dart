import 'dart:async';
import 'dart:convert';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_data.dart';

typedef Json = Map<String, dynamic>;

enum WorkspacePage {
  home,
  sessions,
  search,
  automations,
  chat,
  runs,
  review,
  activity,
  account,
  workspaces,
  connection,
  collaboration,
  archive,
}

enum ToolPanel { files, changes, terminal, browser, settings }

class WorkMessage {
  WorkMessage({
    required this.id,
    required this.text,
    this.isUser = false,
    this.streaming = false,
  });
  final String id, text;
  final bool isUser, streaming;
  factory WorkMessage.fromJson(Json v) => WorkMessage(
    id: v['id'],
    text: v['text'] ?? '',
    isUser: v['isUser'] ?? false,
  );
}

class WorkSession {
  WorkSession({
    required this.id,
    required this.title,
    this.workspace = '',
    this.workspaceId = '',
    this.branch = '',
    this.status = '未开始',
    this.pinned = false,
    this.archived = false,
    List<WorkMessage>? messages,
  }) : messages = messages ?? [];
  final String id, workspace, workspaceId;
  String title, branch, status;
  bool pinned, archived;
  final List<WorkMessage> messages;
  factory WorkSession.fromJson(Json v) => WorkSession(
    id: v['id'],
    title: v['title'],
    workspace: v['workspace'] ?? '',
    workspaceId: v['workspaceId'] ?? '',
    branch: v['branch'] ?? '',
    status: v['status'] ?? '',
    pinned: v['pinned'] ?? false,
    archived: v['archived'] ?? false,
    messages: [
      for (final m in v['messages'] ?? []) WorkMessage.fromJson(Json.from(m)),
    ],
  );
}

class WorkAutomation {
  WorkAutomation(this.data);
  final Json data;
  String get id => data['id'];
  String get title => data['title'];
  String get schedule => data['schedule'];
  String get prompt => data['prompt'];
  bool get enabled => data['enabled'];
}

/// Local view state only. Actions update the preview; nothing is executed.
class WorkbenchController extends ChangeNotifier {
  WorkbenchController({this._preferences}) {
    final samples = sampleWorkspaceData();
    sessions = [
      for (final s in samples.remove('sessions'))
        WorkSession.fromJson(Json.from(s)),
    ];
    automations = [
      for (final a in samples.remove('automations'))
        WorkAutomation(Json.from(a)),
    ];
    state = samples;
    restore();
    _ensureSelection();
    loadFiles('');
    if (workspace == 'design') {
      selectedFile = 'lib/workbench.dart';
      file = {
        'path': selectedFile,
        'text': files[selectedFile],
        'editable': true,
      };
    }
  }
  final SharedPreferences? _preferences;
  static const storageKey = 'ade.appearance.v2';
  static const draftKey = 'ade.drafts.v1';
  final Map<String, Json> fileDrafts = {};
  final Map<String, Json> reviewViews = {};
  final Map<String, String> composerDrafts = {};
  late final Json state;
  late final List<WorkSession> sessions;
  late final List<WorkAutomation> automations;
  bool _disposed = false, toolsRequested = false;
  WorkspacePage page = WorkspacePage.chat;
  ToolPanel panel = ToolPanel.changes;
  BeautifulUiThemeMode themeMode = BeautifulUiThemeMode.light;
  String workspace = 'design',
      model = 'balanced',
      selectedSessionId = 'thread',
      selectedFile = '',
      directory = '';
  String? storageError;
  String terminalOutput = '', connectionPreview = '未连接';
  bool terminalRunning = false,
      notifications = true,
      largeText = false,
      focusMode = false;
  String dock = 'right', executionMode = 'read-only';
  Json file = {};
  List<Json> entries = [];
  int _sequence = 0;
  String nextId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
  List<Json> rows(String key) => (state[key] as List? ?? []).cast<Json>();
  List<Json> get workspaces => rows('workspaces');
  List<Json> get models => rows('models');
  Json get git => state['git'];
  Map<String, dynamic> get files => state['previewFiles'];
  List<WorkSession> get visibleSessions =>
      sessions.where((s) => !s.archived && s.workspaceId == workspace).toList();
  WorkSession get current =>
      sessions.where((s) => s.id == selectedSessionId).firstOrNull ??
      WorkSession(id: '', title: '新会话');
  bool active(Json run) =>
      const ['queued', 'running', 'awaitingApproval'].contains(run['status']);
  Json? get activeRun =>
      rows('runs')
          .where((r) => r['sessionId'] == selectedSessionId && active(r))
          .firstOrNull;
  bool get running => activeRun != null;
  String? get runningSessionId => activeRun?['sessionId'];
  String get workspaceName =>
      workspaces.where((w) => w['id'] == workspace).firstOrNull?['name'] ??
      '选择工作区';
  String get connectionLabel => '前端页面预览';
  int get unread =>
      rows('notifications').where((n) => n['read'] != true).length;

  static Future<WorkbenchController> load() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      /* Appearance storage is optional. */
    }
    await preferences?.remove('ade.shell.preview.v1');
    return WorkbenchController(preferences: preferences);
  }

  void restore() {
    try {
      final v = jsonDecode(_preferences?.getString(storageKey) ?? '{}') as Json;
      final drafts =
          jsonDecode(_preferences?.getString(draftKey) ?? '{}') as Map;
      composerDrafts.addAll({
        for (final e in drafts.entries)
          if (e.value is String) e.key.toString(): e.value as String,
      });
      themeMode = BeautifulUiThemeMode.values.byName(v['theme'] ?? 'light');
      largeText = v['largeText'] == true;
      selectedSessionId = v['selected'] ?? selectedSessionId;
      workspace = v['workspace'] ?? workspace;
      if (['left', 'right', 'bottom'].contains(v['dock'])) dock = v['dock'];
    } catch (_) {
      storageError = '无法恢复外观偏好，已使用默认设置。';
    }
  }

  void _ensureSelection() {
    if (!workspaces.any((w) => w['id'] == workspace)) {
      workspace = workspaces.first['id'];
    }
    if (!visibleSessions.any((s) => s.id == selectedSessionId)) {
      selectedSessionId = visibleSessions.firstOrNull?.id ?? '';
    }
  }

  void changed({bool persist = false}) {
    if (_disposed) return;
    notifyListeners();
    if (persist && _preferences != null) {
      unawaited(
        _preferences
            .setString(
              storageKey,
              jsonEncode({
                'theme': themeMode.name,
                'largeText': largeText,
                'selected': selectedSessionId,
                'workspace': workspace,
                'dock': dock,
              }),
            )
            .catchError((_) => false),
      );
    }
  }

  void rememberDraft(String session, String text) {
    if (text.isEmpty) {
      composerDrafts.remove(session);
    } else {
      composerDrafts[session] = text;
    }
    if (_preferences != null) {
      unawaited(
        _preferences
            .setString(draftKey, jsonEncode(composerDrafts))
            .catchError((_) => false),
      );
    }
  }

  void clearError() {
    storageError = null;
    changed();
  }

  Future<dynamic> perform(Future<dynamic> Function() callback) async {
    try {
      return await callback();
    } catch (e) {
      storageError = e.toString();
      changed();
      return null;
    }
  }

  void navigate(WorkspacePage value) {
    page = value;
    changed();
  }

  void selectSession(String id) {
    final s = sessions.where((s) => s.id == id).firstOrNull;
    if (s == null) return;
    selectedSessionId = id;
    if (workspace != s.workspaceId) _changeWorkspace(s.workspaceId);
    page = WorkspacePage.chat;
    changed(persist: true);
  }

  Future<void> newSession() async {
    final s = WorkSession(
      id: nextId('session'),
      title: '新会话',
      workspaceId: workspace,
      workspace: workspaceName,
      branch: 'design/workbench',
    );
    sessions.insert(0, s);
    selectSession(s.id);
  }

  Future<void> renameSession(String id, String title) async {
    if (title.trim().isEmpty) return;
    sessions.firstWhere((s) => s.id == id).title = title.trim();
    changed();
  }

  Future<void> pinSession(String id) async {
    final s = sessions.firstWhere((s) => s.id == id);
    s.pinned = !s.pinned;
    changed();
  }

  Future<void> archiveSession(String id, bool archived) async {
    sessions.firstWhere((s) => s.id == id).archived = archived;
    _ensureSelection();
    changed(persist: true);
  }

  Future<void> deleteSession(String id, String confirmation) async {
    if (confirmation != 'DELETE') {
      storageError = '请输入 DELETE 确认删除。';
      changed();
      return;
    }
    sessions.removeWhere((s) => s.id == id);
    rememberDraft(id, '');
    for (final key in ['runs', 'approvals', 'shares', 'comments']) {
      rows(key).removeWhere((r) => r['sessionId'] == id);
    }
    _ensureSelection();
    changed(persist: true);
  }

  void selectPanel(ToolPanel value) {
    panel = value;
    toolsRequested = true;
    changed();
  }

  void setTheme(BeautifulUiThemeMode value) {
    themeMode = value;
    changed(persist: true);
  }

  void setLayout({String? position, bool? focus}) {
    dock = position ?? dock;
    focusMode = focus ?? focusMode;
    changed(persist: true);
  }

  void setModel(String value) {
    model = value;
    changed();
  }

  void updatePreferences({bool? notify, bool? bigText, String? mode}) {
    notifications = notify ?? notifications;
    largeText = bigText ?? largeText;
    executionMode = mode ?? executionMode;
    changed(persist: true);
  }

  void _changeWorkspace(String id) {
    workspace = id;
    file = {};
    selectedFile = '';
    directory = '';
    terminalOutput = '';
    terminalRunning = false;
    loadFiles('');
  }

  void selectWorkspace(String id) {
    if (!workspaces.any((w) => w['id'] == id)) return;
    _changeWorkspace(id);
    _ensureSelection();
    page = WorkspacePage.home;
    changed(persist: true);
  }

  void addWorkspace(String path, {String? name}) {
    if (path.trim().isEmpty) return;
    final id = nextId('workspace');
    workspaces.add({
      'id': id,
      'name':
          name ?? path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? path,
      'path': path,
    });
    selectWorkspace(id);
  }

  Future<void> saveAutomation({
    String? id,
    required String title,
    required String schedule,
    required String prompt,
    String execution = 'auto',
  }) async {
    if ([title, schedule, prompt].any((s) => s.trim().isEmpty)) {
      throw const FormatException('请填写任务名称、触发计划和任务说明。');
    }
    final old = automations.where((a) => a.id == id).firstOrNull;
    final data =
        old?.data ??
        {
          'id': nextId('automation'),
          'enabled': false,
          'workspaceId': workspace,
        };
    data.addAll({
      'title': title.trim(),
      'schedule': schedule.trim(),
      'prompt': prompt.trim(),
      'execution': execution,
    });
    if (old == null) automations.insert(0, WorkAutomation(data));
    changed();
  }

  Future<void> toggleAutomation(String id, bool value) async {
    automations.firstWhere((a) => a.id == id).data['enabled'] = value;
    changed();
  }

  Future<void> deleteAutomation(String id) async {
    automations.removeWhere((a) => a.id == id);
    changed();
  }

  void previewRun(String title, {String? sessionId}) {
    rows('runs').insert(0, {
      'id': nextId('run'),
      'title': title,
      'sessionId': sessionId,
      'messageId': sessions
          .where((s) => s.id == sessionId)
          .firstOrNull
          ?.messages
          .lastOrNull
          ?.id,
      'workspaceId': workspace,
      'status': 'preview',
      'created': DateTime.now().millisecondsSinceEpoch / 1000,
      'output': '运行入口预览，等待接入内核。',
    });
    changed();
  }

  void previewAutomation(WorkAutomation a) {
    a.data['lastResult'] = 'preview';
    previewRun(a.title);
  }

  Future<void> send(BeautifulPromptSubmission submission) async {
    if (submission.text.trim().isEmpty && submission.attachments.isEmpty) {
      return;
    }
    if (current.id.isEmpty) await newSession();
    if (current.archived) throw StateError('请先恢复归档会话。');
    final text = [
      submission.text,
      if (submission.attachments.isNotEmpty)
        '附件：${submission.attachments.map((a) => a.label).join('、')}',
    ].where((s) => s.isNotEmpty).join('\n');
    current.messages.add(
      WorkMessage(id: nextId('message'), text: text, isUser: true),
    );
    if (current.title == '新会话') {
      current.title = String.fromCharCodes(text.runes.take(24));
    }
    current.status = '交互预览';
    changed();
  }

  Future<void> stopRun([String? id]) async {
    final run = rows('runs')
        .where((r) => r['id'] == (id ?? activeRun?['id']))
        .firstOrNull;
    if (run != null) {
      run['status'] = 'interrupted';
      for (final approval in rows(
        'approvals',
      ).where((a) => a['runId'] == run['id'] && a['status'] == 'pending')) {
        approval.addAll({'status': 'cancelled', 'decision': 'cancel'});
      }
      final session = sessions
          .where((s) => s.id == run['sessionId'])
          .firstOrNull;
      if (session != null) session.status = '已停止';
    }
    changed();
  }

  void answerApproval(String id, String answer) {
    final a = rows('approvals').where((a) => a['id'] == id).firstOrNull;
    if (a == null || a['status'] != 'pending') return;
    a.addAll({'status': 'answered', 'decision': answer});
    final run = rows('runs').where((r) => r['id'] == a['runId']).firstOrNull;
    if (run != null) {
      run['status'] = answer == 'accept' ? 'preview' : 'interrupted';
    }
    final s = sessions.where((s) => s.id == a['sessionId']).firstOrNull;
    if (s != null) s.status = answer == 'accept' ? '交互预览' : '已停止';
    changed();
  }

  void markRead([String? id]) {
    for (final n in rows('notifications')) {
      if (id == null || n['id'] == id) n['read'] = true;
    }
    changed();
  }

  Future<void> loadFiles(String path) async {
    directory = path;
    entries = workspace == 'design'
        ? [
            for (final p in files.keys)
              if (p.startsWith(path))
                {'path': p, 'name': p.split('/').last, 'directory': false},
          ]
        : [];
    changed();
  }

  Future<void> selectFile(String path) async {
    if (workspace != 'design' || !files.containsKey(path)) return;
    file = {'path': path, 'text': files[path], 'editable': true};
    selectedFile = path;
    selectPanel(ToolPanel.files);
  }

  void saveFile(String path, String text) {
    if (workspace != 'design' || !files.containsKey(path)) return;
    files[path] = text;
    file = {'path': path, 'text': text, 'editable': true};
    changed();
  }

  Future<void> openTerminal() async {
    terminalRunning = true;
    terminalOutput = 'ADE · 终端界面预览\n';
    changed();
  }

  Future<void> terminal(String text) async {
    if (!terminalRunning) await openTerminal();
    terminalOutput += text == '\u0003'
        ? '^C\n'
        : '\$ ${text.trim()}\n[命令未执行，等待接入内核]\n';
    changed();
  }

  Future<void> closeTerminal() async {
    terminalRunning = false;
    changed();
  }

  void saveSnapshot() {
    rows('checkpoints').insert(0, {
      'id': nextId('snapshot'),
      'workspaceId': workspace,
      'label': '文件快照预览',
      'created': DateTime.now().millisecondsSinceEpoch / 1000,
      'files': workspace == 'design' ? files.keys.toList() : [],
      'count': workspace == 'design' ? files.length : 0,
    });
    changed();
  }

  void addComment(String text, {String? path, int? line}) {
    if (text.trim().isEmpty) return;
    rows('comments').add({
      'id': nextId('comment'),
      'sessionId': current.id,
      'text': text.trim(),
      'path': path,
      'line': line,
      'author': '预览用户',
      'created': DateTime.now().millisecondsSinceEpoch / 1000,
      'resolved': false,
    });
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
