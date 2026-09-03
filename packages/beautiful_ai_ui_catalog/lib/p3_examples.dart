part of 'main.dart';

final class _CatalogP3Examples extends StatelessWidget {
  const _CatalogP3Examples();

  @override
  Widget build(BuildContext context) {
    final gap = BeautifulUiTheme.of(context).spacing.lg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _CatalogPromptExample(),
        SizedBox(height: gap),
        const _CatalogDiffExample(),
        SizedBox(height: gap),
        const _CatalogRecordsExample(),
        SizedBox(height: gap),
        const _CatalogSidebarExample(),
        SizedBox(height: gap),
        const _CatalogFlowchartExample(),
        SizedBox(height: gap),
        const _CatalogInsightsExample(),
        SizedBox(height: gap),
        const _CatalogSelectionExample(),
      ],
    );
  }
}

final class _CatalogPromptExample extends StatefulWidget {
  const _CatalogPromptExample();

  @override
  State<_CatalogPromptExample> createState() => _CatalogPromptExampleState();
}

final class _CatalogPromptExampleState extends State<_CatalogPromptExample> {
  var _model = 'balanced';
  var _attachment = 0;
  var _connected = false;
  var _tall = false;
  var _variant = BeautifulPromptBarVariant.rounded;
  final _fileAttachments = CatalogFileAttachments();
  String? _fileError;
  var _activity = catalogRealFiles
      ? 'Choose real files to read locally; dictation remains a sample'
      : 'Compose a restock request with local sample integrations';

  Future<List<BeautifulPromptAttachment>> _attachFiles() async {
    if (!catalogRealFiles) {
      final id = ++_attachment;
      setState(() => _activity = 'Attached sample inventory file $id');
      return <BeautifulPromptAttachment>[
        BeautifulPromptAttachment(
          id: 'inventory-$id',
          label: 'inventory-$id.csv',
        ),
      ];
    }
    setState(() => _fileError = null);
    try {
      final attachments = await _fileAttachments.pick();
      if (!mounted) return const [];
      setState(() {
        _activity = attachments.isEmpty
            ? 'File selection cancelled; existing attachments retained'
            : 'Read ${attachments.length} real files locally:\n${_fileAttachments.receiptsFor(attachments).map((file) => file.summary).join('\n')}';
      });
      return attachments;
    } catch (_) {
      if (mounted) {
        setState(() {
          _fileError = 'Could not read the selected files. Try again.';
          _activity = 'File selection failed; no new files were added';
        });
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => _CatalogCard(
    title: 'Prompt Bar',
    caption: _activity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _CatalogButton(
              label: 'Shape: ${_variant.name}',
              onPressed: () => setState(() {
                _variant = _variant == BeautifulPromptBarVariant.rounded
                    ? BeautifulPromptBarVariant.pill
                    : BeautifulPromptBarVariant.rounded;
              }),
            ),
            _CatalogButton(
              label: _tall ? 'Use compact composer' : 'Use tall composer',
              onPressed: () => setState(() => _tall = !_tall),
            ),
          ],
        ),
        const SizedBox(height: 12),
        BeautifulPromptBar(
          key: const Key('catalog-prompt-bar'),
          composerId: 'catalog-restock-prompt',
          variant: _variant,
          tall: _tall,
          errorText: _fileError,
          placeholder: 'Ask about restocking, or type @ or /',
          models: const <BeautifulPromptModel>[
            BeautifulPromptModel(id: 'balanced', label: 'Balanced'),
            BeautifulPromptModel(id: 'precise', label: 'Precise'),
          ],
          selectedModelId: _model,
          onModelChanged: (id) => setState(() {
            _model = id;
            _activity = 'Selected prompt model: $id';
          }),
          sources: <BeautifulPromptSource>[
            const BeautifulPromptSource(
              id: 'inventory',
              label: 'Inventory',
              description: 'Current sample inventory',
            ),
            BeautifulPromptSource(
              id: 'vendors',
              label: 'Vendor directory',
              description: 'Connect the local sample directory',
              connected: _connected,
            ),
          ],
          commands: const <BeautifulPromptCommand>[
            BeautifulPromptCommand(
              id: 'restock',
              label: 'restock',
              description: 'Draft a restock plan',
            ),
            BeautifulPromptCommand(
              id: 'compare',
              label: 'compare',
              description: 'Compare supplier lead times',
            ),
          ],
          onConnectSource: (id) async {
            setState(() {
              _connected = true;
              _activity = 'Connected sample source: $id';
            });
          },
          attachLabel: catalogRealFiles
              ? 'Choose files from device'
              : 'Add photos and files',
          onAttach: _attachFiles,
          dictateLabel: 'Insert sample dictation',
          onDictate: () {
            setState(() => _activity = 'Inserted local sample transcript');
            return 'Check the pistachio stock before Friday.';
          },
          onSend: (submission) async {
            await Future<void>.delayed(const Duration(milliseconds: 120));
            if (!mounted) return;
            setState(() {
              _activity =
                  'Prompt received: ${submission.text} '
                  '· ${submission.attachments.length} files '
                  '· ${submission.modelId}';
              if (catalogRealFiles && submission.attachments.isNotEmpty) {
                _activity +=
                    '\nRead file receipts:\n${_fileAttachments.receiptsFor(submission.attachments).map((file) => file.summary).join('\n')}';
              }
            });
          },
        ),
      ],
    ),
  );
}

