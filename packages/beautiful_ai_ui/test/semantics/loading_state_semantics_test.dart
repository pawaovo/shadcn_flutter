import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('exposes a status role and a separate non-live elapsed node', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: const BeautifulLoadingState(
          label: 'Preparing workspace',
          elapsed: Duration(milliseconds: 12300),
        ),
      ),
    );

    final status = tester
        .getSemantics(find.bySemanticsLabel('Preparing workspace'))
        .getSemanticsData();
    final elapsed = tester
        .getSemantics(find.bySemanticsLabel('Elapsed time'))
        .getSemanticsData();

    expect(status.role, SemanticsRole.status);
    expect(status.flagsCollection.isLiveRegion, isFalse);
    expect(elapsed.value, '12.3s');
    expect(elapsed.flagsCollection.isLiveRegion, isFalse);
    semantics.dispose();
  });

  testWidgets('preserves descriptive semantics from caller media', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulLoadingState(
          label: 'Processing',
          variant: BeautifulLoadingVariant.surfer,
          surferMedia: Semantics(
            label: 'Licensed decorative illustration',
            child: const ColoredBox(color: Color(0xff0285ff)),
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Licensed decorative illustration'),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
