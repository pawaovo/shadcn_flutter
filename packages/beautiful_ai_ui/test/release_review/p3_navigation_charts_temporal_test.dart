import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

// These checks observe painted frames and geometry after real input. They do
// not turn motion-policy configuration or passing tests into visual acceptance.
void main() {
  const profiles = <_MotionProfile>[
    _MotionProfile('normal'),
    _MotionProfile('reduced', policy: BeautifulMotionPolicy.reduced),
    _MotionProfile('none', policy: BeautifulMotionPolicy.none, immediate: true),
    _MotionProfile(
      'platform disabled',
      disableAnimations: true,
      immediate: true,
    ),
    _MotionProfile('muted ticker', ticker: false, immediate: true),
  ];

  for (final control in _NavigationControl.values) {
    for (final profile in profiles) {
      testWidgets(
        'P3 ${control.title} ${profile.name}: held press paints, cancellation restores hover, release activates',
        (tester) async {
          _surface(tester);
          final disposeSemantics = _semantics(tester);
          final boundary = GlobalKey();
          final activations = <String>[];
          await tester.pumpWidget(
            _app(
              boundary: boundary,
              profile: profile,
              child: _navigation(control, activations.add),
            ),
          );
          await tester.pump();
          final target = find.byKey(control.key);
          final idle = await _paint(tester, boundary);
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(1300, 1000));
          await mouse.moveTo(tester.getCenter(target));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 160));
          final hover = await _paint(tester, boundary);
          expect(listEquals(idle, hover), isFalse, reason: 'Hover is visible.');

          await mouse.down(tester.getCenter(target));
          // A scrollable ancestor lets the tap recognizer wait for its press
          // deadline. Time zero below is the first recognized pressed frame.
          await tester.pump(kPressTimeout + const Duration(milliseconds: 1));
          final start = await _paint(tester, boundary);
          await tester.pump(const Duration(milliseconds: 30));
          final intermediate = await _paint(tester, boundary);
          await tester.pump(const Duration(milliseconds: 130));
          final held = await _paint(tester, boundary);
          expect(
            listEquals(held, hover),
            isFalse,
            reason: 'Press differs from hover.',
          );
          expect(activations, isEmpty, reason: 'Holding must not activate.');
          if (profile.immediate) {
            expect(listEquals(start, held), isTrue);
            expect(listEquals(intermediate, held), isTrue);
          } else {
            expect(listEquals(start, hover), isTrue);
            expect(listEquals(intermediate, hover), isFalse);
            expect(listEquals(intermediate, held), isFalse);
          }
          await tester.pump(const Duration(milliseconds: 500));
          expect(listEquals(await _paint(tester, boundary), held), isTrue);

          await mouse.cancel();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 160));
          expect(
            listEquals(await _paint(tester, boundary), hover),
            isTrue,
            reason: 'A cancelled pointer is still hovering; only its pressed state clears.',
          );
          expect(activations, isEmpty);
          expect(
            tester
                .getSemantics(target)
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            ui.Tristate.isFalse,
          );

          await mouse.down(tester.getCenter(target));
          await tester.pump(kPressTimeout + const Duration(milliseconds: 161));
          await mouse.up();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 160));
          if (control == _NavigationControl.sidebar) {
            expect(activations, <String>['records']);
          } else {
            expect(
              tester
                  .getSemantics(target)
                  .getSemanticsData()
                  .flagsCollection
                  .isSelected,
              ui.Tristate.isTrue,
            );
            expect(
              activations,
              isEmpty,
              reason: 'Selection alone does not edit the graph.',
            );
          }
          await mouse.removePointer();
          expect(tester.takeException(), isNull);
          disposeSemantics();
        },
      );
    }

    testWidgets(
      'P3 ${control.title}: keyboard focus paints and Enter remains actionable',
      (tester) async {
        _surface(tester);
        final disposeSemantics = _semantics(tester);
        final boundary = GlobalKey();
        final activations = <String>[];
        await tester.pumpWidget(
          _app(
            boundary: boundary,
            child: _navigation(control, activations.add),
          ),
        );
        await tester.pump();
        final idle = await _paint(tester, boundary);
        await _tabTo(tester, control);
        await tester.pump(const Duration(milliseconds: 160));
        final focused = await _paint(tester, boundary);
        expect(listEquals(focused, idle), isFalse);
        await tester.pump(const Duration(milliseconds: 500));
        expect(listEquals(await _paint(tester, boundary), focused), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        if (control == _NavigationControl.sidebar) {
          expect(activations, <String>['records']);
        } else {
          expect(
            tester
                .getSemantics(find.byKey(control.key))
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            ui.Tristate.isTrue,
          );
        }
        expect(tester.takeException(), isNull);
        disposeSemantics();
      },
    );
  }

  for (final profile in profiles.where((profile) => profile.ticker)) {
    testWidgets(
      'P3 Flowchart ${profile.name}: real fling samples viewport movement over time',
      (tester) async {
        _surface(tester);
        await tester.pumpWidget(
          _app(
            width: 1280,
            profile: profile,
            child: BeautifulFlowchart(data: _workflow(), onChanged: (_) {}),
          ),
        );
        await tester.pump();
        final extent = find.byKey(
          const Key('beautiful-flowchart-canvas-extent'),
        );
        final initial = tester.getTopLeft(extent);
        await tester.fling(
          find.byKey(const Key('beautiful-flowchart-viewport')),
          const Offset(-80, -60),
          1000,
        );
        await tester.pump();
        final release = tester.getTopLeft(extent);
        expect((release - initial).distance, greaterThan(20));
        final samples = <Offset>[];
        for (final elapsed in <int>[16, 48, 400]) {
          await tester.pump(Duration(milliseconds: elapsed));
          samples.add(tester.getTopLeft(extent));
        }
        if (profile.policy == BeautifulMotionPolicy.system &&
            !profile.disableAnimations) {
          expect((samples[0] - release).distance, greaterThan(1));
          expect((samples[1] - samples[0]).distance, greaterThan(1));
        } else {
          expect(samples, everyElement(release));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'P3 Flowchart: changing to reduced motion cancels active inertia without replaying it',
    (tester) async {
      _surface(tester);
      var profile = const _MotionProfile('normal');
      late StateSetter rebuild;
      final graph = _workflow();
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _app(
              width: 1280,
              profile: profile,
              child: BeautifulFlowchart(data: graph, onChanged: (_) {}),
            );
          },
        ),
      );
      await tester.pump();
      final extent = find.byKey(const Key('beautiful-flowchart-canvas-extent'));
      await tester.fling(
        find.byKey(const Key('beautiful-flowchart-viewport')),
        const Offset(-80, -60),
        1000,
      );
      await tester.pump();
      final release = tester.getTopLeft(extent);
      await tester.pump(const Duration(milliseconds: 32));
      final moving = tester.getTopLeft(extent);
      expect((moving - release).distance, greaterThan(1));
      rebuild(
        () => profile = const _MotionProfile(
          'reduced',
          policy: BeautifulMotionPolicy.reduced,
        ),
      );
      await tester.pump();
      expect(tester.getTopLeft(extent), moving);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getTopLeft(extent), moving);
      rebuild(() => profile = const _MotionProfile('normal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.getTopLeft(extent), moving);
      // Restoring the policy permits new inertia, but does not resurrect the old fling.
      await tester.fling(
        find.byKey(const Key('beautiful-flowchart-viewport')),
        const Offset(70, -60),
        1000,
      );
      await tester.pump();
      final freshRelease = tester.getTopLeft(extent);
      await tester.pump(const Duration(milliseconds: 32));
      expect(
        (tester.getTopLeft(extent) - freshRelease).distance,
        greaterThan(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in profiles.take(2)) {
    testWidgets(
      'P3 Insight ${profile.name}: Arabic RTL inspection selects exact observations and settles',
      (tester) async {
        _surface(tester);
        final disposeSemantics = _semantics(tester);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          _app(
            boundary: boundary,
            profile: profile,
            direction: TextDirection.rtl,
            child: _arabicInsights(),
          ),
        );
        await tester.pump();
        final plot = find.byKey(const Key('beautiful-insight-plot-week'));
        await tester.tapAt(tester.getTopRight(plot) + const Offset(-13, 60));
        await tester.pump();
        expect(_observation(tester), 'الاثنين. الطلب المتوقع: ١٢٪');
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(_observation(tester), 'الثلاثاء. الطلب المتوقع: ٢٦٪');
        final selected = await _plotPaint(tester, plot);
        for (final elapsed in <int>[16, 160, 500]) {
          await tester.pump(Duration(milliseconds: elapsed));
          expect(_observation(tester), 'الثلاثاء. الطلب المتوقع: ٢٦٪');
          expect(listEquals(await _plotPaint(tester, plot), selected), isTrue);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pump();
        expect(_observation(tester), 'الاثنين. الطلب المتوقع: ١٢٪');
        expect(listEquals(await _plotPaint(tester, plot), selected), isFalse);
        await tester.tap(find.byKey(const Key('beautiful-insight-data-week')));
        await tester.pump();
        expect(find.text('الاثنين. الطلب المتوقع: ١٢٪'), findsWidgets);
        expect(find.text('الثلاثاء. الطلب المتوقع: ٢٦٪'), findsOneWidget);
        expect(find.text('الأربعاء. الطلب المتوقع: ١٨٪'), findsOneWidget);
        expect(tester.takeException(), isNull);
        disposeSemantics();
      },
    );
  }

  for (final language in _DataLanguage.values) {
    testWidgets(
      'P3 Insight ${language.name}: 512 complete rows stay lazy and reachable by touch keyboard and semantics',
      (tester) async {
        _surface(tester);
        final disposeSemantics = _semantics(tester);
        await tester.pumpWidget(
          _app(
            direction: language == _DataLanguage.arabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            textScaler: language == _DataLanguage.english
                ? TextScaler.noScaling
                : const TextScaler.linear(2),
            highContrast: true,
            child: _denseInsights(language),
          ),
        );
        final disclosure = find.byKey(
          const Key('beautiful-insight-data-dense'),
        );
        await tester.ensureVisible(disclosure);
        await tester.pumpAndSettle();
        await tester.tap(disclosure);
        await tester.pumpAndSettle();
        expect(
          _realizedDataRows(),
          lessThan(64),
          reason: 'Opening must not build all 512 rows.',
        );
        final list = find.byKey(
          const Key('beautiful-insight-data-scroll-dense'),
        );
        expect(list, findsOneWidget);
        final controller = tester.widget<ListView>(list).controller!;
        final first = find.byKey(const Key('beautiful-insight-datum-dense-p0'));
        final last = find.byKey(
          const Key('beautiful-insight-datum-dense-p511'),
        );
        expect(first, findsOneWidget);
        expect(last, findsNothing);
        await tester.ensureVisible(list);
        await tester.pumpAndSettle();
        expect(tester.getSize(list).height, inInclusiveRange(200, 480));

        await tester.drag(list, const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        expect(_realizedDataRows(), lessThan(64));
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pumpAndSettle();
        expect(controller.offset, 0);
        _expectCompleteDatum(tester, first, language, 0);

        final scrollSemantics = find.semantics.byPredicate(
          (node) => node.getSemanticsData().scrollChildCount == 512,
        );
        expect(scrollSemantics, findsOne);
        tester.semantics.scrollUp(scrollable: scrollSemantics);
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(0));
        expect(_realizedDataRows(), lessThan(64));

        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pumpAndSettle();
        expect(last, findsOneWidget);
        _expectCompleteDatum(tester, last, language, 511);
        expect(controller.position.extentAfter, lessThan(1));
        expect(_realizedDataRows(), lessThan(64));
        final end = controller.offset;
        await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
        await tester.pumpAndSettle();
        expect(controller.offset, lessThan(end));
        await tester.sendKeyEvent(LogicalKeyboardKey.home);
        await tester.pumpAndSettle();
        expect(controller.offset, 0);
        _expectCompleteDatum(tester, first, language, 0);
        await tester.ensureVisible(disclosure);
        await tester.pumpAndSettle();
        await tester.tap(disclosure);
        await tester.pumpAndSettle();
        expect(_realizedDataRows(), 0);
        expect(list, findsNothing);
        expect(tester.takeException(), isNull);
        disposeSemantics();
      },
    );
  }

  for (final wheel in <bool>[true, false]) {
    testWidgets(
      'P3 Insight pending End yields to ${wheel ? 'wheel' : 'drag'} input',
      (tester) async {
        _surface(tester);
        await tester.pumpWidget(
          _app(child: _denseInsights(_DataLanguage.english)),
        );
        final list = await _openDenseData(tester);
        final controller = tester.widget<ListView>(list).controller!;
        await tester.tap(list);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await _settleEnd(tester, controller);
        final end = controller.offset;
        // A fresh End queues work even when already at the actual end. Input
        // before its next frame must take priority over that queued request.
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        if (wheel) {
          await tester.sendEventToBinding(
            PointerScrollEvent(
              position: tester.getCenter(list),
              scrollDelta: const Offset(0, -180),
            ),
          );
        } else {
          await tester.drag(list, const Offset(0, 180));
        }
        expect(controller.offset, lessThan(end - 100));
        await tester.pumpAndSettle();
        expect(controller.position.extentAfter, greaterThan(100));
        final userOffset = controller.offset;
        await tester.pump(const Duration(milliseconds: 500));
        expect(controller.offset, userOffset);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'P3 Insight pending End is cancelled by changed data and a fresh End converges through alternating heights',
    (tester) async {
      _surface(tester);
      var insights = _denseInsights(_DataLanguage.english);
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return _app(child: insights);
          },
        ),
      );
      final list = await _openDenseData(tester);
      final controller = tester.widget<ListView>(list).controller!;
      await tester.tap(list);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      // Replace the accepted data before the pending End can refine its old
      // estimate. The updated rows are much taller on alternating indices.
      update(() {
        insights = _denseInsights(
          _DataLanguage.english,
          alternatingHeights: true,
          revision: ' revised',
        );
      });
      await tester.pump();
      expect(controller.position.extentAfter, greaterThan(1000));
      final updatedOffset = controller.offset;
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.offset, updatedOffset);
      expect(_realizedDataRows(), lessThan(64));

      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await _settleEnd(tester, controller);
      final last = find.byKey(const Key('beautiful-insight-datum-dense-p511'));
      expect(last, findsOneWidget);
      final text = tester.widget<Text>(last).data!;
      for (var series = 0; series < 4; series++) {
        expect(text, contains('$series:511 revised'));
      }
      expect(_realizedDataRows(), lessThan(64));
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

enum _NavigationControl {
  sidebar('Sidebar', Key('beautiful-sidebar-item-records'), '采购记录与需求计划'),
  workflow(
    'Flowchart header',
    Key('beautiful-flowchart-node-start'),
    'Trigger: تحقق من سجلات التوريد',
  );

  const _NavigationControl(this.title, this.key, this.label);
  final String title;
  final Key key;
  final String label;
}

final class _MotionProfile {
  const _MotionProfile(
    this.name, {
    this.policy = BeautifulMotionPolicy.system,
    this.disableAnimations = false,
    this.ticker = true,
    this.immediate = false,
  });
  final String name;
  final BeautifulMotionPolicy policy;
  final bool disableAnimations;
  final bool ticker;
  final bool immediate;
}

void _surface(WidgetTester tester) {
  final highlightStrategy = FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy = highlightStrategy,
  );
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 1200);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _app({
  required Widget child,
  GlobalKey? boundary,
  double width = 390,
  _MotionProfile profile = const _MotionProfile('normal'),
  TextDirection direction = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  bool highContrast = false,
}) => WidgetsApp(
  color: const Color(0xff000000),
  builder: (_, _) => beautifulTestApp(
    size: Size(width, 1100),
    motion: profile.policy,
    disableAnimations: profile.disableAnimations,
    textDirection: direction,
    textScaler: textScaler,
    highContrast: highContrast,
    child: FocusScope(
      autofocus: true,
      child: TickerMode(
        enabled: profile.ticker,
        child: SingleChildScrollView(
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  ),
);

Widget _navigation(
  _NavigationControl control,
  ValueChanged<String> onActivated,
) => switch (control) {
  _NavigationControl.sidebar => Align(
    alignment: AlignmentDirectional.topStart,
    child: BeautifulSidebarNav(
      height: 420,
      presentation: BeautifulSidebarPresentation.expanded,
      workspaces: [BeautifulSidebarWorkspace(id: 'ops', label: '采购工作区')],
      selectedWorkspaceId: 'ops',
      items: [BeautifulSidebarItem(id: 'records', label: control.label)],
      onItemSelected: (item) => onActivated(item.id),
    ),
  ),
  _NavigationControl.workflow => BeautifulFlowchart(
    data: _workflow(),
    onChanged: (next) => onActivated(next.id),
  ),
};

BeautifulFlowchartData _workflow() => BeautifulFlowchartData(
  id: 'procurement',
  nodes: [
    BeautifulFlowchartNode(
      id: 'start',
      kind: BeautifulFlowchartNodeKind.trigger,
      title: 'تحقق من سجلات التوريد',
      caption: 'راجع مواعيد التسليم قبل تأكيد الطلب.',
      position: const Offset(32, 24),
    ),
  ],
  edges: const [],
);

Future<Uint8List> _paint(WidgetTester tester, GlobalKey boundary) => _pixels(
  tester,
  boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary,
);

Future<Uint8List> _plotPaint(WidgetTester tester, Finder plot) => _pixels(
  tester,
  tester.renderObject<RenderRepaintBoundary>(
    find.ancestor(of: plot, matching: find.byType(RepaintBoundary)).first,
  ),
);

Future<Uint8List> _pixels(
  WidgetTester tester,
  RenderRepaintBoundary render,
) async => (await tester.runAsync(() async {
  final image = await render.toImage(pixelRatio: 1);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.fromList(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}))!;

VoidCallback _semantics(WidgetTester tester) {
  final handle = tester.ensureSemantics();
  var active = true;
  void dispose() {
    if (active) {
      active = false;
      handle.dispose();
    }
  }

  addTearDown(dispose);
  return dispose;
}

Future<void> _tabTo(WidgetTester tester, _NavigationControl control) async {
  for (var step = 0; step < 12; step++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (tester
            .getSemantics(find.byKey(control.key))
            .getSemanticsData()
            .flagsCollection
            .isFocused ==
        ui.Tristate.isTrue) {
      return;
    }
  }
  fail('Keyboard traversal did not reach ${control.label}.');
}

BeautifulInsightCards _arabicInsights() => BeautifulInsightCards(
  selectedPageId: 'week',
  pagePositionLabel: '١ من ١',
  labels: const BeautifulInsightLabels(
    title: 'الرؤى',
    previous: 'الرؤية السابقة',
    next: 'الرؤية التالية',
    showData: 'عرض بيانات الرسم',
    hideData: 'إخفاء بيانات الرسم',
    previousPoint: 'الملاحظة السابقة',
    nextPoint: 'الملاحظة التالية',
    inspectHint: 'استخدم مفاتيح الأسهم لفحص الملاحظات.',
    empty: 'لا توجد رؤى',
  ),
  pages: [
    BeautifulInsightPage(
      id: 'week',
      title: 'مراجعة الطلب خلال الأسبوع',
      prose: 'قارن القيم المسجلة لكل يوم قبل تأكيد خطة التوريد.',
      chart: BeautifulInsightComparison(
        title: 'الطلب اليومي',
        summary: 'القيم مأخوذة من السجلات المعتمدة.',
        series: [
          BeautifulInsightSeries(
            id: 'demand',
            label: 'الطلب المتوقع',
            valueLabel: '١٨٪',
            points: const [
              BeautifulInsightPoint(
                id: 'mon',
                label: 'الاثنين',
                value: 12,
                formattedValue: '١٢٪',
              ),
              BeautifulInsightPoint(
                id: 'tue',
                label: 'الثلاثاء',
                value: 26,
                formattedValue: '٢٦٪',
              ),
              BeautifulInsightPoint(
                id: 'wed',
                label: 'الأربعاء',
                value: 18,
                formattedValue: '١٨٪',
              ),
            ],
          ),
        ],
      ),
    ),
  ],
);

String _observation(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('beautiful-insight-observation-week')))
    .data!;

enum _DataLanguage { english, chinese, arabic }

List<String> _seriesLabels(_DataLanguage language) => switch (language) {
  _DataLanguage.english => const [
    'Confirmed demand',
    'Warehouse inventory',
    'Planned deliveries',
    'Available capacity',
  ],
  _DataLanguage.chinese => const ['已确认需求', '仓库现有库存', '计划到货数量', '可用处理能力'],
  _DataLanguage.arabic => const [
    'الطلب المؤكد',
    'المخزون الحالي',
    'التسليم المخطط',
    'القدرة المتاحة',
  ],
};

String _domainLabel(_DataLanguage language, int index) => switch (language) {
  _DataLanguage.english =>
    'Observation $index${index % 9 == 0 ? ' from the complete supplier record with verified delivery dates and warehouse availability' : ''}',
  _DataLanguage.chinese =>
    '第 $index 条观测${index % 9 == 0 ? '，包括已经核对的供应商到货日期与仓库可用数量' : ''}',
  _DataLanguage.arabic =>
    'الملاحظة $index${index % 9 == 0 ? ' من سجل المورد الكامل بعد مراجعة مواعيد التسليم والمخزون المتاح' : ''}',
};

BeautifulInsightCards _denseInsights(
  _DataLanguage language, {
  bool alternatingHeights = false,
  String revision = '',
}) => BeautifulInsightCards(
  selectedPageId: 'dense',
  pages: [
    BeautifulInsightPage(
      id: 'dense',
      title: _domainLabel(language, 511),
      prose: _domainLabel(language, 0),
      chart: BeautifulInsightComparison(
        title: _seriesLabels(language).first,
        summary: _domainLabel(language, 1),
        series: List.generate(
          4,
          (series) => BeautifulInsightSeries(
            id: 's$series',
            label: _seriesLabels(language)[series],
            valueLabel: '$series:511',
            points: List.generate(
              512,
              (index) => BeautifulInsightPoint(
                id: 'p$index',
                label:
                    '${_domainLabel(language, index)}${alternatingHeights && index.isOdd ? List.filled(8, ' Complete accepted supplier record with verified quantities and delivery dates.').join() : ''}',
                value: (series * 512 + index).toDouble(),
                formattedValue: '$series:$index$revision',
              ),
            ),
          ),
        ),
      ),
    ),
  ],
);

int _realizedDataRows() => find
    .byWidgetPredicate((widget) {
      final key = widget.key;
      return widget is Text &&
          key is ValueKey<String> &&
          key.value.startsWith('beautiful-insight-datum-dense-');
    })
    .evaluate()
    .length;

Future<Finder> _openDenseData(WidgetTester tester) async {
  final disclosure = find.byKey(const Key('beautiful-insight-data-dense'));
  await tester.ensureVisible(disclosure);
  await tester.pumpAndSettle();
  await tester.tap(disclosure);
  await tester.pumpAndSettle();
  final list = find.byKey(const Key('beautiful-insight-data-scroll-dense'));
  await tester.ensureVisible(list);
  await tester.pumpAndSettle();
  return list;
}

Future<void> _settleEnd(
  WidgetTester tester,
  ScrollController controller,
) async {
  var stableFrames = 0;
  var previous = controller.offset;
  final samples = <String>[];
  for (var frame = 0; frame < 16 && stableFrames < 2; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    samples.add('${controller.offset}/${controller.position.maxScrollExtent}');
    if (controller.position.extentAfter <= 0.5 &&
        controller.offset == previous) {
      stableFrames++;
    } else {
      stableFrames = 0;
    }
    previous = controller.offset;
  }
  expect(
    stableFrames,
    2,
    reason: 'End must converge within 16 layout frames: $samples',
  );
  final end = controller.offset;
  await tester.pump(const Duration(milliseconds: 500));
  expect(controller.offset, end);
}

void _expectCompleteDatum(
  WidgetTester tester,
  Finder row,
  _DataLanguage language,
  int index,
) {
  final text = tester.widget<Text>(row).data!;
  final semantics = tester.getSemantics(row).getSemanticsData();
  expect(text, contains(_domainLabel(language, index)));
  for (var series = 0; series < 4; series++) {
    final value = '${_seriesLabels(language)[series]}: $series:$index';
    expect(text, contains(value));
    expect(semantics.label, contains(value));
  }
  expect(tester.renderObject<RenderParagraph>(row).didExceedMaxLines, isFalse);
}
