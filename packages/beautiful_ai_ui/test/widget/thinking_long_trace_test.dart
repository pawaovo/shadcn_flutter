import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('200 completed steps settle while hidden and after disclosure', (
    tester,
  ) async {
    final items = List.generate(
      200,
      (index) =>
          BeautifulThinkingItem(id: 'step-$index', label: 'Trace step $index'),
    );
    final changes = <bool>[];
    final activations = <String>[];
    await tester.pumpWidget(
      beautifulTestApp(
        child: SingleChildScrollView(
          child: BeautifulThinking(
            variant: BeautifulThinkingVariant.coding,
            status: BeautifulThinkingStatus.complete,
            workingLabel: 'Working',
            completedLabel: 'Complete',
            items: items,
            onExpandedChanged: changes.add,
            onItemPressed: (item) => activations.add(item.id),
          ),
        ),
      ),
    );
    // This previously remained scheduled for over 24 seconds even collapsed.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.tap(
      find.byKey(const ValueKey<String>('beautiful-thinking-header')),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(changes, <bool>[true]);
    final last = find.byKey(
      const ValueKey<String>('beautiful-thinking-item-step-199'),
    );
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    expect(last.hitTestable(), findsOneWidget);
    final focus = tester.widget<FocusableActionDetector>(
      find.descendant(of: last, matching: find.byType(FocusableActionDetector)),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(activations, <String>['step-199']);
    final header = find.byKey(
      const ValueKey<String>('beautiful-thinking-header'),
    );
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    expect(changes, <bool>[true, false]);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
