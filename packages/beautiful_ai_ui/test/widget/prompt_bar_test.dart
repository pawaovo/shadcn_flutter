import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _sources = <BeautifulPromptSource>[
  BeautifulPromptSource(
    id: 'sales',
    label: 'Sales records',
    description: 'Quarterly totals',
  ),
  BeautifulPromptSource(
    id: 'web',
    label: 'Web search',
    description: 'Current sources',
  ),
];
const _commands = <BeautifulPromptCommand>[
  BeautifulPromptCommand(
    id: 'compare',
    label: 'compare',
    description: 'Compare periods',
  ),
  BeautifulPromptCommand(
    id: 'compose',
    label: '/compose',
    description: 'Write a message',
  ),
];
const _models = <BeautifulPromptModel>[
  BeautifulPromptModel(id: 'basic', label: 'Basic model', description: 'Fast'),
  BeautifulPromptModel(
    id: 'advanced',
    label: 'Advanced model',
    description: 'Detailed',
  ),
];
const _file = BeautifulPromptAttachment(
  id: 'report',
  label: 'Annual report.pdf',
);

void main() {
  testWidgets('sends immutable trimmed text with selected model and files', (
    tester,
  ) async {
    final sent = <BeautifulPromptSubmission>[];
    await tester.pumpWidget(
      _app(
        BeautifulPromptBar(
          composerId: 'one',
          initialDraft: '  Please compare  ',
          initialAttachments: const [_file],
          models: _models,
          selectedModelId: 'basic',
          onSend: sent.add,
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(sent.single.text, 'Please compare');
    expect(sent.single.modelId, 'basic');
    expect(sent.single.attachments.single.id, 'report');
    expect(() => sent.single.attachments.clear(), throwsUnsupportedError);
    expect(_draft(tester).text, isEmpty);
    expect(find.text('Remove Annual report.pdf'), findsNothing);
  });

  testWidgets('attachment-only drafts can send', (tester) async {
    final sent = <BeautifulPromptSubmission>[];
    await tester.pumpWidget(
      _app(
        BeautifulPromptBar(
          composerId: 'one',
          initialAttachments: const [_file],
          onSend: sent.add,
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(sent.single.text, '');
    expect(sent.single.attachments.single, _file);
  });

  testWidgets(
    'source filtering and keyboard insertion preserve text after caret',
    (tester) async {
      await tester.pumpWidget(
        _app(const BeautifulPromptBar(composerId: 'one', sources: _sources)),
      );
      await tester.enterText(find.byType(EditableText), 'Use @we tomorrow');
      _draft(tester).selection = const TextSelection.collapsed(offset: 7);
      await tester.pump();
      expect(find.text('Web search\nCurrent sources'), findsOneWidget);
      expect(find.text('Sales records\nQuarterly totals'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_draft(tester).text, 'Use @Web search  tomorrow');
      expect(_draft(tester).selection.extentOffset, 16);
      expect(find.text('Sources and files'), findsNothing);
    },
  );

  testWidgets('slash menu supports arrow navigation Tab selection and Escape', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const BeautifulPromptBar(composerId: 'one', commands: _commands)),
    );
    await tester.enterText(find.byType(EditableText), '/co');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_draft(tester).text, '/compose ');
    await tester.enterText(find.byType(EditableText), '/');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Commands'), findsNothing);
    expect(_draft(tester).text, '/');
    await tester.enterText(find.byType(EditableText), '/zz');
    await tester.pump();
    expect(find.text('No matching options'), findsOneWidget);
  });

  testWidgets('IME composition bypasses menu navigation and submission', (
    tester,
  ) async {
    final sent = <BeautifulPromptSubmission>[];
    await tester.pumpWidget(
      _app(
        BeautifulPromptBar(
          composerId: 'one',
          commands: _commands,
          onSend: sent.add,
        ),
      ),
    );
    await tester.showKeyboard(find.byType(EditableText));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '/co',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 0, end: 3),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, isEmpty);
    expect(_draft(tester).text, '/co');
    expect(_draft(tester).value.composing, const TextRange(start: 0, end: 3));
    expect(find.text('Commands'), findsNothing);
  });

  testWidgets('Shift Enter does not submit while Enter submits plain text', (
    tester,
  ) async {
    final sent = <BeautifulPromptSubmission>[];
    await tester.pumpWidget(
      _app(BeautifulPromptBar(composerId: 'one', onSend: sent.add)),
    );
    await tester.enterText(find.byType(EditableText), 'hello');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(sent, isEmpty);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent.single.text, startsWith('hello'));
  });

  testWidgets(
    'equal-content parent rebuild preserves pending send and later edits',
    (tester) async {
      final completion = Completer<void>();
      var calls = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeautifulPromptBar(
                composerId: 'one',
                initialDraft: 'first',
                sources: [
                  for (final source in _sources)
                    BeautifulPromptSource(id: source.id, label: source.label),
                ],
                onSend: (_) {
                  calls++;
                  return completion.future;
                },
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Send'));
      await tester.pump();
      update(() {});
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'the next draft');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Sending…'), findsOneWidget);
      completion.complete();
      await tester.pumpAndSettle();
      expect(_draft(tester).text, 'the next draft');
      expect(find.text('Send'), findsOneWidget);
    },
  );

  testWidgets('send completion cannot clear an edited then restored draft', (
    tester,
  ) async {
    final completion = Completer<void>();
    await tester.pumpWidget(
      _app(
        BeautifulPromptBar(
          composerId: 'one',
          initialDraft: 'first',
          onSend: (_) => completion.future,
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.enterText(find.byType(EditableText), 'temporary');
    await tester.enterText(find.byType(EditableText), 'first');
    completion.complete();
    await tester.pump();
    expect(_draft(tester).text, 'first');
  });

  testWidgets(
    'replacement identity ignores old send failure and resets seeded attachments',
    (tester) async {
      final completion = Completer<void>();
      final failures = <BeautifulUiFailure>[];
      var id = 'one';
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeautifulPromptBar(
                composerId: id,
                initialDraft: id,
                initialAttachments: const [_file],
                onSend: (_) => completion.future,
              );
            },
          ),
          onFailure: failures.add,
        ),
      );
      await tester.tap(find.text('Send'));
      await tester.pump();
      update(() => id = 'two');
      await tester.pump();
      completion.completeError(StateError('stale failure'));
      await tester.pump();
      expect(_draft(tester).text, 'two');
      expect(find.text('Remove Annual report.pdf'), findsOneWidget);
      expect(find.text('Sending…'), findsNothing);
      expect(failures, isEmpty);
    },
  );

  testWidgets(
    'failed send retains draft and attachments and reports root failure',
    (tester) async {
      final failures = <BeautifulUiFailure>[];
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            initialDraft: 'keep me',
            initialAttachments: const [_file],
            onSend: (_) => throw StateError('offline'),
          ),
          onFailure: failures.add,
        ),
      );
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(_draft(tester).text, 'keep me');
      expect(find.text('Remove Annual report.pdf'), findsOneWidget);
      expect(failures.single.operation, BeautifulUiOperation.prompt);
      expect(failures.single.message, 'Prompt send failed.');
    },
  );

  testWidgets(
    'picker is de-duplicated and preserves edits made while it is open',
    (tester) async {
      var calls = 0;
      final picker = Completer<List<BeautifulPromptAttachment>>();
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            onAttach: () {
              calls++;
              return picker.future;
            },
          ),
        ),
      );
      await tester.tap(find.text('Add sources and files'));
      await tester.pump();
      await tester.tap(find.text('Add photos and files'));
      await tester.pump();
      await tester.tap(find.text('Adding files…'));
      await tester.enterText(find.byType(EditableText), 'new edit');
      picker.complete([_file, _file]);
      await tester.pump();
      expect(calls, 1);
      expect(find.text('Remove Annual report.pdf'), findsOneWidget);
      expect(_draft(tester).text, 'new edit');
      await tester.tap(find.text('Remove Annual report.pdf'));
      await tester.pump();
      expect(find.text('Remove Annual report.pdf'), findsNothing);
    },
  );

  testWidgets('newly reattached file survives completion of an older send', (
    tester,
  ) async {
    final send = Completer<void>();
    await tester.pumpWidget(
      _app(
        BeautifulPromptBar(
          composerId: 'one',
          initialDraft: 'first',
          initialAttachments: const [_file],
          onSend: (_) => send.future,
          onAttach: () => [_file],
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.tap(find.text('Remove Annual report.pdf'));
    await tester.pump();
    await tester.tap(find.text('Add sources and files'));
    await tester.pump();
    await tester.tap(find.text('Add photos and files'));
    await tester.pump();
    send.complete();
    await tester.pump();
    expect(find.text('Remove Annual report.pdf'), findsOneWidget);
    expect(_draft(tester).text, isEmpty);
  });

  testWidgets('old picker result cannot attach to replacement draft', (
    tester,
  ) async {
    var id = 'one';
    final picker = Completer<List<BeautifulPromptAttachment>>();
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeautifulPromptBar(
              composerId: id,
              onAttach: () => picker.future,
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Add sources and files'));
    await tester.pump();
    await tester.tap(find.text('Add photos and files'));
    await tester.pump();
    update(() => id = 'two');
    await tester.pump();
    picker.complete([_file]);
    await tester.pump();
    expect(find.text('Remove Annual report.pdf'), findsNothing);
  });

  testWidgets(
    'model selection is controlled and Escape restores editor focus',
    (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            models: _models,
            selectedModelId: 'basic',
            onModelChanged: selected.add,
          ),
        ),
      );
      await tester.tap(find.text('Basic model'));
      await tester.pump();
      await tester.tap(find.text('Advanced model\nDetailed'));
      await tester.pump();
      expect(selected, ['advanced']);
      expect(find.text('Basic model'), findsOneWidget);
      expect(_editor(tester).focusNode.hasFocus, isTrue);
      await tester.tap(find.text('Basic model'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Advanced model\nDetailed'), findsNothing);
      expect(_editor(tester).focusNode.hasFocus, isTrue);
    },
  );

  testWidgets('connection completion does not invent a connected source', (
    tester,
  ) async {
    final connection = Completer<void>();
    var connected = false;
    var calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return BeautifulPromptBar(
              composerId: 'one',
              sources: [
                BeautifulPromptSource(
                  id: 'private',
                  label: 'Private records',
                  connected: connected,
                ),
              ],
              onConnectSource: (id) {
                expect(id, 'private');
                calls++;
                return connection.future;
              },
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), '@');
    await tester.pump();
    await tester.tap(find.text('Private records\nConnect'));
    await tester.pump();
    await tester.tap(find.text('Private records\nConnecting…'));
    update(() {});
    await tester.pump();
    connection.complete();
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(_draft(tester).text, '@');
    expect(find.text('Private records\nConnect'), findsOneWidget);
    update(() => connected = true);
    await tester.pump();
    await tester.tap(find.text('Private records'));
    await tester.pump();
    expect(_draft(tester).text, '@Private records ');
  });

  testWidgets(
    'dictation inserts only into its original unchanged editing value',
    (tester) async {
      var response = Completer<String?>();
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            initialDraft: 'Compare',
            onDictate: () => response.future,
          ),
        ),
      );
      await tester.tap(find.text('Start dictation'));
      await tester.pump();
      response.complete('this quarter');
      await tester.pump();
      expect(_draft(tester).text, 'Compare this quarter');
      response = Completer<String?>();
      await tester.tap(find.text('Start dictation'));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'a newer thought');
      response.complete('stale words');
      await tester.pump();
      expect(_draft(tester).text, 'a newer thought');
    },
  );

  testWidgets(
    'stop dictation invalidates late transcript and permits another session',
    (tester) async {
      final transcript = Completer<String?>();
      var stopped = 0;
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            initialDraft: 'unchanged',
            onDictate: () => transcript.future,
            onStopDictation: () {
              stopped++;
            },
          ),
        ),
      );
      await tester.tap(find.text('Start dictation'));
      await tester.pump();
      await tester.tap(find.text('Stop dictation'));
      await tester.pump();
      transcript.complete('ignored after stop');
      await tester.pump();
      expect(stopped, 1);
      expect(_draft(tester).text, 'unchanged');
      expect(find.text('Start dictation'), findsOneWidget);
    },
  );

  testWidgets('disabled composer exposes no executable integrations', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        BeautifulPromptBar(
          composerId: 'one',
          initialDraft: 'read only',
          enabled: false,
          models: _models,
          sources: _sources,
          onModelChanged: (_) => calls++,
          onSend: (_) => calls++,
          onAttach: () {
            calls++;
            return [];
          },
          onDictate: () {
            calls++;
            return 'no';
          },
        ),
      ),
    );
    await tester.tap(find.text('Send'));
    await tester.tap(find.text('Start dictation'));
    await tester.tap(find.text('Add sources and files'));
    await tester.pump();
    expect(calls, 0);
    expect(_editor(tester).readOnly, isTrue);
    expect(_draft(tester).text, 'read only');
  });

  testWidgets(
    'reopening dismissed source token replaces it instead of duplicating @',
    (tester) async {
      await tester.pumpWidget(
        _app(const BeautifulPromptBar(composerId: 'one', sources: _sources)),
      );
      await tester.enterText(find.byType(EditableText), 'Use @we');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tap(find.text('Add sources and files'));
      await tester.pump();
      await tester.tap(find.text('Web search\nCurrent sources'));
      await tester.pump();
      expect(_draft(tester).text, 'Use @Web search ');
    },
  );

  testWidgets(
    'stop invalidates a transcript before asynchronous stop completes',
    (tester) async {
      final transcript = Completer<String?>();
      final stop = Completer<void>();
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            initialDraft: 'original',
            onDictate: () => transcript.future,
            onStopDictation: () => stop.future,
          ),
        ),
      );
      await tester.tap(find.text('Start dictation'));
      await tester.pump();
      await tester.tap(find.text('Stop dictation'));
      await tester.pump();
      transcript.complete('late words');
      await tester.pump();
      expect(_draft(tester).text, 'original');
      expect(find.text('Stopping dictation…'), findsOneWidget);
      stop.complete();
      await tester.pumpAndSettle();
      expect(find.text('Start dictation'), findsOneWidget);
    },
  );

  testWidgets(
    'dictation survives equal-content parent rebuild but not replacement identity',
    (tester) async {
      var transcript = Completer<String?>();
      var id = 'one';
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return BeautifulPromptBar(
                composerId: id,
                initialDraft: 'base',
                onDictate: () => transcript.future,
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Start dictation'));
      await tester.pump();
      update(() {});
      await tester.pump();
      transcript.complete('valid result');
      await tester.pumpAndSettle();
      expect(_draft(tester).text, 'base valid result');
      transcript = Completer<String?>();
      await tester.tap(find.text('Start dictation'));
      await tester.pump();
      update(() => id = 'two');
      await tester.pump();
      transcript.complete('obsolete result');
      await tester.pumpAndSettle();
      expect(_draft(tester).text, 'base');
    },
  );

  testWidgets(
    'host integration errors preserve draft and use the prompt failure seam',
    (tester) async {
      final failures = <BeautifulUiFailure>[];
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            initialDraft: 'unchanged',
            sources: const [
              BeautifulPromptSource(
                id: 'private',
                label: 'Private',
                connected: false,
              ),
            ],
            onAttach: () => throw StateError('picker failed'),
            onDictate: () => throw StateError('microphone failed'),
            onConnectSource: (_) => throw StateError('connection failed'),
          ),
          onFailure: failures.add,
        ),
      );
      await tester.tap(find.text('Start dictation'));
      await tester.pump();
      await tester.tap(find.text('Add sources and files'));
      await tester.pump();
      await tester.tap(find.text('Add photos and files'));
      await tester.pump();
      await tester.tap(find.text('Private\nConnect'));
      await tester.pump();
      expect(
        failures.map((failure) => failure.operation),
        everyElement(BeautifulUiOperation.prompt),
      );
      expect(failures.map((failure) => failure.message), [
        'Prompt dictation failed.',
        'Prompt attachment selection failed.',
        'Prompt source connection failed.',
      ]);
      expect(_draft(tester).text, 'unchanged');
    },
  );

  testWidgets(
    'resize preserves editor selection composing region and attachment draft',
    (tester) async {
      var width = 1024.0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: width,
                child: const BeautifulPromptBar(
                  composerId: 'one',
                  initialAttachments: [_file],
                ),
              );
            },
          ),
          size: const Size(1100, 900),
        ),
      );
      await tester.showKeyboard(find.byType(EditableText));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: '中文 input',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      final before = _draft(tester).value;
      final state = tester.state<EditableTextState>(find.byType(EditableText));
      for (final next in [320.0, 599.0, 600.0, 1023.0, 1024.0]) {
        update(() => width = next);
        await tester.pump();
        expect(_draft(tester).value, before);
        expect(
          tester.state<EditableTextState>(find.byType(EditableText)),
          same(state),
        );
        expect(find.text('Remove Annual report.pdf'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  for (final variant in BeautifulPromptBarVariant.values) {
    testWidgets(
      '$variant wraps full Arabic/Chinese labels at 200 percent with keyboard inset',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          beautifulTestApp(
            size: const Size(320, 600),
            textDirection: TextDirection.rtl,
            textScaler: TextScaler.linear(2),
            highContrast: true,
            disableAnimations: true,
            child: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 600),
                textScaler: TextScaler.linear(2),
                viewInsets: const EdgeInsets.only(bottom: 280),
              ),
              child: BeautifulPromptBar(
                composerId: 'one',
                variant: variant,
                tall: true,
                initialDraft: 'هذا وصف عربي طويل يوضح الفكرة كاملة 中文内容需要保留',
                initialAttachments: const [
                  BeautifulPromptAttachment(
                    id: 'file',
                    label: '完整文件名称不能被截断必须显示给用户查看.pdf',
                  ),
                ],
                sources: const [
                  BeautifulPromptSource(
                    id: 'one',
                    label: 'المصادر والملفات المشتركة',
                  ),
                ],
                models: const [
                  BeautifulPromptModel(id: 'model', label: '完整的模型名称需要自动换行显示'),
                ],
                onModelChanged: (_) {},
                onSend: (_) {},
                sendLabel: 'إرسال الرسالة كاملة الآن',
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('إرسال الرسالة كاملة الآن'));
        await tester.pump();
        expect(
          tester.getRect(find.text('إرسال الرسالة كاملة الآن')).bottom,
          lessThanOrEqualTo(320),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '1000 source options build lazily and keyboard wraps to final result',
    (tester) async {
      final stopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            sources: [
              for (var i = 0; i < 1000; i++)
                BeautifulPromptSource(
                  id: 's$i',
                  label: 'Source $i',
                  description: 'Details $i',
                ),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), '@');
      await tester.pump();
      final options = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'beautiful-prompt-option-',
            ),
      );
      expect(options.evaluate().length, lessThan(50));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(find.text('Source 999\nDetails 999'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_draft(tester).text, '@Source 999 ');
      // Diagnostic only; no machine-dependent timing gate.
      // ignore: avoid_print
      print(
        'Prompt 1000-source keyboard workload: ${stopwatch.elapsedMilliseconds}ms',
      );
    },
  );

  testWidgets(
    '10000-character draft stays height-bounded and sends exact text',
    (tester) async {
      final text = List.filled(1000, 'long text ').join();
      final sent = <BeautifulPromptSubmission>[];
      await tester.pumpWidget(
        _app(
          BeautifulPromptBar(
            composerId: 'one',
            initialDraft: text,
            onSend: sent.add,
          ),
        ),
      );
      expect(tester.getSize(find.byType(EditableText)).height, lessThan(150));
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(sent.single.text, text.trim());
      expect(tester.takeException(), isNull);
    },
  );

  for (final semantic in [false, true]) {
    testWidgets(
      'delayed ${semantic ? 'semantic' : 'keyboard'} paste ignores identical replacement composer',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final read = Completer<Map<String, Object>?>();
        var calls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.hasStrings') {
              return <String, Object>{'value': true};
            }
            if (call.method == 'Clipboard.getData') {
              calls++;
              return read.future;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        var id = 'one';
        late StateSetter update;
        await tester.pumpWidget(
          _overlayApp(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return BeautifulPromptBar(
                  composerId: id,
                  initialDraft: 'unchanged',
                  autofocus: true,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final before = _draft(tester).value;
        if (semantic) {
          tester.semantics.paste(find.semantics.byLabel('Prompt'));
        } else {
          final modifier = defaultTargetPlatform == TargetPlatform.macOS
              ? LogicalKeyboardKey.metaLeft
              : LogicalKeyboardKey.controlLeft;
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
          await tester.sendKeyUpEvent(modifier);
        }
        await tester.pump();
        expect(calls, 1);
        update(() => id = 'two');
        await tester.pump();
        read.complete(<String, Object>{'text': 'stale paste'});
        await tester.pumpAndSettle();
        expect(_draft(tester).value, before);
        semantics.dispose();
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );
  }
}

EditableText _editor(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));
TextEditingController _draft(WidgetTester tester) => _editor(tester).controller;

Widget _app(
  Widget child, {
  Size size = const Size(390, 844),
  BeautifulUiFailureHandler? onFailure,
}) => beautifulTestApp(
  size: size,
  disableAnimations: true,
  child: BeautifulUiScope(onFailure: onFailure, child: child),
);

Widget _overlayApp(Widget child) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => Overlay(
    initialEntries: [
      OverlayEntry(
        builder: (context) => BeautifulUiScope(
          motion: BeautifulMotionPolicy.none,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
      ),
    ],
  ),
);
