import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/release_review/p3_acceptance_scenarios.dart';
import '../../test/release_review/review_fonts.dart';

const _modules = [
  'prompt-bar',
  'diff-table',
  'records-table',
  'sidebar-nav',
  'flowchart',
  'insight-cards',
  'selection-actions',
];
const _export = bool.fromEnvironment('P3_VISUAL_EXPORT');
const _captureOnly = bool.fromEnvironment('P3_VISUAL_CAPTURE_ONLY');
const _onlyModule = String.fromEnvironment('P3_VISUAL_ONLY_MODULE');
const _onlyProfile = String.fromEnvironment('P3_VISUAL_ONLY_PROFILE');
const _output = String.fromEnvironment(
  'P3_VISUAL_OUTPUT',
  defaultValue: 'build/p3_visual_acceptance',
);

void main() {
  final profiles = <_Profile>[
    for (final width in <double>[390, 800, 1280])
      for (final brightness in Brightness.values)
        for (final highContrast in [false, true])
          for (final scale in <double>[1, 2])
            for (final language in P3ReviewLanguage.values)
              for (final reduced in [false, true])
                _Profile(
                  width,
                  brightness,
                  highContrast,
                  scale,
                  language,
                  reduced,
                ),
  ];
  final captures = <Map<String, Object?>>[];
  final cases = <Map<String, Object?>>[];
  setUpAll(loadReviewFonts);

  tearDownAll(() async {
    if (!_export) return;
    final directory = Directory(_output);
    await directory.create(recursive: true);
    await File('${directory.path}/captures.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'purpose': 'P3 finite visual/localization matrix; exported PNGs require human inspection.',
        'platform': Platform.operatingSystem,
        'host_os': Platform.operatingSystemVersion,
        'dart_runtime': Platform.version,
        'pixel_ratio': 1,
        'total_planned_matrix_cases': profiles.length * _modules.length,
        'capture_only': _captureOnly,
        'profiles': [for (final profile in profiles) profile.toJson()],
        'cases': cases,
        'captures': captures,
      }),
    );
  });

  for (final module in _modules) {
    if (_onlyModule.isNotEmpty && module != _onlyModule) continue;
    testWidgets('P3 $module finite translated appearance matrix', (
      tester,
    ) async {
      final oldFatal = WidgetController.hitTestWarningShouldBeFatal;
      final oldHighlight = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      WidgetController.hitTestWarningShouldBeFatal = true;
      final semantics = tester.ensureSemantics();
      addTearDown(() {
        WidgetController.hitTestWarningShouldBeFatal = oldFatal;
        FocusManager.instance.highlightStrategy = oldHighlight;
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });
      tester.view.devicePixelRatio = 1;
      try {
        var visited = 0;
        for (final profile in profiles) {
          if (_onlyProfile.isNotEmpty && profile.id != _onlyProfile) continue;
          if (_captureOnly && !profile.capture) continue;
          final c = P3ReviewCopy(profile.language);
          final boundary = GlobalKey();
          tester.view.physicalSize = Size(profile.width, 4096);
          await tester.pumpWidget(
            _MatrixApp(
              key: UniqueKey(),
              profile: profile,
              module: module,
              boundary: boundary,
              child: buildP3AcceptanceScenarios(c)[module]!(),
            ),
          );
          await tester.pump(const Duration(milliseconds: 350));
          _assertNoRenderingError(tester, module, profile.id, 'initial');
          final box =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          expect(box.size.width, profile.width, reason: profile.id);
          expect(
            box.size.height,
            lessThanOrEqualTo(4096),
            reason: '$module / ${profile.id}',
          );
          expect(
            tester.getSize(_moduleFinder(module)).width,
            lessThanOrEqualTo(profile.width - 32),
          );
          expect(
            Directionality.of(tester.element(_moduleFinder(module))),
            c.direction,
          );
          expect(
            MediaQuery.textScalerOf(tester.element(_moduleFinder(module)))
                .scale(14),
            profile.scale * 14,
          );
          if (module == 'selection-actions') {
            final editor = tester.state<EditableTextState>(
              find.byType(EditableText).first,
            );
            final value = editor.textEditingValue;
            expect(value.selection.textInside(value.text), c.shortBody);
            final selected = editor.renderEditable.getBoxesForSelection(
              value.selection,
            );
            final unselected = editor.renderEditable.getBoxesForSelection(
              TextSelection(
                baseOffset: c.shortBody.length + 1,
                extentOffset: c.shortBody.length + 5,
              ),
            );
            expect(
              selected.any(
                (box) => unselected.any((other) {
                  final overlap = box.toRect().intersect(other.toRect());
                  return overlap.width > .5 && overlap.height > .5;
                }),
              ),
              isFalse,
              reason:
                  'Selected paint must not cover unselected glyphs: ${profile.id}',
            );
          }

          Future<void> capture(String state) async {
            if (!_export || !profile.capture) return;
            if (state != 'prepared' &&
                state != 'closed' &&
                state != 'expanded-rail' &&
                state != 'keyboard-focus' &&
                state != 'pointer-held' &&
                !profile.extendedCapture) {
              return;
            }
            _assertNoRenderingError(tester, module, profile.id, state);
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            expect(
              render.size.height,
              lessThanOrEqualTo(4096),
              reason: '$module/$state/${profile.id}',
            );
            final relative = '${profile.id}/$module-$state.png';
            await tester.runAsync(() async {
              final image = await render.toImage(pixelRatio: 1);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              image.dispose();
              final file = File('$_output/$relative');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes.buffer.asUint8List());
            });
            captures.add({
              'file': relative,
              'module': module,
              'profile': profile.id,
              'state': state,
              'width': render.size.width,
              'height': render.size.height,
              'component_width': tester.getSize(_moduleFinder(module)).width,
              'rendering_errors': <String>[],
              'visual_review': 'unreviewed',
            });
          }

          if (module == 'sidebar-nav' && profile.width < 600) {
            await capture('closed');
            await _tap(
              tester,
              find.byKey(const Key('beautiful-sidebar-toggle')),
            );
            expect(
              find.byKey(const PageStorageKey('beautiful-sidebar-history')),
              findsOneWidget,
            );
          }
          if (module == 'insight-cards') {
            await _tap(
              tester,
              find.byKey(const Key('beautiful-insight-data-comparison')),
            );
            expect(
              find.byKey(const Key('beautiful-insight-datum-comparison-tue')),
              findsOneWidget,
            );
          }
          if (module == 'flowchart') {
            final canvas = profile.width - 32 >= 1024 && profile.scale <= 1.3;
            expect(
              find.byKey(const Key('beautiful-flowchart-viewer')),
              canvas ? findsOneWidget : findsNothing,
            );
          }
          await tester.pump(const Duration(milliseconds: 350));
          _assertNoRenderingError(tester, module, profile.id, 'prepared');
          await capture('prepared');
          if (_export && profile.id == 'expanded-light-hc-1x-english-normal') {
            final control = switch (module) {
              'prompt-bar' => find.byKey(const Key('beautiful-prompt-send')),
              'diff-table' => find.byKey(const Key('diff-table-apply')),
              'records-table' => find.byKey(const Key('records-properties')),
              'sidebar-nav' => find.byKey(
                const Key('beautiful-sidebar-workspace'),
              ),
              'flowchart' => find.byKey(
                const Key('beautiful-flowchart-zoom-in'),
              ),
              'insight-cards' => find.byKey(
                const Key('beautiful-insight-data-comparison'),
              ),
              _ =>
                find
                    .ancestor(
                      of: find.text(c.improve),
                      matching: find.byType(GestureDetector),
                    )
                    .first,
            };
            final gesture = control.evaluate().single.widget is GestureDetector
                ? control
                : find
                      .descendant(
                        of: control,
                        matching: find.byType(GestureDetector),
                      )
                      .last;
            final focus = Focus.of(tester.element(gesture));
            for (var step = 0; step < 80 && !focus.hasPrimaryFocus; step++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pump();
            }
            expect(
              focus.hasPrimaryFocus,
              isTrue,
              reason: '$module keyboard focus',
            );
            await tester.pump(const Duration(milliseconds: 200));
            await capture('keyboard-focus');
            focus.unfocus();
            await tester.pump(const Duration(milliseconds: 200));
            final mouse = await tester.createGesture(
              kind: PointerDeviceKind.mouse,
            );
            await mouse.addPointer(location: Offset(profile.width - 2, 4000));
            await mouse.moveTo(tester.getCenter(control));
            await tester.pump(const Duration(milliseconds: 200));
            await mouse.down(tester.getCenter(control));
            await tester.pump(const Duration(milliseconds: 160));
            await tester.pump(const Duration(milliseconds: 160));
            await capture('pointer-held');
            await mouse.cancel();
            await mouse.removePointer();
            await tester.pump(const Duration(milliseconds: 200));
          }

          // These extra states make intentionally truncated/hidden content
          // reviewable. The main finite matrix always checks their real action.
          if (module == 'selection-actions') {
            await _tap(tester, find.text(c.improve));
            expect(find.text(c.selectionLabels.after), findsOneWidget);
            expect(find.text(c.replacement), findsOneWidget);
            await capture('suggestion');
            await _tap(tester, find.text(c.selectionLabels.discard));
            expect(find.text(c.selectionLabels.after), findsNothing);
          } else if (module == 'records-table') {
            await _tap(tester, find.byKey(const Key('records-detail-maple')));
            expect(
              find.byKey(const Key('records-close-detail')),
              findsOneWidget,
            );
            expect(find.textContaining(c.error), findsWidgets);
            await capture('record-detail');
          } else if (module == 'prompt-bar') {
            await tester.enterText(find.byType(EditableText).first, '@');
            await tester.pump(const Duration(milliseconds: 350));
            expect(
              find.byKey(const Key('beautiful-prompt-option-source-source')),
              findsOneWidget,
            );
            await capture('source-options');
          } else if (module == 'flowchart') {
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
            await capture('condition-options');
          } else if (module == 'sidebar-nav' &&
              profile.width >= 600 &&
              profile.width < 1024) {
            await _tap(
              tester,
              find.byKey(const Key('beautiful-sidebar-toggle')),
            );
            expect(
              find.byKey(const PageStorageKey('beautiful-sidebar-history')),
              findsOneWidget,
            );
            await capture('expanded-rail');
          } else if (module == 'insight-cards') {
            for (final page in ['anomaly', 'allocation']) {
              await _tap(
                tester,
                find.byKey(const Key('beautiful-insight-next')),
              );
              expect(
                tester
                    .widget<BeautifulInsightCards>(
                      find.byType(BeautifulInsightCards),
                    )
                    .selectedPageId,
                page,
              );
              await capture(page);
            }
          }
          if (module == 'sidebar-nav') {
            final history = find.byKey(
              const PageStorageKey('beautiful-sidebar-history'),
            );
            final recent = find.byKey(
              const Key('beautiful-sidebar-recent-restock'),
            );
            await tester.scrollUntilVisible(
              recent,
              180,
              scrollable: find
                  .descendant(of: history, matching: find.byType(Scrollable))
                  .first,
              maxScrolls: 12,
            );
            await tester.pump(const Duration(milliseconds: 350));
            expect(recent.hitTestable(), findsOneWidget);
            await capture('recent-items');
          }
          _assertNoRenderingError(tester, module, profile.id, 'final-action');
          cases.add({
            'module': module,
            'profile': profile.id,
            'status': 'passed',
          });
          visited++;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
        expect(visited, greaterThan(0));
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        semantics.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 10)));
  }
}