final class _CatalogDiffExample extends StatefulWidget {
  const _CatalogDiffExample();

  @override
  State<_CatalogDiffExample> createState() => _CatalogDiffExampleState();
}

final class _CatalogDiffExampleState extends State<_CatalogDiffExample> {
  var _proposal = 0;
  String? _activity;

  @override
  Widget build(BuildContext context) => _CatalogCard(
    title: 'Diff Table',
    caption:
        _activity ??
        'Review exact before/after values and apply selected changes',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BeautifulDiffTable(
          key: const Key('catalog-diff-table'),
          id: 'catalog-restock-proposal-$_proposal',
          title: 'Seasonal inventory proposal',
          pageSize: 3,
          columns: const <BeautifulDiffColumn>[
            BeautifulDiffColumn(id: 'flavor', label: 'Flavor'),
            BeautifulDiffColumn(id: 'quantity', label: 'Quantity'),
          ],
          rows: <BeautifulDiffRow>[
            BeautifulDiffRow(
              id: 'pistachio',
              before: const {'flavor': 'Pistachio', 'quantity': '100 tubs'},
              after: const {'flavor': 'Pistachio', 'quantity': '118 tubs'},
            ),
            BeautifulDiffRow(
              id: 'sorbet',
              after: const {'flavor': 'Mango sorbet', 'quantity': '40 tubs'},
            ),
            BeautifulDiffRow(
              id: 'rocky-road',
              before: const {'flavor': 'Rocky road', 'quantity': '24 tubs'},
            ),
            BeautifulDiffRow(
              id: 'vanilla',
              before: const {'flavor': 'Vanilla', 'quantity': '80 tubs'},
              after: const {'flavor': 'Vanilla', 'quantity': '80 tubs'},
            ),
          ],
          onApply: (ids) async {
            await Future<void>.delayed(const Duration(milliseconds: 120));
            if (!mounted) return;
            setState(
              () => _activity = 'Applied inventory changes: ${ids.join(', ')}',
            );
          },
        ),
        const SizedBox(height: 12),
        _CatalogButton(
          label: 'Reset sample proposal',
          onPressed: () => setState(() {
            _proposal++;
            _activity = null;
          }),
        ),
      ],
    ),
  );
}

final class _CatalogRecordsExample extends StatefulWidget {
  const _CatalogRecordsExample();

  @override
  State<_CatalogRecordsExample> createState() => _CatalogRecordsExampleState();
}

