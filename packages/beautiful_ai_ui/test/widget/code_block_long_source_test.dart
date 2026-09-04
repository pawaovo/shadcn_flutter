import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final _source = List.generate(
  1000,
  (index) =>
      'final value$index = "source line $index with deterministic content";',
).join('\n');

Widget _app({
  String? source,
  bool diff = false,
  required FutureOr<void> Function(String) onCopy,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => MediaQuery(
    data: const MediaQueryData(size: Size(800, 600), disableAnimations: true),
    child: BeautifulUiScope(
      child: Overlay.wrap(
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: diff
                ? const BeautifulCodeBlock.diff(
                    filename: 'long_source.dart',
                    lines: [],
                  )
                : BeautifulCodeBlock.code(
                    filename: 'long_source.dart',
                    code: source ?? _source,
                    onCopy: onCopy,
                  ),
          ),
        ),
      ),
    ),
  ),
);

bool _isSourceText(Widget widget) =>
    widget is Text &&
    (widget.textSpan?.toPlainText().startsWith('final value') ?? false);

void main() {
  testWidgets('copy feedback does not rebuild the unchanged 1000-line source', (
    tester,
  ) async {
    final pending = Completer<void>();
    final copied = <String>[];
    await tester.pumpWidget(
      _app(
        onCopy: (source) {
          copied.add(source);
          return pending.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate(_isSourceText), findsNWidgets(1000));
    final selectionState = tester.state(find.byType(SelectableRegion));

    // Observe real framework rebuild work through Flutter's diagnostic hook;
    // no production counter or private component method is involved.
    var sourceRebuilds = 0;
    final previousHook = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtBefore) {
      previousHook?.call(element, builtBefore);
      if (_isSourceText(element.widget)) sourceRebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = previousHook);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Copy')));
    await tester.pumpAndSettle();
    tester
        .widget<FocusableActionDetector>(find.byType(FocusableActionDetector))
        .focusNode!
        .requestFocus();
    await tester.pump();
    expect(
      sourceRebuilds,
      0,
      reason: 'Hover/focus belong to the copy control.',
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(find.text('Copying'), findsOneWidget);
    expect(
      sourceRebuilds,
      0,
      reason: 'Copy feedback must leave the complete source body untouched.',
    );
    await tester.tap(find.text('Copying'));
    await tester.pump();
    expect(copied, [_source]);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsOneWidget);
    expect(sourceRebuilds, 0);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Copy'), findsOneWidget);
    expect(
      sourceRebuilds,
      0,
      reason: 'The feedback reset must not rebuild 1000 lines.',
    );
    expect(tester.state(find.byType(SelectableRegion)), same(selectionState));
    expect(find.byWidgetPredicate(_isSourceText), findsNWidgets(1000));
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('1000-line native SelectAll/Copy survives feedback reset', (
    tester,
  ) async {
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(_app(onCopy: (_) {}));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(find.text('Copied'), findsOneWidget);
    final selection = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    final sourceContext = tester.element(
      find.byWidgetPredicate(_isSourceText).first,
    );
    Actions.invoke(
      sourceContext,
      const SelectAllTextIntent(SelectionChangedCause.keyboard),
    );
    await tester.pump();
    Actions.invoke(sourceContext, CopySelectionTextIntent.copy);
    await tester.pump();
    expect(clipboard.length, 1);
    final selectedSource = clipboard.single;
    // The native region controls separators between separately rendered
    // paragraphs. Preserve its exact selected text across feedback changes,
    // while independently checking that every complete source line is present.
    for (final line in _source.split('\n')) {
      expect(selectedSource.contains(line), isTrue);
    }
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Copy'), findsOneWidget);
    Actions.invoke(sourceContext, CopySelectionTextIntent.copy);
    await tester.pump();
    expect(clipboard.length, 2);
    expect(clipboard.last == selectedSource, isTrue);
    expect(tester.state(find.byType(SelectableRegion)), same(selection));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source changes and mode disposal invalidate pending copy feedback',
    (tester) async {
      final first = Completer<void>();
      final second = Completer<void>();
      final requests = <String>[];
      Future<void> copy(String source) {
        requests.add(source);
        return requests.length == 1 ? first.future : second.future;
      }

      await tester.pumpWidget(_app(source: 'old source', onCopy: copy));
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(find.text('Copying'), findsOneWidget);
      await tester.pumpWidget(_app(source: 'new source', onCopy: copy));
      expect(find.text('Copy'), findsOneWidget);
      first.complete();
      await tester.pumpAndSettle();
      expect(find.text('Copied'), findsNothing);
      await tester.tap(find.text('Copy'));
      await tester.pump();
      expect(requests, ['old source', 'new source']);
      await tester.pumpWidget(_app(diff: true, onCopy: copy));
      second.complete();
      await tester.pumpAndSettle();
      expect(find.text('Copying'), findsNothing);
      expect(find.text('Copied'), findsNothing);
      await tester.pumpWidget(_app(source: 'new source', onCopy: copy));
      expect(find.text('Copy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
