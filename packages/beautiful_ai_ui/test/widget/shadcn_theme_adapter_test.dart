import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:beautiful_ai_ui/src/implementation/shadcn/theme_adapter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

Widget _host(Widget child, {bool highContrast = false}) => MediaQuery(
  data: MediaQueryData(size: const Size(390, 844), highContrast: highContrast),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void _expectInheritedTheme(
  BuildContext context,
  BeautifulUiThemeData expected,
) {
  final actual = shad.Theme.of(context);
  expect(actual.colorScheme.brightness, expected.colors.brightness);
  expect(actual.colorScheme.background, expected.colors.page);
  expect(actual.colorScheme.foreground, expected.colors.ink);
  expect(actual.colorScheme.primary, expected.colors.accent);
  expect(actual.colorScheme.mutedForeground, expected.colors.inkMuted);
  expect(actual.colorScheme.border, expected.colors.line);
  expect(
    actual.typography.sans.fontFamily,
    expected.typography.body.fontFamily,
  );
  expect(actual.scaling, 1);
  expect(DefaultTextStyle.of(context).style.color, expected.colors.ink);
  expect(
    DefaultTextStyle.of(context).style.decoration,
    expected.typography.body.decoration,
  );
  expect(IconTheme.of(context).color, expected.colors.ink);
}

void main() {
  testWidgets(
    'adapter builder and descendants receive atomic inherited values',
    (tester) async {
      late BuildContext builderContext;
      late BuildContext leafContext;
      Widget app(BeautifulUiThemeData theme) => _host(
        ShadcnLayerAdapter(
          theme: theme,
          animateTheme: false,
          builder: (context, child) {
            builderContext = context;
            return child!;
          },
          child: Builder(
            builder: (context) {
              leafContext = context;
              return const Text('Inherited text');
            },
          ),
        ),
      );
      for (final theme in [
        const BeautifulUiThemeData(
          colors: BeautifulUiColors.light(),
          typography: BeautifulUiTypography(
            body: TextStyle(
              fontFamily: 'GeistSans',
              package: 'shadcn_flutter',
              fontSize: 14,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const BeautifulUiThemeData.light(),
        const BeautifulUiThemeData.dark(),
        const BeautifulUiThemeData.dark().highContrast(),
        const BeautifulUiThemeData.light().highContrast(),
      ]) {
        await tester.pumpWidget(app(theme));
        _expectInheritedTheme(builderContext, theme);
        _expectInheritedTheme(leafContext, theme);
        await tester.pump(const Duration(milliseconds: 75));
        _expectInheritedTheme(builderContext, theme);
        _expectInheritedTheme(leafContext, theme);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'atomic scope changes preserve editor state focus and selection',
    (tester) async {
      const probe = _DraftProbe(key: ValueKey('draft'));
      Widget app(BeautifulUiThemeMode mode, {bool highContrast = false}) =>
          _host(
            BeautifulUiScope(themeMode: mode, child: probe),
            highContrast: highContrast,
          );
      await tester.pumpWidget(app(BeautifulUiThemeMode.light));
      final state = tester.state<_DraftProbeState>(find.byType(_DraftProbe));
      state.focus.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'unfinished draft');
      state.controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 9,
      );
      await tester.pump();
      for (final (mode, highContrast, expected) in [
        (BeautifulUiThemeMode.dark, false, const BeautifulUiThemeData.dark()),
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
        (BeautifulUiThemeMode.light, false, const BeautifulUiThemeData.light()),
      ]) {
        await tester.pumpWidget(app(mode, highContrast: highContrast));
        void verify() {
          expect(tester.state(find.byType(_DraftProbe)), same(state));
          expect(state.controller.text, 'unfinished draft');
          expect(
            state.controller.selection,
            const TextSelection(baseOffset: 2, extentOffset: 9),
          );
          expect(state.focus.hasFocus, isTrue);
          expect(
            BeautifulUiTheme.of(state.context).colors.ink,
            expected.colors.ink,
          );
          _expectInheritedTheme(state.context, expected);
          final editor = tester.widget<EditableText>(find.byType(EditableText));
          expect(editor.style.color, expected.colors.ink);
          expect(tester.takeException(), isNull);
        }

        verify();
        await tester.pump(const Duration(milliseconds: 75));
        verify();
      }
    },
  );
}

final class _DraftProbe extends StatefulWidget {
  const _DraftProbe({super.key});

  @override
  State<_DraftProbe> createState() => _DraftProbeState();
}

final class _DraftProbeState extends State<_DraftProbe> {
  final controller = TextEditingController();
  final focus = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditableText(
    controller: controller,
    focusNode: focus,
    style: DefaultTextStyle.of(context).style,
    cursorColor: shad.Theme.of(context).colorScheme.primary,
    backgroundCursorColor: shad.Theme.of(context).colorScheme.muted,
  );
}
