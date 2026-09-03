import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:beautiful_ai_ui_catalog/main.dart' as catalog;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/catalog_semantics_fixture.dart';
import 'support/interactions.dart';

// This target exercises the complete Catalog through Flutter's public test
// inputs. Native runs also verify the real platform clipboard bridge. OS IME,
// trusted browser input/clipboard, and actual window resizing require the
// separate platform acceptance targets.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final nativeSemantics = CatalogSemanticsFixture(binding);
  final scenarios = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'schema_version': 1,
    'suite': 'beautiful_ai_ui_catalog_framework_input',
    'status': 'started',
    'started_at_utc': DateTime.now().toUtc().toIso8601String(),
    'delivery': 'Flutter-injected integration events',
    'constraints': 'synthetic render constraints',
    'is_web': kIsWeb,
    'target_platform': defaultTargetPlatform.name,
    'native_clipboard_applicable': !kIsWeb,
    'evidence_boundaries': <String>[
      'TextEditingValue updates use EditableTextState.userUpdateTextEditingValue, including an injected composing range.',
      'Keyboard events use Flutter KeyEventSimulator with explicit physical key mappings; they are not OS or WebDriver keyboard events.',
      'Selection uses a Flutter-injected mouse drag through the actual document selection widget.',
      'setSurfaceSize changes Flutter rendering constraints; it does not resize the browser or native window.',
      'Native-only copy/paste uses the real Clipboard platform bridge with Flutter-injected taps and a semantic paste action; the platform channel is not mocked.',
      'Web clipboard requires the separate trusted WebDriver input target. This suite does not verify an OS input method.',
    ],
    'scenarios': scenarios,
  };
  binding.reportData = <String, dynamic>{'catalog_framework_input': report};

  setUpAll(() async {
    if (!kIsWeb) {
      await nativeSemantics.prepare(
        () => prepareCatalogNativeSemantics(binding),
      );
    }
  });
  tearDownAll(nativeSemantics.dispose);

  testWidgets('Catalog preserves framework input contracts', (tester) async {
    final semantics = tester.ensureSemantics();
    final previousFatal = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    final actions = _CatalogInputActions(tester);
    try {
      await binding.setSurfaceSize(const Size(1120, 900));
      catalog.main();
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Beautiful AI UI · P1 + P2 + P3 Catalog'),
        findsOneWidget,
      );
      await actions.tap(find.text('Motion: system'));
      await actions.tap(find.text('Motion: reduced'));
      expect(find.text('Motion: none'), findsOneWidget);

      await _scenario(scenarios, 'prompt_keyboard_menus_and_focus', () async {
        final prompt = _input('catalog-prompt-bar');
        await actions.enter(prompt, '/');
        await actions.key(
          LogicalKeyboardKey.arrowDown,
          PhysicalKeyboardKey.arrowDown,
        );
        await actions.key(LogicalKeyboardKey.tab, PhysicalKeyboardKey.tab);
        expect(_editor(tester, prompt).controller.text, '/compare ');
        expect(_editor(tester, prompt).focusNode.hasFocus, isTrue);

        await actions.enter(prompt, '/');
        final commands = _inside('catalog-prompt-bar', find.text('Commands'));
        expect(commands, findsOneWidget);
        await actions.key(
          LogicalKeyboardKey.escape,
          PhysicalKeyboardKey.escape,
        );
        expect(commands, findsNothing);
        expect(_editor(tester, prompt).controller.text, '/');
        expect(_editor(tester, prompt).focusNode.hasFocus, isTrue);

        await actions.tap(
          _inside('catalog-prompt-bar', _key('beautiful-prompt-model')),
        );
        final precise = _inside(
          'catalog-prompt-bar',
          _key('beautiful-prompt-option-model-precise'),
        );
        expect(precise, findsOneWidget);
        await actions.key(
          LogicalKeyboardKey.escape,
          PhysicalKeyboardKey.escape,
        );
        expect(precise, findsNothing);
        expect(_editor(tester, prompt).focusNode.hasFocus, isTrue);
        expect(_editor(tester, prompt).controller.text, '/');
        return <String, Object?>{
          'command_inserted': '/compare ',
          'escape_preserved_draft': true,
          'model_dismissal_restored_editor_focus': true,
        };
      });

      await _scenario(scenarios, 'prompt_composing_and_submission', () async {
        final prompt = _input('catalog-prompt-bar');
        const composing = TextEditingValue(
          text: '中文',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        );
        await actions.edit(prompt, composing);
        await actions.key(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 180));
        expect(_editor(tester, prompt).controller.value, composing);
        expect(find.textContaining('Prompt received:'), findsNothing);

        await actions.edit(
          prompt,
          composing.copyWith(composing: TextRange.empty),
        );
        await actions.shiftKey(
          LogicalKeyboardKey.enter,
          PhysicalKeyboardKey.enter,
        );
        await tester.pump(const Duration(milliseconds: 180));
        expect(find.textContaining('Prompt received:'), findsNothing);
        expect(_editor(tester, prompt).controller.text.trim(), '中文');

        await actions.key(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          find.text('Prompt received: 中文 · 0 files · balanced'),
          findsOneWidget,
        );
        expect(_editor(tester, prompt).controller.text, isEmpty);
        return <String, Object?>{
          'injected_composing_range': <int>[0, 2],
          'composing_enter_preserved_value': true,
          'shift_enter_did_not_submit': true,
          'committed_submission': '中文',
        };
      });

      await _scenario(
        scenarios,
        'numeric_draft_cancel_adjust_and_bounds',
        () async {
          final width = find.descendant(
            of: _inside(
              'catalog-fine-tune',
              _key('beautiful-fine-tune-input-width'),
            ),
            matching: find.byType(EditableText),
          );
          expect(_editor(tester, width).controller.text, '324');
          await actions.enter(width, 'abc');
          await actions.key(
            LogicalKeyboardKey.enter,
            PhysicalKeyboardKey.enter,
          );
          final error = _inside(
            'catalog-fine-tune',
            find.text('Enter a finite number'),
          );
          expect(error, findsOneWidget);
          await actions.key(
            LogicalKeyboardKey.escape,
            PhysicalKeyboardKey.escape,
          );
          expect(error, findsNothing);
          expect(_editor(tester, width).controller.text, '324');
          expect(_editor(tester, width).focusNode.hasFocus, isTrue);

          await actions.key(
            LogicalKeyboardKey.arrowUp,
            PhysicalKeyboardKey.arrowUp,
          );
          expect(_editor(tester, width).controller.text, '325');
          await actions.shiftKey(
            LogicalKeyboardKey.arrowDown,
            PhysicalKeyboardKey.arrowDown,
          );
          expect(_editor(tester, width).controller.text, '315');
          await actions.enter(width, '5000');
          await actions.key(
            LogicalKeyboardKey.enter,
            PhysicalKeyboardKey.enter,
          );
          expect(_editor(tester, width).controller.text, '999');
          await actions.enter(width, '-50');
          await actions.key(
            LogicalKeyboardKey.enter,
            PhysicalKeyboardKey.enter,
          );
          expect(_editor(tester, width).controller.text, '40');
          return <String, Object?>{
            'escape_restored_value': 324,
            'arrow_value': 325,
            'accelerated_arrow_value': 315,
            'clamped_bounds': <int>[40, 999],
          };
        },
      );

      await _scenario(
        scenarios,
        'synthetic_resize_preserves_prompt_draft',
        () async {
          final prompt = _input('catalog-prompt-bar');
          await actions.tap(
            _inside('catalog-prompt-bar', _key('beautiful-prompt-add')),
          );
          await actions.tap(
            _inside('catalog-prompt-bar', find.text('Add photos and files')),
          );
          final attachment = _inside(
            'catalog-prompt-bar',
            find.text('Remove inventory-1.csv'),
          );
          expect(attachment, findsOneWidget);
          const value = TextEditingValue(
            text: '中文 inventory draft',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          );
          await actions.edit(prompt, value);
          final state = tester.state<EditableTextState>(prompt);
          final controller = _editor(tester, prompt).controller;
          final testedSizes = <Map<String, double>>[];
          for (final size in const <Size>[
            Size(390, 900),
            Size(720, 900),
            Size(1120, 900),
          ]) {
            await binding.setSurfaceSize(size);
            await tester.pump(const Duration(milliseconds: 180));
            await actions.reveal(prompt);
            expect(tester.state<EditableTextState>(prompt), same(state));
            expect(_editor(tester, prompt).controller, same(controller));
            expect(controller.value, value);
            expect(_editor(tester, prompt).focusNode.hasFocus, isTrue);
            expect(attachment, findsOneWidget);
            expect(tester.takeException(), isNull);
            testedSizes.add(<String, double>{
              'width': size.width,
              'height': size.height,
            });
          }
          // Finish the injected composition before exercising another editor.
          await actions.edit(
            prompt,
            value.copyWith(composing: TextRange.empty),
          );
          return <String, Object?>{
            'constraints': 'synthetic render constraints',
            'sizes': testedSizes,
            'same_editor_and_controller': true,
            'draft_selection_composition_focus_and_attachment_preserved': true,
          };
        },
      );

      await _scenario(
        scenarios,
        'pointer_selection_replaces_exact_repeated_range',
        () async {
          final document = _input('catalog-selection-actions');
          final original = _editor(tester, document).controller.text;
          const selectedText = 'order';
          final first = original.indexOf(selectedText);
          final start = original.lastIndexOf(selectedText);
          expect(first, greaterThanOrEqualTo(0));
          expect(start, greaterThan(first));
          final end = start + selectedText.length;
          await actions.reveal(document);
          final state = tester.state<EditableTextState>(document);
          Offset caret(int offset) => state.renderEditable.localToGlobal(
            state.renderEditable
                .getLocalRectForCaret(TextPosition(offset: offset))
                .center,
          );
          final from = caret(start);
          await tester.dragFrom(
            from,
            caret(end) - from,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pump(const Duration(milliseconds: 180));
          expect(
            _editor(tester, document).controller.selection,
            TextSelection(baseOffset: start, extentOffset: end),
          );
          expect(
            _editor(tester, document).controller.selection.textInside(original),
            selectedText,
          );

          const instruction = 'clarify 中文👋';
          const replacement = '$selectedText ($instruction)';
          await actions.enter(
            _input('catalog-selection-actions', index: 1),
            instruction,
          );
          await actions.tap(
            _inside(
              'catalog-selection-actions',
              find.text('Send edit instruction'),
            ),
          );
          expect(find.text('Prepared sample action: custom'), findsOneWidget);
          expect(
            _inside('catalog-selection-actions', find.text(replacement)),
            findsOneWidget,
          );
          await actions.tap(
            _inside('catalog-selection-actions', find.text('Keep change')),
          );
          expect(find.text('Accepted document edit: custom'), findsOneWidget);
          expect(
            _editor(tester, document).controller.text,
            original.replaceRange(start, end, replacement),
          );
          expect(_editor(tester, document).readOnly, isTrue);
          return <String, Object?>{
            'selection_delivery': 'Flutter-injected mouse drag',
            'selected_utf16_range': <int>[start, end],
            'selected_text': selectedText,
            'replacement': replacement,
            'exact_host_document_verified': true,
          };
        },
      );

      if (!kIsWeb) {
        await _scenario(scenarios, 'native_clipboard_copy_and_paste', () async {
          const code = '''export async function churnBatch() {
  const flavor = await getFlavor("pistachio");
  const base = await dairy.fetch({ flavor });
  await freezer.store(base, { temp: "-16C" });
  return base.gallons;
}''';
          const response =
              'Prioritize the pistachio restock. [1]'
              '\nConfirm the waffle cone order before Friday. [2]';
          final prompt = _input('catalog-prompt-bar');
          final previousClipboard = await Clipboard.getData(
            Clipboard.kTextPlain,
          );
          final verified = <Map<String, Object?>>[];
          try {
            for (final sample in <(String, String, String, String)>[
              ('catalog-code-block', 'Copy', 'Copied', code),
              (
                'catalog-streaming-complete',
                'Copy response',
                'Answer copied',
                response,
              ),
            ]) {
              final (component, label, copiedLabel, expectedText) = sample;
              await actions.tap(_inside(component, find.text(label)));
              await actions.until(
                () =>
                    _inside(
                      component,
                      find.text(copiedLabel),
                    ).evaluate().length ==
                    1,
                'The $component copy callback did not complete.',
              );
              final copied = await Clipboard.getData(Clipboard.kTextPlain);
              expect(copied?.text, expectedText);

              await actions.enter(prompt, '');
              await tester.pump(const Duration(milliseconds: 180));
              tester.semantics.paste(find.semantics.byLabel('Prompt'));
              await actions.until(
                () => _editor(tester, prompt).controller.text == expectedText,
                'The prompt did not receive the exact $component clipboard text.',
              );
              expect(_editor(tester, prompt).controller.text, expectedText);
              verified.add(<String, Object?>{
                'component': component,
                'copied_and_pasted_utf16_length': expectedText.length,
                'exact_content_verified': true,
              });
            }
          } finally {
            if (previousClipboard?.text case final String previousText) {
              await Clipboard.setData(ClipboardData(text: previousText));
            }
          }
          return <String, Object?>{
            'clipboard_transport': 'real native Clipboard platform bridge',
            'copy_activation': 'Flutter-injected pointer tap',
            'paste_activation': 'Flutter-injected semantic paste action',
            'platform_channel_mocked': false,
            'verified_components': verified,
          };
        });
      }

      expect(tester.takeException(), isNull);
      report['status'] = 'passed';
    } catch (error) {
      report['status'] = 'failed';
      report['error'] = error.toString();
      rethrow;
    } finally {
      report['finished_at_utc'] = DateTime.now().toUtc().toIso8601String();
      debugPrint(
        'CATALOG_INPUT_REPORT: ${jsonEncode(report)}',
        wrapWidth: null,
      );
      try {
        FocusManager.instance.primaryFocus?.unfocus();
        runApp(const SizedBox.shrink());
        await tester.pump();
        await binding.setSurfaceSize(null);
        await tester.pump();
      } finally {
        semantics.dispose();
        WidgetController.hitTestWarningShouldBeFatal = previousFatal;
      }
    }
  });
}

