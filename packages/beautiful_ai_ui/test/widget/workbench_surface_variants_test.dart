import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets(
    'embedded code fills its work surface and retains exact copying',
    (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const source = 'final label = "精细界面";\n';
      final copies = <String>[];
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(900, 800),
          child: BeautifulCodeBlock.code(
            filename: 'wide.dart',
            code: source,
            density: BeautifulUiDensity.compact,
            surfaceVariant: BeautifulSurfaceVariant.embedded,
            maxWidth: null,
            onCopy: copies.add,
          ),
        ),
      );
      expect(tester.getSize(find.byType(BeautifulCodeBlock)).width, 1000);
      await tester.tap(find.bySemanticsLabel('Copy').last);
      await tester.pump();
      expect(copies, [source]);
      expect(find.bySemanticsLabel('Copied'), findsWidgets);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(900, 800),
          child: const BeautifulCodeBlock.code(
            filename: 'default.dart',
            code: '',
          ),
        ),
      );
      expect(tester.getSize(find.byType(BeautifulCodeBlock)).width, 420);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('compact embedded tool rows retain disclosure and live status', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulToolChips(
          density: BeautifulUiDensity.compact,
          surfaceVariant: BeautifulSurfaceVariant.embedded,
          maxWidth: null,
          steps: [
            BeautifulToolStep(
              id: 'read',
              label: 'Read',
              chip: 'config.dart',
              status: BeautifulToolStatus.running,
              details: const [BeautifulToolDetailLine(text: 'Retained output')],
            ),
          ],
        ),
      ),
    );
    expect(find.text('Read · config.dart'), findsOneWidget);
    expect(find.bySemanticsLabel('Read: Running'), findsOneWidget);
    expect(find.text('Retained output'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('beautiful-tool-step-control-read')),
    );
    await tester.pump();
    expect(find.text('Retained output'), findsOneWidget);
    Focus.of(tester.element(find.text('Read · config.dart'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Retained output'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('compact tasks preserve failure retry and disclosure', (
    tester,
  ) async {
    final pending = Completer<void>();
    var retries = 0;
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulTaskRows(
          density: BeautifulUiDensity.compact,
          surfaceVariant: BeautifulSurfaceVariant.embedded,
          maxWidth: null,
          rows: [
            BeautifulTaskRow(
              id: 'task',
              label: 'Review layout',
              amountLabel: '2 files',
              status: BeautifulTaskStatus.failed,
              details: const [
                BeautifulTaskDetail(
                  id: 'detail',
                  label: 'Spacing',
                  meta: '8 px',
                ),
              ],
            ),
          ],
          onRetry: (_) {
            retries++;
            return pending.future;
          },
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('task-toggle-task')));
    await tester.pump();
    expect(find.text('Spacing'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.tap(find.text('Retrying…'));
    expect(retries, 1);
    pending.complete();
    await tester.pump();
    expect(find.text('Failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quiet answer keeps status semantics and touch copy available', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final copies = <String>[];
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulStreamingText(
          id: 'quiet',
          quiet: true,
          status: BeautifulStreamingStatus.complete,
          content: const [
            BeautifulStreamingPart.text('Answer with '),
            BeautifulStreamingPart.citation('source'),
          ],
          sources: const [
            BeautifulStreamingSource(id: 'source', title: 'Source'),
          ],
          onCopy: copies.add,
        ),
      ),
    );
    expect(find.text('Answer complete'), findsNothing);
    expect(find.bySemanticsLabel('Answer complete'), findsOneWidget);
    expect(
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
      1,
    );
    await tester.tap(find.bySemanticsLabel('Copy answer').last);
    await tester.pump();
    expect(copies, ['Answer with [1]']);
    expect(find.bySemanticsLabel('Answer copied'), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('quiet desktop actions reveal on keyboard focus', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(900, 800),
        disableAnimations: true,
        child: BeautifulStreamingText(
          id: 'desktop',
          quiet: true,
          status: BeautifulStreamingStatus.complete,
          content: const [BeautifulStreamingPart.text('Keyboard reachable')],
        ),
      ),
    );
    final bar = find.byType(AnimatedOpacity);
    expect(tester.widget<AnimatedOpacity>(bar).opacity, 0);
    Focus.of(
      tester.element(
        find.descendant(of: bar, matching: find.byType(CustomPaint)).first,
      ),
    ).requestFocus();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<AnimatedOpacity>(bar).opacity, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
