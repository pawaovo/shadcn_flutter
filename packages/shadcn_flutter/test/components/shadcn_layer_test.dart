import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('ShadcnLayer disables theme transitions when requested', (
    tester,
  ) async {
    await tester.pumpWidget(_testLayer(enableThemeAnimation: false));

    final animatedTheme = tester.widget<ShadcnAnimatedTheme>(
      find.byType(ShadcnAnimatedTheme),
    );
    expect(animatedTheme.duration, Duration.zero);
  });

  testWidgets('ShadcnLayer keeps the default transition when enabled', (
    tester,
  ) async {
    await tester.pumpWidget(_testLayer(enableThemeAnimation: true));

    final animatedTheme = tester.widget<ShadcnAnimatedTheme>(
      find.byType(ShadcnAnimatedTheme),
    );
    expect(animatedTheme.duration, kDefaultDuration);
  });
}

Widget _testLayer({required bool enableThemeAnimation}) {
  return MediaQuery(
    data: const MediaQueryData(),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ShadcnLayer(
        theme: const ThemeData(),
        enableThemeAnimation: enableThemeAnimation,
        child: const SizedBox.shrink(),
      ),
    ),
  );
}
