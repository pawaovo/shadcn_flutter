import 'package:beautiful_ai_ui_catalog/main.dart' as catalog;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/browser_input_bridge.dart';
import 'support/catalog_error_capture.dart';

const _typed = 'browser 中文 draft';
const _multiline = '$_typed\nsecond line';
const _code = '''export async function churnBatch() {
  const flavor = await getFlavor("pistachio");
  const base = await dairy.fetch({ flavor });
  await freezer.store(base, { temp: "-16C" });
  return base.gallons;
}''';
const _stream =
    'Prioritize the pistachio restock. [1]\n'
    'Confirm the waffle cone order before Friday. [2]';

/// The driver sends real W3C browser pointer/key/window commands. This target
/// only reveals the relevant Catalog control, reports its current coordinates,
/// and verifies the actual Flutter state/callback result. It never injects text,
/// mocks Clipboard, or calls a product action on the driver's behalf.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real browser keyboard clipboard focus and window acceptance', (
    tester,
  ) async {
    final flutterErrors = <Map<String, Object?>>[];
    binding.reportData = <String, dynamic>{'flutter_errors': flutterErrors};
    addTearDown(captureCatalogFlutterErrors(flutterErrors));
    expect(kIsWeb, isTrue, reason: 'Use the browser-input driver on a browser');
    final semantics = tester.ensureSemantics();
    final previousDevicePointers = binding.shouldPropagateDevicePointerEvents;
    binding.shouldPropagateDevicePointerEvents = true;
    final completed = <String>[];
    binding.reportData!.addAll(<String, dynamic>{
      'delivery': 'W3C WebDriver native browser pointer and keyboard events',
      'clipboard':
          'real browser clipboard copied by Catalog and pasted into Prompt',
      'resize': 'real WebDriver window rectangles at each breakpoint',
      'ime_boundary':
          'Unicode insertion; actual operating-system IME is separate',
      'completed': completed,
    });
    try {
      await tester.pumpWidget(const catalog.CatalogApp());
      await tester.pump(const Duration(milliseconds: 500));
      final prompt = find.descendant(
        of: find.byKey(const Key('catalog-prompt-bar')),
        matching: find.byType(EditableText),
      );
      EditableText editor() => tester.widget<EditableText>(prompt);
      Finder? readOnlyDocument;

      Map<String, Object?>? documentSnapshot() {
        final target = readOnlyDocument;
        if (target == null || target.evaluate().length != 1) return null;
        final state = tester.state<EditableTextState>(target);
        final controller = state.widget.controller;
        return <String, Object?>{
          'state_id': identityHashCode(state),
          'controller_id': identityHashCode(controller),
          'text': controller.text,
          'focused': state.widget.focusNode.hasPrimaryFocus,
          'readOnly': state.widget.readOnly,
          'selectionStart': controller.selection.start,
          'selectionEnd': controller.selection.end,
        };
      }

      Future<void> reveal(Finder target) async {
        await tester.ensureVisible(target);
        await tester.pump(const Duration(milliseconds: 150));
        expect(target.hitTestable(), findsOneWidget);
      }

      Future<void> stage(
        String name, {
        Finder? target,
        required bool Function() done,
        Map<String, Object?> extra = const <String, Object?>{},
      }) async {
        final elapsed = Stopwatch()..start();
        final offset = target == null ? null : tester.getCenter(target);
        do {
          final view = tester.view;
          publishBrowserInputState(<String, Object?>{
            'stage': name,
            'x': offset?.dx,
            'y': offset?.dy,
            'width': view.physicalSize.width / view.devicePixelRatio,
            'height': view.physicalSize.height / view.devicePixelRatio,
            if (prompt.evaluate().length == 1) ...<String, Object?>{
              'draft': editor().controller.text,
              'focused': editor().focusNode.hasFocus,
              'selectionStart': editor().controller.selection.start,
              'selectionEnd': editor().controller.selection.end,
            },
            'document': ?documentSnapshot(),
            ...extra,
          });
          await tester.pump(const Duration(milliseconds: 30));
          if (done()) {
            completed.add(name);
            return;
          }
        } while (elapsed.elapsed < const Duration(seconds: 60));
        fail('Browser input stage did not complete: $name');
      }

      await reveal(prompt);
      await stage(
        'prompt-type',
        target: prompt,
        done: () => editor().controller.text == _typed,
      );
      await stage(
        'shift-enter',
        target: prompt,
        done: () => editor().controller.text == _multiline,
      );
      expect(find.textContaining('Prompt received: $_typed'), findsNothing);

      final model = find.byKey(const Key('beautiful-prompt-model'));
      await reveal(model);
      await stage(
        'model-open',
        target: model,
        done: () => find
            .byKey(const Key('beautiful-prompt-option-model-precise'))
            .evaluate()
            .isNotEmpty,
      );
      await stage(
        'model-escape',
        done: () =>
            editor().focusNode.hasFocus &&
            find
                .byKey(const Key('beautiful-prompt-option-model-precise'))
                .evaluate()
                .isEmpty,
      );
      expect(editor().controller.text, _multiline);

      await stage(
        'keyboard-copy',
        target: prompt,
        done: () => browserInputAcknowledgement() == 'keyboard-copy',
      );
      expect(
        editor().controller.selection.textInside(editor().controller.text),
        _multiline,
      );
      await stage(
        'keyboard-clear',
        target: prompt,
        done: () => editor().controller.text.isEmpty,
      );
      await stage(
        'keyboard-paste',
        target: prompt,
        done: () => editor().controller.text == _multiline,
      );
      await stage(
        'select-before-resize',
        target: prompt,
        done: () =>
            editor().controller.selection.start == 0 &&
            editor().controller.selection.end == _multiline.length,
      );
      final retained = editor().controller.value;
      for (final width in <int>[599, 600, 1023, 1024, 1440]) {
        await stage(
          'resize-$width',
          done: () =>
              (tester.view.physicalSize.width / tester.view.devicePixelRatio -
                      width)
                  .abs() <
              1,
          extra: <String, Object?>{'requestedWidth': width},
        );
        expect(editor().controller.value, retained);
        expect(editor().focusNode.hasFocus, isTrue);
      }
      await reveal(prompt);
      await stage(
        'send',
        target: prompt,
        done: () =>
            editor().controller.text.isEmpty &&
            find
                .text('Prompt received: $_multiline · 0 files · balanced')
                .evaluate()
                .isNotEmpty,
      );

      for (final scenario in <(String, String, String, String)>[
        ('code', 'catalog-code-block', 'Copy', _code),
        ('stream', 'catalog-streaming-complete', 'Copy response', _stream),
      ]) {
        final copy = find.descendant(
          of: find.byKey(Key(scenario.$2)),
          matching: find.text(scenario.$3),
        );
        await reveal(copy);
        await stage(
          '${scenario.$1}-copy',
          target: copy,
          done: () =>
              browserInputAcknowledgement() == '${scenario.$1}-copy' &&
              find
                  .text(scenario.$1 == 'code' ? 'Copied' : 'Response copied')
                  .evaluate()
                  .isNotEmpty,
        );
        await reveal(prompt);
        await stage(
          '${scenario.$1}-paste',
          target: prompt,
          done: () => editor().controller.text == scenario.$4,
        );
        await stage(
          '${scenario.$1}-clear',
          target: prompt,
          done: () => editor().controller.text.isEmpty,
        );
      }

      final document = find
          .descendant(
            of: find.byKey(const Key('catalog-selection-actions')),
            matching: find.byType(EditableText),
          )
          .first;
      readOnlyDocument = document;
      await reveal(document);
      expect(tester.widget<EditableText>(document).readOnly, isTrue);
      final original = tester.widget<EditableText>(document).controller.text;
      await stage(
        'readonly-copy',
        target: document,
        done: () => browserInputAcknowledgement() == 'readonly-copy',
      );
      expect(tester.widget<EditableText>(document).controller.text, original);
      expect(
        tester
            .widget<EditableText>(document)
            .controller
            .selection
            .textInside(original),
        original,
      );
      for (final operation in <String>['cut', 'paste']) {
        if (operation == 'paste') {
          await stage(
            'readonly-caret',
            done: () {
              final selection = tester
                  .widget<EditableText>(document)
                  .controller
                  .selection;
              return selection.isCollapsed &&
                  selection.extentOffset == original.length;
            },
          );
        }
        await stage(
          'readonly-$operation-rejected',
          done: () =>
              browserInputAcknowledgement() == 'readonly-$operation-rejected',
        );
        expect(tester.widget<EditableText>(document).controller.text, original);
      }
      await reveal(prompt);
      await stage(
        'readonly-paste',
        target: prompt,
        done: () => editor().controller.text == original,
      );
      expect(tester.widget<EditableText>(document).controller.text, original);
      expect(tester.takeException(), isNull);
      await stage(
        'complete',
        done: () => browserInputAcknowledgement() == 'complete',
      );
    } finally {
      resetBrowserInputState();
      binding.shouldPropagateDevicePointerEvents = previousDevicePointers;
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
