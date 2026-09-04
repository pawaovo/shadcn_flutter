import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui/src/implementation/controls/readonly_selection_shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _webArrowPolicy = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowLeft):
      DoNothingAndStopPropagationTextIntent(),
  SingleActivator(LogicalKeyboardKey.arrowRight):
      DoNothingAndStopPropagationTextIntent(),
  SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
      DoNothingAndStopPropagationTextIntent(),
  SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
      DoNothingAndStopPropagationTextIntent(),
};

void main() {
  testWidgets(
    'adapter collapses a whole read-only selection in either direction',
    (tester) async {
      final controller = TextEditingController(text: 'alpha\nbeta');
      final focus = FocusNode();
      await _mount(tester, controller, focus);
      try {
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 10,
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(controller.selection, const TextSelection.collapsed(offset: 10));
        controller.selection = const TextSelection(
          baseOffset: 10,
          extentOffset: 0,
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(controller.selection, const TextSelection.collapsed(offset: 0));
        expect(controller.text, 'alpha\nbeta');
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).readOnly,
          isTrue,
        );
      } finally {
        await _dispose(tester, controller, focus);
      }
    },
  );

  testWidgets('plain and Shift arrows preserve SDK grapheme boundaries', (
    tester,
  ) async {
    // UTF-16 boundaries: A=0..1, family=1..12, e+accent=12..14, 中=14..15.
    const text = 'A👩‍👩‍👧‍👦e\u0301中';
    final controller = TextEditingController(text: text);
    final focus = FocusNode();
    await _mount(tester, controller, focus);
    try {
      controller.selection = const TextSelection.collapsed(offset: 15);
      await tester.pump();
      for (final offset in <int>[14, 12, 1, 0]) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(controller.selection, TextSelection.collapsed(offset: offset));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
      await _shift(tester, LogicalKeyboardKey.arrowRight);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 12),
      );
      expect(controller.selection.textInside(text), '👩‍👩‍👧‍👦');
      await _shift(tester, LogicalKeyboardKey.arrowRight);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 14),
      );
      await _shift(tester, LogicalKeyboardKey.arrowLeft);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 1, extentOffset: 12),
      );
      await _shift(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
      expect(controller.text, text);
    } finally {
      await _dispose(tester, controller, focus);
    }
  });

  testWidgets('RTL text keeps the SDK logical-boundary selection contract', (
    tester,
  ) async {
    const text = 'سَلَام 👋';
    final controller = TextEditingController(text: text);
    final focus = FocusNode();
    await _mount(tester, controller, focus, direction: TextDirection.rtl);
    try {
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: text.length,
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        controller.selection,
        TextSelection.collapsed(offset: text.length),
      );
      await _shift(tester, LogicalKeyboardKey.arrowLeft);
      expect(controller.selection.textInside(text), '👋');
      expect(controller.selection.baseOffset, text.length);
      expect(controller.text, text);
    } finally {
      await _dispose(tester, controller, focus);
    }
  });

  testWidgets('Control Alt and Meta arrows still reach host shortcuts', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'unchanged');
    final focus = FocusNode();
    var hostCalls = 0;
    await _mount(tester, controller, focus, onHost: () => hostCalls++);
    try {
      final before = controller.value;
      for (final modifier in <LogicalKeyboardKey>[
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        try {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        } finally {
          await tester.sendKeyUpEvent(modifier);
        }
        await tester.pump();
      }
      expect(hostCalls, 3);
      expect(controller.value, before);
    } finally {
      await _dispose(tester, controller, focus);
    }
  });

  testWidgets(
    'native SelectionActions retains a host plain-arrow override',
    (tester) async {
      var hostCalls = 0;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xffffffff),
          builder: (context, _) => BeautifulUiScope(
            child: Actions(
              actions: <Type, Action<Intent>>{
                _HostIntent: CallbackAction<_HostIntent>(
                  onInvoke: (_) {
                    hostCalls++;
                    return null;
                  },
                ),
              },
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.arrowRight): _HostIntent(),
                },
                child: BeautifulSelectionActions(
                  documentId: 'native-host',
                  text: 'native document',
                  onRequest: (_) => '',
                ),
              ),
            ),
          ),
        ),
      );
      try {
        final editor = tester.widget<EditableText>(
          find.byType(EditableText).first,
        );
        editor.focusNode.requestFocus();
        await tester.pump();
        final before = editor.controller.value;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(hostCalls, 1);
        expect(editor.controller.value, before);
        expect(find.byType(BeautifulReadonlySelectionShortcuts), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );
}

class _HostIntent extends Intent {
  const _HostIntent();
}

Future<void> _mount(
  WidgetTester tester,
  TextEditingController controller,
  FocusNode focus, {
  TextDirection direction = TextDirection.ltr,
  VoidCallback? onHost,
}) async {
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xffffffff),
      builder: (context, _) => Directionality(
        textDirection: direction,
        child: Actions(
          actions: <Type, Action<Intent>>{
            _HostIntent: CallbackAction<_HostIntent>(
              onInvoke: (_) {
                onHost?.call();
                return null;
              },
            ),
          },
          // Reproduce the installed SDK's web policy, which leaves these
          // native DOM keys unhandled. This is not a real-browser test.
          child: Shortcuts(
            shortcuts: <ShortcutActivator, Intent>{
              ..._webArrowPolicy,
              const SingleActivator(
                LogicalKeyboardKey.arrowRight,
                control: true,
              ): const _HostIntent(),
              const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
                  const _HostIntent(),
              const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
                  const _HostIntent(),
            },
            child: BeautifulReadonlySelectionShortcuts(
              child: EditableText(
                controller: controller,
                focusNode: focus,
                readOnly: true,
                maxLines: 8,
                textDirection: direction,
                style: const TextStyle(color: Color(0xff000000)),
                cursorColor: const Color(0xff000000),
                backgroundCursorColor: const Color(0xff000000),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  focus.requestFocus();
  await tester.pump();
}

Future<void> _shift(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  try {
    await tester.sendKeyEvent(key);
  } finally {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.pump();
}

Future<void> _dispose(
  WidgetTester tester,
  TextEditingController controller,
  FocusNode focus,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  focus.dispose();
}