void _assertNoRenderingError(
  WidgetTester tester,
  String module,
  String profile,
  String state,
) {
  expect(tester.takeException(), isNull, reason: '$module / $profile / $state');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 350));
}

Finder _moduleFinder(String module) => switch (module) {
  'prompt-bar' => find.byType(BeautifulPromptBar),
  'diff-table' => find.byType(BeautifulDiffTable),
  'records-table' => find.byType(BeautifulRecordsTable),
  'sidebar-nav' => find.byType(BeautifulSidebarNav),
  'flowchart' => find.byType(BeautifulFlowchart),
  'insight-cards' => find.byType(BeautifulInsightCards),
  'selection-actions' => find.byType(BeautifulSelectionActions),
  _ => throw StateError('Unknown module $module'),
};

final class _Profile {
  const _Profile(
    this.width,
    this.brightness,
    this.highContrast,
    this.scale,
    this.language,
    this.reduced,
  );
  final double width;
  final Brightness brightness;
  final bool highContrast;
  final double scale;
  final P3ReviewLanguage language;
  final bool reduced;

  String get layout => width < 600
      ? 'compact'
      : width < 1024
      ? 'medium'
      : 'expanded';
  String get id =>
      '$layout-${brightness.name}-${highContrast ? 'hc' : 'normal'}-${scale.toInt()}x-${language.name}-${reduced ? 'reduced' : 'normal'}';
  bool get capture => const {
    'compact-light-normal-2x-english-normal',
    'compact-dark-hc-2x-arabic-reduced',
    'compact-light-hc-2x-chinese-reduced',
    'compact-dark-normal-1x-chinese-normal',
    'medium-light-hc-2x-arabic-normal',
    'medium-dark-normal-2x-english-reduced',
    'medium-light-normal-1x-chinese-reduced',
    'medium-dark-hc-1x-arabic-normal',
    'expanded-light-normal-2x-arabic-reduced',
    'expanded-dark-hc-2x-chinese-normal',
    'expanded-light-hc-1x-english-normal',
    'expanded-dark-normal-1x-english-reduced',
  }.contains(id);

