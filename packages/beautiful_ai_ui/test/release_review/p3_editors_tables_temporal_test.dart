import 'dart:async';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// These tests inspect the evaluated decoration below AnimatedContainer after
// real input and elapsed frames. Inspecting its declared duration would miss a
// muted ticker, a stale tween, or a state change that never reaches the paint.
const _profiles =
    <
      ({
        String name,
        BeautifulMotionPolicy policy,
        bool platformDisabled,
        bool immediate,
      })
    >[
      (
        name: 'normal',
        policy: BeautifulMotionPolicy.system,
        platformDisabled: false,
        immediate: false,
      ),
      (
        name: 'reduced',
        policy: BeautifulMotionPolicy.reduced,
        platformDisabled: false,
        immediate: false,
      ),
      (
        name: 'platform disabled',
        policy: BeautifulMotionPolicy.system,
        platformDisabled: true,
        immediate: true,
      ),
      (
        name: 'none',
        policy: BeautifulMotionPolicy.none,
        platformDisabled: false,
        immediate: true,
      ),
    ];

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Widget _app(
  Widget child, {
  double width = 1100,
  BeautifulMotionPolicy motion = BeautifulMotionPolicy.system,
  bool platformDisabled = false,
  TextDirection direction = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  bool highContrast = false,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => FocusScope(
    autofocus: true,
    child: Overlay.wrap(
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1800),
          disableAnimations: platformDisabled,
          textScaler: textScaler,
          highContrast: highContrast,
        ),
        child: Directionality(
          textDirection: direction,
          child: BeautifulUiScope(
            motion: motion,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

BeautifulDiffTable _diff({Future<void> Function(Set<String>)? onApply}) =>
    BeautifulDiffTable(
      id: 'temporal-diff',
      title: 'مراجعة التغييرات',
      columns: const [BeautifulDiffColumn(id: 'name', label: 'الاسم')],
      rows: [
        BeautifulDiffRow(id: 'one', after: {'name': 'خطة التسليم'}),
      ],
      onApply: onApply,
      labels: const BeautifulDiffTableLabels(
        included: 'مضمّن',
        excluded: 'مستبعد',
        include: 'تضمين التغيير',
        added: 'مضاف',
        apply: 'تطبيق التغييرات',
        applying: 'جارٍ التطبيق',
        applied: 'اكتمل التطبيق',
      ),
    );

BeautifulRecordsTable _records({
  ValueChanged<Set<String>>? onSelectionChanged,
  FutureOr<void> Function(String, BeautifulRecordPropertyConfig)?
  onPropertyChanged,
}) => BeautifulRecordsTable(
  id: 'temporal-records',
  height: 240,
  columns: [
    BeautifulRecordColumn(
      id: 'summary',
      label: 'الملخص',
      property: BeautifulRecordPropertyConfig(prompt: 'راجع تفاصيل التسليم'),
    ),
  ],
  rows: [
    BeautifulRecordRow(
      id: 'one',
      label: 'خطة التسليم',
      cells: {'summary': BeautifulRecordCell(text: 'التسليم يوم الخميس')},
    ),
  ],
  onSelectionChanged: onSelectionChanged,
  onPropertyChanged: onPropertyChanged,
  labels: const BeautifulRecordsTableLabels(
    properties: 'الخصائص',
    configure: 'إعداد',
    select: 'اختيار',
    prompt: 'تعليمات الحساب',
    close: 'إغلاق',
  ),
);

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

FocusNode _focus(WidgetTester tester, Finder control) => Focus.of(
  tester.element(
    find.descendant(of: control, matching: find.byType(GestureDetector)).last,
  ),
);

EditableText _editor(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).last);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final original = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = original);
  });

  for (final profile in _profiles) {
    for (final component in ['prompt', 'diff', 'records']) {
      testWidgets('$component ${profile.name} hover paints elapsed feedback', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        var callbacks = 0;
        final (widget, key) = switch (component) {
          'prompt' => (
            BeautifulPromptBar(
              composerId: 'temporal-prompt',
              initialDraft: 'راجع خطة التسليم',
              onSend: (_) => callbacks++,
              onAttach: () {
                callbacks++;
                return const <BeautifulPromptAttachment>[];
              },
            ),
            'beautiful-prompt-add',
          ),
          'diff' => (
            _diff(onApply: (_) async => callbacks++),
            'diff-table-apply',
          ),
          _ => (
            _records(onSelectionChanged: (_) => callbacks++),
            'records-properties',
          ),
        };
        await tester.pumpWidget(
          _app(
            widget,
            motion: profile.policy,
            platformDisabled: profile.platformDisabled,
          ),
        );
        final control = _key(key);
        final rest = _paint(tester, control).color;
        final bounds = tester.getRect(control);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1190, 1790));
        await tester.pump();
        await mouse.moveTo(tester.getCenter(control));
        await tester.pump();
        final firstFrame = _paint(tester, control).color;
        await tester.pump(const Duration(milliseconds: 24));
        final intermediate = _paint(tester, control).color;
        await tester.pump(const Duration(milliseconds: 160));
        final settled = _paint(tester, control).color;
        expect(settled, isNot(rest));
        if (profile.immediate) {
          expect(firstFrame, settled);
          expect(intermediate, settled);
        } else {
          expect(firstFrame, rest);
          expect(intermediate, isNot(rest));
          expect(intermediate, isNot(settled));
        }
        expect(tester.getRect(control), bounds);
        expect(callbacks, 0);
        await mouse.moveTo(const Offset(1190, 1790));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(_paint(tester, control).color, rest);
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final motion in [
    BeautifulMotionPolicy.system,
    BeautifulMotionPolicy.reduced,
  ]) {
    for (final component in ['prompt', 'diff', 'records']) {
      testWidgets(
        '$component $motion press paints and cancel never activates',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1200, 1800);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          var calls = 0;
          final (widget, key) = switch (component) {
            'prompt' => (
              BeautifulPromptBar(
                composerId: 'pressed-prompt',
                initialDraft: 'راجع خطة التسليم',
                onSend: (_) => calls++,
              ),
              'beautiful-prompt-send',
            ),
            'diff' => (
              _diff(onApply: (_) async => calls++),
              'diff-table-apply',
            ),
            _ => (_records(), 'records-properties'),
          };
          await tester.pumpWidget(_app(widget, motion: motion));
          final control = _key(key);
          final rest = _paint(tester, control).color;
          final restBorder = (_outline(tester, control).border! as Border).top;
          final bounds = tester.getRect(control);
          final pointer = await tester.startGesture(tester.getCenter(control));
          await tester.pump(const Duration(milliseconds: 120));
          await tester.pump(const Duration(milliseconds: 24));
          final intermediate = _paint(tester, control).color;
          await tester.pump(const Duration(milliseconds: 160));
          final pressed = _paint(tester, control).color;
          expect(intermediate, isNot(rest));
          expect(intermediate, isNot(pressed));
          expect(pressed, isNot(rest));
          expect(
            (_outline(tester, control).border! as Border).top.width,
            greaterThan(restBorder.width),
          );
          expect(tester.getRect(control), bounds);
          expect(calls, 0);
          expect(_key('records-config-summary'), findsNothing);
          await pointer.cancel();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 180));
          expect(_paint(tester, control).color, rest);
          expect((_outline(tester, control).border! as Border).top, restBorder);
          expect(calls, 0);
          expect(_key('records-config-summary'), findsNothing);
          await tester.tap(control);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 180));
          if (component == 'records') {
            expect(_key('records-config-summary'), findsOneWidget);
          } else {
            expect(calls, 1);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('prompt $motion pending frames retain localized draft focus', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final pending = Completer<void>();
      final sent = <BeautifulPromptSubmission>[];
      Widget prompt() => BeautifulPromptBar(
        composerId: 'focus-prompt',
        initialDraft: 'راجع خطة التسليم',
        composerLabel: 'الرسالة',
        sendLabel: 'إرسال',
        sendingLabel: 'جارٍ الإرسال',
        onSend: (submission) {
          sent.add(submission);
          return pending.future;
        },
      );
      await tester.pumpWidget(_app(prompt(), motion: motion));
      await tester.showKeyboard(find.byType(EditableText));
      final focus = _editor(tester).focusNode;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      expect(find.text('جارٍ الإرسال'), findsOneWidget);
      expect(sent.single.text, 'راجع خطة التسليم');
      expect(FocusManager.instance.primaryFocus, same(focus));
      const later = TextEditingValue(
        text: 'فكرة تالية',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      );
      tester.testTextInput.updateEditingValue(later);
      await tester.pump();
      await tester.pumpWidget(
        _app(
          prompt(),
          width: 390,
          motion: motion,
          direction: TextDirection.rtl,
          textScaler: const TextScaler.linear(2),
          highContrast: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 180));
      expect(FocusManager.instance.primaryFocus, same(focus));
      expect(_editor(tester).controller.value, later);
      pending.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text('إرسال'), findsOneWidget);
      expect(_editor(tester).controller.value, later);
      expect(FocusManager.instance.primaryFocus, same(focus));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'diff $motion selected paint and focus survive pending frames',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final semantics = tester.ensureSemantics();
        final pending = Completer<void>();
        final applied = <Set<String>>[];
        Widget table() => _diff(
          onApply: (ids) {
            applied.add(ids);
            return pending.future;
          },
        );
        await tester.pumpWidget(_app(table(), motion: motion));
        final include = _key('diff-table-include-one');
        final selectedPaint = _paint(tester, include).color;
        for (
          var count = 0;
          count < 6 && !_focus(tester, include).hasFocus;
          count++
        ) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        final focus = _focus(tester, include);
        expect(FocusManager.instance.primaryFocus, same(focus));
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 24));
        final changingPaint = _paint(tester, include).color;
        await tester.pump(const Duration(milliseconds: 160));
        final excludedPaint = _paint(tester, include).color;
        expect(changingPaint, isNot(selectedPaint));
        expect(changingPaint, isNot(excludedPaint));
        expect(excludedPaint, isNot(selectedPaint));
        expect(find.text('مستبعد'), findsOneWidget);
        expect(
          tester
              .getSemantics(include)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isFalse,
        );
        expect((_outline(tester, include).border! as Border).top.width, 3);
        await tester.pumpWidget(
          _app(
            table(),
            motion: motion,
            width: 390,
            direction: TextDirection.rtl,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await tester.pump(const Duration(milliseconds: 180));
        expect(FocusManager.instance.primaryFocus, same(focus));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(_paint(tester, include).color, selectedPaint);
        expect(
          tester
              .getSemantics(include)
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isTrue,
        );
        await tester.ensureVisible(_key('diff-table-apply'));
        await tester.tap(_key('diff-table-apply'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));
        expect(applied.single, {'one'});
        expect(find.text('جارٍ التطبيق'), findsWidgets);
        expect(
          tester
              .getSemantics(include)
              .getSemanticsData()
              .flagsCollection
              .isEnabled,
          ui.Tristate.isFalse,
        );
        pending.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(find.text('اكتمل التطبيق: 1'), findsWidgets);
        expect(applied, hasLength(1));
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('records $motion localized editor restores keyboard origin', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 1800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      Widget table() => _records(onPropertyChanged: (_, _) {});
      await tester.pumpWidget(_app(table(), motion: motion));
      await tester.tap(_key('records-properties'));
      await tester.pump();
      final configure = _key('records-config-summary');
      for (
        var count = 0;
        count < 12 && !_focus(tester, configure).hasFocus;
        count++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      final origin = _focus(tester, configure);
      expect(FocusManager.instance.primaryFocus, same(origin));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      await tester.showKeyboard(find.byType(EditableText).last);
      final editorFocus = _editor(tester).focusNode;
      const edit = TextEditingValue(
        text: 'استخدم تفاصيل المورد الجديد',
        selection: TextSelection(baseOffset: 0, extentOffset: 6),
      );
      tester.testTextInput.updateEditingValue(edit);
      await tester.pump();
      await tester.pumpWidget(
        _app(
          table(),
          motion: motion,
          width: 720,
          direction: TextDirection.rtl,
          textScaler: const TextScaler.linear(1.5),
        ),
      );
      await tester.pump(const Duration(milliseconds: 750));
      expect(FocusManager.instance.primaryFocus, same(editorFocus));
      expect(_editor(tester).controller.value, edit);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(find.text('تعليمات الحساب'), findsNothing);
      expect(FocusManager.instance.primaryFocus, same(origin));
      expect((_outline(tester, configure).border! as Border).top.width, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  for (final motion in [
    BeautifulMotionPolicy.system,
    BeautifulMotionPolicy.reduced,
  ]) {
    testWidgets(
      'records checkbox $motion hover press cancel and keyboard state',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final semantics = tester.ensureSemantics();
        final selections = <Set<String>>[];
        await tester.pumpWidget(
          _app(_records(onSelectionChanged: selections.add), motion: motion),
        );
        final checkbox = find.bySemanticsLabel('اختيار: خطة التسليم');
        final bounds = tester.getRect(checkbox);
        final rest = _paint(tester, checkbox).color;
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(1190, 1790));
        await mouse.moveTo(tester.getCenter(checkbox));
        await tester.pump();
        final hover = _paint(tester, checkbox).color;
        expect(hover, isNot(rest));
        await mouse.down(tester.getCenter(checkbox));
        await tester.pump(const Duration(milliseconds: 120));
        final pressed = _paint(tester, checkbox).color;
        expect(pressed, isNot(hover));
        expect(selections, isEmpty);
        await mouse.cancel();
        await tester.pump();
        expect(_paint(tester, checkbox).color, hover);
        expect(selections, isEmpty);
        await mouse.removePointer();
        await tester.pump();
        expect(_paint(tester, checkbox).color, rest);
        final focusable = find.descendant(
          of: checkbox,
          matching: find.byType(FocusableActionDetector),
        );
        final focus = tester
            .widget<FocusableActionDetector>(focusable)
            .focusNode!;
        for (var count = 0; count < 15 && !focus.hasFocus; count++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(FocusManager.instance.primaryFocus, same(focus));
        final focused = tester.getSemantics(checkbox).getSemanticsData();
        expect(focused.flagsCollection.isFocused, ui.Tristate.isTrue);
        final outline = _paint(tester, checkbox).border! as Border;
        expect(outline.top.color.a, greaterThan(0));
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));
        expect(selections.single, {'one'});
        expect(
          tester
              .getSemantics(checkbox)
              .getSemanticsData()
              .flagsCollection
              .isChecked,
          ui.CheckedState.isTrue,
        );
        final row = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: _key('records-row-one'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        expect((row.decoration as BoxDecoration).color, isNotNull);
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(tester.getRect(checkbox), bounds);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(selections.last, isEmpty);
        expect(
          tester
              .getSemantics(checkbox)
              .getSemanticsData()
              .flagsCollection
              .isChecked,
          ui.CheckedState.isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
