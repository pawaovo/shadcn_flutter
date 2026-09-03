import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/release_review/p1_p2_scenarios.dart';
import '../../test/release_review/p3_scenarios.dart';
import '../../test/test_fonts.dart';

/// An explicit export target. It never reads or changes canonical goldens.
/// Run from this package with:
/// flutter test tool/release_review/export_test.dart --concurrency=1
void main() {
  setUpAll(loadBeautifulTestFonts);

  testWidgets('export bounded accessibility review candidates', (tester) async {
    const outputPath = String.fromEnvironment(
      'RELEASE_REVIEW_OUTPUT',
      defaultValue: 'build/release_review',
    );
    const only = String.fromEnvironment('RELEASE_REVIEW_ONLY');
    final output = Directory(outputPath).absolute;
    await tester.runAsync(() => output.create(recursive: true));
    final entries = <Map<String, Object?>>[];
    final issues = <String>[];
    final scenarios = {
      ...buildP1P2ReviewScenarios(),
      ...buildP3ReviewScenarios(),
    };
    expect(scenarios.length, 20);
    final previousFatalHitTests = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() {
      WidgetController.hitTestWarningShouldBeFatal = previousFatalHitTests;
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final profile in _profiles) {
      for (final scenario in scenarios.entries) {
        if (only.isNotEmpty && !only.split(',').contains(scenario.key)) {
          continue;
        }
        tester.view.physicalSize = Size(profile.width, 2200);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          _ReviewApp(
            key: UniqueKey(),
            profile: profile,
            module: scenario.key,
            boundary: boundary,
            child: scenario.value(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        Future<void> capture(String state) async {
          Object? error;
          final renderingErrors = <String>[];
          while ((error = tester.takeException()) != null) {
            renderingErrors.add(error.toString());
          }
          final box =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          expect(box.size.width, profile.width);
          expect(box.size.height, lessThanOrEqualTo(4096));
          final filename = '${profile.id}/${scenario.key}-$state.png';
          final file = File('${output.path}/$filename');
          await tester.runAsync(() async {
            final image = await box.toImage(pixelRatio: 1);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            image.dispose();
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes.buffer.asUint8List());
          });
          entries.add({
            'file': filename,
            'module': scenario.key,
            'state': state,
            'profile': profile.id,
            'width': box.size.width,
            'height': box.size.height,
            'rendering_errors': renderingErrors,
            'visual_review': 'unreviewed',
          });
          issues.addAll(renderingErrors.map((error) => '$filename: $error'));
        }

        if (scenario.key == 'sidebar-nav' && profile.width < 600) {
          await capture('closed');
        }
        await _prepare(tester, scenario.key, compact: profile.width < 600);
        await tester.pump(const Duration(milliseconds: 400));
        await capture('prepared');
        if (scenario.key == 'approval-card') {
          await _tap(tester, find.text('Continue'));
          await _tap(tester, find.text('Save for review'));
          await _tap(tester, find.text('Send'));
          expect(find.text('Answers sent'), findsOneWidget);
          await capture('submitted');
        }
        if (scenario.key == 'records-table') {
          await _tap(tester, find.byKey(const Key('records-detail-maple')));
          expect(find.byKey(const Key('records-close-detail')), findsOneWidget);
          await capture('record-detail');
        }
        if (scenario.key == 'insight-cards') {
          for (final page in ['anomaly', 'allocation']) {
            await _tap(tester, find.byKey(const Key('beautiful-insight-next')));
            expect(
              tester
                  .widget<BeautifulInsightCards>(
                    find.byType(BeautifulInsightCards),
                  )
                  .selectedPageId,
              page,
            );
            expect(
              find.byKey(Key('beautiful-insight-card-$page')),
              findsOneWidget,
            );
            await capture(page);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    }
    await tester.runAsync(() async {
      await File('${output.path}/captures.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'schema': 1,
          'purpose': 'Supplemental human visual review; not canonical goldens.',
          'platform': Platform.operatingSystem,
          'host_os': Platform.operatingSystemVersion,
          'runtime': Platform.version,
          'pixel_ratio': 1,
          'profiles': [for (final profile in _profiles) profile.toJson()],
          'captures': entries,
        }),
      );
    });
    expect(issues, isEmpty, reason: issues.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.pump();
  await tester.tap(target.first);
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _prepare(
  WidgetTester tester,
  String module, {
  required bool compact,
}) async {
  switch (module) {
    case 'streaming-text':
      await _tap(tester, find.text('Sources (1)'));
      expect(find.textContaining('stock.csv · Daily export'), findsOneWidget);
    case 'tool-chips':
      final controls = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'beautiful-tool-step-control-',
            ),
      );
      await _tap(tester, controls);
      expect(find.text('2 records matched.'), findsOneWidget);
    case 'sidebar-nav':
      if (compact) {
        await _tap(tester, find.text('Open navigation'));
        expect(find.text('Close navigation'), findsOneWidget);
        expect(
          find.byKey(const Key('beautiful-sidebar-recent-restock')),
          findsOneWidget,
        );
      }
    case 'flowchart':
      if (compact) {
        await _tap(
          tester,
          find.byKey(
            const Key('beautiful-flowchart-field-condition-if-category'),
          ),
        );
        expect(
          find.byKey(
            const Key(
              'beautiful-flowchart-option-condition-if-category-classic',
            ),
          ),
          findsOneWidget,
        );
      }
    case 'insight-cards':
      await _tap(
        tester,
        find.byKey(const Key('beautiful-insight-data-comparison')),
      );
      expect(
        find.byKey(const Key('beautiful-insight-datum-comparison-mon')),
        findsOneWidget,
      );
    case 'selection-actions':
      await _tap(tester, find.text('Improve'));
      expect(find.text('Suggested text'), findsOneWidget);
      expect(find.text('Keep change'), findsOneWidget);
  }
}

const _profiles = [
  _Profile(
    id: 'compact-light-rtl-2x-high-contrast',
    width: 390,
    brightness: Brightness.light,
    scale: 2,
    direction: TextDirection.rtl,
    motion: BeautifulMotionPolicy.system,
    disableAnimations: true,
  ),
  _Profile(
    id: 'expanded-dark-high-contrast-reduced-motion',
    width: 1280,
    brightness: Brightness.dark,
    scale: 1,
    direction: TextDirection.ltr,
    motion: BeautifulMotionPolicy.reduced,
    disableAnimations: false,
  ),
];

final class _Profile {
  const _Profile({
    required this.id,
    required this.width,
    required this.brightness,
    required this.scale,
    required this.direction,
    required this.motion,
    required this.disableAnimations,
  });
  final String id;
  final double width;
  final Brightness brightness;
  final double scale;
  final TextDirection direction;
  final BeautifulMotionPolicy motion;
  final bool disableAnimations;

  Map<String, Object> toJson() => {
    'id': id,
    'viewport_width': width,
    'component_available_width': width - 32,
    'brightness': brightness.name,
    'high_contrast': true,
    'text_scale': scale,
    'direction': direction.name,
    'motion_policy': motion.name,
    'platform_disable_animations': disableAnimations,
    'language': 'English fixture text; RTL layout, not translation coverage',
  };
}

final class _ReviewApp extends StatelessWidget {
  const _ReviewApp({
    super.key,
    required this.profile,
    required this.module,
    required this.boundary,
    required this.child,
  });
  final _Profile profile;
  final String module;
  final GlobalKey boundary;
  final Widget child;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xff0285ff),
    debugShowCheckedModeBanner: false,
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        platformBrightness: profile.brightness,
        highContrast: true,
        disableAnimations: profile.disableAnimations,
        textScaler: TextScaler.linear(profile.scale),
      ),
      child: Directionality(
        textDirection: profile.direction,
        child: BeautifulUiScope(
          themeMode: profile.brightness == Brightness.light
              ? BeautifulUiThemeMode.light
              : BeautifulUiThemeMode.dark,
          motion: profile.motion,
          child: Overlay.wrap(
            child: SingleChildScrollView(
              child: Builder(
                builder: (context) {
                  final theme = BeautifulUiTheme.of(context);
                  return RepaintBoundary(
                    key: boundary,
                    child: ColoredBox(
                      color: theme.colors.canvas,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              module,
                              style: theme.typography.label.copyWith(
                                color: theme.colors.ink,
                              ),
                            ),
                            const SizedBox(height: 16),
                            child,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