final class _CatalogRecordsExampleState extends State<_CatalogRecordsExample> {
  var _added = 0;
  var _activity = 'Inspect, search and configure local supplier records';
  late List<BeautifulRecordColumn> _columns = <BeautifulRecordColumn>[
    BeautifulRecordColumn(id: 'supplier', label: 'Supplier', width: 260),
    BeautifulRecordColumn(id: 'lead', label: 'Lead time', width: 180),
    BeautifulRecordColumn(
      id: 'summary',
      label: 'Review note',
      hideable: true,
      width: 300,
      property: BeautifulRecordPropertyConfig(
        toolId: 'sample',
        inputColumnIds: const ['supplier', 'lead'],
        prompt: 'Summarize the supplier lead time.',
      ),
    ),
  ];
  late List<BeautifulRecordRow> _rows = <BeautifulRecordRow>[
    for (final (id, name, days) in <(String, String, int)>[
      ('cone', 'Cone King', 7),
      ('dairy', 'Meadow Dairy', 3),
      ('fruit', 'Orchard Supply', 5),
      ('vanilla', 'Vanilla Madagascar', 14),
      ('cocoa', 'Cocoa Collective', 9),
    ])
      BeautifulRecordRow(
        id: id,
        label: name,
        cells: <String, BeautifulRecordCell>{
          'supplier': BeautifulRecordCell(text: name),
          'lead': BeautifulRecordCell(text: '$days days', number: days),
          'summary': BeautifulRecordCell(text: 'Awaiting review'),
        },
      ),
  ];

  @override
  Widget build(BuildContext context) => _CatalogCard(
    title: 'Records Table',
    caption: _activity,
    child: BeautifulRecordsTable(
      key: const Key('catalog-records-table'),
      id: 'catalog-suppliers',
      columns: _columns,
      rows: _rows,
      height: 340,
      tools: const <BeautifulRecordTool>[
        BeautifulRecordTool(id: 'sample', label: 'Sample rules'),
      ],
      onSelectionChanged: (ids) => setState(() {
        _activity = 'Selected supplier records: ${ids.length}';
      }),
      onSortChanged: (sort) => setState(() {
        _activity =
            'Sorted supplier records: ${sort.columnId} '
            '${sort.descending ? 'descending' : 'ascending'}';
      }),
      onQueryChanged: (query) => setState(() {
        _activity = 'Supplier search: $query';
      }),
      onPropertyChanged: (id, property) => setState(() {
        _columns = <BeautifulRecordColumn>[
          for (final column in _columns)
            if (column.id != id)
              column
            else
              BeautifulRecordColumn(
                id: column.id,
                label: column.label,
                property: property,
                width: column.width,
                hideable: column.hideable,
                sortable: column.sortable,
                summary: column.summary,
              ),
        ];
        _activity = 'Saved supplier property: $id';
      }),
      onPropertyAdded: (draft) => setState(() {
        final id = 'custom-${++_added}';
        _columns = <BeautifulRecordColumn>[
          ..._columns,
          BeautifulRecordColumn(
            id: id,
            label: draft.label,
            property: draft.property,
            hideable: true,
          ),
        ];
        _activity = 'Added supplier property: ${draft.label}';
      }),
      onRun: (request) async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        setState(() {
          _rows = <BeautifulRecordRow>[
            for (final row in _rows)
              if (!request.rowIds.contains(row.id))
                row
              else
                BeautifulRecordRow(
                  id: row.id,
                  label: row.label,
                  cells: <String, BeautifulRecordCell>{
                    ...row.cells,
                    request.columnId: BeautifulRecordCell(
                      text:
                          '${row.label}: ${row.cells['lead']!.text} lead time; '
                          'ready for review.',
                    ),
                  },
                ),
          ];
          _activity = 'Calculated ${request.rowIds.length} supplier records';
        });
      },
      onCellActivated: (row, column, cell) => setState(() {
        _activity = 'Opened ${row.label} · ${column.label}: ${cell.text}';
      }),
    ),
  );
}

final class _CatalogSidebarExample extends StatefulWidget {
  const _CatalogSidebarExample();

  @override
  State<_CatalogSidebarExample> createState() => _CatalogSidebarExampleState();
}

final class _CatalogSidebarExampleState extends State<_CatalogSidebarExample> {
  var _workspace = 'scoop';
  String? _item = 'overview';
  String? _recent;
  var _newChats = 0;
  var _activity = 'Overview';
  final _workspaces = <BeautifulSidebarWorkspace>[
    BeautifulSidebarWorkspace(id: 'scoop', label: 'Scoop Studio'),
    BeautifulSidebarWorkspace(id: 'seasonal', label: 'Seasonal Lab'),
  ];
  final _recents = <BeautifulSidebarRecent>[
    BeautifulSidebarRecent(id: 'forecast', label: 'September forecast'),
    BeautifulSidebarRecent(id: 'vendors', label: 'Supplier review'),
    BeautifulSidebarRecent(id: 'launch', label: 'Autumn flavor launch'),
  ];

