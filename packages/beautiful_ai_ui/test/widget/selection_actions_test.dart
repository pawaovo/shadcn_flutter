import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _text = 'alpha beta alpha';
const _secondAlpha = TextSelection(baseOffset: 11, extentOffset: 16);

void main() {
  test('validates document, action, viewport and UTF-16 boundaries', () {
    BeautifulSelectionActions make({
      String id = 'doc',
      TextSelection? selection,
      int lines = 8,
      Iterable<BeautifulSelectionAction> actions = const [],
    }) => BeautifulSelectionActions(
      documentId: id,
      text: '中👋文',
      initialSelection: selection,
      actions: actions,
      documentMaxLines: lines,
      onRequest: (_) => '',
    );

    expect(() => make(id: '  '), throwsArgumentError);
    for (final range in const [
      TextSelection(baseOffset: -1, extentOffset: 1),
      TextSelection(baseOffset: 0, extentOffset: 5),
      TextSelection(baseOffset: 1, extentOffset: 2),
      TextSelection(baseOffset: 2, extentOffset: 3),
    ]) {
      expect(() => make(selection: range), throwsArgumentError);
    }
    for (final lines in [0, 41]) {
      expect(() => make(lines: lines), throwsArgumentError);
    }
    for (final actions in const [
      [BeautifulSelectionAction(id: '', label: 'Action')],
      [BeautifulSelectionAction(id: 'action', label: ' ')],
      [
        BeautifulSelectionAction(id: 'same', label: 'First'),
        BeautifulSelectionAction(id: 'same', label: 'Second'),
      ],
    ]) {
      expect(() => make(actions: actions), throwsArgumentError);
    }
    expect(
      make(selection: const TextSelection(baseOffset: 3, extentOffset: 1)),
      isA<BeautifulSelectionActions>(),
    );
    final actions = [const BeautifulSelectionAction(id: 'one', label: 'One')];
    final widget = make(actions: actions);
    actions.clear();
    expect(widget.actions.single.id, 'one');
    expect(() => widget.actions.clear(), throwsUnsupportedError);
  });

  testWidgets('empty selection only exposes the real read-only document', (
    tester,
  ) async {
    await tester.pumpWidget(_app(selection: null));
    expect(find.text('Select text to see actions'), findsOneWidget);
    expect(find.text('Improve'), findsNothing);
    expect(find.byType(EditableText), findsOneWidget);
    expect(_document(tester).readOnly, isTrue);
    expect(_document(tester).controller.text, _text);
  });

  testWidgets('native mouse drag requests the second repeated occurrence', (
    tester,
  ) async {
    final requests = <BeautifulSelectionRequest>[];
    await tester.pumpWidget(
      _overlayApp(
        BeautifulSelectionActions(
          documentId: 'mouse',
          text: _text,
          onRequest: (request) {
            requests.add(request);
            return 'improved';
          },
        ),
      ),
    );
    await tester.pump();
    await tester.dragFrom(
      _point(tester, 11),
      _point(tester, 16) - _point(tester, 11),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(_document(tester).controller.selection, _secondAlpha);
    await tester.tap(find.text('Improve').first);
    await tester.pump();
    expect(requests.single.selection, _secondAlpha);
    expect(requests.single.selectedText, 'alpha');
    expect(requests.single.baseText, _text);
    expect(requests.single.documentId, 'mouse');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'native touch toolbar copies and invokes an anchored primary action',
    (tester) async {
      var clipboard = 'previous';
      final requests = <BeautifulSelectionRequest>[];
      _clipboard(tester, (call) async {
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      await tester.pumpWidget(
        _overlayApp(
          BeautifulSelectionActions(
            documentId: 'touch',
            text: _text,
            onRequest: (request) {
              requests.add(request);
              return 'An explanation';
            },
          ),
        ),
      );
      await tester.pump();
      await tester.longPressAt(_point(tester, 13));
      await tester.pumpAndSettle();
      expect(_document(tester).controller.selection, _secondAlpha);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Cut'), findsNothing);
      expect(find.text('Paste'), findsNothing);
      expect(find.text('Explain'), findsNWidgets(2));
      expect(find.text('Shorten'), findsNothing);
      expect(
        tester
            .getSize(
              find
                  .ancestor(
                    of: find.text('Copy'),
                    matching: find.byType(GestureDetector),
                  )
                  .first,
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, 'alpha');
      expect(_document(tester).controller.text, _text);
      await tester.longPressAt(_point(tester, 13));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explain').last);
      await tester.pumpAndSettle();
      expect(requests.single.selection, _secondAlpha);
      expect(requests.single.action.kind, BeautifulSelectionActionKind.explain);
      expect(find.text('Explanation'), findsOneWidget);
      expect(find.text('Keep change'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'native keyboard selection preserves reversed CJK and surrogate offsets',
    (tester) async {
      final requests = <BeautifulSelectionRequest>[];
      const text = '中👋文 中👋文';
      await tester.pumpWidget(
        _overlayApp(
          BeautifulSelectionActions(
            documentId: 'keyboard',
            text: text,
            initialSelection: const TextSelection.collapsed(offset: 9),
            onRequest: (request) {
              requests.add(request);
              return '';
            },
          ),
        ),
      );
      _document(tester).focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        _document(tester).controller.selection,
        const TextSelection(baseOffset: 9, extentOffset: 5),
      );
      await tester.tap(find.text('Improve'));
      await tester.pump();
      expect(requests.single.selectedText, '中👋文');
      expect(requests.single.selection.baseOffset, 9);
      expect(requests.single.selection.extentOffset, 5);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'initial selection seeds insertion and new ID but not same-document updates',
    (tester) async {
      var id = 'first';
      var text = _text;
      var initial = _secondAlpha;
      late StateSetter updateHost;
      await tester.pumpWidget(
        _appChild(
          StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return BeautifulSelectionActions(
                documentId: id,
                text: text,
                initialSelection: initial,
                onRequest: (_) => '',
              );
            },
          ),
        ),
      );
      expect(_document(tester).controller.selection, _secondAlpha);
      updateHost(
        () => initial = const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tester.pump();
      expect(_document(tester).controller.selection, _secondAlpha);
      updateHost(() => text = 'omega beta omega');
      await tester.pump();
      expect(
        _document(tester).controller.selection,
        const TextSelection.collapsed(offset: 0),
      );
      expect(find.text('Improve'), findsNothing);
      updateHost(() => id = 'second');
      await tester.pump();
      expect(_document(tester).controller.selection, initial);
      expect(_document(tester).controller.selection.textInside(text), 'omega');
    },
  );

  testWidgets('Tab and Enter reach the same host action without a pointer', (
    tester,
  ) async {
    final requests = <BeautifulSelectionRequest>[];
    await tester.pumpWidget(
      _overlayApp(
        BeautifulSelectionActions(
          documentId: 'keyboard-actions',
          text: _text,
          initialSelection: _secondAlpha,
          onRequest: (request) {
            requests.add(request);
            return 'Meaning';
          },
        ),
      ),
    );
    _document(tester).focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(requests.single.action.id, 'explain');
    expect(requests.single.selection, _secondAlpha);
    expect(find.text('Meaning'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'request de-duplicates and exact empty replacement stays host controlled',
    (tester) async {
      final completion = Completer<String>();
      final requests = <BeautifulSelectionRequest>[];
      final edits = <BeautifulSelectionEdit>[];
      await tester.pumpWidget(
        _app(
          onRequest: (request) {
            requests.add(request);
            return completion.future;
          },
          onApply: edits.add,
        ),
      );
      await tester.tap(find.text('Improve'));
      await tester.tap(find.text('Improve'));
      await tester.pump();
      expect(requests, hasLength(1));
      expect(find.text('Working on selection'), findsOneWidget);
      completion.complete('');
      await tester.pump();
      expect(find.text('Suggestion ready'), findsOneWidget);
      await tester.tap(find.text('Keep change'));
      await tester.pump();
      expect(edits.single.request, same(requests.single));
      expect(edits.single.request.baseText, _text);
      expect(edits.single.request.selection, _secondAlpha);
      expect(edits.single.request.selectedText, 'alpha');
      expect(edits.single.replacement, '');
      expect(edits.single.updatedText, 'alpha beta ');
      expect(_document(tester).controller.text, _text);
      expect(find.text('Change accepted'), findsOneWidget);
    },
  );

  testWidgets(
    'explanation cannot apply and preview-only replacement disables keep',
    (tester) async {
      final edits = <BeautifulSelectionEdit>[];
      await tester.pumpWidget(
        _app(onApply: edits.add, onRequest: (_) => 'Meaning'),
      );
      await tester.tap(find.text('Explain'));
      await tester.pump();
      expect(find.text('Explanation'), findsOneWidget);
      expect(find.text('Meaning'), findsOneWidget);
      expect(find.text('Keep change'), findsNothing);
      expect(find.text('Original text'), findsNothing);
      expect(edits, isEmpty);
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pumpWidget(_app(onRequest: (_) => 'Replacement'));
      await tester.tap(find.text('Improve'));
      await tester.pump();
      await tester.tap(find.text('Keep change'));
      await tester.pump();
      expect(find.text('Replacement'), findsOneWidget);
      expect(find.text('Change accepted'), findsNothing);
      expect(_document(tester).controller.text, _text);
    },
  );

  testWidgets(
    'request failure reports and retries the exact custom instruction',
    (tester) async {
      final failures = <BeautifulUiFailure>[];
      final requests = <BeautifulSelectionRequest>[];
      await tester.pumpWidget(
        _app(
          onFailure: failures.add,
          onRequest: (request) {
            requests.add(request);
            if (requests.length == 1) throw StateError('offline');
            return 'Retried';
          },
        ),
      );
      await tester.enterText(_instructionFinder, '  retain punctuation!  ');
      await tester.pump();
      await tester.tap(find.text('Send edit instruction'));
      await tester.pump();
      expect(find.text('Could not prepare a suggestion'), findsOneWidget);
      expect(failures.single.operation, BeautifulUiOperation.selection);
      expect(failures.single.cause, isA<StateError>());
      expect(find.text('Try again'), findsOneWidget);
      await tester.enterText(_instructionFinder, 'A later draft');
      await tester.pump();
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(requests, hasLength(2));
      expect(requests.last.instruction, 'retain punctuation!');
      expect(requests.last.selection, requests.first.selection);
      expect(requests.last.baseText, requests.first.baseText);
      expect(find.text('Retried'), findsOneWidget);
    },
  );

  testWidgets(
    'apply failure retains suggestion and de-duplicates a successful retry',
    (tester) async {
      final failures = <BeautifulUiFailure>[];
      final completion = Completer<void>();
      final edits = <BeautifulSelectionEdit>[];
      await tester.pumpWidget(
        _app(
          onFailure: failures.add,
          onRequest: (_) => 'proposed',
          onApply: (edit) {
            edits.add(edit);
            if (edits.length == 1) throw StateError('conflict');
            return completion.future;
          },
        ),
      );
      await tester.tap(find.text('Improve'));
      await tester.pump();
      await tester.tap(find.text('Keep change'));
      await tester.pump();
      expect(failures.single.operation, BeautifulUiOperation.selection);
      expect(find.text('Could not apply the change'), findsOneWidget);
      expect(find.text('proposed'), findsOneWidget);
      await tester.tap(find.text('Keep change'));
      await tester.tap(find.text('Keep change'));
      await tester.pump();
      expect(edits, hasLength(2));
      expect(edits.last.request, same(edits.first.request));
      expect(find.text('Applying change'), findsOneWidget);
      completion.complete();
      await tester.pump();
      expect(find.text('Change accepted'), findsOneWidget);
      expect(find.text('proposed'), findsNothing);
    },
  );

  for (final mutation in [
    'identity',
    'text',
    'range',
    'disabled',
    'disposed',
  ]) {
    for (final fails in [false, true]) {
      testWidgets(
        'stale request ${fails ? 'failure' : 'success'} ignored after $mutation',
        (tester) async {
          final completion = Completer<String>();
          final failures = <BeautifulUiFailure>[];
          var id = 'first';
          var text = _text;
          var enabled = true;
          late StateSetter updateHost;
          await tester.pumpWidget(
            _appChild(
              StatefulBuilder(
                builder: (context, setState) {
                  updateHost = setState;
                  return BeautifulSelectionActions(
                    documentId: id,
                    text: text,
                    enabled: enabled,
                    initialSelection: _secondAlpha,
                    onRequest: (_) => completion.future,
                  );
                },
              ),
              onFailure: failures.add,
            ),
          );
          await tester.tap(find.text('Improve'));
          await tester.pump();
          switch (mutation) {
            case 'identity':
              updateHost(() => id = 'replacement');
            case 'text':
              updateHost(() => text = 'omega beta omega');
            case 'range':
              _select(
                tester,
                const TextSelection(baseOffset: 0, extentOffset: 5),
              );
            case 'disabled':
              updateHost(() => enabled = false);
            case 'disposed':
              await tester.pumpWidget(const SizedBox.shrink());
          }
          await tester.pump();
          if (fails) {
            completion.completeError(StateError('obsolete'));
          } else {
            completion.complete('obsolete');
          }
          await tester.pump();
          expect(find.text('obsolete'), findsNothing);
          expect(find.text('Suggestion ready'), findsNothing);
          expect(find.text('Working on selection'), findsNothing);
          expect(failures, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final mutation in ['identity', 'text', 'range']) {
    for (final fails in [false, true]) {
      testWidgets(
        'stale host application ${fails ? 'failure' : 'success'} ignored after $mutation',
        (tester) async {
          final completion = Completer<void>();
          final failures = <BeautifulUiFailure>[];
          var id = 'first';
          var text = _text;
          late StateSetter updateHost;
          await tester.pumpWidget(
            _appChild(
              StatefulBuilder(
                builder: (context, setState) {
                  updateHost = setState;
                  return BeautifulSelectionActions(
                    documentId: id,
                    text: text,
                    initialSelection: _secondAlpha,
                    onRequest: (_) => 'proposal',
                    onApply: (_) => completion.future,
                  );
                },
              ),
              onFailure: failures.add,
            ),
          );
          await tester.tap(find.text('Improve'));
          await tester.pump();
          await tester.tap(find.text('Keep change'));
          await tester.pump();
          switch (mutation) {
            case 'identity':
              updateHost(() => id = 'replacement');
            case 'text':
              updateHost(() => text = 'omega beta omega');
            case 'range':
              _select(
                tester,
                const TextSelection(baseOffset: 0, extentOffset: 5),
              );
          }
          await tester.pump();
          if (fails) {
            completion.completeError(StateError('obsolete application'));
          } else {
            completion.complete();
          }
          await tester.pump();
          expect(find.text('Applying change'), findsNothing);
          expect(find.text('Could not apply the change'), findsNothing);
          expect(find.text('proposal'), findsNothing);
          expect(find.text('Change accepted'), findsNothing);
          expect(failures, isEmpty);
        },
      );
    }
  }

  testWidgets(
    'Discard cancels pending presentation and retry repeats the last result request',
    (tester) async {
      final pending = Completer<String>();
      final requests = <BeautifulSelectionRequest>[];
      await tester.pumpWidget(
        _app(
          onRequest: (request) {
            requests.add(request);
            return requests.length == 1
                ? pending.future
                : 'version ${requests.length}';
          },
        ),
      );
      await tester.tap(find.text('Improve'));
      await tester.pump();
      await tester.tap(find.text('Discard'));
      await tester.pump();
      expect(_document(tester).focusNode.hasFocus, isTrue);
      expect(_document(tester).controller.selection, _secondAlpha);
      pending.complete('discarded result');
      await tester.pump();
      expect(find.text('discarded result'), findsNothing);
      await tester.tap(find.text('Improve'));
      await tester.pump();
      expect(find.text('version 2'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(requests, hasLength(3));
      expect(requests.last.selection, _secondAlpha);
      expect(requests.last.action.id, requests[1].action.id);
      expect(requests.last.baseText, _text);
      expect(find.text('version 3'), findsOneWidget);
      expect(find.text('version 2'), findsNothing);
    },
  );

  testWidgets(
    'document only updates after the host accepts the proposed replacement',
    (tester) async {
      var text = _text;
      BeautifulSelectionEdit? proposed;
      late StateSetter updateHost;
      await tester.pumpWidget(
        _appChild(
          StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return BeautifulSelectionActions(
                documentId: 'controlled',
                text: text,
                initialSelection: _secondAlpha,
                onRequest: (_) => 'updated',
                onApply: (edit) => proposed = edit,
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Improve'));
      await tester.pump();
      await tester.tap(find.text('Keep change'));
      await tester.pump();
      expect(proposed!.updatedText, 'alpha beta updated');
      expect(_document(tester).controller.text, _text);
      updateHost(() => text = proposed!.updatedText);
      await tester.pump();
      expect(_document(tester).controller.text, 'alpha beta updated');
      expect(find.text('Select text to see actions'), findsOneWidget);
    },
  );

  testWidgets(
    'equivalent snapshots and resize preserve selection draft focus disclosure and pending work',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final completion = Completer<String>();
      var width = 599.0;
      var keyboard = 0.0;
      late StateSetter updateHost;
      await tester.pumpWidget(
        _appChild(
          StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
                child: SizedBox(
                  width: width,
                  child: BeautifulSelectionActions(
                    documentId: 'same',
                    text: String.fromCharCodes(_text.codeUnits),
                    initialSelection: _secondAlpha,
                    onRequest: (_) => completion.future,
                  ),
                ),
              );
            },
          ),
          size: const Size(1100, 900),
        ),
      );
      expect(tester.getSize(find.byType(BeautifulSelectionActions)).width, 599);
      await tester.tap(find.text('More actions'));
      await tester.enterText(_instructionFinder, 'Preserve draft');
      final instruction = tester.widget<EditableText>(_instructionFinder);
      instruction.controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      await tester.pump();
      updateHost(() {
        width = 280;
        keyboard = 300;
      });
      await tester.pump();
      expect(tester.getSize(find.byType(BeautifulSelectionActions)).width, 280);
      expect(_document(tester).controller.selection, _secondAlpha);
      expect(
        tester.widget<EditableText>(_instructionFinder).controller,
        same(instruction.controller),
      );
      expect(instruction.controller.text, 'Preserve draft');
      expect(
        instruction.controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );
      expect(instruction.focusNode.hasFocus, isTrue);
      expect(find.text('Shorten'), findsOneWidget);
      await tester.tap(find.text('Improve'));
      await tester.pump();
      updateHost(() => width = 1024);
      await tester.pump();
      expect(
        tester.getSize(find.byType(BeautifulSelectionActions)).width,
        1024,
      );
      expect(find.text('Working on selection'), findsOneWidget);
      completion.complete('Current result');
      await tester.pump();
      expect(find.text('Current result'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom instruction protects IME and secondary disclosure dismisses with Escape',
    (tester) async {
      final requests = <BeautifulSelectionRequest>[];
      await tester.pumpWidget(
        _app(
          onRequest: (request) {
            requests.add(request);
            return 'done';
          },
        ),
      );
      expect(find.text('Shorten'), findsNothing);
      await tester.tap(find.text('More actions'));
      await tester.pump();
      expect(find.text('Shorten'), findsOneWidget);
      await tester.enterText(_instructionFinder, '编辑文字');
      final instruction = tester.widget<EditableText>(_instructionFinder);
      instruction.controller.value = const TextEditingValue(
        text: '编辑文字',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 0, end: 4),
      );
      await tester.pump();
      await tester.tap(find.text('Send edit instruction'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(requests, isEmpty);
      instruction.controller.clearComposing();
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(requests.single.instruction, '编辑文字');
      expect(requests.single.action.id, 'custom');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('done'), findsNothing);
      expect(find.text('Shorten'), findsNothing);
      expect(_document(tester).focusNode.hasFocus, isTrue);
    },
  );

  for (final semantic in [false, true]) {
    testWidgets(
      'delayed ${semantic ? 'semantic' : 'keyboard'} instruction paste is isolated by document identity',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final read = Completer<Map<String, Object>?>();
        var readCount = 0;
        var id = 'first';
        late StateSetter updateHost;
        _clipboard(tester, (call) async {
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          if (call.method == 'Clipboard.getData') {
            readCount++;
            return read.future;
          }
          return null;
        });
        await tester.pumpWidget(
          _overlayApp(
            StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return BeautifulSelectionActions(
                  documentId: id,
                  text: _text,
                  initialSelection: _secondAlpha,
                  onRequest: (_) => '',
                );
              },
            ),
          ),
        );
        await tester.enterText(_instructionFinder, '');
        await tester.pumpAndSettle();
        if (semantic) {
          tester.semantics.paste(find.semantics.byLabel('Describe edits'));
        } else {
          await _shortcut(tester, LogicalKeyboardKey.keyV);
        }
        await tester.pump();
        expect(readCount, 1);
        final before = tester
            .widget<EditableText>(_instructionFinder)
            .controller
            .value;
        updateHost(() => id = 'second');
        await tester.pump();
        expect(
          tester.widget<EditableText>(_instructionFinder).controller.value,
          before,
        );
        read.complete({'text': 'stale clipboard'});
        await tester.pumpAndSettle();
        expect(
          tester.widget<EditableText>(_instructionFinder).controller.value,
          before,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'keyboard copy is literal and read-only document ignores cut paste and typing',
    (tester) async {
      var copied = '';
      var reads = 0;
      _clipboard(tester, (call) async {
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        if (call.method == 'Clipboard.getData') {
          reads++;
          return {'text': 'malicious replacement'};
        }
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      await tester.pumpWidget(
        _overlayApp(
          BeautifulSelectionActions(
            documentId: 'read-only',
            text: _text,
            initialSelection: _secondAlpha,
            onRequest: (_) => '',
          ),
        ),
      );
      _document(tester).focusNode.requestFocus();
      await tester.pumpAndSettle();
      await _shortcut(tester, LogicalKeyboardKey.keyC);
      await tester.pumpAndSettle();
      expect(copied, 'alpha');
      await _shortcut(tester, LogicalKeyboardKey.keyX);
      await _shortcut(tester, LogicalKeyboardKey.keyV);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      expect(_document(tester).controller.text, _text);
      expect(reads, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'all boundaries fit RTL 200 percent high contrast with 48dp controls and reduced motion',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in <double>[280, 599, 600, 1023, 1024]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpWidget(
          beautifulTestApp(
            size: Size(width, 900),
            brightness: Brightness.dark,
            highContrast: true,
            disableAnimations: true,
            textScaler: const TextScaler.linear(2),
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: BeautifulSelectionActions(
                key: ValueKey(width),
                documentId: 'rtl',
                text: 'النص الأصلي لتحسين الوضوح',
                initialSelection: const TextSelection(
                  baseOffset: 0,
                  extentOffset: 10,
                ),
                actions: const [
                  BeautifulSelectionAction(
                    id: 'improve',
                    label: 'تحسين النص المحدد',
                  ),
                ],
                onRequest: (_) => 'اقتراح أكثر وضوحا',
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width $width');
        final action = find
            .ancestor(
              of: find.text('تحسين النص المحدد'),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        expect(tester.getRect(action).right, lessThanOrEqualTo(width));
        await tester.tap(find.text('تحسين النص المحدد'));
        await tester.pumpAndSettle();
        expect(find.text('اقتراح أكثر وضوحا'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'result width $width');
      }
    },
  );

  testWidgets(
    '20k-character document has a bounded internally scrollable editor',
    (tester) async {
      final text = List.filled(
        1000,
        'line of content 123\n',
      ).join().padRight(20000, 'x');
      expect(text.length, 20000);
      final requests = <BeautifulSelectionRequest>[];
      final diagnostic = Stopwatch()..start();
      await tester.pumpWidget(
        _app(
          text: text,
          selection: const TextSelection(baseOffset: 0, extentOffset: 4),
          onRequest: (request) {
            requests.add(request);
            return 'sentence';
          },
        ),
      );
      await tester.pump();
      final editor = _document(tester);
      expect(tester.getSize(_documentFinder).height, lessThan(300));
      expect(
        editor.scrollController!.position.maxScrollExtent,
        greaterThan(10000),
      );
      editor.scrollController!.jumpTo(
        editor.scrollController!.position.maxScrollExtent,
      );
      await tester.pump();
      expect(editor.scrollController!.position.extentAfter, 0);
      await tester.tap(find.text('Improve'));
      await tester.pump();
      expect(requests.single.baseText, text);
      expect(requests.single.selectedText, 'line');
      expect(tester.takeException(), isNull);
      diagnostic.stop();
      // Diagnostic only: frame/memory claims require platform profile evidence.
      debugPrint(
        'Selection Actions 20k document widget workload: ${diagnostic.elapsedMilliseconds} ms',
      );
    },
  );
}

Finder get _documentFinder => find.byType(EditableText).first;
Finder get _instructionFinder => find.byType(EditableText).at(1);
EditableText _document(WidgetTester tester) =>
    tester.widget<EditableText>(_documentFinder);

Offset _point(WidgetTester tester, int offset) {
  final editor = tester.state<EditableTextState>(_documentFinder);
  return editor.renderEditable.localToGlobal(
    editor.renderEditable
        .getLocalRectForCaret(TextPosition(offset: offset))
        .center,
  );
}

void _select(WidgetTester tester, TextSelection selection) {
  final editor = tester.state<EditableTextState>(_documentFinder);
  editor.userUpdateTextEditingValue(
    editor.textEditingValue.copyWith(selection: selection),
    SelectionChangedCause.keyboard,
  );
}

Future<void> _shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
}

void _clipboard(
  WidgetTester tester,
  Future<Object?> Function(MethodCall) handler,
) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    handler,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

Widget _overlayApp(Widget child) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => Overlay(
    initialEntries: [
      OverlayEntry(
        builder: (context) => BeautifulUiScope(
          motion: BeautifulMotionPolicy.none,
          child: Align(
            alignment: Alignment.topLeft,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ],
  ),
);

Widget _app({
  String text = _text,
  TextSelection? selection = _secondAlpha,
  FutureOr<String> Function(BeautifulSelectionRequest)? onRequest,
  FutureOr<void> Function(BeautifulSelectionEdit)? onApply,
  BeautifulUiFailureHandler? onFailure,
}) => _appChild(
  BeautifulSelectionActions(
    documentId: 'document',
    text: text,
    initialSelection: selection,
    onRequest: onRequest ?? (_) => 'result',
    onApply: onApply,
  ),
  onFailure: onFailure,
);

Widget _appChild(
  Widget child, {
  BeautifulUiFailureHandler? onFailure,
  Size size = const Size(390, 844),
}) => beautifulTestApp(
  size: size,
  disableAnimations: true,
  child: BeautifulUiScope(
    onFailure: onFailure,
    child: SingleChildScrollView(child: child),
  ),
);
