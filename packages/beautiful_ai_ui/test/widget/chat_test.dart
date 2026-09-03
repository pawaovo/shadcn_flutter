import 'dart:async';

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _messages = <BeautifulChatMessage>[
  BeautifulChatMessage(
    id: 'user-1',
    role: BeautifulChatRole.user,
    text: 'Compare this summer with last year',
  ),
  BeautifulChatMessage(
    id: 'assistant-1',
    role: BeautifulChatRole.assistant,
    title: 'Sales history',
    subtitle: 'Flavor data',
    detailLabel: '4 seconds',
    text: 'Pulled three summers of sales for comparison.',
  ),
];

void main() {
  for (final semantic in <bool>[false, true]) {
    final mechanism = semantic ? 'semantic' : 'keyboard';
    testWidgets(
      'delayed $mechanism paste cannot edit an identical replacement conversation',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final clipboardRead = Completer<Map<String, Object>?>();
        var readCalls = 0;
        var conversationId = 'original';
        late StateSetter updateHost;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.hasStrings') {
              return <String, Object>{'value': true};
            }
            if (call.method == 'Clipboard.getData') {
              readCalls++;
              return clipboardRead.future;
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
        await tester.pumpWidget(
          _overlayApp(
            StatefulBuilder(
              builder: (context, setState) {
                updateHost = setState;
                return BeautifulChat(
                  conversationId: conversationId,
                  initialDraft: 'unchanged',
                  messages: const [],
                  autofocus: true,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final previousValue = _draft(tester).value;
        if (semantic) {
          tester.semantics.paste(find.semantics.byLabel('Chat prompt'));
        } else {
          await _clipboardShortcut(tester, LogicalKeyboardKey.keyV);
        }
        await tester.pump();
        expect(readCalls, 1);
        updateHost(() => conversationId = 'replacement');
        await tester.pump();
        expect(_draft(tester).value, previousValue);
        clipboardRead.complete(<String, Object>{
          'text': 'stale clipboard text',
        });
        await tester.pumpAndSettle();
        expect(_draft(tester).value, previousValue);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
      variant: const TargetPlatformVariant(<TargetPlatform>{
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );

    testWidgets(
      'failed $mechanism cut preserves selected draft and reports clipboard failure',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final clipboardWrite = Completer<void>();
        final failures = <BeautifulUiFailure>[];
        var writeCalls = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.hasStrings') {
              return <String, Object>{'value': true};
            }
            if (call.method == 'Clipboard.setData') {
              writeCalls++;
              await clipboardWrite.future;
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
        await tester.pumpWidget(
          _overlayApp(
            const BeautifulChat(
              conversationId: 'cut',
              initialDraft: 'protect this',
              messages: [],
              autofocus: true,
            ),
            onFailure: failures.add,
          ),
        );
        await tester.pumpAndSettle();
        await _clipboardShortcut(tester, LogicalKeyboardKey.keyA);
        await tester.pump();
        final original = _draft(tester).value;
        expect(original.selection.textInside(original.text), 'protect this');
        if (semantic) {
          tester.semantics.cut(find.semantics.byLabel('Chat prompt'));
        } else {
          await _clipboardShortcut(tester, LogicalKeyboardKey.keyX);
        }
        await tester.pump();
        expect(writeCalls, 1);
        expect(_draft(tester).value, original);
        clipboardWrite.completeError(PlatformException(code: 'denied'));
        await tester.pumpAndSettle();
        expect(_draft(tester).value, original);
        expect(failures.single.operation, BeautifulUiOperation.clipboard);
        expect(failures.single.message, contains('cut'));
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
      variant: const TargetPlatformVariant(<TargetPlatform>{
        TargetPlatform.android,
        TargetPlatform.macOS,
      }),
    );
  }

  testWidgets('touch composer menu copies cuts and pastes the selected word', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var clipboard = 'replacement';
    final sent = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, Object>{'text': clipboard};
        }
        if (call.method == 'Clipboard.hasStrings') {
          return <String, Object>{'value': clipboard.isNotEmpty};
        }
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
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
    await tester.pumpWidget(
      _overlayApp(
        BeautifulChat(
          conversationId: 'native-composer',
          messages: const [],
          initialDraft: 'alpha beta gamma',
          onSend: sent.add,
        ),
      ),
    );
    await tester.pump();
    await tester.longPressAt(_composerPoint(tester, 8));
    await tester.pumpAndSettle();
    expect(_draft(tester).selection.textInside(_draft(tester).text), 'beta');
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);
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
    expect(clipboard, 'beta');
    expect(_draft(tester).text, 'alpha beta gamma');
    await tester.longPressAt(_composerPoint(tester, 8));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cut'));
    await tester.pumpAndSettle();
    expect(clipboard, 'beta');
    expect(_draft(tester).text, 'alpha  gamma');
    clipboard = 'new phrase';
    await tester.longPressAt(_composerPoint(tester, 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(_draft(tester).text, 'new phrase  gamma');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(sent, ['new phrase  gamma']);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'touch transcript menu copies selected substring and reports clipboard failure',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var clipboard = '';
      var rejectCopy = false;
      final failures = <BeautifulUiFailure>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.hasStrings') {
            return <String, Object>{'value': clipboard.isNotEmpty};
          }
          if (call.method == 'Clipboard.setData') {
            if (rejectCopy) throw PlatformException(code: 'unavailable');
            clipboard = (call.arguments as Map)['text'] as String;
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
      await tester.pumpWidget(
        _overlayApp(
          const BeautifulChat(
            conversationId: 'native-transcript',
            messages: [
              BeautifulChatMessage(
                id: 'answer',
                role: BeautifulChatRole.assistant,
                text: 'alpha beta gamma',
              ),
            ],
          ),
          onFailure: failures.add,
        ),
      );
      await tester.pump();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('alpha beta gamma'),
          matching: find.byType(RichText),
        ),
      );
      final wordBox = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 6, extentOffset: 10),
          )
          .single;
      final point = paragraph.localToGlobal(wordBox.toRect().center);
      await tester.longPressAt(point);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(clipboard, 'beta');
      rejectCopy = true;
      await tester.longPressAt(point);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(failures.single.operation, BeautifulUiOperation.clipboard);
      expect(failures.single.cause, isA<PlatformException>());
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  test('requires conversation and active response identity', () {
    expect(
      () => BeautifulChat(conversationId: '', messages: const []),
      throwsAssertionError,
    );
    expect(
      () => BeautifulChat(
        conversationId: 'conversation',
        messages: const [],
        status: BeautifulChatStatus.responding,
      ),
      throwsAssertionError,
    );
  });

  testWidgets('renders supplied messages and context metadata only', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    expect(find.text('Compare this summer with last year'), findsOneWidget);
    expect(find.text('Sales history'), findsOneWidget);
    expect(find.text('Flavor data'), findsOneWidget);
    expect(find.text('4 seconds'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(EditableText), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('beautiful-chat-message-user-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends trimmed draft once and clears only after completion', (
    tester,
  ) async {
    final completion = Completer<void>();
    final sent = <String>[];
    await tester.pumpWidget(
      _app(
        onSend: (text) {
          sent.add(text);
          return completion.future;
        },
      ),
    );
    await tester.enterText(find.byType(EditableText), '  First\nmessage  ');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.tap(find.byKey(const ValueKey<String>('beautiful-chat-send')));
    await tester.pump();
    expect(sent, ['First\nmessage']);
    expect(_draft(tester).text, '  First\nmessage  ');
    expect(find.text('Sending…'), findsOneWidget);
    completion.complete();
    await tester.pump();
    expect(_draft(tester).text, '');
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets(
    'successful old draft does not clear edits or an edited-back draft',
    (tester) async {
      final completion = Completer<void>();
      await tester.pumpWidget(_app(onSend: (_) => completion.future));
      await tester.enterText(find.byType(EditableText), 'First');
      await tester.pump();
      await tester.tap(find.text('Send'));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'Next draft');
      await tester.enterText(find.byType(EditableText), 'First');
      completion.complete();
      await tester.pump();
      expect(_draft(tester).text, 'First');
    },
  );

  testWidgets('reports send failure and preserves the draft for retry', (
    tester,
  ) async {
    final failures = <BeautifulUiFailure>[];
    await tester.pumpWidget(
      _app(onFailure: failures.add, onSend: (_) => throw StateError('offline')),
    );
    await tester.enterText(find.byType(EditableText), 'Keep this');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(failures.single.operation, BeautifulUiOperation.chat);
    expect(failures.single.cause, isA<StateError>());
    expect(_draft(tester).text, 'Keep this');
    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets(
    'conversation replacement isolates stale send success and failure',
    (tester) async {
      for (final fails in [false, true]) {
        final completion = Completer<void>();
        final failures = <BeautifulUiFailure>[];
        late StateSetter updateHost;
        var conversation = 'original';
        await tester.pumpWidget(
          beautifulTestApp(
            disableAnimations: true,
            child: BeautifulUiScope(
              onFailure: failures.add,
              child: StatefulBuilder(
                builder: (context, setState) {
                  updateHost = setState;
                  return BeautifulChat(
                    key: ValueKey<bool>(fails),
                    conversationId: conversation,
                    messages: const [],
                    initialDraft: conversation == 'original'
                        ? 'Send old'
                        : 'New draft',
                    onSend: (_) => completion.future,
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Send'));
        await tester.pump();
        updateHost(() => conversation = 'replacement');
        await tester.pump();
        if (fails) {
          completion.completeError(StateError('stale'));
        } else {
          completion.complete();
        }
        await tester.pump();
        expect(_draft(tester).text, 'New draft');
        expect(find.text('Sending…'), findsNothing);
        expect(failures, isEmpty);
      }
    },
  );

  testWidgets('message updates preserve a pending send and input selection', (
    tester,
  ) async {
    final completion = Completer<void>();
    late StateSetter updateHost;
    var partialText = 'Partial';
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: StatefulBuilder(
          builder: (context, setState) {
            updateHost = setState;
            return BeautifulChat(
              conversationId: 'same',
              messages: [
                BeautifulChatMessage(
                  id: 'stream',
                  role: BeautifulChatRole.assistant,
                  text: partialText,
                ),
              ],
              onSend: (_) => completion.future,
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(EditableText), 'Draft');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    final controller = _draft(tester);
    controller.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    updateHost(() => partialText = 'Partial text updated');
    await tester.pump();
    expect(identical(_draft(tester), controller), isTrue);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 1, extentOffset: 3),
    );
    expect(find.text('Sending…'), findsOneWidget);
    completion.complete();
    await tester.pump();
  });

  testWidgets('Enter sends and IME composition prevents submission', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(_app(onSend: sent.add));
    await tester.enterText(find.byType(EditableText), 'Hello');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['Hello']);
    _draft(tester).value = const TextEditingValue(
      text: '你好',
      selection: TextSelection.collapsed(offset: 2),
      composing: TextRange(start: 0, end: 2),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['Hello']);
    expect(_draft(tester).text, '你好');
    _draft(tester).value = const TextEditingValue(
      text: '你好',
      selection: TextSelection.collapsed(offset: 2),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, ['Hello', '你好']);
  });

  testWidgets('Shift Enter and software newline do not submit', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_app(onSend: sent.add));
    await tester.enterText(find.byType(EditableText), 'Line one');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(sent, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.pump();
    expect(sent, isEmpty);
    expect(tester.widget<EditableText>(find.byType(EditableText)).maxLines, 3);
  });

  testWidgets(
    'tabs report controlled selection and preserve the current draft',
    (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _app(
          tabs: const [
            BeautifulChatTab(id: 'flavors', label: 'Flavors'),
            BeautifulChatTab(id: 'suppliers', label: 'Suppliers'),
          ],
          selectedTabId: 'flavors',
          onTabChanged: selected.add,
        ),
      );
      await tester.enterText(find.byType(EditableText), 'Working draft');
      await tester.tap(find.text('Suppliers'));
      await tester.pump();
      expect(selected, ['suppliers']);
      expect(_draft(tester).text, 'Working draft');
    },
  );

  testWidgets('stop de-duplicates and old response completions are isolated', (
    tester,
  ) async {
    final completion = Completer<void>();
    final stopped = <String>[];
    final failures = <BeautifulUiFailure>[];
    late StateSetter updateHost;
    var response = 'first';
    await tester.pumpWidget(
      beautifulTestApp(
        disableAnimations: true,
        child: BeautifulUiScope(
          onFailure: failures.add,
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return BeautifulChat(
                conversationId: 'same',
                messages: _messages,
                status: BeautifulChatStatus.responding,
                responseId: response,
                onStop: (id) {
                  stopped.add(id);
                  return completion.future;
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Stop response'));
    await tester.tap(find.byKey(const ValueKey<String>('beautiful-chat-stop')));
    await tester.pump();
    expect(stopped, ['first']);
    expect(find.text('Stopping…'), findsOneWidget);
    updateHost(() => response = 'second');
    await tester.pump();
    expect(find.text('Stop response'), findsOneWidget);
    completion.completeError(StateError('old response failed'));
    await tester.pump();
    expect(failures, isEmpty);
    expect(find.text('Stop response'), findsOneWidget);
  });

  testWidgets(
    'stop failure reports the active response and preserves host status',
    (tester) async {
      final failures = <BeautifulUiFailure>[];
      await tester.pumpWidget(
        _app(
          status: BeautifulChatStatus.responding,
          responseId: 'active',
          onFailure: failures.add,
          onStop: (_) => throw StateError('cannot stop'),
        ),
      );
      await tester.tap(find.text('Stop response'));
      await tester.pump();
      expect(failures.single.message, contains('active'));
      expect(find.text('Responding…'), findsOneWidget);
      expect(find.text('Stop response'), findsOneWidget);
    },
  );

  testWidgets(
    'reader scroll remains stable on append and latest reveals new messages',
    (tester) async {
      late StateSetter updateHost;
      var count = 30;
      await tester.pumpWidget(
        beautifulTestApp(
          disableAnimations: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return BeautifulChat(
                conversationId: 'long',
                messages: _longMessages(count),
                onSend: (_) {},
              );
            },
          ),
        ),
      );
      await tester.pump();
      final transcript = find.byKey(
        const ValueKey<String>('beautiful-chat-transcript'),
      );
      final controller = tester
          .widget<SingleChildScrollView>(transcript)
          .controller!;
      expect(controller.position.extentAfter, 0);
      await tester.drag(transcript, const Offset(0, 350));
      await tester.pumpAndSettle();
      final readingOffset = controller.offset;
      expect(controller.position.extentAfter, greaterThan(32));
      expect(find.text('Scroll to latest'), findsOneWidget);
      updateHost(() => count = 31);
      await tester.pump();
      await tester.pump();
      expect(controller.offset, readingOffset);
      await tester.tap(find.text('Scroll to latest'));
      await tester.pump();
      expect(controller.position.extentAfter, 0);
      expect(find.text('Scroll to latest'), findsNothing);
    },
  );

  testWidgets(
    'draft focus selection and read position survive resize and keyboard',
    (tester) async {
      late StateSetter updateHost;
      var size = const Size(599, 760);
      var keyboard = 0.0;
      await tester.pumpWidget(
        beautifulTestApp(
          size: const Size(1100, 900),
          disableAnimations: true,
          child: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: size,
                  viewInsets: EdgeInsets.only(bottom: keyboard),
                ),
                child: SizedBox(
                  width: size.width,
                  height: size.height - keyboard,
                  child: BeautifulChat(
                    conversationId: 'same',
                    messages: _longMessages(30),
                    onSend: (_) {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'Keep my selection');
      _draft(tester).selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 6,
      );
      final focus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      final transcript = find.byKey(
        const ValueKey<String>('beautiful-chat-transcript'),
      );
      final controller = tester
          .widget<SingleChildScrollView>(transcript)
          .controller!;
      await tester.drag(transcript, const Offset(0, 250));
      await tester.pumpAndSettle();
      final offset = controller.offset;
      updateHost(() {
        size = const Size(1024, 760);
        keyboard = 360;
      });
      await tester.pump();
      await tester.pump();
      expect(_draft(tester).text, 'Keep my selection');
      expect(
        _draft(tester).selection,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      expect(focus.hasFocus, isTrue);
      expect(controller.offset, offset);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey<String>('beautiful-chat-surface')),
            )
            .height,
        400,
      );
      updateHost(() => keyboard = 520);
      await tester.pump();
      await tester.pump();
      expect(_draft(tester).text, 'Keep my selection');
      expect(
        _draft(tester).selection,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      expect(focus.hasFocus, isTrue);
      expect(controller.offset, offset);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all boundaries and short RTL 200 percent keyboard viewport fit',
    (tester) async {
      for (final width in <double>[280, 599, 600, 1023, 1024]) {
        await tester.pumpWidget(
          beautifulTestApp(
            size: Size(width, 800),
            textScaler: const TextScaler.linear(2),
            textDirection: TextDirection.rtl,
            highContrast: true,
            brightness: Brightness.dark,
            disableAnimations: true,
            child: BeautifulChat(
              key: ValueKey<double>(width),
              conversationId: 'arabic',
              height: 260,
              messages: const [
                BeautifulChatMessage(
                  id: 'arabic',
                  role: BeautifulChatRole.assistant,
                  text: 'مقارنة المبيعات خلال الصيف الماضي مع النتائج الحالية',
                  title: 'مصادر النتائج',
                  subtitle: 'معلومات مفصلة وطويلة',
                  isResolving: true,
                ),
              ],
              tabs: const [
                BeautifulChatTab(id: 'arabic', label: 'السياق والنتائج'),
              ],
              selectedTabId: 'arabic',
              onTabChanged: (_) {},
              initialDraft: 'مسودة متعددة الأسطر\nالسطر الثاني\nالسطر الثالث',
              sendLabel: 'إرسال الرسالة الآن',
              onSend: (_) {},
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width $width');
        expect(
          find.byKey(const ValueKey<String>('beautiful-chat-viewport')),
          findsOneWidget,
        );
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey<String>('beautiful-chat-send')),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
      }
    },
  );

  testWidgets('late failures after disposal are ignored', (tester) async {
    final completion = Completer<void>();
    final failures = <BeautifulUiFailure>[];
    await tester.pumpWidget(
      _app(onSend: (_) => completion.future, onFailure: failures.add),
    );
    await tester.enterText(find.byType(EditableText), 'Send before leaving');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    completion.completeError(StateError('late'));
    await tester.pump();
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

TextEditingController _draft(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller;

Offset _composerPoint(WidgetTester tester, int offset) {
  final editor = tester.state<EditableTextState>(find.byType(EditableText));
  final caret = editor.renderEditable.getLocalRectForCaret(
    TextPosition(offset: offset),
  );
  return editor.renderEditable.localToGlobal(caret.center);
}

Future<void> _clipboardShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  final modifier = defaultTargetPlatform == TargetPlatform.macOS
      ? LogicalKeyboardKey.metaLeft
      : LogicalKeyboardKey.controlLeft;
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
}

Widget _overlayApp(Widget child, {BeautifulUiFailureHandler? onFailure}) =>
    WidgetsApp(
      color: const Color(0xffffffff),
      builder: (context, _) => Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => BeautifulUiScope(
              onFailure: onFailure,
              motion: BeautifulMotionPolicy.none,
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ],
      ),
    );

List<BeautifulChatMessage> _longMessages(int count) => List.generate(
  count,
  (index) => BeautifulChatMessage(
    id: 'message-$index',
    role: BeautifulChatRole.assistant,
    text: 'Message $index with enough content for a scrollable conversation.',
  ),
);

Widget _app({
  FutureOr<void> Function(String)? onSend,
  FutureOr<void> Function(String)? onStop,
  BeautifulChatStatus status = BeautifulChatStatus.idle,
  String? responseId,
  BeautifulUiFailureHandler? onFailure,
  List<BeautifulChatTab> tabs = const [],
  String? selectedTabId,
  ValueChanged<String>? onTabChanged,
}) => beautifulTestApp(
  disableAnimations: true,
  child: BeautifulUiScope(
    onFailure: onFailure,
    child: BeautifulChat(
      conversationId: 'summer',
      messages: _messages,
      onSend: onSend ?? (_) {},
      onStop: onStop,
      status: status,
      responseId: responseId,
      tabs: tabs,
      selectedTabId: selectedTabId,
      onTabChanged: onTabChanged,
    ),
  ),
);