  @override
  Widget build(BuildContext context) => _CatalogCard(
    title: 'Sidebar Nav',
    caption: 'Selected workspace: $_workspace · destination: $_activity',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final navigation = BeautifulSidebarNav(
          key: const Key('catalog-sidebar-nav'),
          workspaces: _workspaces,
          selectedWorkspaceId: _workspace,
          selectedItemId: _item,
          selectedRecentId: _recent,
          recents: _recents,
          items: <BeautifulSidebarItem>[
            BeautifulSidebarItem(id: 'overview', label: 'Overview'),
            BeautifulSidebarItem(
              id: 'inventory',
              label: 'Inventory review',
              count: '5',
            ),
            BeautifulSidebarItem(id: 'reports', label: 'Reports'),
          ],
          presentation: compact
              ? BeautifulSidebarPresentation.drawer
              : BeautifulSidebarPresentation.expanded,
          height: 500,
          onWorkspaceSelected: (workspace) =>
              setState(() => _workspace = workspace.id),
          onItemSelected: (item) => setState(() {
            _item = item.id;
            _recent = null;
            _activity = item.id;
          }),
          onRecentSelected: (recent) => setState(() {
            _recent = recent.id;
            _item = null;
            _activity = recent.label;
          }),
          onNewChat: () => setState(() {
            final id = 'new-${++_newChats}';
            _recents.insert(
              0,
              BeautifulSidebarRecent(
                id: id,
                label: 'New restock chat $_newChats',
              ),
            );
            _recent = id;
            _item = null;
            _activity = 'New restock chat $_newChats';
          }),
          onWorkspaceAction: (action) => setState(() {
            if (action == BeautifulSidebarWorkspaceAction.create) {
              final id = 'workspace-${_workspaces.length}';
              _workspaces.add(
                BeautifulSidebarWorkspace(
                  id: id,
                  label: 'Sample workspace ${_workspaces.length}',
                ),
              );
              _workspace = id;
            }
            _activity = 'Sample workspace action: ${action.name}';
          }),
          footerLabel: 'Usage overview',
          onFooterPressed: () => setState(
            () => _activity = '5 sample supplier records · 3 workflows',
          ),
        );
        final content = Container(
          key: const Key('catalog-sidebar-destination'),
          padding: const EdgeInsets.all(24),
          child: Text(
            'Workspace: $_workspace\n$_activity',
            style: BeautifulUiTheme.of(context).typography.body,
          ),
        );
        // A stable Flex parent preserves navigation disclosure/search state.
        return Flex(
          direction: compact ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: compact ? constraints.maxWidth : 288,
              child: navigation,
            ),
            SizedBox(
              width: compact
                  ? constraints.maxWidth
                  : constraints.maxWidth - 288,
              child: content,
            ),
          ],
        );
      },
    ),
  );
}

