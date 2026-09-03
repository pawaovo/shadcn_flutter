part of 'main.dart';

const _streamSources = <BeautifulStreamingSource>[
  BeautifulStreamingSource(
    id: 'sales',
    title: 'September sales forecast',
    detail: 'Pistachio demand is up 18%.',
  ),
  BeautifulStreamingSource(
    id: 'suppliers',
    title: 'Supplier availability',
    detail: 'Cone King can deliver within seven days.',
  ),
];

const _streamParts = <BeautifulStreamingPart>[
  BeautifulStreamingPart.text('Prioritize the pistachio restock. '),
  BeautifulStreamingPart.citation('sales'),
  BeautifulStreamingPart.text(
    '\nConfirm the waffle cone order before Friday. ',
  ),
  BeautifulStreamingPart.citation('suppliers'),
];

final class _CatalogStreamingExample extends StatefulWidget {
  const _CatalogStreamingExample({super.key, required this.initialStatus});

  final BeautifulStreamingStatus initialStatus;

  @override
  State<_CatalogStreamingExample> createState() =>
      _CatalogStreamingExampleState();
}

final class _CatalogStreamingExampleState
    extends State<_CatalogStreamingExample> {
  late BeautifulStreamingStatus _status = widget.initialStatus;
  var _visibleParts = 1;
  String? _activity;
  BeautifulStreamingFeedback? _feedback;
  Timer? _streamTimer;

  @override
  void dispose() {
    _streamTimer?.cancel();
    super.dispose();
  }

  void _runDemo() {
    _streamTimer?.cancel();
    setState(() {
      _status = BeautifulStreamingStatus.streaming;
      _visibleParts = 1;
      _activity = 'Receiving a demonstration response';
    });
    _streamTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_visibleParts < _streamParts.length) {
          _visibleParts++;
        } else {
          timer.cancel();
          _status = BeautifulStreamingStatus.complete;
          _activity = 'Demonstration response complete';
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.initialStatus.name;
    final title = switch (widget.initialStatus) {
      BeautifulStreamingStatus.streaming => 'Streaming Text · Live',
      BeautifulStreamingStatus.complete => 'Streaming Text · Complete',
      BeautifulStreamingStatus.failed => 'Streaming Text · Failed',
    };
    return _CatalogCard(
      title: title,
      caption: _activity ?? 'Host-owned text, citations, and response actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BeautifulStreamingText(
            key: ValueKey('catalog-streaming-$name'),
            id: 'catalog-response-$name',
            content: _status == BeautifulStreamingStatus.complete
                ? _streamParts
                : _streamParts.take(_visibleParts),
            status: _status,
            sources: _streamSources,
            followUps: const <BeautifulStreamingFollowUp>[
              BeautifulStreamingFollowUp(
                id: 'lead-times',
                label: 'Compare supplier lead times',
              ),
            ],
            onSourcePressed: (source) {
              setState(() => _activity = 'Opened citation: ${source.title}');
            },
            onFollowUp: (followUp) {
              setState(
                () => _activity = 'Follow-up selected: ${followUp.label}',
              );
            },
            onCopy: (text) async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!mounted) return;
              setState(() => _activity = 'Response copied');
            },
            feedback: _feedback,
            onFeedback: (feedback) {
              setState(() {
                _feedback = feedback;
                _activity = 'Feedback received: ${feedback.name}';
              });
            },
            onRetry: () async {
              await Future<void>.delayed(const Duration(milliseconds: 120));
              if (!mounted) return;
              setState(() {
                _status = BeautifulStreamingStatus.complete;
                _activity = 'Response recovered';
              });
            },
            errorMessage: _status == BeautifulStreamingStatus.failed
                ? 'The supplier lookup was interrupted.'
                : null,
            labels: const BeautifulStreamingLabels(copy: 'Copy response'),
          ),
          if (widget.initialStatus == BeautifulStreamingStatus.streaming) ...[
            const SizedBox(height: 12),
            _CatalogButton(label: 'Run stream demo', onPressed: _runDemo),
          ],
        ],
      ),
    );
  }
}

final class _CatalogApprovalExample extends StatefulWidget {
  const _CatalogApprovalExample();

  @override
  State<_CatalogApprovalExample> createState() =>
      _CatalogApprovalExampleState();
}

