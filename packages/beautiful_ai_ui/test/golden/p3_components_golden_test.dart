import 'dart:io';
import 'dart:typed_data';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_fonts.dart';
import '../test_harness.dart';

const _contentSize = Size(1440, 1180);
const _workspaceSize = Size(1440, 1800);
const _contentKey = Key('p3-content-fixture');
const _workspaceKey = Key('p3-workspace-fixture');

void main() {
  GoldenFileComparator? previousComparator;
  setUpAll(() async {
    await loadBeautifulTestFonts();
    if (Platform.isLinux) {
      final comparator = goldenFileComparator;
      if (comparator is! LocalFileComparator) {
        throw StateError('P3 Linux goldens require a local file comparator.');
      }
      previousComparator = comparator;
      goldenFileComparator = _P3LinuxCandidateComparator(
        comparator.basedir.resolve('p3_components_golden_test.dart'),
      );
    }
  });
  tearDownAll(() {
    final comparator = previousComparator;
    if (Platform.isLinux && comparator != null) {
      goldenFileComparator = comparator;
    }
  });

  test('missing Linux P3 baseline emits a candidate and still fails', () async {
    final scratch = await Directory.systemTemp.createTemp(
      'p3-golden-candidate-',
    );
    addTearDown(() => scratch.delete(recursive: true));
    final comparator = _P3LinuxCandidateComparator(
      scratch.uri.resolve('p3_components_golden_test.dart'),
    );
    final golden = Uri.parse('goldens/p3_content_light.png');
    final bytes = Uint8List.fromList(<int>[1, 2, 3]);
    await expectLater(
      comparator.compare(bytes, golden),
      throwsA(isA<TestFailure>()),
    );
    final candidate = File.fromUri(
      scratch.uri.resolve('failures/p3_content_light_testImage.png'),
    );
    expect(await candidate.readAsBytes(), orderedEquals(bytes));
    expect(
      await File.fromUri(scratch.uri.resolveUri(golden)).exists(),
      isFalse,
    );
  });

  for (final brightness in Brightness.values) {
    for (final workspace in <bool>[false, true]) {
      final name = workspace ? 'workspace' : 'content';
      testWidgets('P3 $name modules match the ${brightness.name} golden', (
        tester,
      ) async {
        final size = workspace ? _workspaceSize : _contentSize;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final boundary = Key('p3-$name-${brightness.name}');
        await tester.pumpWidget(
          beautifulTestApp(
            size: size,
            brightness: brightness,
            disableAnimations: true,
            motion: BeautifulMotionPolicy.none,
            child: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: brightness == Brightness.dark
                    ? const Color(0xff17181a)
                    : const Color(0xfffafafb),
                child: SizedBox.fromSize(
                  size: size,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: workspace
                          ? const _WorkspaceFixture()
                          : const _ContentFixture(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (!workspace) {
          // Invoke the public action to display a real host-provided result.
          await tester.tap(find.text('Improve'));
          await tester.pumpAndSettle();
          expect(find.text('Suggested text'), findsOneWidget);
          expect(find.text('Keep change'), findsOneWidget);
          expect(find.byType(BeautifulPromptBar), findsNWidgets(2));
          expect(find.byType(BeautifulSelectionActions), findsOneWidget);
          expect(find.byType(BeautifulInsightCards), findsNWidgets(3));
          for (final chart in <String>['comparison', 'anomaly', 'allocation']) {
            expect(
              find.byKey(ValueKey('beautiful-insight-card-$chart')),
              findsOneWidget,
            );
          }
        } else {
          expect(find.byType(BeautifulSidebarNav), findsOneWidget);
          expect(find.byType(BeautifulRecordsTable), findsOneWidget);
          expect(find.byType(BeautifulFlowchart), findsOneWidget);
          expect(find.byType(BeautifulDiffTable), findsOneWidget);
          expect(
            tester.getSize(find.byType(BeautifulRecordsTable)).width,
            greaterThanOrEqualTo(1024),
          );
          expect(
            tester.getSize(find.byType(BeautifulFlowchart)).width,
            greaterThanOrEqualTo(1024),
          );
          expect(
            find.byKey(const Key('beautiful-flowchart-viewer')),
            findsOneWidget,
          );
          expect(find.byType(SliverPersistentHeader), findsOneWidget);
          final tables = tester
              .widgetList<Semantics>(find.byType(Semantics))
              .where((widget) => widget.properties.role == SemanticsRole.table);
          expect(tables.length, greaterThanOrEqualTo(2));
          final viewport = tester.getRect(
            find.byKey(const Key('beautiful-flowchart-viewport')),
          );
          for (final node in <String>['trigger', 'condition']) {
            final bounds = tester.getRect(
              find.byKey(ValueKey('beautiful-flowchart-node-$node')),
            );
            expect(bounds.left, greaterThanOrEqualTo(viewport.left));
            expect(bounds.right, lessThanOrEqualTo(viewport.right));
            expect(bounds.top, greaterThanOrEqualTo(viewport.top));
            expect(bounds.bottom, lessThanOrEqualTo(viewport.bottom));
          }
        }
        expect(tester.takeException(), isNull);
        final bounds = tester.getRect(find.byKey(boundary));
        final content = tester.getRect(
          find.byKey(workspace ? _workspaceKey : _contentKey),
        );
        expect(content.left, greaterThanOrEqualTo(bounds.left + 32));
        expect(content.right, lessThanOrEqualTo(bounds.right - 32));
        expect(content.bottom, lessThanOrEqualTo(bounds.bottom - 32));
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile(
            'goldens/p3_${name}_${brightness.name}'
            '${Platform.isMacOS ? '_macos' : ''}.png',
          ),
        );
      }, skip: !(Platform.isLinux || Platform.isMacOS));
    }
  }
}

/// Produces review evidence without accepting an absent Linux baseline.
final class _P3LinuxCandidateComparator extends LocalFileComparator {
  _P3LinuxCandidateComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final canonical = File.fromUri(basedir.resolveUri(golden));
    if (!await canonical.exists()) {
      final candidate = getFailureFile('testImage', golden, basedir);
      await candidate.parent.create(recursive: true);
      await candidate.writeAsBytes(imageBytes, flush: true);
    }
    return super.compare(imageBytes, golden);
  }
}

final class _ContentFixture extends StatelessWidget {
  const _ContentFixture();

  @override
  Widget build(BuildContext context) => Column(
    key: _contentKey,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Section(
                  label: 'Prompt Bar / Rounded',
                  child: BeautifulPromptBar(
                    composerId: 'rounded',
                    initialDraft: 'Review supplier lead times for the weekend.',
                    initialAttachments: const [
                      BeautifulPromptAttachment(
                        id: 'inventory',
                        label: 'inventory.csv',
                      ),
                    ],
                    models: const [
                      BeautifulPromptModel(
                        id: 'fast',
                        label: 'Fast model',
                        description: 'Daily work',
                      ),
                    ],
                    selectedModelId: 'fast',
                    sources: const [
                      BeautifulPromptSource(
                        id: 'stock',
                        label: 'Inventory',
                        description: 'Supplier records',
                      ),
                    ],
                    onSend: (_) {},
                    onModelChanged: (_) {},
                    onAttach: () => const [],
                    onDictate: () => null,
                    tall: true,
                  ),
                ),
                const SizedBox(height: 28),
                _Section(
                  label: 'Prompt Bar / Pill',
                  child: BeautifulPromptBar(
                    composerId: 'pill',
                    variant: BeautifulPromptBarVariant.pill,
                    initialDraft: 'Summarize the weekly changes.',
                    onSend: (_) {},
                    onAttach: () => const [],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: _Section(
              label: 'Selection Actions / Edit preview',
              child: BeautifulSelectionActions(
                documentId: 'restock-note',
                text:
                    'Place the order soon. Confirm the delivery date with '
                    'the supplier before Friday.',
                initialSelection: const TextSelection(
                  baseOffset: 0,
                  extentOffset: 21,
                ),
                onRequest: (_) => 'Place the order today.',
                onApply: (_) {},
                documentMaxLines: 3,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 36),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (index, page) in _insightPages().indexed) ...<Widget>[
            if (index > 0) const SizedBox(width: 24),
            Expanded(
              child: _Section(
                label: 'Insight Cards / ${page.id}',
                child: BeautifulInsightCards(
                  pages: _insightPages(),
                  selectedPageId: page.id,
                  onPageChanged: (_) {},
                  onFollowUp: (_) {},
                  onMetricChanged: (_, _) {},
                  onSegmentChanged: (_, _) {},
                ),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

List<BeautifulInsightPage> _insightPages() {
  const first = <BeautifulInsightPoint>[
    BeautifulInsightPoint(
      id: 'mon',
      label: 'Monday',
      value: 12,
      formattedValue: '12%',
    ),
    BeautifulInsightPoint(
      id: 'tue',
      label: 'Tuesday',
      value: 18,
      formattedValue: '18%',
    ),
    BeautifulInsightPoint(
      id: 'wed',
      label: 'Wednesday',
      value: 14,
      formattedValue: '14%',
    ),
    BeautifulInsightPoint(
      id: 'thu',
      label: 'Thursday',
      value: 26,
      formattedValue: '26%',
    ),
  ];
  const second = <BeautifulInsightPoint>[
    BeautifulInsightPoint(
      id: 'mon',
      label: 'Monday',
      value: 8,
      formattedValue: '8%',
    ),
    BeautifulInsightPoint(
      id: 'tue',
      label: 'Tuesday',
      value: 11,
      formattedValue: '11%',
    ),
    BeautifulInsightPoint(
      id: 'wed',
      label: 'Wednesday',
      value: 17,
      formattedValue: '17%',
    ),
    BeautifulInsightPoint(
      id: 'thu',
      label: 'Thursday',
      value: 19,
      formattedValue: '19%',
    ),
  ];
  return <BeautifulInsightPage>[
    BeautifulInsightPage(
      id: 'comparison',
      title: 'Supplier performance',
      prose: 'Local suppliers improved their on-time delivery rate this week.',
      followUpLabel: 'Review supplier records',
      chart: BeautifulInsightComparison(
        title: 'On-time improvement',
        summary: 'Local suppliers gained 26%, compared with 19% for wholesale.',
        series: <BeautifulInsightSeries>[
          BeautifulInsightSeries(
            id: 'local',
            label: 'Local',
            valueLabel: '+26%',
            points: first,
          ),
          BeautifulInsightSeries(
            id: 'wholesale',
            label: 'Wholesale',
            valueLabel: '+19%',
            points: second,
            tone: BeautifulInsightTone.positive,
          ),
        ],
      ),
    ),
    BeautifulInsightPage(
      id: 'anomaly',
      title: 'Stock threshold',
      prose: 'Cone demand crossed the planned threshold on Thursday.',
      chart: BeautifulInsightAnomaly(
        title: 'Demand anomaly',
        summary: 'The final observation exceeded the 20% threshold.',
        selectedMetricId: 'demand',
        metrics: <BeautifulInsightMetric>[
          BeautifulInsightMetric(
            id: 'demand',
            label: 'Demand',
            valueLabel: '+26%',
            points: first,
            thresholdValue: 20,
            thresholdLabel: '20% threshold',
          ),
          BeautifulInsightMetric(
            id: 'orders',
            label: 'Orders',
            valueLabel: '+19%',
            points: second,
            thresholdValue: 20,
            thresholdLabel: '20% threshold',
          ),
        ],
      ),
    ),
    BeautifulInsightPage(
      id: 'allocation',
      title: 'Inventory allocation',
      prose: 'Classic flavors account for most of the weekly inventory value.',
      chart: BeautifulInsightAllocation(
        title: 'Inventory value',
        summary: 'Classic flavors represent 60% of the stock value.',
        selectedSegmentId: 'classic',
        segments: const <BeautifulInsightAllocationSegment>[
          BeautifulInsightAllocationSegment(
            id: 'classic',
            label: 'Classic',
            share: 0.6,
            shareLabel: '60%',
            valueLabel: r'$1,200',
            detail: 'Vanilla, chocolate, and mint.',
          ),
          BeautifulInsightAllocationSegment(
            id: 'seasonal',
            label: 'Seasonal',
            share: 0.25,
            shareLabel: '25%',
            valueLabel: r'$500',
            detail: 'Pistachio and summer berries.',
          ),
          BeautifulInsightAllocationSegment(
            id: 'limited',
            label: 'Limited',
            share: 0.15,
            shareLabel: '15%',
            valueLabel: r'$300',
            detail: 'Small-batch trial flavors.',
          ),
        ],
      ),
    ),
  ];
}

final class _WorkspaceFixture extends StatelessWidget {
  const _WorkspaceFixture();

  @override
  Widget build(BuildContext context) => Column(
    key: _workspaceKey,
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 288,
            child: _Section(
              label: 'Sidebar Nav',
              child: BeautifulSidebarNav(
                presentation: BeautifulSidebarPresentation.expanded,
                height: 590,
                workspaces: [
                  BeautifulSidebarWorkspace(
                    id: 'operations',
                    label: 'Operations workspace',
                  ),
                ],
                selectedWorkspaceId: 'operations',
                selectedItemId: 'overview',
                items: [
                  BeautifulSidebarItem(id: 'overview', label: 'Overview'),
                  BeautifulSidebarItem(
                    id: 'records',
                    label: 'Supplier records',
                    count: '12',
                  ),
                  BeautifulSidebarItem(id: 'workflow', label: 'Workflows'),
                ],
                recents: [
                  BeautifulSidebarRecent(
                    id: 'restock',
                    label: 'Weekend restock',
                  ),
                  BeautifulSidebarRecent(
                    id: 'delivery',
                    label: 'Delivery review',
                  ),
                  BeautifulSidebarRecent(
                    id: 'inventory',
                    label: 'Inventory notes',
                  ),
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
          ),
          const SizedBox(width: 32),
          Expanded(
            child: _Section(
              label: 'Flowchart / Expanded canvas',
              child: BeautifulFlowchart(
                data: _workflow(),
                onChanged: (_) {},
                viewportHeight: 400,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      _Section(label: 'Records Table / Expanded grid', child: _records()),
      const SizedBox(height: 28),
      _Section(
        label: 'Diff Table / Before and after',
        child: BeautifulDiffTable(
          id: 'menu-cleanup',
          title: 'Proposed menu cleanup',
          columns: const [
            BeautifulDiffColumn(id: 'flavor', label: 'Flavor'),
            BeautifulDiffColumn(id: 'supplier', label: 'Supplier'),
          ],
          rows: [
            BeautifulDiffRow(
              id: 'rocky',
              before: {'flavor': 'Rocky Road', 'supplier': 'Aurora Scoops'},
            ),
            BeautifulDiffRow(
              id: 'pistachio',
              after: {'flavor': 'Pistachio', 'supplier': 'Maple Orbit'},
            ),
            BeautifulDiffRow(
              id: 'mint',
              before: {'flavor': 'Mint Chip', 'supplier': 'Kumo Creamery'},
              after: {'flavor': 'Mint Chip', 'supplier': 'Maple Orbit'},
            ),
          ],
          initialIncludedRowIds: const {'rocky', 'pistachio'},
          onApply: (_) async {},
        ),
      ),
    ],
  );
}

BeautifulFlowchartData _workflow() => BeautifulFlowchartData(
  id: 'restock-workflow',
  nodes: [
    BeautifulFlowchartNode(
      id: 'trigger',
      kind: BeautifulFlowchartNodeKind.trigger,
      title: 'Inventory updated',
      caption: 'Start when a supplier record changes.',
      position: const Offset(32, 24),
    ),
    BeautifulFlowchartNode(
      id: 'condition',
      kind: BeautifulFlowchartNodeKind.condition,
      title: 'Check reorder category',
      position: const Offset(576, 176),
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
      id: 'trigger-condition',
      from: 'trigger',
      to: 'condition',
      label: 'Updated record',
    ),
  ],
);

BeautifulRecordsTable _records() => BeautifulRecordsTable(
  id: 'suppliers',
  height: 340,
  columns: [
    BeautifulRecordColumn(
      id: 'category',
      label: 'Category',
      width: 250,
      property: BeautifulRecordPropertyConfig(
        type: BeautifulRecordPropertyType.multiSelect,
      ),
      summary: '3 categories',
    ),
    BeautifulRecordColumn(
      id: 'lead',
      label: 'Lead time',
      width: 220,
      property: BeautifulRecordPropertyConfig(
        type: BeautifulRecordPropertyType.text,
      ),
      summary: 'Average 5 days',
    ),
    BeautifulRecordColumn(
      id: 'contact',
      label: 'Contact',
      width: 300,
      property: BeautifulRecordPropertyConfig(
        type: BeautifulRecordPropertyType.text,
      ),
      summary: '3 supplier contacts',
    ),
    BeautifulRecordColumn(
      id: 'review',
      label: 'Review',
      width: 260,
      property: BeautifulRecordPropertyConfig(
        toolId: 'review',
        inputColumnIds: const ['category'],
        prompt: 'Summarize delivery reliability.',
      ),
      summary: '3 records reviewed',
    ),
  ],
  tools: const [BeautifulRecordTool(id: 'review', label: 'Review model')],
  initialSelectedIds: const {'aurora'},
  rows: [
    BeautifulRecordRow(
      id: 'aurora',
      label: 'Aurora Scoops',
      cells: {
        'category': BeautifulRecordCell(
          text: 'Classic',
          tags: const ['Classic', 'Local'],
        ),
        'lead': BeautifulRecordCell(text: '3 days', number: 3),
        'contact': BeautifulRecordCell(text: 'hello@aurora.example'),
        'review': BeautifulRecordCell(text: 'Reliable weekly deliveries'),
      },
    ),
    BeautifulRecordRow(
      id: 'kumo',
      label: 'Kumo Creamery',
      cells: {
        'category': BeautifulRecordCell(text: 'Retro', tags: const ['Retro']),
        'lead': BeautifulRecordCell(text: '5 days', number: 5),
        'contact': BeautifulRecordCell(text: 'orders@kumo.example'),
        'review': BeautifulRecordCell(text: 'Confirm lead time for specials'),
      },
    ),
    BeautifulRecordRow(
      id: 'maple',
      label: 'Maple Orbit',
      cells: {
        'category': BeautifulRecordCell(
          text: 'Seasonal',
          tags: const ['Seasonal'],
        ),
        'lead': BeautifulRecordCell(text: '7 days', number: 7),
        'contact': BeautifulRecordCell(text: 'team@maple.example'),
        'review': BeautifulRecordCell(text: 'Reserve limited batches early'),
      },
    ),
  ],
  onSelectionChanged: (_) {},
  onPropertyChanged: (_, _) {},
  onPropertyAdded: (_) {},
  onRun: (_) {},
);

final class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = BeautifulUiTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          label,
          style: theme.typography.caption.copyWith(
            color: theme.colors.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
