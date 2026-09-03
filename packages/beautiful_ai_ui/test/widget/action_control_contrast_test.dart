import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui/src/implementation/controls/action_control.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets(
    'muted tickers paint a replacement theme without leaving old fill',
    (tester) async {
      var dark = true;
      late StateSetter update;
      await tester.pumpWidget(
        beautifulTestApp(
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeautifulUiTheme(
                data: dark
                    ? const BeautifulUiThemeData.dark()
                    : const BeautifulUiThemeData.light(),
                child: TickerMode(
                  enabled: false,
                  child: BeautifulActionControl(
                    label: 'Execute action',
                    minHeight: 48,
                    onPressed: () {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      expect(_painted(tester).background, const BeautifulUiColors.dark().inset);
      update(() => dark = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final painted = _painted(tester);
      expect(painted.foreground, const BeautifulUiColors.light().ink);
      expect(painted.background, const BeautifulUiColors.light().inset);
    },
  );

  testWidgets('muted tickers paint selected state without leaving old fill', (
    tester,
  ) async {
    var selected = false;
    late StateSetter update;
    await tester.pumpWidget(
      beautifulTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return TickerMode(
              enabled: false,
              child: BeautifulActionControl(
                label: 'Execute action',
                selected: selected,
                minHeight: 48,
                onPressed: () {},
              ),
            );
          },
        ),
      ),
    );
    const colors = BeautifulUiColors.light();
    expect(_painted(tester).background, colors.inset);
    update(() => selected = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final painted = _painted(tester);
    expect(
      painted.background,
      Color.alphaBlend(colors.accentTint, colors.surface),
    );
    expect(painted.border.width, 2);
  });

  testWidgets(
    'muted tickers in reduced-motion Flowchart paint a replacement theme',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var dark = true;
      late StateSetter update;
      final data = BeautifulFlowchartData(
        id: 'stock-flow',
        nodes: [
          BeautifulFlowchartNode(
            id: 'condition',
            kind: BeautifulFlowchartNodeKind.condition,
            title: 'Check stock',
            position: const Offset(24, 24),
            conditions: [
              BeautifulFlowchartCondition(
                id: 'if',
                label: 'If',
                fields: [
                  BeautifulFlowchartField(
                    id: 'property',
                    label: 'Property',
                    valueId: 'stock',
                    options: const [
                      BeautifulFlowchartOption(
                        id: 'stock',
                        label: 'Stock threshold',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(1200, 844),
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeautifulUiScope(
                themeMode: dark
                    ? BeautifulUiThemeMode.dark
                    : BeautifulUiThemeMode.light,
                motion: BeautifulMotionPolicy.reduced,
                child: SingleChildScrollView(
                  child: BeautifulFlowchart(
                    data: data,
                    viewportHeight: 400,
                    onChanged: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byKey(
        const Key('beautiful-flowchart-field-condition-if-property'),
      );
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(TickerMode.valuesOf(tester.element(field)).enabled, isFalse);
      expect(
        _painted(
          tester,
          label: 'Property: Stock threshold',
          control: field,
        ).background,
        const BeautifulUiColors.dark().inset,
      );
      update(() => dark = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final painted = _painted(
        tester,
        label: 'Property: Stock threshold',
        control: field,
      );
      expect(painted.foreground, const BeautifulUiColors.light().ink);
      expect(painted.background, const BeautifulUiColors.light().inset);
      expect(TickerMode.valuesOf(tester.element(field)).enabled, isFalse);
    },
  );

  for (final brightness in Brightness.values) {
    for (final highContrast in <bool>[false, true]) {
      final variant = '${brightness.name}, highContrast=$highContrast';
      for (final tone in BeautifulActionTone.values) {
        for (final selected in <bool>[false, true]) {
          testWidgets(
            '$variant ${tone.name} selected=$selected text and outlines remain readable',
            (tester) async {
              final semantics = tester.ensureSemantics();
              final previousHighlightStrategy =
                  FocusManager.instance.highlightStrategy;
              FocusManager.instance.highlightStrategy =
                  FocusHighlightStrategy.alwaysTraditional;
              addTearDown(
                () => FocusManager.instance.highlightStrategy =
                    previousHighlightStrategy,
              );
              await tester.pumpWidget(
                _app(
                  brightness: brightness,
                  highContrast: highContrast,
                  child: BeautifulActionControl(
                    label: 'Execute action',
                    tone: tone,
                    selected: selected,
                    minHeight: 48,
                    onPressed: () {},
                  ),
                ),
              );
              final colors = BeautifulUiTheme.of(
                tester.element(find.text('Execute action')),
              ).colors;
              var painted = _painted(tester);
              final initialSize = tester.getSize(
                find.byType(BeautifulActionControl),
              );
              expect(
                _contrast(
                  painted.foreground,
                  painted.background,
                  colors.surface,
                ),
                greaterThanOrEqualTo(4.5),
              );
              expect(painted.border.width, selected ? 2 : 1);
              if (selected) {
                expect(
                  _contrast(
                    painted.border.color,
                    painted.background,
                    colors.surface,
                  ),
                  greaterThanOrEqualTo(3),
                );
              }
              expect(
                tester
                    .getSemantics(find.bySemanticsLabel('Execute action'))
                    .getSemanticsData()
                    .flagsCollection
                    .isSelected,
                selected ? ui.Tristate.isTrue : ui.Tristate.isFalse,
              );

              final mouse = await tester.createGesture(
                kind: PointerDeviceKind.mouse,
              );
              await mouse.addPointer(location: const Offset(700, 500));
              await mouse.moveTo(
                tester.getCenter(find.byType(BeautifulActionControl)),
              );
              await tester.pump();
              painted = _painted(tester);
              expect(
                _contrast(
                  painted.foreground,
                  painted.background,
                  colors.surface,
                ),
                greaterThanOrEqualTo(4.5),
              );
              expect(
                tester.getSize(find.byType(BeautifulActionControl)),
                initialSize,
              );
              if (selected) {
                expect(
                  _contrast(
                    painted.border.color,
                    painted.background,
                    colors.surface,
                  ),
                  greaterThanOrEqualTo(3),
                );
              }

              Focus.of(tester.element(find.text('Execute action')))
                  .requestFocus();
              await tester.pumpAndSettle();
              painted = _painted(tester);
              expect(painted.border.width, 3);
              expect(
                _contrast(
                  painted.border.color,
                  painted.background,
                  colors.surface,
                ),
                greaterThanOrEqualTo(3),
              );
              expect(
                tester.getSize(find.byType(BeautifulActionControl)),
                initialSize,
              );
              await mouse.removePointer();
              semantics.dispose();
            },
          );
        }
      }

      testWidgets(
        '$variant disabled selection keeps its visible non-color outline',
        (tester) async {
          final semantics = tester.ensureSemantics();
          var selected = false;
          late StateSetter update;
          await tester.pumpWidget(
            _app(
              brightness: brightness,
              highContrast: highContrast,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return BeautifulActionControl(
                    label: 'Saved choice',
                    selected: selected,
                    minHeight: 48,
                    onPressed: null,
                  );
                },
              ),
            ),
          );
          final initial = _painted(tester, label: 'Saved choice');
          final beforeSize = tester.getSize(
            find.byType(BeautifulActionControl),
          );
          update(() => selected = true);
          await tester.pump();
          final selectedPaint = _painted(tester, label: 'Saved choice');
          final colors = BeautifulUiTheme.of(
            tester.element(find.text('Saved choice')),
          ).colors;
          expect(initial.border.width, 1);
          expect(selectedPaint.border.width, 2);
          expect(
            _contrast(
              selectedPaint.border.color,
              selectedPaint.background,
              colors.surface,
            ),
            greaterThanOrEqualTo(3),
          );
          expect(
            tester.getSize(find.byType(BeautifulActionControl)),
            beforeSize,
          );
          final data = tester
              .getSemantics(find.bySemanticsLabel('Saved choice'))
              .getSemanticsData();
          expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
          expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets(
    'selected full-wrap action retains text and dimensions at 200 percent',
    (tester) async {
      const label =
          'A complete localized selection label that wraps across several lines';
      var selected = false;
      late StateSetter update;
      await tester.pumpWidget(
        beautifulTestApp(
          textScaler: TextScaler.linear(2),
          disableAnimations: true,
          child: SizedBox(
            width: 220,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return BeautifulActionControl(
                  label: label,
                  tone: BeautifulActionTone.quiet,
                  selected: selected,
                  maxLines: null,
                  minHeight: 48,
                  onPressed: () {},
                );
              },
            ),
          ),
        ),
      );
      final before = tester.getSize(find.byType(BeautifulActionControl));
      final unselected = _painted(tester, label: label);
      update(() => selected = true);
      await tester.pump();
      final selectedPaint = _painted(tester, label: label);
      expect(tester.getSize(find.byType(BeautifulActionControl)), before);
      expect(selectedPaint.background, isNot(unselected.background));
      expect(selectedPaint.border.width, greaterThan(unselected.border.width));
      expect(tester.widget<Text>(find.text(label)).maxLines, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _app({
  required Brightness brightness,
  required bool highContrast,
  required Widget child,
}) => beautifulTestApp(
  brightness: brightness,
  highContrast: highContrast,
  disableAnimations: true,
  child: child,
);

({Color background, Color foreground, BorderSide border}) _painted(
  WidgetTester tester, {
  String label = 'Execute action',
  Finder? control,
}) {
  final boxes = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: control ?? find.byType(BeautifulActionControl),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((box) => box.decoration)
      .whereType<BoxDecoration>();
  final background = boxes.singleWhere((box) => box.color != null).color!;
  final border =
      boxes.singleWhere((box) => box.border != null).border! as Border;
  final foreground = tester.widget<Text>(find.text(label)).style!.color!;
  return (background: background, foreground: foreground, border: border.top);
}

double _contrast(Color foreground, Color background, Color surface) {
  final paintedBackground = Color.alphaBlend(background, surface);
  final paintedForeground = Color.alphaBlend(foreground, paintedBackground);
  final a = paintedForeground.computeLuminance();
  final b = paintedBackground.computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}