final class _CatalogApprovalExampleState
    extends State<_CatalogApprovalExample> {
  int? _submittedAnswers;

  @override
  Widget build(BuildContext context) {
    return _CatalogCard(
      title: 'Approval Card',
      caption: _submittedAnswers == null
          ? 'Single choice, multiple choice, and custom answers'
          : 'Submitted $_submittedAnswers approval answers',
      child: BeautifulApprovalCard(
        key: const Key('catalog-approval'),
        id: 'seasonal-launch',
        questions: <BeautifulApprovalQuestion>[
          BeautifulApprovalQuestion(
            id: 'market',
            title: 'Where should we launch first?',
            options: const <BeautifulApprovalOption>[
              BeautifulApprovalOption(id: 'shops', label: 'Scoop shops'),
              BeautifulApprovalOption(id: 'online', label: 'Online store'),
            ],
          ),
          BeautifulApprovalQuestion(
            id: 'flavors',
            title: 'Which flavors should we include?',
            type: BeautifulApprovalQuestionType.multipleChoice,
            options: const <BeautifulApprovalOption>[
              BeautifulApprovalOption(id: 'pistachio', label: 'Pistachio'),
              BeautifulApprovalOption(id: 'vanilla', label: 'Vanilla'),
            ],
          ),
          BeautifulApprovalQuestion(
            id: 'timing',
            title: 'When should the launch begin?',
            options: const <BeautifulApprovalOption>[
              BeautifulApprovalOption(id: 'friday', label: 'This Friday'),
              BeautifulApprovalOption(id: 'later', label: 'Next week'),
            ],
          ),
        ],
        onSubmit: (answers) async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (!mounted) return;
          setState(() => _submittedAnswers = answers.length);
        },
      ),
    );
  }
}

final class _CatalogToolExample extends StatefulWidget {
  const _CatalogToolExample();

  @override
  State<_CatalogToolExample> createState() => _CatalogToolExampleState();
}

final class _CatalogToolExampleState extends State<_CatalogToolExample> {
  String? _activity;

  @override
  Widget build(BuildContext context) {
    return _CatalogCard(
      title: 'Tool Chips',
      caption: _activity ?? 'Tool states, expandable output, and changed files',
      child: BeautifulToolChips(
        key: const Key('catalog-tool-chips'),
        headerLabel: 'Restock workflow · 4 tools',
        initiallyVisibleDiffCount: 1,
        steps: <BeautifulToolStep>[
          BeautifulToolStep(
            id: 'plan',
            label: 'Plan restock',
            chip: 'Compare inventory and demand',
            kind: BeautifulToolKind.think,
            mono: false,
            detailMono: false,
            details: const <BeautifulToolDetailLine>[
              BeautifulToolDetailLine(
                text: 'Prioritize the top three flavors.',
              ),
            ],
          ),
          BeautifulToolStep(
            id: 'write',
            label: 'Update forecast',
            chip: 'forecast.csv',
            kind: BeautifulToolKind.write,
            details: const <BeautifulToolDetailLine>[
              BeautifulToolDetailLine(
                text: 'pistachio,118',
                tone: BeautifulToolLineTone.addition,
              ),
            ],
          ),
          BeautifulToolStep(
            id: 'run',
            label: 'Check stock',
            chip: 'inventory verify',
            status: BeautifulToolStatus.running,
            details: const <BeautifulToolDetailLine>[
              BeautifulToolDetailLine(text: 'Checking 7 seasonal SKUs…'),
            ],
          ),
          BeautifulToolStep(
            id: 'read',
            label: 'Read supplier sheet',
            chip: 'suppliers.csv',
            kind: BeautifulToolKind.read,
            status: BeautifulToolStatus.failed,
            details: const <BeautifulToolDetailLine>[
              BeautifulToolDetailLine(
                text: 'The source is temporarily unavailable.',
              ),
            ],
          ),
        ],
        diffs: <BeautifulToolDiff>[
          BeautifulToolDiff(
            id: 'forecast',
            file: 'forecast.csv',
            additions: 1,
            deletions: 1,
            lines: const <BeautifulToolDetailLine>[
              BeautifulToolDetailLine(
                text: 'pistachio,100',
                tone: BeautifulToolLineTone.deletion,
              ),
              BeautifulToolDetailLine(
                text: 'pistachio,118',
                tone: BeautifulToolLineTone.addition,
              ),
            ],
          ),
          BeautifulToolDiff(id: 'order', file: 'restock.json', additions: 4),
          BeautifulToolDiff(
            id: 'notes',
            file: 'supplier-notes.md',
            additions: 2,
          ),
        ],
        onStepExpandedChanged: (id, expanded) {
          setState(
            () => _activity = '${expanded ? 'Opened' : 'Closed'} tool: $id',
          );
        },
        onDiffExpandedChanged: (id, expanded) {
          setState(
            () => _activity = '${expanded ? 'Opened' : 'Closed'} file: $id',
          );
        },
      ),
    );
  }
}

