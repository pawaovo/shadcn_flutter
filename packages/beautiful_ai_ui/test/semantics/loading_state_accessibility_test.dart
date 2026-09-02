import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('loading text meets contrast guidance in ${brightness.name}', (
      tester,
    ) async {
      await tester.pumpWidget(
        beautifulTestApp(
          brightness: brightness,
          highContrast: true,
          disableAnimations: true,
          child: Builder(
            builder: (context) {
              final theme = BeautifulUiTheme.of(context);
              return ColoredBox(
                color: theme.colors.page,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: BeautifulLoadingState(
                    label: 'Preparing workspace',
                    elapsed: Duration(milliseconds: 12300),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
