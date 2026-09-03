import 'dart:convert';
import 'dart:ui' show BoxWidthStyle;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/release_review/p3_acceptance_scenarios.dart';
import '../../test/release_review/review_fonts.dart';

void main() {
  setUpAll(loadReviewFonts);
  testWidgets('probe exact Arabic selection paint boxes at two text scales', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const c = P3ReviewCopy(P3ReviewLanguage.arabic);
    final observations = <Map<String, Object?>>[];
    for (final scale in <double>[1, 2]) {
      for (final width in <double>[390, 800, 1280]) {
        tester.view.physicalSize = Size(width, 1600);
        await tester.pumpWidget(
          WidgetsApp(
            key: UniqueKey(),
            color: const Color(0xffffffff),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [GlobalWidgetsLocalizations.delegate],
            builder: (context, _) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: BeautifulUiScope(
                  theme: reviewTheme(const BeautifulUiThemeData.light()),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: buildP3AcceptanceScenarios(
                          c,
                        )['selection-actions']!(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final editor = tester.state<EditableTextState>(
          find.byType(EditableText).first,
        );
        final range = editor.textEditingValue.selection;
        final render = editor.renderEditable;
        expect(range.textInside(editor.textEditingValue.text), c.shortBody);
        final current = render
            .getBoxesForSelection(range)
            .map((box) => box.toRect())
            .toList();
        render.selectionWidthStyle = BoxWidthStyle.tight;
        final tight = render
            .getBoxesForSelection(range)
            .map((box) => box.toRect())
            .toList();
        final body = render
            .getBoxesForSelection(
              TextSelection(
                baseOffset: c.shortBody.length + 1,
                extentOffset: c.shortBody.length + 5,
              ),
            )
            .map((box) => box.toRect())
            .toList();
        bool overlaps(List<Rect> boxes) => boxes.any(
          (box) => body.any(
            (other) =>
                box.intersect(other).width > .5 &&
                box.intersect(other).height > .5,
          ),
        );
        expect(
          overlaps(current),
          isFalse,
          reason:
              'Native selected paint overlaps unselected Arabic glyphs at width=$width, scale=$scale',
        );
        observations.add({
          'scale': scale,
          'width': width,
          'range': [range.start, range.end],
          'current_boxes': current.map((rect) => rect.toString()).toList(),
          'tight_boxes': tight.map((rect) => rect.toString()).toList(),
          'body_boxes': body.map((rect) => rect.toString()).toList(),
          'current_overlaps_unselected_body': overlaps(current),
          'tight_overlaps_unselected_body': overlaps(tight),
        });
      }
    }
    debugPrint(const JsonEncoder.withIndent('  ').convert(observations));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