  bool get extendedCapture => const {
    'compact-dark-hc-2x-arabic-reduced',
    'medium-light-normal-1x-chinese-reduced',
    'expanded-light-hc-1x-english-normal',
  }.contains(id);

  Map<String, Object> toJson() => {
    'id': id,
    'layout_constraints': layout,
    'viewport_width': width,
    'component_available_width': width - 32,
    'brightness': brightness.name,
    'high_contrast': highContrast,
    'text_scale': scale,
    'language': language.name,
    'direction': P3ReviewCopy(language).direction.name,
    'motion': reduced ? 'reduced' : 'system',
    'platform_disable_animations': false,
    'human_review_capture_profile': capture,
  };
}

final class _MatrixApp extends StatelessWidget {
  const _MatrixApp({
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
    color: const Color(0xfffafafb),
    debugShowCheckedModeBanner: false,
    locale: switch (profile.language) {
      P3ReviewLanguage.english => const Locale('en'),
      P3ReviewLanguage.chinese => const Locale('zh'),
      P3ReviewLanguage.arabic => const Locale('ar'),
    },
    supportedLocales: const [Locale('en'), Locale('zh'), Locale('ar')],
    localizationsDelegates: const [GlobalWidgetsLocalizations.delegate],
    builder: (context, _) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        platformBrightness: profile.brightness,
        highContrast: profile.highContrast,
        textScaler: TextScaler.linear(profile.scale),
        disableAnimations: false,
      ),
      child: Directionality(
        textDirection: P3ReviewCopy(profile.language).direction,
        child: BeautifulUiScope(
          theme: reviewTheme(const BeautifulUiThemeData.light()),
          darkTheme: reviewTheme(const BeautifulUiThemeData.dark()),
          themeMode: profile.brightness == Brightness.light
              ? BeautifulUiThemeMode.light
              : BeautifulUiThemeMode.dark,
          motion: profile.reduced
              ? BeautifulMotionPolicy.reduced
              : BeautifulMotionPolicy.system,
          child: FocusScope(
            autofocus: true,
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
                                '$module · ${profile.id}',
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
    ),
  );
}
