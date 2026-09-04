import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _lines = List.generate(
  1000,
  (index) => BeautifulToolDetailLine(
    text: 'tool-output-${index.toString().padLeft(4, '0')}',
  ),
);

final class _ScaleCount {
  var calls = 0;
}

final class _CountingScaler extends TextScaler {
  final _count = _ScaleCount();
  int get calls => _count.calls;
  set calls(int value) => _count.calls = value;

  @override
  double scale(double fontSize) {
    calls++;
    return fontSize;
  }

  @override
  double get textScaleFactor => 1;
}

Finder get _trigger =>
    find.byKey(const ValueKey('beautiful-tool-step-control-output'));

Widget _app({
  required TextScaler scaler,
  List<BeautifulToolDetailLine>? lines,
  BeautifulToolStatus status = BeautifulToolStatus.complete,
  bool disableAnimations = true,
  bool showTool = true,
}) => material.MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: scaler, disableAnimations: disableAnimations),
      child: BeautifulUiScope(
        child: material.SelectionArea(
          child: SingleChildScrollView(
            child: SizedBox(
              width: 390,
              child: Column(
                children: [
                  const Text('Host before'),
                  if (showTool)
                    BeautifulToolChips(
                      steps: [
                        BeautifulToolStep(
                          id: 'output',
                          label: 'Inspect output',
                          chip: 'retained-output',
                          status: status,
                          details: lines ?? _lines,
                        ),
                      ],
                    ),
                  const Text('Host after'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _selectAllAndCopy(WidgetTester tester) async {
  Focus.of(tester.element(find.text('Host before'))).requestFocus();
  final region = tester.state<SelectableRegionState>(
    find.byType(SelectableRegion),
  );
  region.selectAll();
  await tester.pump();
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<FocusNode> _focusControl(WidgetTester tester, Finder control) async {
  final node = Focus.of(
    tester.element(
      find
          .descendant(of: control, matching: find.byType(GestureDetector))
          .first,
    ),
  );
  node.requestFocus();
  await tester.pump();
  return node;
}

void main() {
  testWidgets(
    'reopening 1000 output lines reuses layout without exposing closed output to host copy',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var copied = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.hasStrings') return {'value': false};
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final scaler = _CountingScaler();
      await tester.pumpWidget(_app(scaler: scaler));
      await tester.pumpAndSettle();
      expect(find.text('tool-output-0999', skipOffstage: false), findsNothing);

      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(find.text('tool-output-0999'), findsOneWidget);
      await _selectAllAndCopy(tester);
      final expandedCopy = copied;
      expect(
        RegExp('tool-output-[0-9]{4}')
            .allMatches(copied)
            .map((match) => match.group(0))
            .toList(),
        _lines.map((line) => line.text).toList(),
      );
      expect(copied, contains('Host before'));
      expect(copied, contains('Host after'));

      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(find.text('tool-output-0000'), findsNothing);
      expect(
        find.text('tool-output-0000', skipOffstage: false).hitTestable(),
        findsNothing,
      );
      expect(find.bySemanticsLabel(RegExp('tool-output-')), findsNothing);
      await _selectAllAndCopy(tester);
      expect(copied, isNot(contains('tool-output-')));
      expect(copied, contains('Host before'));
      expect(copied, contains('Host after'));
      expect(tester.binding.transientCallbackCount, 0);

      scaler.calls = 0;
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(
        scaler.calls,
        lessThan(250),
        reason: 'Reopening unchanged output must not reshape 1000 paragraphs.',
      );
      expect(find.text('tool-output-0999'), findsOneWidget);
      await _selectAllAndCopy(tester);
      expect(copied, expandedCopy);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'closing the run excludes retained selection and focus and stops descendant motion',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var copied = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.hasStrings') return {'value': false};
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await tester.pumpWidget(
        _app(scaler: TextScaler.noScaling, disableAnimations: false),
      );
      await tester.pumpAndSettle();
      final stepFocus = await _focusControl(tester, _trigger);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('tool-output-0999'), findsOneWidget);
      expect(stepFocus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(stepFocus.hasFocus, isTrue);
      expect(find.text('tool-output-0000'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('tool-output-')), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      await _selectAllAndCopy(tester);
      final expandedCopy = copied;
      expect(
        RegExp('tool-output-[0-9]{4}').allMatches(copied),
        hasLength(1000),
      );
      final runControl = find.byKey(
        const ValueKey('beautiful-tool-chips-header'),
      );
      final runFocus = await _focusControl(tester, runControl);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(runFocus.hasFocus, isTrue);
      expect(stepFocus.hasFocus, isFalse);
      expect(stepFocus.canRequestFocus, isFalse);
      expect(find.bySemanticsLabel(RegExp('tool-output-')), findsNothing);
      expect(find.text('Inspect output'), findsNothing);
      expect(
        find.text('tool-output-0000', skipOffstage: false).hitTestable(),
        findsNothing,
      );
      expect(
        TickerMode.valuesOf(
          tester.element(find.text('tool-output-0000', skipOffstage: false)),
        ).enabled,
        isFalse,
      );
      await _selectAllAndCopy(tester);
      expect(copied, isNot(contains('tool-output-')));
      expect(copied, isNot(contains('Inspect output')));
      expect(tester.binding.transientCallbackCount, 0);

      await _focusControl(tester, runControl);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(stepFocus.canRequestFocus, isTrue);
      expect(find.text('tool-output-0999'), findsOneWidget);
      await _selectAllAndCopy(tester);
      expect(copied, expandedCopy);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'status snapshots reuse output while closed replacements and disposal stay current',
    (tester) async {
      var copied = '';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.hasStrings') return {'value': false};
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      await tester.pumpWidget(_app(scaler: TextScaler.noScaling));
      await tester.pumpAndSettle();
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(BeautifulToolChips));

      var outputBuilds = 0;
      final previous = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previous?.call(element, builtOnce);
        final widget = element.widget;
        if (widget is Text &&
            (widget.data?.startsWith('tool-output-') ?? false)) {
          outputBuilds++;
        }
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      await tester.pumpWidget(
        _app(
          scaler: TextScaler.noScaling,
          status: BeautifulToolStatus.running,
          lines: [
            for (final line in _lines)
              BeautifulToolDetailLine(text: line.text, tone: line.tone),
          ],
        ),
      );
      await tester.pumpAndSettle();
      debugOnRebuildDirtyWidget = previous;
      expect(tester.state(find.byType(BeautifulToolChips)), same(state));
      expect(outputBuilds, 0);
      expect(find.text('Running'), findsOneWidget);
      await _selectAllAndCopy(tester);
      expect(
        RegExp('tool-output-[0-9]{4}')
            .allMatches(copied)
            .map((match) => match.group(0))
            .toList(),
        _lines.map((line) => line.text).toList(),
      );

      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      final longLine = 'Replacement wrapping paragraph. ' * 30;
      final replacement = [
        BeautifulToolDetailLine(text: longLine),
        const BeautifulToolDetailLine(
          text: 'New addition',
          tone: BeautifulToolLineTone.addition,
        ),
        const BeautifulToolDetailLine(
          text: 'Removed output',
          tone: BeautifulToolLineTone.deletion,
        ),
        const BeautifulToolDetailLine(text: ''),
        const BeautifulToolDetailLine(text: 'Last replacement'),
      ];
      await tester.pumpWidget(
        _app(
          scaler: TextScaler.noScaling,
          status: BeautifulToolStatus.failed,
          lines: replacement,
        ),
      );
      await tester.pumpAndSettle();
      await _selectAllAndCopy(tester);
      expect(copied, isNot(contains('Replacement')));
      expect(copied, isNot(contains('tool-output-')));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(find.text(longLine), findsOneWidget);
      expect(find.text('+ New addition'), findsOneWidget);
      expect(find.text('− Removed output'), findsOneWidget);
      expect(find.text('Last replacement'), findsOneWidget);
      expect(find.text('tool-output-0000', skipOffstage: false), findsNothing);
      await _selectAllAndCopy(tester);
      expect(copied, contains(longLine));
      expect(copied, contains('+ New addition'));
      expect(copied, contains('− Removed output'));
      expect(copied, contains('Last replacement'));
      expect(copied, isNot(contains('tool-output-')));

      await tester.pumpWidget(
        _app(scaler: TextScaler.noScaling, showTool: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('Last replacement', skipOffstage: false), findsNothing);
      await _selectAllAndCopy(tester);
      expect(copied, contains('Host before'));
      expect(copied, contains('Host after'));
      expect(copied, isNot(contains('replacement')));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
