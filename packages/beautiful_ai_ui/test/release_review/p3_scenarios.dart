import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';

/// Small public-API snapshots for independent visual inspection, not baselines.
Map<String, Widget Function()> buildP3ReviewScenarios() => {
  'prompt-bar': () => BeautifulPromptBar(
    composerId: 'review-prompt',
    initialDraft: 'Review the supplier plan.\nInclude delivery dates.',
    initialAttachments: const [
      BeautifulPromptAttachment(id: 'plan', label: 'supplier-plan.csv'),
    ],
    models: const [BeautifulPromptModel(id: 'daily', label: 'Daily model')],
    selectedModelId: 'daily',
    onModelChanged: (_) {},
    onSend: (_) {},
    onAttach: () => const [],
    onDictate: () => null,
    tall: true,
  ),
  'diff-table': () => BeautifulDiffTable(
    id: 'review-diff',
    title: 'Supplier changes for review',
    columns: const [
      BeautifulDiffColumn(id: 'name', label: 'Supplier'),
      BeautifulDiffColumn(id: 'lead', label: 'Lead time'),
    ],
    rows: [
      BeautifulDiffRow(id: 'old', before: {'name': 'Aurora', 'lead': '7 days'}),
      BeautifulDiffRow(
        id: 'new',
        after: {'name': 'Maple Orbit', 'lead': '3 days'},
      ),
      BeautifulDiffRow(
        id: 'changed',
        before: {'name': 'Kumo', 'lead': '5 days'},
        after: {'name': 'Kumo', 'lead': '4 days'},
      ),
    ],
    initialIncludedRowIds: const {'old', 'new'},
    onApply: (_) async {},
  ),
  'records-table': () => BeautifulRecordsTable(
    id: 'review-records',
    height: 650,
    columns: [
      BeautifulRecordColumn(
        id: 'category',
        label: 'Category',
        property: BeautifulRecordPropertyConfig(
          type: BeautifulRecordPropertyType.multiSelect,
        ),
      ),
      BeautifulRecordColumn(
        id: 'review',
        label: 'Delivery review',
        property: BeautifulRecordPropertyConfig(
          toolId: 'summary',
          inputColumnIds: const ['category'],
          prompt: 'Summarize delivery reliability.',
        ),
      ),
    ],
    tools: const [BeautifulRecordTool(id: 'summary', label: 'Review model')],
    rows: [
      BeautifulRecordRow(
        id: 'aurora',
        label: 'Aurora Scoops',
        cells: {
          'category': BeautifulRecordCell(
            text: 'Classic',
            tags: const ['Classic', 'Local'],
          ),
          'review': BeautifulRecordCell(text: 'Reliable weekly delivery'),
        },
      ),
      BeautifulRecordRow(
        id: 'maple',
        label: 'Maple Orbit',
        cells: {
          'category': BeautifulRecordCell(text: 'Seasonal'),
          'review': BeautifulRecordCell(
            text: 'Review unavailable',
            status: BeautifulRecordCellStatus.failed,
            error: 'Check the supplier record.',
          ),
        },
      ),
    ],
    initialSelectedIds: const {'aurora'},
    onSelectionChanged: (_) {},
    onPropertyChanged: (_, _) {},
    onPropertyAdded: (_) {},
    onRun: (_) {},
  ),
  'sidebar-nav': () => Align(
    alignment: AlignmentDirectional.topStart,
    child: BeautifulSidebarNav(
      height: 720,
      workspaces: [
        BeautifulSidebarWorkspace(id: 'ops', label: 'Operations workspace'),
        BeautifulSidebarWorkspace(id: 'seasonal', label: 'Seasonal planning'),
      ],
      selectedWorkspaceId: 'ops',
      selectedItemId: 'suppliers',
      items: [
        BeautifulSidebarItem(id: 'overview', label: 'Overview'),
        BeautifulSidebarItem(
          id: 'suppliers',
          label: 'Supplier records',
          count: '12',
        ),
      ],
      recents: [
        BeautifulSidebarRecent(id: 'restock', label: 'Weekend restock plan'),
        BeautifulSidebarRecent(id: 'delivery', label: 'Delivery date review'),
      ],
      onWorkspaceSelected: (_) {},
      onWorkspaceAction: (_) {},
      onItemSelected: (_) {},
      onRecentSelected: (_) {},
      onNewChat: () {},
      footerLabel: 'Workspace settings',
      onFooterPressed: () {},
    ),
  ),
  'flowchart': () => BeautifulFlowchart(
    data: BeautifulFlowchartData(
      id: 'review-flow',
      nodes: [
        BeautifulFlowchartNode(
          id: 'trigger',
          kind: BeautifulFlowchartNodeKind.trigger,
          title: 'Inventory updated',
          caption: 'Review the latest supplier record.',
          position: const Offset(32, 24),
        ),
        BeautifulFlowchartNode(
          id: 'condition',
          kind: BeautifulFlowchartNodeKind.condition,
          title: 'Check the reorder category',
          position: const Offset(520, 24),
          conditions: [
            BeautifulFlowchartCondition(
              id: 'if',
              label: 'If',
              sourceLabel: 'Inventory record',
              fields: [
                BeautifulFlowchartField(
                  id: 'category',
                  label: 'Category',
                  valueId: 'seasonal',
                  options: const [
                    BeautifulFlowchartOption(id: 'seasonal', label: 'Seasonal'),
                    BeautifulFlowchartOption(id: 'classic', label: 'Classic'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      edges: const [
        BeautifulFlowchartEdge(
          id: 'next',
          from: 'trigger',
          to: 'condition',
          label: 'Changed record',
        ),
      ],
    ),
    onChanged: (_) {},
    viewportHeight: 520,
  ),
  'insight-cards': () => const _ReviewInsights(),
  'selection-actions': () => BeautifulSelectionActions(
    documentId: 'review-note',
    text: 'Place the order soon. Confirm delivery before Friday.',
    initialSelection: const TextSelection(baseOffset: 0, extentOffset: 21),
    onRequest: (_) => 'Place the order today.',
    onApply: (_) {},
    documentMaxLines: 3,
  ),
};

final class _ReviewInsights extends StatefulWidget {
  const _ReviewInsights();

  @override
  State<_ReviewInsights> createState() => _ReviewInsightsState();
}

final class _ReviewInsightsState extends State<_ReviewInsights> {
  String _page = 'comparison';
  String _metric = 'demand';
  String _segment = 'classic';

  static const _points = [
    BeautifulInsightPoint(
      id: 'mon',
      label: 'Monday',
      value: 12,
      formattedValue: '12%',
    ),
    BeautifulInsightPoint(
      id: 'tue',
      label: 'Tuesday',
      value: 26,
      formattedValue: '26%',
    ),
  ];

  @override
  Widget build(BuildContext context) => BeautifulInsightCards(
    selectedPageId: _page,
    onPageChanged: (id) => setState(() => _page = id),
    onMetricChanged: (_, id) => setState(() => _metric = id),
    onSegmentChanged: (_, id) => setState(() => _segment = id),
    onFollowUp: (_) {},
    pages: [
      BeautifulInsightPage(
        id: 'comparison',
        title: 'Supplier performance',
        prose: 'Local suppliers improved their on-time delivery rate.',
        followUpLabel: 'Review supplier records',
        chart: BeautifulInsightComparison(
          title: 'On-time improvement',
          summary: 'Both suppliers increased from 12% to 26%.',
          series: [
            BeautifulInsightSeries(
              id: 'local',
              label: 'Local',
              valueLabel: '+26%',
              points: _points,
            ),
            BeautifulInsightSeries(
              id: 'wholesale',
              label: 'Wholesale',
              valueLabel: '+26%',
              points: _points,
              tone: BeautifulInsightTone.positive,
            ),
          ],
        ),
      ),
      BeautifulInsightPage(
        id: 'anomaly',
        title: 'Stock threshold',
        prose: 'Demand crossed the planned threshold on Tuesday.',
        chart: BeautifulInsightAnomaly(
          title: 'Demand anomaly',
          summary: 'The final observation exceeded the 20% threshold.',
          selectedMetricId: _metric,
          metrics: [
            for (final id in ['demand', 'orders'])
              BeautifulInsightMetric(
                id: id,
                label: id == 'demand' ? 'Demand' : 'Orders',
                valueLabel: '+26%',
                points: _points,
                thresholdValue: 20,
                thresholdLabel: '20% threshold',
              ),
          ],
        ),
      ),
      BeautifulInsightPage(
        id: 'allocation',
        title: 'Inventory allocation',
        prose: 'Classic flavors account for most inventory value.',
        chart: BeautifulInsightAllocation(
          title: 'Inventory value',
          summary: 'Classic flavors represent 60% of inventory value.',
          selectedSegmentId: _segment,
          segments: const [
            BeautifulInsightAllocationSegment(
              id: 'classic',
              label: 'Classic',
              share: 0.6,
              shareLabel: '60%',
              valueLabel: r'$1,200',
              detail: 'Vanilla and chocolate.',
            ),
            BeautifulInsightAllocationSegment(
              id: 'seasonal',
              label: 'Seasonal',
              share: 0.4,
              shareLabel: '40%',
              valueLabel: r'$800',
              detail: 'Pistachio and berries.',
            ),
          ],
        ),
      ),
    ],
  );
}
