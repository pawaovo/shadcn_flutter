import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _firstChunk = BeautifulContextChunk(
  id: 'vendor-rule',
  title: 'Vendor onboarding rule',
  characterCountLabel: '290 characters',
  body: 'Cold-chain certification must be verified before a new dairy can be added.',
  sourceLabel: 'Dairy Onboarding SOP.pdf',
  sourceBadge: 'PDF',
  tone: BeautifulContextTone.destructive,
);

const _secondChunk = BeautifulContextChunk(
  id: 'seasonal-demand',
  title: 'Seasonal demand row',
  characterCountLabel: '1,250 characters',
  body: 'Q4 velocity table: pistachio +18%, vanilla +6%, rocky road -11%.',
  sourceLabel: 'Sales Velocity Export.csv',
  sourceBadge: 'CSV',
  tone: BeautifulContextTone.success,
);

void main() {
  testWidgets('renders caller data and localized header/count labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulContextCards(
          chunks: <BeautifulContextChunk>[_firstChunk, _secondChunk],
          headerLabel: '检索片段',
          countLabel: '共 32 个',
        ),
      ),
    );

    expect(find.text('检索片段'), findsOneWidget);
    expect(find.text('共 32 个'), findsOneWidget);
    expect(find.text(_firstChunk.title), findsOneWidget);
    expect(find.text(_firstChunk.characterCountLabel), findsOneWidget);
    expect(find.text(_firstChunk.body), findsOneWidget);
    expect(find.text(_firstChunk.sourceLabel), findsOneWidget);
    expect(find.text(_secondChunk.sourceBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('derives a count and renders a quiet empty list', (tester) async {
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulContextCards(chunks: <BeautifulContextChunk>[]),
      ),
    );

    expect(find.text('All chunks'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('context-card-vendor-rule')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('activates a source by pointer, Enter, and Space', (
    tester,
  ) async {
    final activated = <BeautifulContextChunk>[];
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulContextCards(
          chunks: const <BeautifulContextChunk>[_firstChunk],
          onSourcePressed: activated.add,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('context-source-vendor-rule')),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(activated, <BeautifulContextChunk>[
      _firstChunk,
      _firstChunk,
      _firstChunk,
    ]);
  });

  testWidgets('expands long compact content and retains it across resize', (
    tester,
  ) async {
    final longBody = List<String>.filled(
      12,
      'This retrieved paragraph is intentionally long enough to wrap.',
    ).join(' ');
    const cardsKey = ValueKey<String>('resizable-context-cards');

    Widget app(double width) {
      return beautifulTestApp(
        size: Size(width, 900),
        disableAnimations: true,
        child: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: BeautifulContextCards(
              key: cardsKey,
              chunks: <BeautifulContextChunk>[
                BeautifulContextChunk(
                  id: 'long',
                  title: 'Long retrieved note',
                  characterCountLabel: '720 characters',
                  body: longBody,
                  sourceLabel: 'Long research note.txt',
                  sourceBadge: 'TXT',
                ),
              ],
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(app(599));
    expect(find.text('Show more'), findsOneWidget);
    expect(tester.widget<Text>(find.text(longBody)).maxLines, 3);

    await tester.tap(find.text('Show more'));
    await tester.pump();
    expect(find.text('Show less'), findsOneWidget);
    expect(tester.widget<Text>(find.text(longBody)).maxLines, isNull);

    await tester.pumpWidget(app(600));
    expect(find.text('Show more'), findsNothing);
    expect(find.text('Show less'), findsNothing);
    expect(tester.widget<Text>(find.text(longBody)).maxLines, isNull);

    await tester.pumpWidget(app(599));
    expect(find.text('Show less'), findsOneWidget);
    expect(tester.widget<Text>(find.text(longBody)).maxLines, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports boundary widths, RTL, and 200 percent text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final longBody = List<String>.filled(
      8,
      'هذا نص عربي طويل لاختبار التخطيط المتجاوب واتجاه القراءة.',
    ).join(' ');
    final chunk = BeautifulContextChunk(
      id: 'arabic',
      title: 'قاعدة استرجاع ذات عنوان طويل للغاية',
      characterCountLabel: '١٬٢٥٠ حرفًا',
      body: longBody,
      sourceLabel: 'مستند مرجعي طويل الاسم للغاية.pdf',
      sourceBadge: 'PDF',
      tone: BeautifulContextTone.accent,
    );

    for (final width in <double>[320, 599, 600, 1023, 1024]) {
      await tester.pumpWidget(
        beautifulTestApp(
          size: Size(width, 1200),
          disableAnimations: true,
          textDirection: TextDirection.rtl,
          textScaler: const TextScaler.linear(2),
          child: SingleChildScrollView(
            child: SizedBox(
              width: width,
              child: BeautifulContextCards(
                chunks: <BeautifulContextChunk>[chunk],
                headerLabel: 'كل المقاطع المسترجعة',
                countLabel: '٣٢',
                expandLabel: 'عرض المزيد',
                collapseLabel: 'عرض أقل',
                openSourceLabel: 'فتح المصدر',
                onSourcePressed: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('settles entrances immediately for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        motion: BeautifulMotionPolicy.reduced,
        child: const BeautifulContextCards(
          chunks: <BeautifulContextChunk>[_firstChunk, _secondChunk],
        ),
      ),
    );
    await tester.pump();

    for (final opacity in tester.widgetList<Opacity>(find.byType(Opacity))) {
      expect(opacity.opacity, 1);
    }
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses Android 48dp and Apple 44pt source targets', (
    tester,
  ) async {
    final originalPlatform = debugDefaultTargetPlatformOverride;
    addTearDown(() => debugDefaultTargetPlatformOverride = originalPlatform);

    Widget app() {
      return beautifulTestApp(
        disableAnimations: true,
        child: BeautifulContextCards(
          chunks: const <BeautifulContextChunk>[_firstChunk],
          onSourcePressed: (_) {},
        ),
      );
    }

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(app());
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('context-source-vendor-rule')),
          )
          .height,
      greaterThanOrEqualTo(48),
    );

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(app());
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey<String>('context-source-vendor-rule')),
          )
          .height,
      greaterThanOrEqualTo(44),
    );
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  testWidgets('rejects duplicate chunk ids with a descriptive error', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulContextCards(
          chunks: <BeautifulContextChunk>[_firstChunk, _firstChunk],
        ),
      ),
    );

    final error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect('$error', contains('unique chunk ids'));
  });

  testWidgets('defensively snapshots the caller chunk list', (tester) async {
    final chunks = <BeautifulContextChunk>[_firstChunk];
    const cardsKey = Key('snapshot-context-cards');
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulContextCards(key: cardsKey, chunks: chunks),
      ),
    );

    chunks.add(_secondChunk);
    await tester.pump();
    expect(find.text(_secondChunk.title), findsNothing);

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulContextCards(key: cardsKey, chunks: chunks),
      ),
    );
    await tester.pump();
    expect(find.text(_secondChunk.title), findsOneWidget);
  });
}
