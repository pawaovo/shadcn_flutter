import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _points = <BeautifulInsightPoint>[
  BeautifulInsightPoint(
    id: 'first',
    label: 'Monday',
    value: 10,
    formattedValue: r'$10',
  ),
  BeautifulInsightPoint(
    id: 'last',
    label: 'Tuesday',
    value: 20,
    formattedValue: r'$20',
  ),
];

final _comparison = BeautifulInsightComparison(
  title: 'Return chart',
  summary: 'Returns rose.',
  series: <BeautifulInsightSeries>[
    BeautifulInsightSeries(
      id: 'revenue',
      label: 'Revenue',
      valueLabel: r'$20',
      points: _points,
    ),
  ],
);
final _allocation = BeautifulInsightAllocation(
  title: 'Inventory chart',
  summary: 'Vanilla dominates.',
  selectedSegmentId: 'vanilla',
  segments: const <BeautifulInsightAllocationSegment>[
    BeautifulInsightAllocationSegment(
      id: 'vanilla',
      label: 'Vanilla',
      share: 0.95,
      shareLabel: '95%',
      valueLabel: r'$950',
    ),
    BeautifulInsightAllocationSegment(
      id: 'mint',
      label: 'Mint',
      share: 0.05,
      shareLabel: '5%',
      valueLabel: r'$50',
    ),
  ],
);

Widget _app({
  BeautifulInsightChart? chart,
  void Function(String, String)? onSegmentChanged,
  Brightness brightness = Brightness.light,
}) => beautifulTestApp(
  size: const Size(390, 1800),
  disableAnimations: true,
  highContrast: true,
  brightness: brightness,
  child: Builder(
    builder: (context) => ColoredBox(
      color: BeautifulUiTheme.of(context).colors.page,
      child: SizedBox(
        width: 390,
        child: SingleChildScrollView(
          child: BeautifulInsightCards(
            pages: <BeautifulInsightPage>[
              BeautifulInsightPage(
                id: 'page',
                title: 'Business insights',
                prose: 'An explanation supplied by the host.',
                chart: chart ?? _comparison,
                followUpLabel: 'Investigate',
              ),
            ],
            selectedPageId: 'page',
            onSegmentChanged: onSegmentChanged,
            onFollowUp: (_) {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'chart exposes textual alternative, exact values and bounded adjustment',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      const label = 'Return chart. Returns rose.';
      var data = tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData();
      expect(data.flagsCollection.isSlider, isTrue);
      expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(data.value, r'Tuesday. Revenue: $20');
      expect(data.decreasedValue, r'Monday. Revenue: $10');
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
      tester.semantics.decrease(find.semantics.byLabel(label));
      await tester.pump();
      data = tester
          .getSemantics(find.bySemanticsLabel(label))
          .getSemanticsData();
      expect(data.value, r'Monday. Revenue: $10');
      expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(data.increasedValue, r'Tuesday. Revenue: $20');
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isFalse);
      tester.semantics.increase(find.semantics.byLabel(label));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData()
            .value,
        r'Tuesday. Revenue: $20',
      );
      handle.dispose();
    },
  );

  testWidgets(
    'complete chart data enters semantics only when explicitly disclosed',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      const first = r'Monday. Revenue: $10';
      expect(find.bySemanticsLabel(first), findsNothing);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('View chart data'))
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        ui.Tristate.isFalse,
      );
      tester.semantics.tap(find.semantics.byLabel('View chart data'));
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp(RegExp.escape(first))), findsWidgets);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Hide chart data'))
            .getSemanticsData()
            .flagsCollection
            .isExpanded,
        ui.Tristate.isTrue,
      );
      tester.semantics.tap(find.semantics.byLabel('Hide chart data'));
      await tester.pump();
      expect(find.bySemanticsLabel(first), findsNothing);
      handle.dispose();
    },
  );

  testWidgets(
    'allocation labels expose every amount, share, selection and real action',
    (tester) async {
      final handle = tester.ensureSemantics();
      final selected = <(String, String)>[];
      await tester.pumpWidget(
        _app(
          chart: _allocation,
          onSegmentChanged: (page, segment) => selected.add((page, segment)),
        ),
      );
      const vanilla = r'Vanilla: 95%, $950';
      const mint = r'Mint: 5%, $50';
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(vanilla))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(mint))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isFalse,
      );
      tester.semantics.tap(find.semantics.byLabel(mint));
      await tester.pump();
      expect(selected, <(String, String)>[('page', 'mint')]);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(vanilla))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      handle.dispose();
    },
  );

  testWidgets('metric selection and disabled navigation expose native states', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final chart = BeautifulInsightAnomaly(
      title: 'Metrics',
      summary: 'Host analysis.',
      selectedMetricId: 'spend',
      metrics: <BeautifulInsightMetric>[
        BeautifulInsightMetric(
          id: 'spend',
          label: 'Spend',
          valueLabel: r'$20',
          points: _points,
        ),
        BeautifulInsightMetric(
          id: 'usage',
          label: 'Usage',
          valueLabel: '20 kWh',
          points: _points,
        ),
      ],
    );
    await tester.pumpWidget(_app(chart: chart));
    final spend = tester
        .getSemantics(
          find.byKey(const Key('beautiful-insight-metric-page-spend')),
        )
        .getSemanticsData();
    final usage = tester
        .getSemantics(
          find.byKey(const Key('beautiful-insight-metric-page-usage')),
        )
        .getSemanticsData();
    expect(spend.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(usage.flagsCollection.isSelected, ui.Tristate.isFalse);
    expect(spend.hasAction(SemanticsAction.tap), isFalse);
    final next = tester
        .getSemantics(find.bySemanticsLabel('Next insight'))
        .getSemanticsData();
    expect(next.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(next.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets(
    'all visible controls meet 48dp target and accessible name guidance',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final handle = tester.ensureSemantics();
      for (final chart in <BeautifulInsightChart>[_comparison, _allocation]) {
        await tester.pumpWidget(
          _app(chart: chart, onSegmentChanged: (_, _) {}),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }
      handle.dispose();
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets('high contrast text meets guidance in ${brightness.name}', (
      tester,
    ) async {
      await tester.pumpWidget(_app(brightness: brightness));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