final class _CatalogTaskExample extends StatefulWidget {
  const _CatalogTaskExample({required this.variant});

  final BeautifulTaskRowsVariant variant;

  @override
  State<_CatalogTaskExample> createState() => _CatalogTaskExampleState();
}

final class _CatalogTaskExampleState extends State<_CatalogTaskExample> {
  var _recovered = false;

  @override
  Widget build(BuildContext context) {
    return _CatalogCard(
      title: 'Task Rows · ${widget.variant.name}',
      caption: _recovered
          ? 'Supplier email draft recovered'
          : 'Pending, running, completed, and retryable task snapshots',
      child: BeautifulTaskRows(
        key: ValueKey('catalog-task-rows-${widget.variant.name}'),
        variant: widget.variant,
        rows: <BeautifulTaskRow>[
          BeautifulTaskRow(
            id: 'vendors',
            label: 'Verify vendors',
            amountLabel: '12 suppliers',
            status: BeautifulTaskStatus.completed,
            details: const <BeautifulTaskDetail>[
              BeautifulTaskDetail(
                id: 'certificate',
                label: 'Cold-chain certificates',
                meta: 'Verified',
              ),
            ],
          ),
          BeautifulTaskRow(
            id: 'index',
            label: 'Index seasonal inventory',
            amountLabel: '7 SKUs',
            status: BeautifulTaskStatus.running,
            step: 2,
            progress: 0.68,
          ),
          BeautifulTaskRow(
            id: 'email',
            label: 'Draft supplier email',
            amountLabel: '2 messages',
            status: _recovered
                ? BeautifulTaskStatus.completed
                : BeautifulTaskStatus.failed,
            details: const <BeautifulTaskDetail>[
              BeautifulTaskDetail(
                id: 'drafts',
                label: 'Supplier outreach',
                meta: 'Review before sending',
              ),
            ],
          ),
          BeautifulTaskRow(
            id: 'review',
            label: 'Review restock order',
            amountLabel: '1 order',
            status: BeautifulTaskStatus.pending,
          ),
        ],
        onRetry: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (!mounted) return;
          setState(() => _recovered = true);
        },
      ),
    );
  }
}

final class _CatalogChatExample extends StatefulWidget {
  const _CatalogChatExample();

  @override
  State<_CatalogChatExample> createState() => _CatalogChatExampleState();
}

final class _CatalogChatExampleState extends State<_CatalogChatExample> {
  var _tab = 'flavors';
  var _generation = 0;
  var _responding = false;
  final _messages = <BeautifulChatMessage>[
    const BeautifulChatMessage(
      id: 'initial-user',
      role: BeautifulChatRole.user,
      text: 'What should we restock this week?',
    ),
    const BeautifulChatMessage(
      id: 'initial-assistant',
      role: BeautifulChatRole.assistant,
      text: 'Start with pistachio and waffle cones. Both have rising demand.',
      title: 'Sales forecast',
      subtitle: 'September demand',
      detailLabel: 'Updated today',
    ),
  ];

  void _send(String text) {
    final generation = ++_generation;
    final responseId = 'reply-$generation';
    setState(() {
      _responding = true;
      _messages.add(
        BeautifulChatMessage(
          id: 'prompt-$generation',
          role: BeautifulChatRole.user,
          text: text,
        ),
      );
      _messages.add(
        BeautifulChatMessage(
          id: responseId,
          role: BeautifulChatRole.assistant,
          text: 'Checking the catalog examples…',
          isResolving: true,
        ),
      );
    });
  }

