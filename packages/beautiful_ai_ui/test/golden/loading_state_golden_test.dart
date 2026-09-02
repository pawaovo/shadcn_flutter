import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_fonts.dart';
import '../test_harness.dart';

void main() {
  setUpAll(loadBeautifulTestFonts);

  for (final brightness in Brightness.values) {
    testWidgets('loading variants match the ${brightness.name} golden', (
      tester,
    ) async {
      final background = brightness == Brightness.dark
          ? const Color(0xff17181a)
          : const Color(0xfffafafb);
      final boundaryKey = Key('loading-${brightness.name}');

      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(520, 380),
          brightness: brightness,
          disableAnimations: true,
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: background,
              child: const SizedBox(
                width: 520,
                height: 380,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      BeautifulLoadingState(
                        label: 'Drive · Preparing workspace',
                        elapsed: Duration(milliseconds: 12300),
                      ),
                      SizedBox(height: 24),
                      BeautifulLoadingState(
                        label: 'Dots · Indexing sources',
                        variant: BeautifulLoadingVariant.dots,
                        elapsed: Duration(milliseconds: 48700),
                      ),
                      SizedBox(height: 24),
                      BeautifulLoadingState(
                        label: 'Orbit · Checking dependencies',
                        variant: BeautifulLoadingVariant.orbit,
                        elapsed: Duration(milliseconds: 61200),
                      ),
                      SizedBox(height: 24),
                      BeautifulLoadingState(
                        label: 'Surfer · Long-running task',
                        variant: BeautifulLoadingVariant.surfer,
                        elapsed: Duration(milliseconds: 123400),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/loading_state_${brightness.name}.png'),
      );
    });
  }
}
