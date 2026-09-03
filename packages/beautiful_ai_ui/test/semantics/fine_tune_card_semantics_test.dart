import 'dart:ui' as ui;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

void main() {
  testWidgets('numeric properties expose editable and adjustable semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final changes = <BeautifulFineTuneSettings>[];
    await tester.pumpWidget(_app(onChanged: changes.add));
    final slider = tester
        .getSemantics(find.bySemanticsLabel('Opacity'))
        .getSemanticsData();
    expect(slider.flagsCollection.isSlider, isTrue);
    expect(slider.flagsCollection.isEnabled, ui.Tristate.isTrue);
    expect(slider.value, '50%');
    expect(slider.increasedValue, '55%');
    expect(slider.decreasedValue, '45%');
    expect(slider.hasAction(SemanticsAction.increase), isTrue);
    expect(slider.hasAction(SemanticsAction.decrease), isTrue);
    final field = tester
        .getSemantics(find.bySemanticsLabel('Opacity value'))
        .getSemanticsData();
    expect(field.flagsCollection.isTextField, isTrue);
    expect(field.value, '50');
    expect(field.hasAction(SemanticsAction.setText), isTrue);
    tester.semantics.increase(find.semantics.byLabel('Opacity'));
    await tester.pump();
    expect(changes.single.fields.single.value, 55);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Opacity'))
          .getSemanticsData()
          .flagsCollection
          .isEnabled,
      ui.Tristate.isTrue,
    );
    handle.dispose();
  });

  testWidgets('selected layout and type disclosure expose their state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(onChanged: (_) {}));
    final row = tester
        .getSemantics(find.bySemanticsLabel('Row Layout'))
        .getSemanticsData();
    final grid = tester
        .getSemantics(find.bySemanticsLabel('Grid Layout'))
        .getSemanticsData();
    expect(row.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(grid.flagsCollection.isSelected, ui.Tristate.isFalse);
    final typeFinder = find.bySemanticsLabel('Type: Seasonal');
    expect(
      tester
          .getSemantics(typeFinder)
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      ui.Tristate.isFalse,
    );
    await tester.tap(find.byKey(const Key('beautiful-fine-tune-type')));
    await tester.pump();
    expect(
      tester
          .getSemantics(typeFinder)
          .getSemanticsData()
          .flagsCollection
          .isExpanded,
      ui.Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Seasonal'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      ui.Tristate.isTrue,
    );
    handle.dispose();
  });

  testWidgets(
    'semantic adjustment emits values and omits impossible endpoint actions',
    (tester) async {
      final handle = tester.ensureSemantics();
      final values = <BeautifulFineTuneSettings>[];
      await tester.pumpWidget(_app(onChanged: values.add, value: 100));
      final slider = tester.getSemantics(find.bySemanticsLabel('Opacity'));
      expect(
        slider.getSemanticsData().hasAction(SemanticsAction.increase),
        isFalse,
      );
      expect(
        slider.getSemanticsData().hasAction(SemanticsAction.decrease),
        isTrue,
      );
      tester.semantics.decrease(find.semantics.byLabel('Opacity'));
      await tester.pump();
      expect(values.single.fields.single.value, 95);
      handle.dispose();
    },
  );

  testWidgets('disabled inspector exposes no editing actions', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    final slider = tester
        .getSemantics(find.bySemanticsLabel('Opacity'))
        .getSemanticsData();
    final increase = tester
        .getSemantics(find.bySemanticsLabel('Increase Opacity'))
        .getSemanticsData();
    final input = tester
        .getSemantics(find.bySemanticsLabel('Opacity value'))
        .getSemanticsData();
    expect(slider.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(slider.hasAction(SemanticsAction.increase), isFalse);
    expect(slider.hasAction(SemanticsAction.decrease), isFalse);
    expect(increase.flagsCollection.isEnabled, ui.Tristate.isFalse);
    expect(increase.hasAction(SemanticsAction.tap), isFalse);
    expect(input.flagsCollection.isReadOnly, isTrue);
    expect(input.hasAction(SemanticsAction.setText), isFalse);
    handle.dispose();
  });

  testWidgets('controls meet Android touch targets and have accessible names', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(onChanged: (_) {}));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}

Widget _app({
  ValueChanged<BeautifulFineTuneSettings>? onChanged,
  double value = 50,
}) => beautifulTestApp(
  disableAnimations: true,
  child: SingleChildScrollView(
    child: BeautifulFineTuneCard(
      settings: BeautifulFineTuneSettings(
        fields: <BeautifulFineTuneField>[
          BeautifulFineTuneField(
            id: 'opacity',
            label: 'Opacity',
            value: value,
            min: 0,
            max: 100,
            step: 5,
            suffix: '%',
          ),
        ],
        typeId: 'seasonal',
      ),
      options: const <BeautifulFineTuneOption>[
        BeautifulFineTuneOption(id: 'seasonal', label: 'Seasonal'),
        BeautifulFineTuneOption(id: 'classic', label: 'Classic'),
      ],
      onChanged: onChanged,
    ),
  ),
);