  void _completeResponse() {
    if (!_responding) return;
    setState(() {
      _responding = false;
      _messages[_messages.length - 1] = BeautifulChatMessage(
        id: 'reply-$_generation',
        role: BeautifulChatRole.assistant,
        text: 'The demonstration has 7 seasonal SKUs ready for review. Confirm supplier quantities before ordering.',
        detailLabel: 'Catalog demonstration',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _CatalogCard(
      title: 'Chat',
      caption: 'Active context: $_tab · local demonstration replies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          BeautifulChat(
            key: const Key('catalog-chat'),
            conversationId: 'restock-catalog',
            messages: List<BeautifulChatMessage>.unmodifiable(_messages),
            status: _responding
                ? BeautifulChatStatus.responding
                : BeautifulChatStatus.idle,
            responseId: _responding ? 'reply-$_generation' : null,
            onSend: _send,
            onStop: (_) {
              setState(() {
                _responding = false;
                _messages[_messages.length - 1] = BeautifulChatMessage(
                  id: 'reply-$_generation',
                  role: BeautifulChatRole.assistant,
                  text: 'Demonstration response stopped.',
                );
              });
            },
            tabs: const <BeautifulChatTab>[
              BeautifulChatTab(id: 'flavors', label: 'Flavors'),
              BeautifulChatTab(id: 'suppliers', label: 'Suppliers'),
            ],
            selectedTabId: _tab,
            onTabChanged: (id) => setState(() => _tab = id),
          ),
          if (_responding) ...<Widget>[
            const SizedBox(height: 12),
            _CatalogButton(
              label: 'Complete demonstration response',
              onPressed: _completeResponse,
            ),
          ],
        ],
      ),
    );
  }
}

final class _CatalogFilterExample extends StatefulWidget {
  const _CatalogFilterExample();

  @override
  State<_CatalogFilterExample> createState() => _CatalogFilterExampleState();
}

final class _CatalogFilterExampleState extends State<_CatalogFilterExample> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return _CatalogCard(
      title: 'Filter Table',
      caption: 'Selected filter: $_filter',
      child: BeautifulFilterTable(
        key: const Key('catalog-filter-table'),
        rows: const <BeautifulFilterTableRow>[
          BeautifulFilterTableRow(
            id: 'forecast',
            task: 'Review seasonal forecast',
            date: 'Sep 3',
            status: BeautifulFilterTableStatus.completed,
            owner: 'Maya',
          ),
          BeautifulFilterTableRow(
            id: 'stock',
            task: 'Count waffle cone stock',
            date: 'Sep 4',
            status: BeautifulFilterTableStatus.inProgress,
            owner: 'Alex',
          ),
          BeautifulFilterTableRow(
            id: 'supplier',
            task: 'Confirm supplier quantities',
            date: 'Sep 5',
            status: BeautifulFilterTableStatus.todo,
            owner: 'Jordan',
          ),
          BeautifulFilterTableRow(
            id: 'launch',
            task: 'Schedule flavor launch',
            date: 'Sep 6',
            status: BeautifulFilterTableStatus.todo,
            owner: 'Maya',
          ),
        ],
        onFilterChanged: (status) =>
            setState(() => _filter = status?.name ?? 'all'),
      ),
    );
  }
}

final class _CatalogFineTuneExample extends StatefulWidget {
  const _CatalogFineTuneExample();

  @override
  State<_CatalogFineTuneExample> createState() =>
      _CatalogFineTuneExampleState();
}

final class _CatalogFineTuneExampleState
    extends State<_CatalogFineTuneExample> {
  var _settings = BeautifulFineTuneSettings(
    fields: const <BeautifulFineTuneField>[
      BeautifulFineTuneField(
        id: 'width',
        label: 'Width',
        value: 324,
        min: 40,
        max: 999,
      ),
      BeautifulFineTuneField(
        id: 'height',
        label: 'Height',
        value: 96,
        min: 24,
        max: 999,
      ),
      BeautifulFineTuneField(
        id: 'radius',
        label: 'Radius',
        value: 28,
        min: 0,
        max: 64,
      ),
      BeautifulFineTuneField(
        id: 'opacity',
        label: 'Opacity',
        value: 100,
        min: 0,
        max: 100,
        suffix: '%',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return _CatalogCard(
      title: 'Fine-tune Card',
      caption:
          'Accepted layout: ${_settings.layout.name} · numeric values update the host snapshot',
      child: BeautifulFineTuneCard(
        key: const Key('catalog-fine-tune'),
        settings: _settings,
        options: const <BeautifulFineTuneOption>[
          BeautifulFineTuneOption(id: 'seasonal', label: 'Seasonal'),
          BeautifulFineTuneOption(id: 'classic', label: 'Classic'),
          BeautifulFineTuneOption(id: 'limited', label: 'Limited edition'),
        ],
        labels: const BeautifulFineTuneLabels(title: 'Flavor card'),
        onChanged: (settings) => setState(() => _settings = settings),
      ),
    );
  }
}