Finder _key(String key) => find.byKey(Key(key));

Finder _inside(String key, Finder matching) =>
    find.descendant(of: _key(key), matching: matching);

Finder _input(String key, {int index = 0}) =>
    _inside(key, find.byType(EditableText)).at(index);

EditableText _editor(WidgetTester tester, Finder finder) =>
    tester.widget<EditableText>(finder);

Future<void> _scenario(
  List<Map<String, Object?>> scenarios,
  String id,
  Future<Map<String, Object?>> Function() exercise,
) async {
  final result = <String, Object?>{'id': id, 'status': 'started'};
  scenarios.add(result);
  try {
    result['outcomes'] = await exercise();
    result['status'] = 'passed';
  } catch (error) {
    result['status'] = 'failed';
    result['error'] = error.toString();
    rethrow;
  }
}

final class _CatalogInputActions {
  const _CatalogInputActions(this.tester);

  final WidgetTester tester;

  Future<void> reveal(Finder target) async {
    await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> tap(Finder target) async {
    await tapCatalogTarget(tester, target);
    // Catalog sample callbacks complete after 120 ms; live timers prevent
    // pumpAndSettle from being a useful completion condition here.
    await tester.pump(const Duration(milliseconds: 180));
  }

  Future<void> until(bool Function() completed, String failure) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (completed()) return;
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(completed(), isTrue, reason: failure);
  }

  Future<void> enter(Finder target, String text) => edit(
    target,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ),
  );

  Future<void> edit(Finder target, TextEditingValue value) async {
    await reveal(target);
    final state = tester.state<EditableTextState>(target);
    state.widget.focusNode.requestFocus();
    await tester.pump();
    // IntegrationTest leaves TestTextInput unregistered. This public editing
    // path also works in profile mode and runs formatting/onChanged callbacks.
    state.userUpdateTextEditingValue(value, SelectionChangedCause.keyboard);
    await tester.pump(const Duration(milliseconds: 16));
    expect(state.textEditingValue, value);
  }

  Future<void> key(
    LogicalKeyboardKey logical,
    PhysicalKeyboardKey physical,
  ) async {
    await tester.sendKeyEvent(logical, physicalKey: physical);
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> shiftKey(
    LogicalKeyboardKey logical,
    PhysicalKeyboardKey physical,
  ) async {
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.shiftLeft,
      physicalKey: PhysicalKeyboardKey.shiftLeft,
    );
    try {
      await key(logical, physical);
    } finally {
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.shiftLeft,
        physicalKey: PhysicalKeyboardKey.shiftLeft,
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}
