import 'dart:ui' show Tristate;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui/src/implementation/controls/action_control.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _filesIcon = IconData(0xe2c8, fontFamily: 'MaterialIcons');

void main() {
  testWidgets('text action retains keyboard and disabled semantics', (
    tester,
  ) async {
    var calls = 0;
    var enabled = true;
    late StateSetter update;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      beautifulTestApp(
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeautifulButton(
              label: 'Save file',
              onPressed: enabled ? () => calls++ : null,
            );
          },
        ),
      ),
    );
    expect(tester.getSize(find.byType(BeautifulButton)).height, 44);
    Focus.of(tester.element(find.text('Save file'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.tap(find.text('Save file'));
    await tester.pump();
    expect(calls, 3);

    update(() => enabled = false);
    await tester.pump();
    await tester.tap(find.text('Save file'));
    expect(calls, 3);
    final flags = tester
        .getSemantics(find.bySemanticsLabel('Save file'))
        .getSemanticsData()
        .flagsCollection;
    expect(flags.isButton, isTrue);
    expect(flags.isEnabled, Tristate.isFalse);
    semantics.dispose();
  });

  testWidgets(
    'compact full-width action aligns its label to the leading edge',
    (tester) async {
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(1200, 800),
          child: SizedBox(
            width: 300,
            child: BeautifulButton(
              label: 'Read configuration',
              onPressed: () {},
              density: BeautifulUiDensity.compact,
              alignment: TextAlign.start,
              fullWidth: true,
            ),
          ),
        ),
      );
      final action = find.byType(BeautifulActionControl);
      final label = find.text('Read configuration');
      expect(tester.getSize(action), const Size(300, 32));
      expect(tester.getTopLeft(label).dx - tester.getTopLeft(action).dx, 8);
      expect(tester.widget<Text>(label).style?.fontSize, 12);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('icon action stays usable in a host without an overlay', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      beautifulTestApp(
        child: BeautifulIconButton(
          label: 'Open files',
          icon: _filesIcon,
          onPressed: () => calls++,
          density: BeautifulUiDensity.compact,
        ),
      ),
    );
    await tester.tap(find.byIcon(_filesIcon));
    await tester.pump();
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('quiet compact selection keeps a clear focus in $brightness', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final strategy = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = strategy);
      await tester.pumpWidget(
        beautifulTestApp(
          brightness: brightness,
          child: BeautifulButton(
            label: 'Changes',
            onPressed: () {},
            density: BeautifulUiDensity.compact,
            tone: BeautifulButtonTone.quiet,
            selected: true,
          ),
        ),
      );
      AnimatedContainer painted() => tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(BeautifulActionControl),
          matching: find.byType(AnimatedContainer),
        ),
      );
      BorderSide outline() =>
          ((painted().foregroundDecoration! as BoxDecoration).border! as Border)
              .top;
      final colors = BeautifulUiTheme.of(tester.element(find.text('Changes')))
          .colors;
      final size = tester.getSize(find.byType(BeautifulActionControl));
      expect((painted().decoration! as BoxDecoration).color, colors.inset);
      expect(outline().color.a, 0);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Changes'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      Focus.of(tester.element(find.text('Changes'))).requestFocus();
      await tester.pumpAndSettle();
      expect(outline().color.a, greaterThan(0));
      expect(outline().width, 3);
      expect(tester.getSize(find.byType(BeautifulActionControl)), size);
      semantics.dispose();
    });
  }

  testWidgets('compact icon has no hidden label width and exposes a tooltip', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(
      beautifulTestApp(
        size: const Size(1200, 800),
        child: _overlay(
          BeautifulIconButton(
            label: 'Open workspace files',
            icon: _filesIcon,
            onPressed: () => calls++,
            density: BeautifulUiDensity.compact,
          ),
        ),
      ),
    );
    final action = find.byType(BeautifulActionControl);
    expect(tester.getSize(action), const Size(32, 32));
    expect(find.text('Open workspace files'), findsNothing);
    expect(find.bySemanticsLabel('Open workspace files'), findsOneWidget);
    Focus.of(tester.element(find.byIcon(_filesIcon))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 1);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(400, 400));
    await mouse.moveTo(tester.getCenter(action));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Open workspace files'), findsOneWidget);
    expect(find.bySemanticsLabel('Open workspace files'), findsOneWidget);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  for (final scenario in [
    (TargetPlatform.android, const Size(1200, 800)),
    (TargetPlatform.macOS, const Size(390, 844)),
  ]) {
    testWidgets('compact icon preserves a touch target for $scenario', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        beautifulTestApp(
          size: scenario.$2,
          child: _overlay(
            BeautifulIconButton(
              label: 'Open files',
              icon: _filesIcon,
              onPressed: () => calls++,
              density: BeautifulUiDensity.compact,
            ),
          ),
        ),
      );
      final action = find.byType(BeautifulActionControl);
      final painted = find.descendant(
        of: action,
        matching: find.byType(AnimatedContainer),
      );
      expect(tester.getSize(action), const Size(44, 44));
      expect(tester.getSize(painted), const Size(32, 32));
      await tester.tapAt(tester.getTopLeft(action) + const Offset(2, 2));
      expect(
        calls,
        1,
        reason: 'Padding outside the visual icon is interactive.',
      );
      await tester.longPress(action);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Open files'), findsOneWidget);
      expect(calls, 1, reason: 'A tooltip does not activate the action.');
      await tester.pumpAndSettle();
    }, variant: TargetPlatformVariant.only(scenario.$1));
  }
}

Widget _overlay(Widget child) => Overlay(
  initialEntries: [
    OverlayEntry(
      builder: (context) => Align(alignment: Alignment.topLeft, child: child),
    ),
  ],
);