BeautifulFlowchartData _sampleWorkflow() => BeautifulFlowchartData(
  id: 'catalog-restock-workflow',
  nodes: <BeautifulFlowchartNode>[
    BeautifulFlowchartNode(
      id: 'trigger',
      kind: BeautifulFlowchartNodeKind.trigger,
      title: 'Inventory updated',
      caption: 'Start when the weekly stock count arrives',
      position: const Offset(40, 40),
    ),
    BeautifulFlowchartNode(
      id: 'stock',
      kind: BeautifulFlowchartNodeKind.condition,
      title: 'Check stock level',
      position: const Offset(460, 80),
      conditions: <BeautifulFlowchartCondition>[
        BeautifulFlowchartCondition(
          id: 'rule',
          label: 'If',
          sourceLabel: 'Inventory',
          fields: <BeautifulFlowchartField>[
            BeautifulFlowchartField(
              id: 'threshold',
              label: 'Stock threshold',
              valueId: '40',
              options: const <BeautifulFlowchartOption>[
                BeautifulFlowchartOption(id: '40', label: 'Below 40 tubs'),
                BeautifulFlowchartOption(id: '60', label: 'Below 60 tubs'),
                BeautifulFlowchartOption(id: '80', label: 'Below 80 tubs'),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
  edges: const <BeautifulFlowchartEdge>[
    BeautifulFlowchartEdge(
      id: 'start-stock',
      from: 'trigger',
      to: 'stock',
      label: 'Check availability',
    ),
  ],
);

final class _CatalogFlowchartExample extends StatefulWidget {
  const _CatalogFlowchartExample();

  @override
  State<_CatalogFlowchartExample> createState() =>
      _CatalogFlowchartExampleState();
}

final class _CatalogFlowchartExampleState
    extends State<_CatalogFlowchartExample> {
  var _data = _sampleWorkflow();
  var _activity =
      'Edit conditions in Steps or move nodes on the desktop Canvas';

  @override
  Widget build(BuildContext context) => _CatalogCard(
    title: 'Flowchart',
    caption: _activity,
    child: BeautifulFlowchart(
      key: const Key('catalog-flowchart'),
      data: _data,
      viewportHeight: 480,
      onChanged: (data) => setState(() {
        _data = data;
        final stock = data.nodes.firstWhere((node) => node.id == 'stock');
        _activity =
            'Accepted stock threshold: ${stock.conditions.single.fields.single.valueId} tubs '
            '· position ${stock.position.dx.toInt()}, ${stock.position.dy.toInt()}';
      }),
    ),
  );
}

List<BeautifulInsightPoint> _samplePoints(List<double> values, String unit) =>
    <BeautifulInsightPoint>[
      for (var i = 0; i < values.length; i++)
        BeautifulInsightPoint(
          id: 'week-${i + 1}',
          label: 'Week ${i + 1}',
          value: values[i],
          formattedValue: '${values[i].toInt()} $unit',
        ),
    ];

final class _CatalogInsightsExample extends StatefulWidget {
  const _CatalogInsightsExample();

  @override
  State<_CatalogInsightsExample> createState() =>
      _CatalogInsightsExampleState();
}

final class _CatalogInsightsExampleState
    extends State<_CatalogInsightsExample> {
  var _page = 'comparison';
  var _metric = 'lead';
  var _segment = 'pistachio';
  var _activity = 'Inspect exact sample observations and their textual data';

  @override
  Widget build(BuildContext context) => _CatalogCard(
    title: 'Insight Cards',
    caption: _activity,
    child: BeautifulInsightCards(
      key: const Key('catalog-insight-cards'),
      selectedPageId: _page,
      pages: <BeautifulInsightPage>[
        BeautifulInsightPage(
          id: 'comparison',
          title: 'Seasonal demand comparison',
          prose:
              'Pistachio demand rose each week while vanilla remained steady.',
          followUpLabel: 'Plan the pistachio restock',
          chart: BeautifulInsightComparison(
            title: 'Weekly tubs requested',
            summary: 'Pistachio rises from 80 to 118 tubs; vanilla rises from 75 to 80 tubs.',
            series: <BeautifulInsightSeries>[
              BeautifulInsightSeries(
                id: 'pistachio',
                label: 'Pistachio',
                valueLabel: '118 tubs',
                points: _samplePoints([80, 90, 105, 118], 'tubs'),
              ),
              BeautifulInsightSeries(
                id: 'vanilla',
                label: 'Vanilla',
                valueLabel: '80 tubs',
                tone: BeautifulInsightTone.neutral,
                points: _samplePoints([75, 78, 76, 80], 'tubs'),
              ),
            ],
          ),
        ),
        BeautifulInsightPage(
          id: 'anomaly',
          title: 'Supplier delivery watch',
          prose: 'Compare lead times with the supplied seven-day review threshold.',
          followUpLabel: 'Review delivery exceptions',
          chart: BeautifulInsightAnomaly(
            title: 'Delivery observations',
            summary: 'Lead time reaches nine days in week three before returning to six days.',
            selectedMetricId: _metric,
            metrics: <BeautifulInsightMetric>[
              BeautifulInsightMetric(
                id: 'lead',
                label: 'Lead time',
                valueLabel: '6 days',
                thresholdValue: 7,
                thresholdLabel: 'Review above 7 days',
                points: _samplePoints([5, 6, 9, 6], 'days'),
              ),
              BeautifulInsightMetric(
                id: 'delay',
                label: 'Late deliveries',
                valueLabel: '1 delivery',
                thresholdValue: 2,
                thresholdLabel: 'Review above 2 deliveries',
                points: _samplePoints([0, 1, 3, 1], 'deliveries'),
              ),
            ],
          ),
        ),
        BeautifulInsightPage(
          id: 'allocation',
          title: 'Restock allocation',
          prose: 'Pistachio receives half of the sample order, with vanilla and sorbet sharing the remainder.',
          followUpLabel: 'Review allocation plan',
          chart: BeautifulInsightAllocation(
            title: 'Order share by flavor',
            summary: 'Pistachio 50%, vanilla 30%, mango sorbet 20%.',
            selectedSegmentId: _segment,
            segments: const <BeautifulInsightAllocationSegment>[
              BeautifulInsightAllocationSegment(
                id: 'pistachio',
                label: 'Pistachio',
                share: 0.5,
                shareLabel: '50%',
                valueLabel: '100 tubs',
              ),
              BeautifulInsightAllocationSegment(
                id: 'vanilla',
                label: 'Vanilla',
                share: 0.3,
                shareLabel: '30%',
                valueLabel: '60 tubs',
              ),
              BeautifulInsightAllocationSegment(
                id: 'sorbet',
                label: 'Mango sorbet',
                share: 0.2,
                shareLabel: '20%',
                valueLabel: '40 tubs',
              ),
            ],
          ),
        ),
      ],
      onPageChanged: (id) => setState(() {
        _page = id;
        _activity = 'Selected insight: $id';
      }),
      onMetricChanged: (_, id) => setState(() {
        _metric = id;
        _activity = 'Selected delivery metric: $id';
      }),
      onSegmentChanged: (_, id) => setState(() {
        _segment = id;
        _activity = 'Selected order allocation: $id';
      }),
      onFollowUp: (id) =>
          setState(() => _activity = 'Opened insight follow-up: $id'),
    ),
  );
}

const _selectionSample =
    'We should maybe order some more pistachio tubs soon. '
    'Confirm the supplier lead time before sending the order.';

final class _CatalogSelectionExample extends StatefulWidget {
  const _CatalogSelectionExample();

  @override
  State<_CatalogSelectionExample> createState() =>
      _CatalogSelectionExampleState();
}

final class _CatalogSelectionExampleState
    extends State<_CatalogSelectionExample> {
  var _text = _selectionSample;
  var _document = 0;
  var _activity =
      'Select a passage, preview a sample edit, then keep or discard it';

  @override
  Widget build(BuildContext context) => _CatalogCard(
    title: 'Selection Actions',
    caption: _activity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        BeautifulSelectionActions(
          key: const Key('catalog-selection-actions'),
          documentId: 'catalog-restock-copy-$_document',
          text: _text,
          initialSelection: const TextSelection(
            baseOffset: 0,
            extentOffset: 52,
          ),
          onRequest: (request) async {
            await Future<void>.delayed(const Duration(milliseconds: 120));
            if (mounted) {
              setState(
                () =>
                    _activity = 'Prepared sample action: ${request.action.id}',
              );
            }
            return switch (request.action.id) {
              'explain' => 'This passage asks the team to review pistachio inventory before ordering.',
              'shorten' => 'Review the pistachio restock.',
              'tone' =>
                'Please review the pistachio restock at your convenience.',
              'grammar' => request.selectedText.replaceAll('maybe ', ''),
              'custom' =>
                '${request.selectedText.trim()} (${request.instruction})',
              _ => 'Review pistachio stock and confirm the required quantity.',
            };
          },
          onApply: (edit) {
            if (edit.request.baseText != _text) return;
            setState(() {
              _text = edit.updatedText;
              _activity = 'Accepted document edit: ${edit.request.action.id}';
            });
          },
        ),
        const SizedBox(height: 12),
        _CatalogButton(
          label: 'Reset sample document',
          onPressed: () => setState(() {
            _document++;
            _text = _selectionSample;
            _activity = 'Sample document restored';
          }),
        ),
      ],
    ),
  );
}
