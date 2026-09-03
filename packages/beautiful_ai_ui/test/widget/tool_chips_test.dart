import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

BeautifulToolStep _step({
  String id = 'verify',
  BeautifulToolStatus status = BeautifulToolStatus.complete,
  BeautifulToolKind kind = BeautifulToolKind.run,
}) => BeautifulToolStep(
  id: id,
  label: 'Verify $id',
  chip: 'flutter test $id',
  status: status,
  kind: kind,
  details: [BeautifulToolDetailLine(text: 'Output $id')],
);

BeautifulToolDiff _diff(String id) => BeautifulToolDiff(
  id: id,
  file: '$id.dart',
  additions: 2,
  deletions: 1,
  lines: [
    BeautifulToolDetailLine(
      text: 'new $id',
      tone: BeautifulToolLineTone.addition,
    ),
    BeautifulToolDetailLine(
      text: 'old $id',
      tone: BeautifulToolLineTone.deletion,
    ),
  ],
);

Widget _app(Widget child, {double width = 390}) => beautifulTestApp(
  size: Size(width, 900),
  disableAnimations: true,
  child: SingleChildScrollView(
    child: SizedBox(width: width, child: child),
  ),
);

void main() {
  test(
    'validates identities, labels, counts and defensively copies snapshots',
    () {
      final lines = [const BeautifulToolDetailLine(text: 'first')];
      final step = BeautifulToolStep(
        id: 'verify',
        label: 'Verify',
        chip: 'flutter test',
        details: lines,
      );
      final diff = BeautifulToolDiff(
        id: 'file',
        file: 'file.dart',
        additions: 1,
        lines: lines,
      );
      final steps = [step];
      final diffs = [diff];
      final chips = BeautifulToolChips(steps: steps, diffs: diffs);
      lines.clear();
      steps.clear();
      diffs.clear();
      expect(step.details.single.text, 'first');
      expect(diff.lines.single.text, 'first');
      expect(chips.steps.single, step);
      expect(chips.diffs.single, diff);
      expect(() => chips.steps.clear(), throwsUnsupportedError);
      expect(() => step.details.clear(), throwsUnsupportedError);
      expect(
        () => BeautifulToolStep(id: ' ', label: 'Read', chip: 'config.json'),
        throwsArgumentError,
      );
      expect(
        () => BeautifulToolChips(steps: [step, step]),
        throwsArgumentError,
      );
      expect(
        () => BeautifulToolChips(steps: [], diffs: [diff, diff]),
        throwsArgumentError,
      );
      expect(
        () => BeautifulToolDiff(id: 'x', file: 'x', additions: -1),
        throwsArgumentError,
      );
      expect(
        () =>
            BeautifulToolDiff(id: 'x', file: 'x', additions: 0, deletions: -1),
        throwsArgumentError,
      );
      expect(
        () => BeautifulToolChips(steps: [], initiallyVisibleDiffCount: -1),
        throwsArgumentError,
      );
      expect(
        () => BeautifulToolChips(steps: [], headerLabel: ' '),
        throwsArgumentError,
      );
    },
  );

  testWidgets('renders host states immediately and never advances execution', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        BeautifulToolChips(
          steps: [
            for (final status in BeautifulToolStatus.values)
              _step(
                id: status.name,
                status: status,
                kind: BeautifulToolKind.values[status.index],
              ),
          ],
        ),
      ),
    );
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('Output running'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'tap expands full tool output and run collapse preserves choice',
    (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        _app(
          BeautifulToolChips(
            steps: [_step()],
            onStepExpandedChanged: (id, open) => events.add('$id:$open'),
            onExpandedChanged: (open) => events.add('run:$open'),
          ),
        ),
      );
      await tester.tap(find.text('Verify verify'));
      await tester.pumpAndSettle();
      expect(find.text('Output verify'), findsOneWidget);
      await tester.tap(find.text('Tool activity'));
      await tester.pumpAndSettle();
      expect(find.text('Verify verify'), findsNothing);
      expect(find.text('Output verify'), findsNothing);
      await tester.tap(find.text('Tool activity'));
      await tester.pumpAndSettle();
      expect(find.text('Output verify'), findsOneWidget);
      expect(events, ['verify:true', 'run:false', 'run:true']);
    },
  );

  testWidgets('file previews open by tap and display signed full diff lines', (
    tester,
  ) async {
    final events = <String>[];
    await tester.pumpWidget(
      _app(
        BeautifulToolChips(
          steps: [],
          diffs: [_diff('config')],
          onDiffExpandedChanged: (id, open) => events.add('$id:$open'),
        ),
      ),
    );
    expect(find.text('+ new config'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('beautiful-tool-diff-control-config')),
    );
    await tester.pumpAndSettle();
    expect(find.text('+ new config'), findsOneWidget);
    expect(find.text('− old config'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('beautiful-tool-diff-control-config')),
    );
    await tester.pumpAndSettle();
    expect(find.text('+ new config'), findsNothing);
    expect(events, ['config:true', 'config:false']);
  });

  testWidgets(
    'show more reveals real hidden files and retains their previews',
    (tester) async {
      await tester.pumpWidget(
        _app(
          BeautifulToolChips(
            steps: [],
            diffs: [_diff('one'), _diff('two')],
            initiallyVisibleDiffCount: 1,
          ),
        ),
      );
      expect(find.text('two.dart'), findsNothing);
      await tester.tap(find.text('Show more files'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('two.dart'));
      await tester.pumpAndSettle();
      expect(find.text('+ new two'), findsOneWidget);
      await tester.tap(find.text('Show fewer files'));
      await tester.pumpAndSettle();
      expect(find.text('two.dart'), findsNothing);
      await tester.tap(find.text('Show more files'));
      await tester.pumpAndSettle();
      expect(find.text('+ new two'), findsOneWidget);
    },
  );

  testWidgets('Enter Space Escape navigate and restore disclosure focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xffffffff),
        onGenerateRoute: (settings) => PageRouteBuilder<void>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              beautifulTestApp(
                disableAnimations: true,
                child: BeautifulToolChips(
                  steps: [_step()],
                  diffs: [_diff('config')],
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The host may provide a focusable scope before the module. Traverse until
    // the public tool action receives focus instead of assuming host tab count.
    final row = find.bySemanticsLabel('Verify verify, flutter test verify');
    for (var tabs = 0; tabs < 8; tabs++) {
      if (tester
              .getSemantics(row)
              .getSemanticsData()
              .flagsCollection
              .isFocused ==
          Tristate.isTrue) {
        break;
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(
      tester.getSemantics(row).getSemanticsData().flagsCollection.isFocused,
      Tristate.isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Output verify'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Output verify'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Output verify'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('+ new config'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('+ new config'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Verify verify'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Verify verify'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(find.text('Verify verify'), findsNothing);
    semantics.dispose();
  });

  testWidgets(
    'reorder resize and replacement preserve disclosure by identity',
    (tester) async {
      final first = _step(id: 'one');
      final second = _step(id: 'two');
      Widget app(List<BeautifulToolStep> steps, double width) => _app(
        BeautifulToolChips(
          key: const ValueKey('retained'),
          steps: steps,
          initiallyExpanded: false,
        ),
        width: width,
      );
      await tester.pumpWidget(app([first, second], 320));
      await tester.tap(find.text('Tool activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify two'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app([second, first], 1024));
      await tester.pumpAndSettle();
      expect(find.text('Output two'), findsOneWidget);
      expect(find.text('Output one'), findsNothing);
      await tester.pumpWidget(app([first], 320));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app([first, second], 320));
      await tester.pumpAndSettle();
      expect(find.text('Output two'), findsNothing);
    },
  );

  testWidgets('long RTL output and 200 percent text fit boundary widths', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final text = List.filled(
      3,
      'ملف طويل يحتوي على تفاصيل العملية باللغة العربية 中文内容 long_source_path.dart',
    ).join(' ');
    for (final width in [280.0, 320.0, 599.0, 600.0, 1023.0, 1024.0]) {
      await tester.pumpWidget(
        beautifulTestApp(
          size: Size(width, 1200),
          textDirection: TextDirection.rtl,
          textScaler: const TextScaler.linear(2),
          brightness: Brightness.dark,
          highContrast: true,
          disableAnimations: true,
          child: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: BeautifulToolChips(
                key: ValueKey(width),
                headerLabel: 'الأدوات المتاحة',
                steps: [
                  BeautifulToolStep(
                    id: 'long',
                    label: text,
                    chip: text,
                    statusLabel: 'قيد التشغيل',
                    details: [BeautifulToolDetailLine(text: text)],
                  ),
                ],
                diffs: [_diff(text)],
              ),
            ),
          ),
        ),
      );
      final stepControl = find.byKey(
        const ValueKey('beautiful-tool-step-control-long'),
      );
      await tester.ensureVisible(stepControl);
      await tester.tapAt(tester.getTopLeft(stepControl) + const Offset(24, 24));
      await tester.pumpAndSettle();
      final fileControl = find.byKey(
        ValueKey('beautiful-tool-diff-control-$text'),
      );
      await tester.ensureVisible(fileControl);
      await tester.tapAt(tester.getTopLeft(fileControl) + const Offset(24, 24));
      await tester.pumpAndSettle();
      final fullFileName = tester.widget<Text>(find.text('$text.dart'));
      expect(fullFileName.data, '$text.dart');
      expect(fullFileName.maxLines, isNull);
      expect(fullFileName.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('reduced motion removes disclosure animation and settles', (
    tester,
  ) async {
    for (final policy in [
      BeautifulMotionPolicy.reduced,
      BeautifulMotionPolicy.none,
    ]) {
      await tester.pumpWidget(
        beautifulTestApp(
          motion: policy,
          child: BeautifulToolChips(steps: [_step()]),
        ),
      );
      await tester.tap(find.text('Verify verify'));
      await tester.pump();
      expect(find.byType(AnimatedSize), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'normal disclosure motion settles and policy changes retain state',
    (tester) async {
      Widget app(BeautifulMotionPolicy motion) => beautifulTestApp(
        motion: motion,
        child: BeautifulToolChips(
          key: const ValueKey('motion-tool-chips'),
          steps: [_step()],
          diffs: [_diff('config')],
        ),
      );
      await tester.pumpWidget(app(BeautifulMotionPolicy.system));
      await tester.tap(find.text('Verify verify'));
      await tester.pumpAndSettle();
      expect(find.text('Output verify'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('beautiful-tool-diff-control-config')),
      );
      await tester.pumpAndSettle();
      expect(find.text('+ new config'), findsOneWidget);
      await tester.pumpWidget(app(BeautifulMotionPolicy.none));
      await tester.pumpAndSettle();
      expect(find.text('Output verify'), findsOneWidget);
      expect(find.text('+ new config'), findsOneWidget);
      await tester.pumpWidget(app(BeautifulMotionPolicy.system));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tool activity'));
      await tester.pumpAndSettle();
      expect(find.text('Output verify'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty run and previews without output remain descriptive', (
    tester,
  ) async {
    await tester.pumpWidget(_app(BeautifulToolChips(steps: [])));
    expect(find.text('Tool activity'), findsOneWidget);
    await tester.tap(find.text('Tool activity'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      _app(
        BeautifulToolChips(
          key: const ValueKey('descriptive'),
          steps: [
            BeautifulToolStep(id: 'read', label: 'Read', chip: 'read.txt'),
          ],
          diffs: [
            BeautifulToolDiff(id: 'read', file: 'read.txt', additions: 0),
          ],
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
