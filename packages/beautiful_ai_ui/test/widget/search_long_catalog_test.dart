import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

final _items = List.generate(
  1000,
  (index) => BeautifulSearchItem(
    id: 'entry-$index',
    title: 'Search entry ${index.toString().padLeft(4, '0')}',
    subtitle: index.isEven
        ? 'A deterministic searchable catalog entry with supporting text'
        : null,
    group: index % 3 == 0 ? 'Planning' : null,
  ),
);

Finder _result(int index) =>
    find.byKey(ValueKey<String>('beautiful-search-result-entry-$index'));

Finder _mountedResults() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(
        'beautiful-search-result-entry-',
      ),
);

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

Widget _app({
  required TextScaler scaler,
  List<BeautifulSearchItem>? items,
  double width = 390,
  TextDirection direction = TextDirection.ltr,
  Locale locale = const Locale('en'),
  TextStyle? labelStyle,
  BeautifulUiSpacing spacing = const BeautifulUiSpacing(),
  bool boldText = false,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => Localizations(
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
              child: BeautifulSearch(
                items: items ?? _items,
                initialQuery: 'Search entry 0',
                autofocus: true,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

// Compare each row with the actual rendered Text configuration, not the
// production measurement helper. Wrapped titles/subtitles retain their two
// lines and groups their single line even after inherited inputs change.
void _fitsRow(WidgetTester tester, int index) {
  final result = _result(index);
  final texts = find.descendant(of: result, matching: find.byType(RichText));
  var height = 0.0;
  for (final element in texts.evaluate()) {
    final rich = element.widget as RichText;
    final painter = TextPainter(
      text: rich.text,
      textAlign: rich.textAlign,
      textDirection: rich.textDirection ?? Directionality.of(element),
      textScaler: rich.textScaler,
      locale: rich.locale ?? Localizations.maybeLocaleOf(element),
      maxLines: rich.maxLines,
      ellipsis: rich.overflow == TextOverflow.ellipsis ? '\u2026' : null,
      textWidthBasis: rich.textWidthBasis,
      textHeightBehavior: rich.textHeightBehavior,
    )..layout(maxWidth: (element.findRenderObject()! as RenderBox).size.width);
    height += painter.height;
    painter.dispose();
  }
  final spacing = BeautifulUiTheme.of(tester.element(result)).spacing.sm;
  expect(
    tester.getSize(result).height,
    greaterThanOrEqualTo(height + spacing * 2 - .01),
  );
}

void main() {
  testWidgets('1000 matches mount a viewport and ArrowUp reveals the last', (
    tester,
  ) async {
    BeautifulSearchItem? selected;
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulSearch(
          items: _items,
          initialQuery: 'Search entry 0',
          onSelected: (item) => selected = item,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      _mountedResults().evaluate().length,
      lessThan(50),
      reason: 'A broad query must not mount all 1000 result rows.',
    );
    tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode
        .requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_result(999).hitTestable(), findsOneWidget);
    expect(_mountedResults().evaluate().length, lessThan(50));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_result(0).hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected?.id, 'entry-999');
    expect(tester.takeException(), isNull);
  });

  testWidgets('ten broad-match keyboard moves reuse warm row measurements', (
    tester,
  ) async {
    final scaler = _CountingScaler(1);
    await tester.pumpWidget(_app(scaler: scaler));
    await tester.pumpAndSettle();
    for (var move = 0; move < 10; move++) {
      scaler.calls = 0;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        scaler.calls,
        lessThan(250),
        reason: 'Move $move must not remeasure the full catalog.',
      );
      expect(_result(move).hitTestable(), findsOneWidget);
      expect(_mountedResults().evaluate().length, lessThan(50));
      _fitsRow(tester, move);
    }
    // Reopening the broad query also reuses measurements from the snapshot.
    await tester.enterText(find.byType(EditableText), 'Search entry 0999');
    await tester.pumpAndSettle();
    scaler.calls = 0;
    await tester.enterText(find.byType(EditableText), 'Search entry 0');
    await tester.pumpAndSettle();
    expect(scaler.calls, lessThan(250));
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
    testWidgets('$change invalidates 1000 variable result extents', (
      tester,
    ) async {
      final oldScaler = _CountingScaler(1);
      final nextScaler = change == 'text scale'
          ? _CountingScaler(2)
          : oldScaler;
      await tester.pumpWidget(_app(scaler: oldScaler));
      await tester.pumpAndSettle();
      final state = tester.state(find.byType(BeautifulSearch));
      nextScaler.calls = 0;
      await tester.pumpWidget(
        _app(
          scaler: nextScaler,
          width: change == 'width' ? 220 : 390,
          direction: change == 'direction'
              ? TextDirection.rtl
              : TextDirection.ltr,
          locale: change == 'locale' ? const Locale('ar') : const Locale('en'),
          labelStyle: switch (change) {
            'font family' => const TextStyle(
              fontFamily: 'SearchAlternateFamily',
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
              ? const BeautifulUiSpacing(sm: 12, xs: 8)
              : const BeautifulUiSpacing(),
          boldText: change == 'bold text preference',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(BeautifulSearch)), same(state));
      expect(nextScaler.calls, greaterThanOrEqualTo(1000));
      _fitsRow(tester, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_result(999).hitTestable(), findsOneWidget);
      expect(_mountedResults().evaluate().length, lessThan(50));
      _fitsRow(tester, 999);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'same list republish refreshes last-row text and keyword snapshot',
    (tester) async {
      final keywords = <String>['old-alias'];
      final items = List<BeautifulSearchItem>.of(_items);
      items[999] = BeautifulSearchItem(
        id: 'entry-999',
        title: 'Search entry 0999',
        keywords: keywords,
      );
      final scaler = _CountingScaler(2);
      await tester.pumpWidget(_app(scaler: scaler, items: items));
      await tester.pumpAndSettle();
      keywords[0] = 'new-alias';
      await tester.enterText(find.byType(EditableText), 'new-alias');
      await tester.pumpAndSettle();
      expect(_result(999), findsNothing);
      // Republish the identical list while the query is cached and unchanged.
      await tester.pumpWidget(_app(scaler: scaler, items: items));
      await tester.pumpAndSettle();
      expect(_result(999), findsOneWidget);
      items[999] = const BeautifulSearchItem(
        id: 'entry-999',
        title: 'Search entry 0999 with a much longer wrapping title',
        subtitle: 'A newly supplied long subtitle that wraps over two lines',
        group: 'Changed group',
      );
      await tester.pumpWidget(_app(scaler: scaler, items: items));
      await tester.enterText(find.byType(EditableText), 'Search entry 0');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(_result(999).hitTestable(), findsOneWidget);
      _fitsRow(tester, 999);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('last lazy result remains reachable through selected semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(scaler: TextScaler.noScaling));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    final last = find.bySemanticsLabel('Search entry 0999. Planning');
    final data = tester.getSemantics(last).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.tap(find.semantics.byLabel('Search entry 0999. Planning'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Search entry 0999',
    );
    semantics.dispose();
  });

  testWidgets(
    'scrolling and reordering a focused result retains its keyboard identity',
    (tester) async {
      final items = List<BeautifulSearchItem>.of(_items);
      await tester.pumpWidget(_app(scaler: TextScaler.noScaling, items: items));
      await tester.pumpAndSettle();
      final rowAction = find
          .ancestor(
            of: _result(0),
            matching: find.byType(FocusableActionDetector),
          )
          .first;
      final focus = tester
          .widget<FocusableActionDetector>(rowAction)
          .focusNode!;
      focus.requestFocus();
      await tester.pumpAndSettle();
      final scroll = tester.widget<ListView>(find.byType(ListView)).controller!;
      scroll.jumpTo(10000);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(_mountedResults().evaluate().length, lessThan(50));
      items.insert(900, items.removeAt(0));
      await tester.pumpWidget(_app(scaler: TextScaler.noScaling, items: items));
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(_result(901).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
