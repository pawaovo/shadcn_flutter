import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _width = BeautifulFineTuneField(
  id: 'width',
  label: 'Width',
  value: 100,
  min: 40,
  max: 999,
);
const _options = <BeautifulFineTuneOption>[
  BeautifulFineTuneOption(id: 'seasonal', label: 'Seasonal'),
  BeautifulFineTuneOption(id: 'classic', label: 'Classic'),
];

Finder _input([String id = 'width']) => find.descendant(
  of: find.byKey(ValueKey<String>('beautiful-fine-tune-input-$id')),
  matching: find.byType(EditableText),
);
Finder _increase([String id = 'width']) =>
    find.byKey(ValueKey<String>('beautiful-fine-tune-increase-$id'));
Finder _decrease([String id = 'width']) =>
    find.byKey(ValueKey<String>('beautiful-fine-tune-decrease-$id'));
String _text(WidgetTester tester, [String id = 'width']) =>
    tester.widget<EditableText>(_input(id)).controller.text;

void main() {
  test('settings snapshot fields and reject invalid identities or numbers', () {
    final fields = <BeautifulFineTuneField>[_width];
    final settings = BeautifulFineTuneSettings(fields: fields);
    fields.clear();
    expect(settings.fields, hasLength(1));
    expect(() => settings.fields.clear(), throwsUnsupportedError);
    expect(
      () => BeautifulFineTuneSettings(
        fields: <BeautifulFineTuneField>[_width, _width],
      ),
      throwsArgumentError,
    );
    for (final field in <BeautifulFineTuneField>[
      const BeautifulFineTuneField(
        id: ' ',
        label: 'Width',
        value: 1,
        min: 0,
        max: 2,
      ),
      const BeautifulFineTuneField(
        id: 'width',
        label: '',
        value: 1,
        min: 0,
        max: 2,
      ),
      const BeautifulFineTuneField(
        id: 'width',
        label: 'Width',
        value: double.nan,
        min: 0,
        max: 2,
      ),
      const BeautifulFineTuneField(
        id: 'width',
        label: 'Width',
        value: 1,
        min: 2,
        max: 0,
      ),
      const BeautifulFineTuneField(
        id: 'width',
        label: 'Width',
        value: 3,
        min: 0,
        max: 2,
      ),
      const BeautifulFineTuneField(
        id: 'width',
        label: 'Width',
        value: 1,
        min: 0,
        max: double.infinity,
      ),
      const BeautifulFineTuneField(
        id: 'width',
        label: 'Width',
        value: 1,
        min: 0,
        max: 2,
        step: 0,
      ),
    ]) {
      expect(
        () =>
            BeautifulFineTuneSettings(fields: <BeautifulFineTuneField>[field]),
        throwsArgumentError,
      );
    }
  });

  testWidgets('emits host controlled snapshots without assuming acceptance', (
    tester,
  ) async {
    final events = <BeautifulFineTuneSettings>[];
    await tester.pumpWidget(_app(onChanged: events.add));
    await tester.tap(_increase());
    await tester.pump();
    expect(events.single.fields.single.value, 101);
    expect(_text(tester), '100');
    expect(find.text('Adjust'), findsOneWidget);
  });

  testWidgets('touch adjustments preserve the complete settings snapshot', (
    tester,
  ) async {
    final events = <BeautifulFineTuneSettings>[];
    await tester.pumpWidget(_controlled(onChanged: events.add));
    await tester.tap(_increase());
    await tester.pump();
    expect(_text(tester), '101');
    expect(find.text('Edited'), findsOneWidget);
    await tester.tap(_decrease());
    await tester.pump();
    expect(_text(tester), '100');
    expect(find.text('Adjust'), findsOneWidget);
    expect(events.map((event) => event.fields.single.value), <double>[
      101,
      100,
    ]);
    expect(events.last.fields.single.label, 'Width');
    expect(events.last.fields.single.max, 999);
  });

  testWidgets('the full numeric touch target opens the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(_controlled());
    final target = find.byKey(
      const Key('beautiful-fine-tune-input-target-width'),
    );
    await tester.tapAt(tester.getTopLeft(target) + const Offset(12, 6));
    await tester.pump();
    expect(tester.widget<EditableText>(_input()).focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets(
    'numeric touch selection copies and pastes through the native menu',
    (tester) async {
      final originalPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = originalPlatform);
      var clipboardText = '250';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.getData':
            return <String, String>{'text': clipboardText};
          case 'Clipboard.hasStrings':
            return <String, bool>{'value': clipboardText.isNotEmpty};
          case 'Clipboard.setData':
            clipboardText = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final proposals = <BeautifulFineTuneSettings>[];
      final controlled = _controlled(onChanged: proposals.add);
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xff000000),
          builder: (_, child) => Overlay(
            initialEntries: <OverlayEntry>[
              OverlayEntry(builder: (_) => controlled),
            ],
          ),
        ),
      );
      await tester.longPressAt(
        tester.getTopLeft(_input()) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboardText, '100');

      clipboardText = '250';
      await tester.longPressAt(
        tester.getTopLeft(_input()) + const Offset(8, 8),
      );
      await tester.pumpAndSettle();
      expect(find.text('Paste'), findsOneWidget);
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(_text(tester), '250');
      expect(proposals, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(proposals.single.fields.single.value, 250);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = originalPlatform;
    },
  );

  testWidgets(
    'type disclosure supports keyboard dismissal and restores focus',
    (tester) async {
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xff000000),
          builder: (context, child) => _controlled(),
        ),
      );
      tester.widget<EditableText>(_input()).focusNode.requestFocus();
      await tester.pump();
      for (var index = 0; index < 3; index++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        find.byKey(const Key('beautiful-fine-tune-option-seasonal')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(
        find.byKey(const Key('beautiful-fine-tune-option-seasonal')),
        findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(
        find.byKey(const Key('beautiful-fine-tune-option-seasonal')),
        findsOneWidget,
      );
    },
  );

  testWidgets('numeric drafts commit on Enter and clamp at both bounds', (
    tester,
  ) async {
    final events = <BeautifulFineTuneSettings>[];
    await tester.pumpWidget(_controlled(onChanged: events.add));
    await tester.enterText(_input(), '5');
    await tester.pump();
    expect(_text(tester), '5');
    expect(events, isEmpty);
    await tester.enterText(_input(), '5000');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(_text(tester), '999');
    expect(events.single.fields.single.value, 999);
    await tester.enterText(_input(), '-50');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_text(tester), '40');
    expect(events.last.fields.single.value, 40);
  });

  testWidgets(
    'invalid and non-finite drafts report an error and Escape cancels',
    (tester) async {
      final events = <BeautifulFineTuneSettings>[];
      await tester.pumpWidget(_controlled(onChanged: events.add));
      for (final draft in <String>['-', 'abc', 'NaN', 'Infinity']) {
        await tester.enterText(_input(), draft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(find.text('Enter a finite number'), findsOneWidget);
        expect(events, isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(_text(tester), '100');
        expect(find.text('Enter a finite number'), findsNothing);
      }
    },
  );

  testWidgets('IME composition is untouched until committed', (tester) async {
    final events = <BeautifulFineTuneSettings>[];
    await tester.pumpWidget(_controlled(onChanged: events.add));
    await tester.showKeyboard(_input());
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '200',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(events, isEmpty);
    expect(
      tester.widget<EditableText>(_input()).controller.value.composing,
      const TextRange(start: 0, end: 3),
    );
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '200',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(events.single.fields.single.value, 200);
    expect(_text(tester), '200');
  });

  testWidgets('horizontal scrubbing preserves an active IME draft', (
    tester,
  ) async {
    final proposals = <BeautifulFineTuneSettings>[];
    // This host deliberately declines proposed changes.
    await tester.pumpWidget(_app(onChanged: proposals.add));
    await tester.showKeyboard(_input());
    const composingDraft = TextEditingValue(
      text: '200',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );
    tester.testTextInput.updateEditingValue(composingDraft);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('beautiful-fine-tune-scrub-width')),
      const Offset(64, 0),
    );
    await tester.pump();

    expect(proposals, isEmpty);
    expect(
      tester.widget<EditableText>(_input()).controller.value,
      composingDraft,
    );
    expect(tester.widget<EditableText>(_input()).focusNode.hasFocus, isTrue);
  });

  testWidgets('Arrow keys support fractional steps and Shift acceleration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _controlled(
        fields: const <BeautifulFineTuneField>[
          BeautifulFineTuneField(
            id: 'width',
            label: 'Width',
            value: 1.5,
            min: -5,
            max: 5,
            step: 0.25,
          ),
        ],
      ),
    );
    tester.widget<EditableText>(_input()).focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(_text(tester), '1.75');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_text(tester), '-0.75');
  });

  testWidgets('scrubbing is horizontal, clamped, and mirrored in RTL', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      final events = <BeautifulFineTuneSettings>[];
      await tester.pumpWidget(
        _controlled(
          key: ValueKey<TextDirection>(direction),
          textDirection: direction,
          onChanged: events.add,
        ),
      );
      await tester.drag(
        find.byKey(const Key('beautiful-fine-tune-scrub-width')),
        const Offset(48, 0),
      );
      await tester.pump();
      expect(events, isNotEmpty);
      expect(
        events.last.fields.single.value,
        direction == TextDirection.ltr ? greaterThan(100) : lessThan(100),
      );
      expect(events.last.fields.single.value, inInclusiveRange(40, 999));
    }
  });

  testWidgets(
    'layout and type actions emit accepted state and collapse options',
    (tester) async {
      final events = <BeautifulFineTuneSettings>[];
      await tester.pumpWidget(_controlled(onChanged: events.add));
      await tester.tap(
        find.byKey(const Key('beautiful-fine-tune-layout-grid')),
      );
      await tester.pump();
      expect(events.last.layout, BeautifulFineTuneLayout.grid);
      await tester.tap(find.byKey(const Key('beautiful-fine-tune-type')));
      await tester.pump();
      await tester.tap(
        find.byKey(const Key('beautiful-fine-tune-option-classic')),
      );
      await tester.pump();
      expect(events.last.typeId, 'classic');
      expect(events.last.layout, BeautifulFineTuneLayout.grid);
      expect(events.last.fields.single.value, 100);
      expect(
        find.byKey(const Key('beautiful-fine-tune-option-classic')),
        findsNothing,
      );
      expect(find.text('Classic'), findsOneWidget);
    },
  );

  testWidgets(
    'disabling editing preserves accepted values and removes options',
    (tester) async {
      await tester.pumpWidget(_app());
      await tester.tap(_increase(), warnIfMissed: false);
      await tester.tap(
        find.byKey(const Key('beautiful-fine-tune-layout-grid')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(const Key('beautiful-fine-tune-type')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(_text(tester), '100');
      expect(tester.widget<EditableText>(_input()).readOnly, isTrue);
      expect(
        find.byKey(const Key('beautiful-fine-tune-option-classic')),
        findsNothing,
      );
    },
  );

  testWidgets('draft and field identity survive resize and reorder', (
    tester,
  ) async {
    final first = BeautifulFineTuneSettings(
      fields: const <BeautifulFineTuneField>[
        _width,
        BeautifulFineTuneField(
          id: 'radius',
          label: 'Radius',
          value: 28,
          min: 0,
          max: 64,
        ),
      ],
    );
    await tester.pumpWidget(
      _app(settings: first, size: const Size(599, 900), onChanged: (_) {}),
    );
    await tester.enterText(_input(), '-');
    await tester.pumpWidget(
      _app(
        settings: BeautifulFineTuneSettings(fields: first.fields.reversed),
        size: const Size(1024, 900),
        onChanged: (_) {},
      ),
    );
    await tester.pump();
    expect(_text(tester), '-');
    expect(tester.widget<EditableText>(_input()).focusNode.hasFocus, isTrue);
    expect(_text(tester, 'radius'), '28');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'host updates replace accepted values without resetting unrelated drafts',
    (tester) async {
      await tester.pumpWidget(_app(onChanged: (_) {}));
      await tester.enterText(_input(), '-');
      await tester.pumpWidget(
        _app(
          settings: BeautifulFineTuneSettings(
            fields: const <BeautifulFineTuneField>[
              BeautifulFineTuneField(
                id: 'width',
                label: 'Width',
                value: 250,
                min: 40,
                max: 999,
              ),
            ],
          ),
          onChanged: (_) {},
        ),
      );
      await tester.pump();
      expect(_text(tester), '250');
      expect(find.text('Edited'), findsOneWidget);
    },
  );

  testWidgets('adaptive boundaries and RTL large text retain all controls', (
    tester,
  ) async {
    for (final width in <double>[320, 599, 600, 1023, 1024]) {
      await tester.pumpWidget(
        _app(
          size: Size(width, 900),
          textDirection: TextDirection.rtl,
          textScaler: const TextScaler.linear(2),
          brightness: Brightness.dark,
          highContrast: true,
          settings: BeautifulFineTuneSettings(
            fields: const <BeautifulFineTuneField>[
              BeautifulFineTuneField(
                id: 'width',
                label: 'عرض البطاقة مع وصف طويل للمحتوى',
                value: 100,
                min: 0,
                max: 1000,
                suffix: '%',
              ),
            ],
          ),
          labels: const BeautifulFineTuneLabels(
            title: 'إعدادات البطاقة وتعديل المظهر',
            row: 'ترتيب أفقي',
            column: 'ترتيب عمودي',
            grid: 'ترتيب شبكي',
          ),
          onChanged: (_) {},
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');
      for (final target in <Finder>[
        _increase(),
        _decrease(),
        find.byKey(const Key('beautiful-fine-tune-input-target-width')),
        find.byKey(const Key('beautiful-fine-tune-scrub-width')),
      ]) {
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
    }
  });

  testWidgets('long localized layout and type labels remain distinguishable', (
    tester,
  ) async {
    const prefix = '面向多语言协作空间的内容展示方式，完整保留字段和状态以便与其他选项区分：';
    const options = <BeautifulFineTuneOption>[
      BeautifulFineTuneOption(id: 'seasonal', label: '$prefix季节限定'),
      BeautifulFineTuneOption(id: 'classic', label: '$prefix经典常驻'),
    ];
    const labels = BeautifulFineTuneLabels(
      row: '$prefix横向排列',
      column: '$prefix纵向排列',
      grid: '$prefix网格排列',
    );
    await tester.pumpWidget(
      _app(
        size: const Size(320, 900),
        textScaler: const TextScaler.linear(2),
        settings: BeautifulFineTuneSettings(
          fields: const <BeautifulFineTuneField>[],
          typeId: 'seasonal',
        ),
        options: options,
        labels: labels,
        onChanged: (_) {},
      ),
    );
    for (final text in <String>[
      labels.row,
      labels.column,
      labels.grid,
      options.first.label,
    ]) {
      expect(
        tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines,
        isFalse,
        reason: text,
      );
    }

    await tester.ensureVisible(
      find.byKey(const Key('beautiful-fine-tune-type')),
    );
    await tester.tap(find.byKey(const Key('beautiful-fine-tune-type')));
    await tester.pump();
    for (final option in options) {
      final text = find.descendant(
        of: find.byKey(
          ValueKey<String>('beautiful-fine-tune-option-${option.id}'),
        ),
        matching: find.text(option.label),
      );
      expect(
        tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
        isFalse,
        reason: option.label,
      );
    }
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  BeautifulFineTuneSettings? settings,
  ValueChanged<BeautifulFineTuneSettings>? onChanged,
  Size size = const Size(390, 844),
  TextDirection textDirection = TextDirection.ltr,
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  BeautifulFineTuneLabels labels = const BeautifulFineTuneLabels(),
  List<BeautifulFineTuneOption> options = _options,
}) => beautifulTestApp(
  size: size,
  textDirection: textDirection,
  textScaler: textScaler,
  brightness: brightness,
  highContrast: highContrast,
  disableAnimations: true,
  child: SingleChildScrollView(
    child: BeautifulFineTuneCard(
      settings:
          settings ??
          BeautifulFineTuneSettings(
            fields: const <BeautifulFineTuneField>[_width],
          ),
      options: options,
      labels: labels,
      onChanged: onChanged,
    ),
  ),
);

Widget _controlled({
  Key? key,
  List<BeautifulFineTuneField> fields = const <BeautifulFineTuneField>[_width],
  ValueChanged<BeautifulFineTuneSettings>? onChanged,
  TextDirection textDirection = TextDirection.ltr,
}) {
  var settings = BeautifulFineTuneSettings(fields: fields);
  return StatefulBuilder(
    key: key,
    builder: (context, setState) => _app(
      settings: settings,
      textDirection: textDirection,
      onChanged: (next) {
        onChanged?.call(next);
        setState(() => settings = next);
      },
    ),
  );
}
