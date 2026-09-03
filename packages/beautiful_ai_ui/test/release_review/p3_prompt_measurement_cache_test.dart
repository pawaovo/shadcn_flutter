import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Count actual text scaling requests made during layout. This exercises the
// public composer with the full workload without relying on wall-clock speed
// or exposing a production cache/test counter.
final class _ScaleCounter {
  var calls = 0;
}

final class _CountingScaler extends TextScaler {
  _CountingScaler(this.factor);
  final double factor;
  final _counter = _ScaleCounter();

  int get calls => _counter.calls;
  set calls(int value) => _counter.calls = value;

  @override
  double scale(double fontSize) {
    calls++;
    return fontSize * factor;
  }

  @override
  double get textScaleFactor => factor;
}

List<BeautifulPromptSource> _sources({String suffix = ''}) => [
  for (var index = 0; index < 1000; index++)
    BeautifulPromptSource(
      id: 's$index',
      label: 'Source $index',
      description: 'Details $index$suffix',
    ),
];

Widget _app({
  required TextScaler scaler,
  List<BeautifulPromptSource>? sources,
  double width = 390,
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  TextStyle? labelStyle,
  BeautifulUiSpacing spacing = const BeautifulUiSpacing(),
  bool boldText = false,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => FocusScope(
    autofocus: true,
    child: Localizations(
      locale: locale,
      delegates: const [DefaultWidgetsLocalizations.delegate],
      child: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 1000),
          textScaler: scaler,
          disableAnimations: true,
          boldText: boldText,
        ),
        child: Directionality(
          textDirection: direction,
          child: BeautifulUiScope(
            theme: BeautifulUiThemeData(
              colors: const BeautifulUiColors.light(),
              typography: BeautifulUiTypography(
                label: labelStyle ?? const BeautifulUiTypography().label,
              ),
              spacing: spacing,
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: BeautifulPromptBar(
                  composerId: 'measurement-workload',
                  initialDraft: List.filled(1000, 'long text ').join(),
                  sources: sources ?? _sources(),
                  onSend: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder _option(int index) =>
    find.byKey(ValueKey<String>('beautiful-prompt-option-source-s$index'));

Finder _realizedOptions() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(
        'beautiful-prompt-option-source-',
      ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText), '@');
  await tester.pumpAndSettle();
  expect(_realizedOptions().evaluate().length, lessThan(50));
}

Future<void> _last(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
  await tester.pumpAndSettle();
  expect(_option(999), findsOneWidget);
  expect(_realizedOptions().evaluate().length, lessThan(50));
}

void _fitsLabel(WidgetTester tester, int index) {
  final control = _option(index);
  final text = find.descendant(of: control, matching: find.byType(RichText));
  final theme = BeautifulUiTheme.of(tester.element(control));
  final rich = tester.widget<RichText>(text);
  final paragraph = TextPainter(
    text: rich.text,
    textAlign: rich.textAlign,
    textDirection:
        rich.textDirection ?? Directionality.of(tester.element(text)),
    textScaler: rich.textScaler,
    locale: rich.locale ?? Localizations.maybeLocaleOf(tester.element(text)),
    maxLines: rich.maxLines,
    strutStyle: rich.strutStyle,
    textWidthBasis: rich.textWidthBasis,
    textHeightBehavior: rich.textHeightBehavior,
  )..layout(maxWidth: tester.getSize(text).width);
  expect(
    tester.getSize(control).height,
    greaterThanOrEqualTo(paragraph.height + theme.spacing.sm * 2 + 2 - .01),
  );
  paragraph.dispose();
}

void main() {
  testWidgets('1000 sources reuse measurements for keyboard and reopen', (
    tester,
  ) async {
    final scaler = _CountingScaler(1);
    await tester.pumpWidget(_app(scaler: scaler));
    await _open(tester);
    for (var round = 0; round < 3; round++) {
      scaler.calls = 0;
      await _last(tester);
      expect(
        scaler.calls,
        lessThan(250),
        reason: 'ArrowUp must not measure all 1000 option labels again.',
      );
      _fitsLabel(tester, 999);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '@Source 999 ',
      );
      scaler.calls = 0;
      await _open(tester);
      expect(
        scaler.calls,
        lessThan(250),
        reason: 'Closing and reopening retains unchanged option measurements.',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final change in [
    'width',
    'text scale',
    'direction',
    'locale',
    'font family',
    'font weight and height',
    'theme spacing',
    'bold text preference',
  ]) {
    testWidgets('$change invalidates warm 1000-option layout', (tester) async {
      final originalScaler = _CountingScaler(1);
      final updatedScaler = change == 'text scale'
          ? _CountingScaler(2)
          : originalScaler;
      final sources = _sources(suffix: ' with a deliberately wrapping label');
      await tester.pumpWidget(_app(scaler: originalScaler, sources: sources));
      await _open(tester);
      final state = tester.state(find.byType(BeautifulPromptBar));
      updatedScaler.calls = 0;
      await tester.pumpWidget(
        _app(
          scaler: updatedScaler,
          sources: sources,
          width: change == 'width' ? 260 : 390,
          direction: change == 'direction'
              ? TextDirection.rtl
              : TextDirection.ltr,
          locale: change == 'locale' ? const Locale('ar') : const Locale('en'),
          labelStyle: switch (change) {
            'font family' => const TextStyle(
              fontFamily: 'P3PromptAlternateFamily',
              height: 1.5,
            ),
            'font weight and height' =>
              const BeautifulUiTypography().label.copyWith(
                fontWeight: FontWeight.w900,
                height: 2.4,
              ),
            _ => null,
          },
          spacing: change == 'theme spacing'
              ? const BeautifulUiSpacing(sm: 12, md: 20)
              : const BeautifulUiSpacing(),
          boldText: change == 'bold text preference',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(BeautifulPromptBar)), same(state));
      expect(
        updatedScaler.calls,
        greaterThanOrEqualTo(1000),
        reason: 'All retained option extents depend on the changed $change.',
      );
      _fitsLabel(tester, 0);
      await _last(tester);
      _fitsLabel(tester, 999);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '@Source 999 ',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('same source ID with new complete text gets a new extent', (
    tester,
  ) async {
    final scaler = _CountingScaler(1);
    final sources = _sources();
    await tester.pumpWidget(_app(scaler: scaler, sources: sources));
    await _open(tester);
    sources[999] = const BeautifulPromptSource(
      id: 's999',
      label: 'Source 999 updated',
      description:
          'التفاصيل الجديدة\n保留完整说明文字，不得遮挡\n'
          'A longer replacement description that wraps on a narrow composer.',
    );
    scaler.calls = 0;
    await tester.pumpWidget(_app(scaler: scaler, sources: sources));
    await tester.pumpAndSettle();
    expect(scaler.calls, lessThan(250));
    await _last(tester);
    _fitsLabel(tester, 999);
    expect(find.textContaining('التفاصيل الجديدة'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '@Source 999 updated ',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late FontLoader invalidates cached metrics without family change',
    (tester) async {
      final scaler = _CountingScaler(1);
      const family = 'P3PromptDynamicallyLoadedSans';
      await tester.pumpWidget(
        _app(
          scaler: scaler,
          labelStyle: const TextStyle(
            inherit: false,
            fontFamily: family,
            fontSize: 13,
            height: 1.5,
          ),
          sources: _sources(suffix: ' with a deliberately wrapping label'),
        ),
      );
      await _open(tester);
      final previousHeight = tester.getSize(_option(0)).height;
      final state = tester.state(find.byType(BeautifulPromptBar));
      scaler.calls = 0;
      await tester.runAsync(() async {
        final loader = FontLoader(family)
          ..addFont(
            rootBundle.load(
              'packages/shadcn_flutter/lib/fonts/Geist-Regular.otf',
            ),
          );
        await loader.load();
      });
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(BeautifulPromptBar)), same(state));
      expect(scaler.calls, greaterThanOrEqualTo(1000));
      expect(tester.getSize(_option(0)).height, isNot(previousHeight));
      _fitsLabel(tester, 0);
      await _last(tester);
      _fitsLabel(tester, 999);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.binding.handleSystemMessage({'type': 'fontsChange'});
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
