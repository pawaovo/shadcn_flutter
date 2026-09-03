import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _points = <BeautifulInsightPoint>[
  BeautifulInsightPoint(
    id: 'a',
    label: 'Monday',
    value: -2,
    formattedValue: '-2%',
  ),
  BeautifulInsightPoint(
    id: 'b',
    label: 'Tuesday',
    value: 1,
    formattedValue: '+1%',
  ),
  BeautifulInsightPoint(
    id: 'c',
    label: 'Wednesday',
    value: 3,
    formattedValue: '+3%',
  ),
];

BeautifulInsightComparison _comparison({
  List<BeautifulInsightPoint> points = _points,
}) => BeautifulInsightComparison(
  title: 'Return comparison',
  summary: 'Returns recovered over three observations.',
  series: <BeautifulInsightSeries>[
    BeautifulInsightSeries(
      id: 'alpha',
      label: 'Alpha',
      valueLabel: '+3%',
      points: points,
    ),
    BeautifulInsightSeries(
      id: 'beta',
      label: 'Beta',
      valueLabel: '+3%',
      points: points,
      tone: BeautifulInsightTone.positive,
    ),
  ],
);

BeautifulInsightAnomaly _anomaly({String metric = 'spend'}) =>
    BeautifulInsightAnomaly(
      title: 'Freezer anomaly',
      summary: 'Spend and usage rose above their thresholds.',
      selectedMetricId: metric,
      metrics: <BeautifulInsightMetric>[
        BeautifulInsightMetric(
          id: 'spend',
          label: 'Spend',
          valueLabel: r'$2,112 spent',
          points: _points,
          thresholdValue: 2,
          thresholdLabel: r'$2 threshold',
        ),
        BeautifulInsightMetric(
          id: 'usage',
          label: 'Usage',
          valueLabel: '96 kWh',
          points: _points,
          thresholdValue: 1,
          thresholdLabel: '1 kWh threshold',
        ),
      ],
    );

BeautifulInsightAllocation _allocation({String segment = 'vanilla'}) =>
    BeautifulInsightAllocation(
      title: 'Allocation',
      summary: 'Vanilla represents most inventory value.',
      selectedSegmentId: segment,
      segments: const <BeautifulInsightAllocationSegment>[
        BeautifulInsightAllocationSegment(
          id: 'vanilla',
          label: 'Vanilla',
          share: 0.95,
          shareLabel: '95%',
          valueLabel: r'$950',
          detail: 'Vanilla inventory detail',
        ),
        BeautifulInsightAllocationSegment(
          id: 'mint',
          label: 'Mint',
          share: 0.05,
          shareLabel: '5%',
          valueLabel: r'$50',
          detail: 'Mint inventory detail',
        ),
      ],
    );

List<BeautifulInsightPage> _pages({
  String metric = 'spend',
  String segment = 'vanilla',
}) => <BeautifulInsightPage>[
  BeautifulInsightPage(
    id: 'compare',
    title: 'Portfolio',
    prose: 'Inspect actual observations.',
    chart: _comparison(),
    followUpLabel: 'Review allocation',
  ),
  BeautifulInsightPage(
    id: 'anomaly',
    title: 'Energy',
    prose: 'Inspect each energy metric.',
    chart: _anomaly(metric: metric),
  ),
  BeautifulInsightPage(
    id: 'allocation',
    title: 'Inventory',
    prose: 'Inspect inventory contributions.',
    chart: _allocation(segment: segment),
  ),
];

Widget _app({
  List<BeautifulInsightPage>? pages,
  String page = 'compare',
  ValueChanged<String>? onPageChanged,
  ValueChanged<String>? onFollowUp,
  void Function(String, String)? onMetricChanged,
  void Function(String, String)? onSegmentChanged,
  double width = 390,
  TextDirection direction = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  BeautifulInsightLabels labels = const BeautifulInsightLabels(),
}) => beautifulTestApp(
  size: Size(width, 1600),
  textDirection: direction,
  textScaler: textScaler,
  brightness: Brightness.dark,
  highContrast: true,
  disableAnimations: true,
  child: SizedBox(
    width: width,
    child: SingleChildScrollView(
      child: BeautifulInsightCards(
        pages: pages ?? _pages(),
        selectedPageId: page,
        onPageChanged: onPageChanged,
        onFollowUp: onFollowUp,
        onMetricChanged: onMetricChanged,
        onSegmentChanged: onSegmentChanged,
        labels: labels,
      ),
    ),
  ),
);

