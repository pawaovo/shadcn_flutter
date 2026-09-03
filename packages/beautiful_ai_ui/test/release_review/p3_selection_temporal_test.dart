import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _selection = TextSelection(baseOffset: 0, extentOffset: 8);
const _text = 'Selected wording for review.';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final before = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = before);
  });

  for (final profile in [
    (
      name: 'normal',
      motion: BeautifulMotionPolicy.system,
      disabled: false,
      immediate: false,
    ),
    (
      name: 'reduced',
      motion: BeautifulMotionPolicy.reduced,
      disabled: false,
      immediate: false,
    ),
    (
      name: 'platform-disabled',
      motion: BeautifulMotionPolicy.system,
      disabled: true,
      immediate: true,
    ),
    (
      name: 'none',
      motion: BeautifulMotionPolicy.none,
      disabled: false,
      immediate: true,
    ),
  ]) {
    testWidgets(
      'selection ${profile.name} hover paints elapsed feedback without requests',
      (tester) async {
        final requests = <BeautifulSelectionRequest>[];
        await tester.pumpWidget(
          _app(
            motion: profile.motion,
            disabledAnimations: profile.disabled,
            child: _surface(
              onRequest: (request) {
                requests.add(request);
                return 'Result';
              },
            ),
          ),
        );
        final control = _action('Improve');
        final bounds = tester.getRect(control);
        final rest = _paint(tester, control).color;
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(799, 599));
        await mouse.moveTo(tester.getCenter(control));
        await tester.pump();
        final first = _paint(tester, control).color;
        await tester.pump(const Duration(milliseconds: 24));
        final intermediate = _paint(tester, control).color;
        await tester.pump(const Duration(milliseconds: 180));
        final settled = _paint(tester, control).color;
        expect(settled, isNot(rest));
        if (profile.immediate) {
          expect(first, settled);
          expect(intermediate, settled);
        } else {
          expect(first, rest);
          expect(intermediate, isNot(rest));
          expect(intermediate, isNot(settled));
        }
        expect(tester.getRect(control), bounds);
        expect(requests, isEmpty);
        await mouse.removePointer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(_paint(tester, control).color, rest);
      },
    );
  }

  for (final motion in [
    BeautifulMotionPolicy.system,
    BeautifulMotionPolicy.reduced,
  ]) {
    testWidgets(
      'selection $motion held press cancels to hover and release requests once',
      (tester) async {
        final pending = Completer<String>();
        final requests = <BeautifulSelectionRequest>[];
        await tester.pumpWidget(
          _app(
            motion: motion,
            child: _surface(
              onRequest: (request) {
                requests.add(request);
                return pending.future;
              },
            ),
          ),
        );
        final control = _action('Improve');
        final bounds = tester.getRect(control);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(799, 599));
        await mouse.moveTo(tester.getCenter(control));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        final hover = _paint(tester, control).color;
        await mouse.down(tester.getCenter(control));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 24));
        final intermediate = _paint(tester, control).color;
        await tester.pump(const Duration(milliseconds: 180));
        final pressed = _paint(tester, control).color;
        expect(pressed, isNot(hover));
        expect(intermediate, isNot(pressed));
        expect(
          (_outline(tester, control).border! as Border).top.width,
          greaterThan(0),
        );
        expect(tester.getRect(control), bounds);
        expect(requests, isEmpty);
        await mouse.cancel();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(_paint(tester, control).color, hover);
        expect(requests, isEmpty);
        await mouse.down(tester.getCenter(control));
        await tester.pump(const Duration(milliseconds: 120));
        await mouse.up();
        await tester.pump();
        expect(requests, hasLength(1));
        expect(requests.single.selection, _selection);
        expect(find.text('Working on selection'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('Working on selection'), findsOneWidget);
        expect(find.text('Suggestion ready'), findsNothing);
        pending.complete('The host supplied this exact suggestion.');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          find.text('The host supplied this exact suggestion.'),
          findsOneWidget,
        );
        expect(_document(tester).controller.text, _text);
        expect(requests, hasLength(1));
        await mouse.removePointer();
      },
    );

    testWidgets(
      'selection $motion async preview preserves exact native range and Escape focus',
      (tester) async {
        final pending = Completer<String>();
        final requests = <BeautifulSelectionRequest>[];
        var width = 720.0;
        late StateSetter updateHost;
        await tester.pumpWidget(
          _app(
            motion: motion,
            child: StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return SizedBox(
                  width: width,
                  child: _surface(
                    onRequest: (request) {
                      requests.add(request);
                      return pending.future;
                    },
                  ),
                );
              },
            ),
          ),
        );
        final document = _document(tester);
        document.focusNode.requestFocus();
        await tester.pump();
        final control = _action('Improve');
        final focus = Focus.of(tester.element(control));
        for (var count = 0; count < 12 && !focus.hasPrimaryFocus; count++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(focus.hasPrimaryFocus, isTrue);
        expect(
          (_outline(tester, control).border! as Border).top.width,
          greaterThan(0),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(requests.single.selection, _selection);
        expect(document.focusNode.hasFocus, isTrue);
        updateHost(() => width = 320);
        await tester.pump(const Duration(milliseconds: 750));
        expect(_document(tester).controller, same(document.controller));
        expect(document.controller.selection, _selection);
        expect(find.text('Working on selection'), findsOneWidget);
        pending.complete('Reviewed passage.');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));
        expect(find.text('Reviewed passage.'), findsOneWidget);
        expect(document.focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump(const Duration(milliseconds: 180));
        expect(find.text('Reviewed passage.'), findsNothing);
        expect(document.focusNode.hasFocus, isTrue);
        expect(document.controller.selection, _selection);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'selection disabled during held press clears feedback without requesting',
    (tester) async {
      var enabled = true;
      var requests = 0;
      late StateSetter updateHost;
      await tester.pumpWidget(
        _app(
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return _surface(
                enabled: enabled,
                onRequest: (_) {
                  requests++;
                  return 'Result';
                },
              );
            },
          ),
        ),
      );
      final control = _action('Improve');
      final restingWidth =
          (_outline(tester, control).border! as Border).top.width;
      final mouse = await tester.startGesture(
        tester.getCenter(control),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        (_outline(tester, control).border! as Border).top.width,
        greaterThan(0),
      );
      updateHost(() => enabled = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        (_outline(tester, control).border! as Border).top.width,
        restingWidth,
      );
      await mouse.up();
      await tester.pump();
      expect(requests, 0);
      expect(_document(tester).readOnly, isTrue);
    },
  );
}

BeautifulSelectionActions _surface({
  required FutureOr<String> Function(BeautifulSelectionRequest) onRequest,
  bool enabled = true,
}) => BeautifulSelectionActions(
  documentId: 'selection-temporal',
  text: _text,
  initialSelection: _selection,
  enabled: enabled,
  onRequest: onRequest,
  onApply: (_) {},
);

Finder _action(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
    .first;
EditableText _document(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).first);

BoxDecoration _paint(WidgetTester tester, Finder control) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: control, matching: find.byType(DecoratedBox)),
    )
    .where((box) => box.position == DecorationPosition.background)
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .single;
BoxDecoration _outline(WidgetTester tester, Finder control) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: control, matching: find.byType(DecoratedBox)),
    )
    .where((box) => box.position == DecorationPosition.foreground)
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .single;

Widget _app({
  required Widget child,
  BeautifulMotionPolicy motion = BeautifulMotionPolicy.system,
  bool disabledAnimations = false,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(disableAnimations: disabledAnimations),
    child: BeautifulUiScope(
      motion: motion,
      child: FocusScope(
        autofocus: true,
        child: Overlay.wrap(
          child: Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  ),
);
