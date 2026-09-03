import 'dart:convert';
import 'dart:io';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../lib/main.dart';

void _onSelected(BeautifulSearchItem item) {}

Widget _app(BeautifulUiThemeMode mode, {bool highContrast = false}) =>
    WidgetsApp(
      color: const Color(0xff0285ff),
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          highContrast: highContrast,
        ),
        child: BeautifulUiScope(
          themeMode: mode,
          motion: BeautifulMotionPolicy.none,
          child: const _ConsumerProbe(key: ValueKey('consumer-state')),
        ),
      ),
    );

void _verifyTheme(BuildContext context, BeautifulUiThemeData expected) {
  final actual = shad.Theme.of(context);
  expect(BeautifulUiTheme.of(context).colors.ink, expected.colors.ink);
  expect(actual.colorScheme.brightness, expected.colors.brightness);
  expect(actual.colorScheme.background, expected.colors.page);
  expect(actual.colorScheme.foreground, expected.colors.ink);
  expect(actual.colorScheme.primary, expected.colors.accent);
  expect(actual.colorScheme.mutedForeground, expected.colors.inkMuted);
  expect(actual.colorScheme.border, expected.colors.line);
  expect(actual.scaling, 1);
  expect(
    actual.typography.sans.fontFamily,
    expected.typography.body.fontFamily,
  );
  expect(DefaultTextStyle.of(context).style.color, expected.colors.ink);
  expect(IconTheme.of(context).color, expected.colors.ink);
}

void main() {
  testWidgets('minimal application connects through public package imports', (
    tester,
  ) async {
    await tester.pumpWidget(const HostedConsumerApp());
    expect(find.text('Hosted package connected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hosted dependency keeps theme atomic and consumer state intact',
    (tester) async {
      await tester.pumpWidget(_app(BeautifulUiThemeMode.light));
      final state = tester.state<_ConsumerProbeState>(
        find.byType(_ConsumerProbe),
      );
      final input = find.byType(EditableText);
      final originalEditor = tester.widget<EditableText>(input);
      originalEditor.focusNode.requestFocus();
      await tester.pump();
      await tester.enterText(input, 'supplier');
      originalEditor.controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 5,
      );
      await tester.pump();
      final evidence = <Map<String, Object>>[];
      for (final (mode, highContrast, expected)
          in <(BeautifulUiThemeMode, bool, BeautifulUiThemeData)>[
            (
              BeautifulUiThemeMode.dark,
              false,
              const BeautifulUiThemeData.dark(),
            ),
            (
              BeautifulUiThemeMode.dark,
              true,
              const BeautifulUiThemeData.dark().highContrast(),
            ),
            (
              BeautifulUiThemeMode.light,
              true,
              const BeautifulUiThemeData.light().highContrast(),
            ),
            (
              BeautifulUiThemeMode.light,
              false,
              const BeautifulUiThemeData.light(),
            ),
          ]) {
        await tester.pumpWidget(_app(mode, highContrast: highContrast));
        void verify(String phase) {
          expect(tester.state(find.byType(_ConsumerProbe)), same(state));
          final editor = tester.widget<EditableText>(input);
          expect(editor.controller, same(originalEditor.controller));
          expect(editor.focusNode, same(originalEditor.focusNode));
          expect(editor.controller.text, 'supplier');
          expect(
            editor.controller.selection,
            const TextSelection(baseOffset: 1, extentOffset: 5),
          );
          expect(editor.focusNode.hasFocus, isTrue);
          _verifyTheme(state.context, expected);
          expect(tester.takeException(), isNull);
          evidence.add(<String, Object>{
            'theme': mode.name,
            'high_contrast': highContrast,
            'phase': phase,
            'state_controller_selection_focus_preserved': true,
            'public_and_internal_inherited_theme_agree': true,
          });
        }

        verify('immediate');
        await tester.pump(const Duration(milliseconds: 75));
        verify('75ms');
        await tester.pump(const Duration(milliseconds: 100));
        verify('175ms');
      }
      File('theme_probe_result.json').writeAsStringSync(
        jsonEncode(<String, Object>{'passed': true, 'observations': evidence}),
      );
    },
  );
}

final class _ConsumerProbe extends StatefulWidget {
  const _ConsumerProbe({super.key});

  @override
  State<_ConsumerProbe> createState() => _ConsumerProbeState();
}

final class _ConsumerProbeState extends State<_ConsumerProbe> {
  @override
  Widget build(BuildContext context) => const BeautifulSearch(
    initialQuery: '',
    onSelected: _onSelected,
    items: <BeautifulSearchItem>[
      BeautifulSearchItem(id: 'supplier', title: 'Find supplier'),
      BeautifulSearchItem(id: 'stock', title: 'Check stock'),
    ],
  );
}
