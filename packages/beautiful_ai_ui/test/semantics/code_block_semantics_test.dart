import 'dart:async';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('copy state is a button and announces successful completion', (
    tester,
  ) async {
    final pending = Completer<void>();
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulCodeBlock.code(
          filename: 'main.dart',
          code: 'void main() {}',
          onCopy: (_) => pending.future,
        ),
      ),
    );

    final idle = tester
        .getSemantics(find.bySemanticsLabel('Copy'))
        .getSemanticsData();
    expect(idle.flagsCollection.isButton, isTrue);
    expect(idle.hasAction(SemanticsAction.tap), isTrue);
    expect(idle.flagsCollection.isLiveRegion, isFalse);

    await tester.tap(find.text('Copy'));
    await tester.pump();
    final copying = tester
        .getSemantics(find.bySemanticsLabel('Copying'))
        .getSemanticsData();
    expect(copying.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(copying.hasAction(SemanticsAction.tap), isFalse);

    pending.complete();
    await tester.pump();
    await tester.pump();
    final copied = tester
        .getSemantics(find.bySemanticsLabel('Copied'))
        .getSemanticsData();
    expect(copied.flagsCollection.isButton, isTrue);
    expect(copied.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });

  testWidgets('copy failure is live and reports a normalized failure', (
    tester,
  ) async {
    final failures = <BeautifulUiFailure>[];
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _failureApp(
        onFailure: failures.add,
        child: BeautifulCodeBlock.code(
          filename: 'main.dart',
          code: 'void main() {}',
          onCopy: (_) => throw StateError('clipboard unavailable'),
        ),
      ),
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();

    final failed = tester
        .getSemantics(find.bySemanticsLabel('Copy failed'))
        .getSemanticsData();
    expect(failed.flagsCollection.isLiveRegion, isTrue);
    expect(failures, hasLength(1));
    expect(failures.single.operation, BeautifulUiOperation.clipboard);
    expect(failures.single.cause, isA<StateError>());
    semantics.dispose();
  });

  testWidgets('diff rows expose added removed and context meaning in text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulCodeBlock.diff(
          filename: 'main.dart',
          lines: const <BeautifulDiffLine>[
            BeautifulDiffLine(
              oldLineNumber: 1,
              newLineNumber: 1,
              kind: BeautifulDiffLineKind.context,
              pieces: <BeautifulCodePiece>[
                BeautifulCodePiece(text: 'void main() {'),
              ],
            ),
            BeautifulDiffLine(
              oldLineNumber: 2,
              kind: BeautifulDiffLineKind.removed,
              pieces: <BeautifulCodePiece>[
                BeautifulCodePiece(text: '  print("old");'),
              ],
            ),
            BeautifulDiffLine(
              newLineNumber: 2,
              kind: BeautifulDiffLineKind.added,
              pieces: <BeautifulCodePiece>[
                BeautifulCodePiece(text: '  print("new");'),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsLabel('1 addition, 1 deletion'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Context line 1: void main() {'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Removed line 2:   print("old");'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Added line 2:   print("new");'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Copy'), findsNothing);
    semantics.dispose();
  });
}

Widget _failureApp({
  required Widget child,
  required BeautifulUiFailureHandler onFailure,
}) {
  const size = Size(390, 844);
  return MediaQuery(
    data: const MediaQueryData(size: size, disableAnimations: true),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: BeautifulUiScope(
        onFailure: onFailure,
        child: SizedBox.fromSize(
          size: size,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ),
  );
}
