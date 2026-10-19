import 'workbench_controller.dart' show Json;

// Small, local fixtures for inspecting the frontend without a running kernel.
Json sampleWorkspaceData() {
  final now = DateTime.now().millisecondsSinceEpoch / 1000;
  return {
    'workspaces': <Json>[
      {'id': 'design', 'name': 'Design', 'path': '~/Projects/design'},
      {'id': 'cometixy', 'name': 'Cometixy', 'path': '~/Projects/cometixy'},
    ],
    'sessions': [
      {
        'id': 'thread',
        'title': '组件化会话流',
        'workspaceId': 'design',
        'workspace': 'Design',
        'branch': 'design/workbench',
        'status': '待评审',
        'pinned': true,
        'archived': false,
        'messages': [
          {
            'id': 'brief',
            'text': '把会话流里的工具卡拆成可复用组件，并适配电脑端和移动端。',
            'isUser': true,
          },
          {
            'id': 'reply',
            'text': '已将会话工具整理为独立组件，并完成响应式布局。\n\n电脑端可以同时查看会话、文件与变更；手机端通过底部工具入口切换，继续处理同一个任务。\n\n你可以先审阅右侧文件，或继续调整组件的视觉细节。',
            'isUser': false,
          },
        ],
      },
      {
        'id': 'mobile',
        'title': '移动端导航与工具面板',
        'workspaceId': 'design',
        'workspace': 'Design',
        'branch': 'design/mobile',
        'status': '已完成',
        'pinned': false,
        'archived': false,
        'messages': [],
      },
      {
        'id': 'approval',
        'title': '等待操作确认',
        'workspaceId': 'design',
        'workspace': 'Design',
        'branch': 'design/workbench',
        'status': '等待审批',
        'pinned': false,
        'archived': false,
        'messages': [
          {
            'id': 'question',
            'text': '审批卡片用于展示内核请求的操作范围和你的选择。当前内容为预览。',
            'isUser': false,
          },
        ],
      },
      {
        'id': 'archived',
        'title': '已归档的设计讨论',
        'workspaceId': 'design',
        'workspace': 'Design',
        'branch': 'main',
        'status': '已完成',
        'pinned': false,
        'archived': true,
        'messages': [],
      },
    ],
    'automations': [
      {
        'id': 'daily',
        'title': '每日设计一致性检查',
        'workspaceId': 'design',
        'schedule': '每天 09:00',
        'prompt': '检查组件间距、颜色和交互的一致性。',
        'enabled': false,
        'execution': 'auto',
        'lastResult': null,
        'nextAt': null,
      },
    ],
    'runs': <Json>[
      {
        'id': 'preview-review',
        'kind': 'agent',
        'sessionId': 'thread',
        'messageId': 'reply',
        'workspaceId': 'design',
        'title': '响应式布局与组件整理',
        'status': 'completed',
        'created': now,
        'output': '会话、文件与工具面板已整理。',
        'plan': [
          {'step': '拆分会话组件', 'status': 'completed'},
          {'step': '适配窄屏导航', 'status': 'completed'},
        ],
        'items': [
          {
            'id': 'read',
            'type': 'fileChange',
            'changes': [
              {'path': 'lib/workbench.dart', 'kind': 'update'},
            ],
          },
        ],
      },
      {
        'id': 'preview-approval',
        'kind': 'agent',
        'sessionId': 'approval',
        'messageId': 'question',
        'workspaceId': 'design',
        'title': '审批状态示例',
        'status': 'awaitingApproval',
        'created': now,
        'items': [],
        'plan': [],
        'output': '',
      },
      {
        'id': 'preview-failed',
        'kind': 'command',
        'workspaceId': 'design',
        'title': '失败与重试状态示例',
        'command': 'flutter test',
        'status': 'failed',
        'created': now,
        'error': '示例错误：展示失败状态与重试入口。',
        'output': '此处由内核返回命令日志。',
      },
    ],
    'approvals': <Json>[
      {
        'id': 'preview-approval-card',
        'runId': 'preview-approval',
        'sessionId': 'approval',
        'status': 'pending',
        'command': 'flutter test',
        'cwd': '~/Projects/design',
        'reason': '操作确认的页面示例，不会执行命令。',
      },
    ],
    'notifications': <Json>[
      {
        'id': 'notice',
        'title': '页面预览已就绪',
        'detail': '会话、工具和状态数据均来自本地示例。',
        'read': false,
        'kind': 'info',
        'created': now,
        'sessionId': 'thread',
      },
    ],
    'shares': <Json>[],
    'checkpoints': <Json>[],
    'comments': <Json>[],
    'models': <Json>[
      {'model': 'balanced', 'displayName': 'Balanced · 预览', 'isDefault': true},
      {'model': 'fast', 'displayName': 'Fast · 预览'},
      {'model': 'deep', 'displayName': 'Deep · 预览'},
    ],
    'git': {
      'branch': 'design/workbench',
      'files': [
        {'path': 'lib/workbench.dart', 'staged': false},
        {'path': 'lib/composer.dart', 'staged': false},
      ],
    },
    'previewFiles': {
      'lib/workbench.dart': "import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';\n\nWidget buildComposer() {\n  return BeautifulPromptBar(\n    composerId: 'workspace',\n    placeholder: '下一步，想做些什么？',\n    tall: true,\n    onSend: (message) {\n      // 在此接入会话操作。\n    },\n  );\n}\n",
      'lib/composer.dart': '// 消息输入区示例\n// 输入、附件和发送状态的展示区域。\n',
    },
    'previewBranches': <Json>[
      {'name': 'design/workbench', 'sha': 'preview', 'current': true},
      {'name': 'main', 'sha': 'preview', 'current': false},
    ],
    'previewCommits': <Json>[
      {
        'sha': 'preview',
        'subject': '组合响应式工作台',
        'author': '预览用户',
        'date': '示例记录',
      },
    ],
    'previewPrs': <Json>[
      {
        'number': 1,
        'title': '响应式工作台 · PR 卡片示例',
        'headRefName': 'design/workbench',
        'mergeable': '示例状态',
        'isDraft': true,
        'url': 'https://example.invalid/preview',
      },
    ],
  };
}
