import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('uses Flutter Clipboard when no copy callback is supplied', (
    tester,
  ) async {
    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCall = call;
        }
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
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulCodeBlock.code(
          filename: 'main.dart',
          code: 'print("system clipboard");',
        ),
      ),
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();
    await tester.pump();

    expect(clipboardCall?.method, 'Clipboard.setData');
    expect(clipboardCall?.arguments, <String, Object?>{
      'text': 'print("system clipboard");',
    });
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('copies the exact source and de-duplicates a pending request', (
    tester,
  ) async {
    const source = 'void main() {\n  print("hello");\n}\n';
    final pending = Completer<void>();
    final copied = <String>[];

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulCodeBlock.code(
          filename: 'main.dart',
          code: source,
          onCopy: (value) {
            copied.add(value);
            return pending.future;
          },
        ),
      ),
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(find.text('Copying'), findsOneWidget);

    await tester.tap(find.text('Copying'));
    await tester.pump();
    expect(copied, <String>[source]);

    pending.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1499));
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('supports keyboard activation and localized copy labels', (
    tester,
  ) async {
    var invocations = 0;
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulCodeBlock.code(
          filename: 'main.dart',
          code: 'print("hello");',
          copyLabel: 'Kopieren',
          copyingLabel: 'Wird kopiert',
          copiedLabel: 'Kopiert',
          copyFailedLabel: 'Kopieren fehlgeschlagen',
          onCopy: (_) => invocations += 1,
        ),
      ),
    );

    final detector = tester.widget<FocusableActionDetector>(
      find.byType(FocusableActionDetector),
    );
    detector.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(invocations, 1);
    expect(find.text('Kopiert'), findsOneWidget);
  });

  testWidgets('renders diff statistics and every row kind', (tester) async {
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulCodeBlock.diff(
          filename: 'churn.ts',
          lines: const <BeautifulDiffLine>[
            BeautifulDiffLine(
              oldLineNumber: 1,
              newLineNumber: 1,
              kind: BeautifulDiffLineKind.context,
              pieces: <BeautifulCodePiece>[
                BeautifulCodePiece(text: 'const temperature = value;'),
              ],
            ),
            BeautifulDiffLine(
              oldLineNumber: 2,
              kind: BeautifulDiffLineKind.removed,
              pieces: <BeautifulCodePiece>[
                BeautifulCodePiece(text: 'return '),
                BeautifulCodePiece(
                  text: 'oldValue',
                  change: BeautifulDiffLineKind.removed,
                ),
                BeautifulCodePiece(text: ';'),
              ],
            ),
            BeautifulDiffLine(
              newLineNumber: 2,
              kind: BeautifulDiffLineKind.added,
              pieces: <BeautifulCodePiece>[
                BeautifulCodePiece(text: 'return '),
                BeautifulCodePiece(
                  text: 'newValue',
                  change: BeautifulDiffLineKind.added,
                ),
                BeautifulCodePiece(text: ';'),
              ],
            ),
            BeautifulDiffLine(
              newLineNumber: 3,
              kind: BeautifulDiffLineKind.added,
              pieces: <BeautifulCodePiece>[
                BeautifulCodePiece(text: 'logChange();'),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('+2'), findsOneWidget);
    expect(find.text('-1'), findsOneWidget);
    expect(find.text('Copy'), findsNothing);
    expect(find.textContaining('oldValue', findRichText: true), findsOneWidget);
    expect(find.textContaining('newValue', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a long line unwrapped in a horizontal viewport', (
    tester,
  ) async {
    final longLine = 'final value = "${'long-value-' * 40}";';

    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(320, 568),
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
        child: SizedBox(
          width: 280,
          child: BeautifulCodeBlock.code(
            filename: 'an-unusually-long-source-file-name.dart',
            code: longLine,
            onCopy: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final horizontal = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .where((state) => state.position.axis == Axis.horizontal)
        .single;
    expect(horizontal.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports RTL and 200 percent text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(320, 568),
        textDirection: TextDirection.rtl,
        textScaler: const TextScaler.linear(2),
        disableAnimations: true,
        child: SizedBox(
          width: 300,
          child: BeautifulCodeBlock.code(
            filename: 'ملف-طويل-جدا.dart',
            code: 'void main() => print("مرحبا بالعالم");',
            copyLabel: 'نسخ',
            copyingLabel: 'جارٍ النسخ',
            copiedLabel: 'تم النسخ',
            copyFailedLabel: 'تعذر النسخ',
            onCopy: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('نسخ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders at every adaptive boundary without overflow', (
    tester,
  ) async {
    const source = '''Future<void> loadWorkspace() async {
  final workspace = await repository.open();
  await workspace.refresh();
}''';
    for (final width in <double>[599, 600, 1023, 1024]) {
      await tester.pumpWidget(
        beautifulTestApp(
          size: Size(width, 800),
          disableAnimations: true,
          child: SingleChildScrollView(
            child: BeautifulCodeBlock.code(
              key: ValueKey<double>(width),
              filename: 'workspace.dart',
              code: source,
              onCopy: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