Finder _key(String name) =>
    find.byKey(ValueKey<String>('beautiful-insight-$name'));
String _observation(WidgetTester tester, [String page = 'compare']) =>
    tester.widget<Text>(_key('observation-$page')).data!;

void main() {
  test('snapshots reject malformed, unaligned, and oversized data', () {
    BeautifulInsightSeries series(List<BeautifulInsightPoint> points) =>
        BeautifulInsightSeries(
          id: 'series',
          label: 'Series',
          valueLabel: 'Value',
          points: points,
        );
    expect(() => series(const <BeautifulInsightPoint>[]), throwsArgumentError);
    expect(
      () => series(<BeautifulInsightPoint>[_points.first, _points.first]),
      throwsArgumentError,
    );
    expect(
      () => series(const <BeautifulInsightPoint>[
        BeautifulInsightPoint(
          id: 'bad',
          label: 'Invalid',
          value: double.nan,
          formattedValue: 'Invalid',
        ),
      ]),
      throwsArgumentError,
    );
    expect(
      () => series(
        List.generate(
          513,
          (i) => BeautifulInsightPoint(
            id: '$i',
            label: '$i',
            value: i.toDouble(),
            formattedValue: '$i',
          ),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => BeautifulInsightComparison(
        title: 'Compare',
        summary: 'Summary',
        series: <BeautifulInsightSeries>[
          series(_points),
          BeautifulInsightSeries(
            id: 'other',
            label: 'Other',
            valueLabel: 'Value',
            points: _points.reversed,
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(() => _anomaly(metric: 'missing'), throwsArgumentError);
    expect(() => _allocation(segment: 'missing'), throwsArgumentError);
    expect(
      () => BeautifulInsightMetric(
        id: 'm',
        label: 'Metric',
        valueLabel: '1',
        points: _points,
        thresholdValue: double.infinity,
        thresholdLabel: 'Infinite',
      ),
      throwsArgumentError,
    );
    expect(
      () => BeautifulInsightMetric(
        id: 'm',
        label: 'Metric',
        valueLabel: '1',
        points: _points,
        thresholdValue: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => BeautifulInsightCards(pages: _pages(), selectedPageId: 'missing'),
      throwsArgumentError,
    );
    expect(
      () => BeautifulInsightCards(
        pages: <BeautifulInsightPage>[_pages().first, _pages().first],
        selectedPageId: 'compare',
      ),
      throwsArgumentError,
    );
    expect(
      () => BeautifulInsightAllocation(
        title: 'Allocation',
        summary: 'Summary',
        segments: const <BeautifulInsightAllocationSegment>[
          BeautifulInsightAllocationSegment(
            id: 'one',
            label: 'One',
            share: 0.3,
            shareLabel: '30%',
            valueLabel: '30',
          ),
        ],
        selectedSegmentId: 'one',
      ),
      throwsArgumentError,
    );
  });

  test('snapshots defensively copy collections', () {
    final points = _points.toList();
    final series = BeautifulInsightSeries(
      id: 'one',
      label: 'One',
      valueLabel: '+3%',
      points: points,
    );
    points.clear();
    expect(series.points, hasLength(3));
    expect(() => series.points.clear(), throwsUnsupportedError);
    final pages = _pages();
    final widget = BeautifulInsightCards(
      pages: pages,
      selectedPageId: 'compare',
    );
    pages.clear();
    expect(widget.pages, hasLength(3));
    expect(() => widget.pages.clear(), throwsUnsupportedError);
  });

  testWidgets('empty insights expose a readable empty state', (tester) async {
    await tester.pumpWidget(
      beautifulTestApp(
        child: BeautifulInsightCards(
          pages: const <BeautifulInsightPage>[],
          selectedPageId: null,
        ),
      ),
    );
    expect(find.text('No insights'), findsOneWidget);
    expect(_key('next'), findsNothing);
  });

  testWidgets('navigation wraps and proposes IDs without accepting them', (
    tester,
  ) async {
    final proposals = <String>[];
    await tester.pumpWidget(_app(onPageChanged: proposals.add));
    await tester.tap(_key('previous'));
    await tester.tap(_key('next'));
    await tester.pump();
    expect(proposals, <String>['allocation', 'anomaly']);
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('Energy'), findsNothing);
    await tester.pumpWidget(
      _app(page: 'allocation', onPageChanged: proposals.add),
    );
    await tester.tap(_key('next'));
    expect(proposals.last, 'compare');
  });

  testWidgets(
    'follow-up delegates the active page and is disabled without callback',
    (tester) async {
      final actions = <String>[];
      await tester.pumpWidget(_app(onFollowUp: actions.add));
      await tester.ensureVisible(_key('followup-compare'));
      await tester.tap(_key('followup-compare'));
      expect(actions, <String>['compare']);
      await tester.pumpWidget(_app());
      await tester.tap(_key('followup-compare'));
      expect(actions, hasLength(1));
    },
  );

  testWidgets(
    'metric choices preserve controlled state and expose threshold data',
    (tester) async {
      final proposals = <(String, String)>[];
      await tester.pumpWidget(
        _app(
          page: 'anomaly',
          onMetricChanged: (page, metric) => proposals.add((page, metric)),
        ),
      );
      await tester.tap(_key('metric-anomaly-usage'));
      await tester.pump();
      expect(proposals, <(String, String)>[('anomaly', 'usage')]);
      expect(find.text(r'$2,112 spent'), findsOneWidget);
      expect(find.text(r'$2 threshold'), findsOneWidget);
      await tester.pumpWidget(
        _app(
          page: 'anomaly',
          pages: _pages(metric: 'usage'),
        ),
      );
      expect(find.text('96 kWh'), findsOneWidget);
      expect(find.text('1 kWh threshold'), findsOneWidget);
      expect(find.text(r'$2 threshold'), findsNothing);
    },
  );

  testWidgets('allocation bar and full-size legend propose the same segment', (
    tester,
  ) async {
    final proposals = <(String, String)>[];
    await tester.pumpWidget(
      _app(
        page: 'allocation',
        onSegmentChanged: (page, segment) => proposals.add((page, segment)),
      ),
    );
    final bar = _key('allocation-bar-allocation');
    await tester.tapAt(tester.getTopRight(bar) + const Offset(-2, 24));
    await tester.tap(_key('segment-allocation-mint'));
    await tester.pump();
    expect(proposals, <(String, String)>[
      ('allocation', 'mint'),
      ('allocation', 'mint'),
    ]);
    expect(find.text('Vanilla inventory detail'), findsOneWidget);
    expect(
      tester.getSize(_key('segment-allocation-mint')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.pumpWidget(
      _app(
        page: 'allocation',
        pages: _pages(segment: 'mint'),
      ),
    );
    expect(find.text('Mint inventory detail'), findsOneWidget);
    expect(find.text('Vanilla inventory detail'), findsNothing);
  });

  testWidgets(
    'pointer inspection uses exact data and keyboard supports Home End arrows',
    (tester) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xff000000),
          builder: (_, child) => _app(),
        ),
      );
      final plot = _key('plot-compare');
      await tester.tapAt(tester.getTopLeft(plot) + const Offset(13, 70));
      await tester.pump();
      expect(_observation(tester), 'Monday. Alpha: -2%. Beta: -2%');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_observation(tester), 'Tuesday. Alpha: +1%. Beta: +1%');
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(_observation(tester), startsWith('Wednesday'));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(_observation(tester), startsWith('Monday'));
    },
  );

  testWidgets('mouse hover and RTL pointer inspection mirror the domain axis', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(_app(direction: direction));
      final plot = _key('plot-compare');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getTopLeft(plot) + const Offset(13, 60));
      await tester.pump();
      expect(
        _observation(tester),
        startsWith(direction == TextDirection.ltr ? 'Monday' : 'Wednesday'),
      );
      await mouse.removePointer();
    }
  });

  testWidgets(
    'only active chart and requested textual observations are realized',
    (tester) async {
      await tester.pumpWidget(_app());
      expect(_key('plot-compare'), findsOneWidget);
      expect(_key('plot-anomaly'), findsNothing);
      expect(_key('datum-compare-a'), findsNothing);
      await tester.ensureVisible(_key('data-compare'));
      await tester.tap(_key('data-compare'));
      await tester.pump();
      expect(_key('datum-compare-a'), findsOneWidget);
      expect(_key('datum-compare-c'), findsOneWidget);
      await tester.tap(_key('data-compare'));
      await tester.pump();
      expect(_key('datum-compare-a'), findsNothing);
    },
  );

  testWidgets(
    'inspection and disclosure survive width changes and page reorder',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_app(width: 599));
      await tester.tap(_key('previous-point-compare'));
      await tester.tap(_key('data-compare'));
      await tester.pump();
      await tester.pumpWidget(
        _app(width: 1024, pages: _pages().reversed.toList()),
      );
      await tester.pump();
      expect(_observation(tester), startsWith('Tuesday'));
      expect(_key('datum-compare-a'), findsOneWidget);
      await tester.pumpWidget(_app(page: 'anomaly'));
      await tester.pumpWidget(_app());
      expect(_observation(tester), startsWith('Tuesday'));
      expect(_key('datum-compare-a'), findsOneWidget);
    },
  );

  testWidgets(
    'keyboard inspection keeps focus through compact and expanded resize',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      Widget atWidth(double width) => WidgetsApp(
        color: const Color(0xff000000),
        builder: (_, child) => _app(width: width),
      );

      await tester.pumpWidget(atWidth(599));
      await tester.tapAt(
        tester.getTopLeft(_key('plot-compare')) + const Offset(13, 70),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_observation(tester), startsWith('Tuesday'));

      await tester.pumpWidget(atWidth(1024));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_observation(tester), startsWith('Wednesday'));

      await tester.pumpWidget(atWidth(599));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_observation(tester), startsWith('Tuesday'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'replacing observations preserves matching identity and resets missing selection',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.ensureVisible(_key('previous-point-compare'));
      await tester.tap(_key('previous-point-compare'));
      await tester.pump();
      final nextPoints = <BeautifulInsightPoint>[
        const BeautifulInsightPoint(
          id: 'b',
          label: 'Tuesday revised',
          value: -8,
          formattedValue: '-8%',
        ),
        const BeautifulInsightPoint(
          id: 'new',
          label: 'Thursday',
          value: 10,
          formattedValue: '+10%',
        ),
      ];
      List<BeautifulInsightPage> pages(List<BeautifulInsightPoint> points) =>
          <BeautifulInsightPage>[
            BeautifulInsightPage(
              id: 'compare',
              title: 'Updated',
              prose: 'Updated data',
              chart: _comparison(points: points),
            ),
          ];
      await tester.pumpWidget(_app(pages: pages(nextPoints)));
      expect(_observation(tester), startsWith('Tuesday revised. Alpha: -8%'));
      await tester.pumpWidget(_app(pages: pages(nextPoints.skip(1).toList())));
      expect(_observation(tester), startsWith('Thursday. Alpha: +10%'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all variants fit boundary widths, RTL 200 percent, contrast and reduced motion',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 2200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in <double>[320, 599, 600, 1023, 1024]) {
        for (final page in <String>['compare', 'anomaly', 'allocation']) {
          await tester.pumpWidget(
            _app(
              width: width,
              page: page,
              direction: TextDirection.rtl,
              textScaler: const TextScaler.linear(2),
              labels: const BeautifulInsightLabels(
                previous: 'عرض الرؤية السابقة والبيانات',
                next: 'عرض الرؤية التالية والبيانات',
                showData: '显示所有观测值和对应日期的完整数据',
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$width $page');
          expect(
            tester.getSize(_key('previous')).height,
            greaterThanOrEqualTo(48),
          );
        }
      }
    },
  );

  testWidgets(
    'bounded maximum chart handles finite extremes without creating hidden data',
    (tester) async {
      final points = List.generate(
        512,
        (i) => BeautifulInsightPoint(
          id: '$i',
          label: 'Observation $i',
          value: i.isEven ? 1e308 : -1e308,
          formattedValue: 'Value $i',
        ),
      );
      final chart = BeautifulInsightComparison(
        title: 'Bounded workload',
        summary: 'Four exact series of 512 points.',
        series: List.generate(
          4,
          (i) => BeautifulInsightSeries(
            id: 's$i',
            label: 'Series $i',
            valueLabel: 'Current',
            points: points,
          ),
        ),
      );
      final watch = Stopwatch()..start();
      await tester.pumpWidget(
        _app(
          pages: <BeautifulInsightPage>[
            BeautifulInsightPage(
              id: 'compare',
              title: 'Workload',
              prose: 'Host supplied data',
              chart: chart,
            ),
          ],
        ),
      );
      await tester.pump();
      watch.stop();
      // Diagnostic only; hardware-dependent timing is not a pass/fail gate.
      debugPrint(
        'Insight maximum workload: ${watch.elapsedMicroseconds} us, 4 x 512 points; data collapsed.',
      );
      expect(_key('plot-compare'), findsOneWidget);
      expect(_key('datum-compare-0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
