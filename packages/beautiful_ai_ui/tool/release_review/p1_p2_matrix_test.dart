import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/release_review/p1_p2_matrix_scenarios.dart';
import '../../test/release_review/review_fonts.dart';

const p1P2MatrixProfiles = <P1P2MatrixProfile>[
  P1P2MatrixProfile(
    'compact-dark-long-en-2x',
    390,
    Brightness.dark,
    false,
    2,
    'en',
    BeautifulMotionPolicy.none,
  ),
  P1P2MatrixProfile(
    'compact-light-hc-ar-rtl-2x',
    390,
    Brightness.light,
    true,
    2,
    'ar',
    BeautifulMotionPolicy.system,
    disableAnimations: true,
  ),
  P1P2MatrixProfile(
    'medium-light-zh-2x',
    768,
    Brightness.light,
    false,
    2,
    'zh',
    BeautifulMotionPolicy.reduced,
  ),
  P1P2MatrixProfile(
    'medium-dark-hc-long-en-1x',
    768,
    Brightness.dark,
    true,
    1,
    'en',
    BeautifulMotionPolicy.none,
  ),
  P1P2MatrixProfile(
    'expanded-light-ar-rtl-1x',
    1280,
    Brightness.light,
    false,
    1,
    'ar',
    BeautifulMotionPolicy.reduced,
  ),
  P1P2MatrixProfile(
    'expanded-dark-zh-2x',
    1280,
    Brightness.dark,
    false,
    2,
    'zh',
    BeautifulMotionPolicy.system,
    disableAnimations: true,
  ),
];

void main() {
  setUpAll(loadReviewFonts);

  testWidgets('P1/P2 complementary locale and adaptive matrix', (tester) async {
    const outputPath = String.fromEnvironment('P1P2_MATRIX_OUTPUT');
    const selectedModules = String.fromEnvironment('P1P2_MATRIX_ONLY');
    const selectedProfiles = String.fromEnvironment('P1P2_MATRIX_PROFILES');
    final entries = <Map<String, Object?>>[];
    final failures = <String>[];
    final fatal = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = fatal);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final profile in p1P2MatrixProfiles) {
      if (selectedProfiles.isNotEmpty &&
          !selectedProfiles.split(',').contains(profile.id)) {
        continue;
      }
      final copy = MatrixCopy(profile.language);
      final scenarios = buildP1P2MatrixScenarios(copy);
      expect(scenarios.length, 13);
      for (final scenario in scenarios.entries) {
        if (selectedModules.isNotEmpty &&
            !selectedModules.split(',').contains(scenario.key)) {
          continue;
        }
        tester.view.physicalSize = Size(profile.width, 2400);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          P1P2MatrixApp(
            key: UniqueKey(),
            profile: profile,
            boundary: boundary,
            title: '${scenario.key} · ${profile.id}',
            child: scenario.value(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        await prepareMatrixScenario(tester, scenario.key, copy);
        await tester.pump(const Duration(milliseconds: 400));
        final box =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        expect(box.size.width, profile.width);
        expect(box.size.height, lessThanOrEqualTo(4096));
        final errors = <String>[];
        Object? error;
        while ((error = tester.takeException()) != null) {
          errors.add(error.toString());
        }
        failures.addAll(
          errors.map((error) => '${profile.id}/${scenario.key}: $error'),
        );
        final filename = '${profile.id}/${scenario.key}.png';
        if (outputPath.isNotEmpty) {
          await tester.runAsync(() async {
            final image = await box.toImage(pixelRatio: 1);
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            image.dispose();
            final file = File('$outputPath/$filename');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes.buffer.asUint8List());
          });
        }
        entries.add({
          'module': scenario.key,
          'profile': profile.id,
          'file': filename,
          'width': box.size.width,
          'height': box.size.height,
          'rendering_errors': errors,
          'visual_review': 'unreviewed',
        });
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    }
    if (outputPath.isNotEmpty) {
      await tester.runAsync(() async {
        await File('$outputPath/captures.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'schema': 1,
            'scope': 'Six complementary profiles; not a full Cartesian matrix.',
            'platform': Platform.operatingSystem,
            'host_os': Platform.operatingSystemVersion,
            'dpr': 1,
            'captured_at_utc': DateTime.now().toUtc().toIso8601String(),
            'profiles': [
              for (final profile in p1P2MatrixProfiles) profile.toJson(),
            ],
            'captures': entries,
          }),
        );
      });
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 4)));
}

Future<void> prepareMatrixScenario(
  WidgetTester tester,
  String module,
  MatrixCopy copy,
) async {
  Future<void> tap(Finder finder) async {
    expect(finder, findsWidgets);
    await tester.ensureVisible(finder.first);
    await tester.pump();
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 220));
  }

  if (module == 'streaming-text') {
    await tap(find.text('${copy.text('Sources')} (1)'));
    expect(find.textContaining(copy.text('Daily export')), findsOneWidget);
  }
  if (module == 'tool-chips') {
    await tap(find.byKey(const ValueKey('beautiful-tool-step-control-read')));
    expect(find.text(copy.text('2 records matched.')), findsOneWidget);
  }
}

final class P1P2MatrixProfile {
  const P1P2MatrixProfile(
    this.id,
    this.width,
    this.brightness,
    this.highContrast,
    this.scale,
    this.language,
    this.motion, {
    this.disableAnimations = false,
  });
  final String id;
  final double width;
  final Brightness brightness;
  final bool highContrast;
  final double scale;
  final String language;
  final BeautifulMotionPolicy motion;
  final bool disableAnimations;
  TextDirection get direction =>
      language == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  Map<String, Object> toJson() => {
    'id': id,
    'viewport_width': width,
    'component_width': width - 32,
    'brightness': brightness.name,
    'high_contrast': highContrast,
    'text_scale': scale,
    'language': language,
    'direction': direction.name,
    'motion': motion.name,
    'disable_animations': disableAnimations,
  };
}

final class P1P2MatrixApp extends StatelessWidget {
  const P1P2MatrixApp({
    super.key,
    required this.profile,
    required this.boundary,
    required this.title,
    required this.child,
  });
  final P1P2MatrixProfile profile;
  final GlobalKey boundary;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => WidgetsApp(
    color: const Color(0xff0285ff),
    debugShowCheckedModeBanner: false,
    locale: Locale(profile.language),
    supportedLocales: const [Locale('en'), Locale('zh'), Locale('ar')],
    localizationsDelegates: const [GlobalWidgetsLocalizations.delegate],
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        platformBrightness: profile.brightness,
        highContrast: profile.highContrast,
        disableAnimations: profile.disableAnimations,
        textScaler: TextScaler.linear(profile.scale),
      ),
      child: Directionality(
        textDirection: profile.direction,
        child: BeautifulUiScope(
          theme: reviewTheme(const BeautifulUiThemeData.light()),
          darkTheme: reviewTheme(const BeautifulUiThemeData.dark()),
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
                              title,
                              style: theme.typography.caption.copyWith(
                                color: theme.colors.inkMuted,
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
