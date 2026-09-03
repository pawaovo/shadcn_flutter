import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart' as harness;

Widget _approvalApp({
  required Widget child,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  bool highContrast = false,
  TextScaler textScaler = TextScaler.noScaling,
  TextDirection textDirection = TextDirection.ltr,
}) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, _) => Overlay.wrap(
    child: harness.beautifulTestApp(
      child: child,
      size: size,
      brightness: brightness,
      disableAnimations: disableAnimations,
      highContrast: highContrast,
      textScaler: textScaler,
      textDirection: textDirection,
    ),
  ),
);

List<BeautifulApprovalQuestion> _questions() => <BeautifulApprovalQuestion>[
  BeautifulApprovalQuestion(
    id: 'flavors',
    title: 'How many flavors?',
    options: const <BeautifulApprovalOption>[
      BeautifulApprovalOption(id: 'three', label: 'Three flavors'),
      BeautifulApprovalOption(id: 'five', label: 'Five flavors'),
    ],
  ),
  BeautifulApprovalQuestion(
    id: 'mix',
    title: 'Which mix-ins?',
    type: BeautifulApprovalQuestionType.multipleChoice,
    options: const <BeautifulApprovalOption>[
      BeautifulApprovalOption(id: 'chips', label: 'Chocolate chips'),
      BeautifulApprovalOption(id: 'waffles', label: 'Waffle bits'),
    ],
  ),
  BeautifulApprovalQuestion(
    id: 'market',
    title: 'Which market?',
    options: const <BeautifulApprovalOption>[
      BeautifulApprovalOption(id: 'shops', label: 'Scoop shops'),
      BeautifulApprovalOption(id: 'trucks', label: 'Food trucks'),
    ],
  ),
];

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.pump();
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  test('validates identities and freezes every caller-owned list', () {
    final options = <BeautifulApprovalOption>[
      const BeautifulApprovalOption(id: 'one', label: 'One'),
    ];
    final question = BeautifulApprovalQuestion(
      id: 'q',
      title: 'Question',
      options: options,
    );
    final questions = <BeautifulApprovalQuestion>[question];
    final optionIds = <String>['one'];
    final answer = BeautifulApprovalAnswer(
      questionId: 'q',
      optionIds: optionIds,
    );
    final answers = <BeautifulApprovalAnswer>[answer];
    final card = BeautifulApprovalCard(
      id: 'a',
      questions: questions,
      initialAnswers: answers,
      onSubmit: (_) {},
    );
    options.clear();
    questions.clear();
    answers.clear();
    optionIds.clear();
    expect(question.options.single.label, 'One');
    expect(card.questions.single.id, 'q');
    expect(card.initialAnswers.single.optionIds, <String>['one']);
    expect(() => question.options.clear(), throwsUnsupportedError);
    expect(() => card.questions.clear(), throwsUnsupportedError);
    expect(() => answer.optionIds.clear(), throwsUnsupportedError);
    expect(
      () => BeautifulApprovalCard(id: 'a', questions: [], onSubmit: (_) {}),
      throwsAssertionError,
    );
    expect(
      () => BeautifulApprovalCard(
        id: 'a',
        questions: [question, question],
        onSubmit: (_) {},
      ),
      throwsAssertionError,
    );
    expect(
      () => BeautifulApprovalCard(
        id: 'a',
        questions: [question],
        initialAnswers: [BeautifulApprovalAnswer(questionId: 'missing')],
        onSubmit: (_) {},
      ),
      throwsAssertionError,
    );
  });

  testWidgets(
    'radio advances, multiple choice waits, all custom text submits',
    (tester) async {
      List<BeautifulApprovalAnswer>? submitted;
      final changes = <BeautifulApprovalAnswer>[];
      await tester.pumpWidget(
        _approvalApp(
          disableAnimations: true,
          child: BeautifulApprovalCard(
            id: 'launch',
            questions: _questions(),
            onSubmit: (answers) => submitted = answers,
            onAnswerChanged: changes.add,
          ),
        ),
      );
      await _tap(tester, 'Three flavors');
      expect(find.text('Which mix-ins?'), findsOneWidget);
      expect(find.text('How many flavors?'), findsNothing);
      await _tap(tester, 'Chocolate chips');
      await _tap(tester, 'Waffle bits');
      await _tap(tester, 'Chocolate chips');
      expect(find.text('Which mix-ins?'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '  Seasonal fruit  ');
      await _tap(tester, 'Continue');
      await tester.enterText(find.byType(EditableText), 'Online subscriptions');
      await _tap(tester, 'Send');
      expect(submitted, hasLength(3));
      expect(submitted![0].optionIds, <String>['three']);
      expect(submitted![1].optionIds, <String>['waffles']);
      expect(submitted![1].customText, '  Seasonal fruit  ');
      expect(submitted![2].optionIds, isEmpty);
      expect(submitted![2].customText, 'Online subscriptions');
      expect(() => submitted!.clear(), throwsUnsupportedError);
      expect(changes.last.customText, 'Online subscriptions');
      expect(find.text('Answers sent'), findsOneWidget);
      await _tap(tester, 'Start over');
      expect(find.text('How many flavors?'), findsOneWidget);
      expect(changes.takeLast(3).every((answer) => !answer.hasAnswer), isTrue);
    },
  );

  testWidgets('final radio submits its current selection exactly once', (
    tester,
  ) async {
    final completion = Completer<void>();
    var submissions = 0;
    List<BeautifulApprovalAnswer>? submitted;
    await tester.pumpWidget(
      _approvalApp(
        disableAnimations: true,
        child: BeautifulApprovalCard(
          id: 'launch',
          questions: [_questions().last],
          onSubmit: (answers) {
            submissions++;
            submitted = answers;
            return completion.future;
          },
        ),
      ),
    );
    await _tap(tester, 'Scoop shops');
    await _tap(tester, 'Food trucks');
    await _tap(tester, 'Sending…');
    expect(submissions, 1);
    expect(submitted!.single.optionIds, <String>['shops']);
    expect(find.text('Answers sent'), findsNothing);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Answers sent'), findsOneWidget);
  });

  testWidgets('restored selections submit in question presentation order', (
    tester,
  ) async {
    List<BeautifulApprovalAnswer>? submitted;
    await tester.pumpWidget(
      _approvalApp(
        disableAnimations: true,
        child: BeautifulApprovalCard(
          id: 'restored',
          questions: [_questions()[1]],
          initialAnswers: [
            BeautifulApprovalAnswer(
              questionId: 'mix',
              optionIds: ['waffles', 'chips'],
            ),
          ],
          onSubmit: (answers) => submitted = answers,
        ),
      ),
    );
    await _tap(tester, 'Send');
    expect(submitted!.single.optionIds, <String>['chips', 'waffles']);
  });

  testWidgets('advancing from a long question reveals the next heading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 340));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _approvalApp(
        size: const Size(390, 340),
        disableAnimations: true,
        child: BeautifulApprovalCard(
          id: 'long-questions',
          autoAdvance: false,
          questions: [
            for (final id in ['First', 'Second'])
              BeautifulApprovalQuestion(
                id: id,
                title: '$id long question',
                options: [
                  for (var index = 0; index < 8; index++)
                    BeautifulApprovalOption(
                      id: '$index',
                      label: 'Option $index',
                    ),
                ],
              ),
          ],
          onSubmit: (_) {},
        ),
      ),
    );
    await _tap(tester, 'Option 0');
    await _tap(tester, 'Continue');
    expect(find.text('First long question'), findsNothing);
    final heading = tester.getTopLeft(find.text('Second long question'));
    expect(heading.dy, inInclusiveRange(0, 60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom replaces radio, navigation and dismissal retain drafts', (
    tester,
  ) async {
    final changes = <BeautifulApprovalAnswer>[];
    await tester.pumpWidget(
      _approvalApp(
        disableAnimations: true,
        child: BeautifulApprovalCard(
          id: 'launch',
          questions: _questions(),
          autoAdvance: false,
          onAnswerChanged: changes.add,
          onSubmit: (_) {},
        ),
      ),
    );
    await _tap(tester, 'Three flavors');
    await tester.enterText(find.byType(EditableText), 'A seasonal range');
    expect(changes.last.optionIds, isEmpty);
    await tester.tap(find.bySemanticsLabel('Next question'));
    await tester.pump();
    await _tap(tester, 'Waffle bits');
    await tester.tap(find.bySemanticsLabel('Previous question'));
    await tester.pump();
    expect(find.text('A seasonal range'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Dismiss'));
    await tester.pump();
    expect(find.text('How many flavors?'), findsNothing);
    await _tap(tester, 'Open approval');
    expect(find.text('A seasonal range'), findsOneWidget);
    await _tap(tester, 'Five flavors');
    expect(changes.last.customText, isEmpty);
    expect(find.text('A seasonal range'), findsNothing);
    await _tap(tester, 'Skip');
    await _tap(tester, 'Skip');
    await _tap(tester, 'Skip');
    expect(find.text('Open approval'), findsOneWidget);
    expect(find.text('Answers sent'), findsNothing);
  });

  testWidgets('pending failure preserves answer and retry can succeed', (
    tester,
  ) async {
    final failures = <BeautifulUiFailure>[];
    var fail = true;
    await tester.pumpWidget(
      _approvalApp(
        disableAnimations: true,
        child: BeautifulUiScope(
          onFailure: failures.add,
          child: BeautifulApprovalCard(
            id: 'launch',
            questions: [_questions().last],
            autoAdvance: false,
            errorMessage: 'Please review your answer and retry.',
            onSubmit: (_) async {
              if (fail) throw StateError('network unavailable');
            },
          ),
        ),
      ),
    );
    await _tap(tester, 'Scoop shops');
    await _tap(tester, 'Send');
    expect(failures.single.operation, BeautifulUiOperation.approval);
    expect(failures.single.cause, isA<StateError>());
    expect(find.text('Please review your answer and retry.'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    fail = false;
    await _tap(tester, 'Send');
    expect(find.text('Answers sent'), findsOneWidget);
  });

  for (final oldFails in <bool>[false, true]) {
    testWidgets(
      'ignores stale ${oldFails ? 'failure' : 'success'} on replacement',
      (tester) async {
        final oldCompletion = Completer<void>();
        final failures = <BeautifulUiFailure>[];
        Widget app(String title) => _approvalApp(
          disableAnimations: true,
          child: BeautifulUiScope(
            onFailure: failures.add,
            child: BeautifulApprovalCard(
              id: 'approval',
              questions: [
                BeautifulApprovalQuestion(
                  id: 'q',
                  title: title,
                  options: const [
                    BeautifulApprovalOption(id: 'yes', label: 'Yes'),
                  ],
                ),
              ],
              onSubmit: (_) => oldCompletion.future,
            ),
          ),
        );
        await tester.pumpWidget(app('Original approval'));
        await _tap(tester, 'Yes');
        expect(find.text('Sending…'), findsOneWidget);
        await tester.pumpWidget(app('Replacement approval'));
        if (oldFails) {
          oldCompletion.completeError(StateError('obsolete failure'));
        } else {
          oldCompletion.complete();
        }
        await tester.pump();
        expect(find.text('Replacement approval'), findsOneWidget);
        expect(find.text('Answers sent'), findsNothing);
        expect(find.text('Sending…'), findsNothing);
        expect(failures, isEmpty);
      },
    );
  }

  testWidgets('question reordering preserves identity; new approval reseeds', (
    tester,
  ) async {
    var id = 'launch';
    var questions = _questions();
    Widget app() => _approvalApp(
      disableAnimations: true,
      child: BeautifulApprovalCard(
        id: id,
        questions: questions,
        initialAnswers: [
          BeautifulApprovalAnswer(questionId: 'flavors', customText: 'Seed'),
        ],
        autoAdvance: false,
        onSubmit: (_) {},
      ),
    );
    await tester.pumpWidget(app());
    await tester.enterText(find.byType(EditableText), 'Edited draft');
    questions = questions.reversed.toList();
    await tester.pumpWidget(app());
    expect(find.text('How many flavors?'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Edited draft'), findsOneWidget);
    id = 'new-launch';
    await tester.pumpWidget(app());
    expect(find.text('Which market?'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Next question'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Next question'));
    await tester.pump();
    expect(find.text('Seed'), findsOneWidget);
  });

  testWidgets('keyboard options, custom submission, and Escape work', (
    tester,
  ) async {
    List<BeautifulApprovalAnswer>? submitted;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xffffffff),
        builder: (context, child) => _approvalApp(
          disableAnimations: true,
          child: BeautifulApprovalCard(
            id: 'launch',
            questions: [_questions().last],
            autoAdvance: false,
            onSubmit: (answers) => submitted = answers,
          ),
        ),
      ),
    );
    await tester.showKeyboard(find.byType(EditableText));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // Last option
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // First option
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    final selected = tester.getSemantics(find.bySemanticsLabel('Scoop shops'));
    expect(
      selected.getSemanticsData().flagsCollection.isChecked.name,
      'isTrue',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Open approval'), findsOneWidget);
    await _tap(tester, 'Open approval');
    await tester.enterText(find.byType(EditableText), 'Online');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(submitted!.single.customText, 'Online');
  });

  testWidgets('IME composing Enter does not submit an unfinished answer', (
    tester,
  ) async {
    var submissions = 0;
    await tester.pumpWidget(
      _approvalApp(
        disableAnimations: true,
        child: BeautifulApprovalCard(
          id: 'launch',
          questions: [_questions().last],
          onSubmit: (_) => submissions++,
        ),
      ),
    );
    await tester.showKeyboard(find.byType(EditableText));
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '测试',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(submissions, 0);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(submissions, 0);
    expect(find.text('Which market?'), findsOneWidget);
  });

  testWidgets(
    'touch selection exposes native editing actions and pastes a draft',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var clipboard = 'Pasted answer';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          switch (call.method) {
            case 'Clipboard.hasStrings':
              return <String, bool>{'value': clipboard.isNotEmpty};
            case 'Clipboard.getData':
              return <String, String>{'text': clipboard};
            case 'Clipboard.setData':
              clipboard =
                  (call.arguments as Map<Object?, Object?>)['text']! as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      List<BeautifulApprovalAnswer>? submitted;
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xffffffff),
          builder: (context, child) => Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) => _approvalApp(
                  disableAnimations: true,
                  child: BeautifulApprovalCard(
                    id: 'native-editing',
                    questions: [_questions().last],
                    initialAnswers: [
                      BeautifulApprovalAnswer(
                        questionId: 'market',
                        customText: 'Keep this draft',
                      ),
                    ],
                    onSubmit: (answers) => submitted = answers,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      final field = find.byType(EditableText);
      await tester.longPressAt(tester.getTopLeft(field) + const Offset(12, 10));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Cut'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      final fieldSemantics = tester
          .getSemantics(find.bySemanticsLabel('Custom answer'))
          .getSemanticsData();
      expect(fieldSemantics.hasAction(SemanticsAction.copy), isTrue);
      expect(fieldSemantics.hasAction(SemanticsAction.cut), isTrue);
      expect(fieldSemantics.hasAction(SemanticsAction.paste), isTrue);
      await tester.tap(find.text('Paste'));
      await tester.pump();
      await tester.pump();
      await _tap(tester, 'Send');
      expect(submitted!.single.customText, 'Pasted answer this draft');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  for (final topPadding in <bool>[true, false]) {
    testWidgets(
      'empty answer ${topPadding ? 'top' : 'bottom'} padding opens Paste on long press',
      (tester) async {
        final semantics = tester.ensureSemantics();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => switch (call.method) {
            'Clipboard.hasStrings' => <String, bool>{'value': true},
            'Clipboard.getData' => <String, String>{
              'text': 'Pasted from padding',
            },
            _ => null,
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        List<BeautifulApprovalAnswer>? submitted;
        await tester.pumpWidget(
          _approvalApp(
            disableAnimations: true,
            child: BeautifulApprovalCard(
              id: 'padding-editing',
              questions: [_questions().last],
              onSubmit: (answers) => submitted = answers,
            ),
          ),
        );
        final target = tester.getRect(find.bySemanticsLabel('Custom answer'));
        final editor = tester.getRect(find.byType(EditableText));
        final point = Offset(
          target.center.dx,
          topPadding ? target.top + 4 : target.bottom - 4,
        );
        expect(target.contains(point), isTrue);
        expect(editor.contains(point), isFalse);
        await tester.longPressAt(point);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.text('Paste'), findsOneWidget);
        await tester.tap(find.text('Paste'));
        await tester.pump();
        await tester.pump();
        await _tap(tester, 'Send');
        expect(submitted!.single.customText, 'Pasted from padding');
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  for (final viaSemantics in <bool>[false, true]) {
    testWidgets(
      'ignores delayed ${viaSemantics ? 'semantic' : 'keyboard'} paste after approval replacement',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final clipboard = Completer<Object?>();
        var reads = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.hasStrings') {
              return <String, bool>{'value': true};
            }
            if (call.method == 'Clipboard.getData') {
              reads++;
              return clipboard.future;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });
        final changes = <BeautifulApprovalAnswer>[];
        Widget app(String id) => _approvalApp(
          disableAnimations: true,
          child: BeautifulApprovalCard(
            id: id,
            questions: [_questions().last],
            onAnswerChanged: changes.add,
            onSubmit: (_) {},
          ),
        );
        await tester.pumpWidget(app('original'));
        await tester.showKeyboard(find.byType(EditableText));
        await tester.pump();
        if (viaSemantics) {
          final node = tester.getSemantics(
            find.bySemanticsLabel('Custom answer'),
          );
          node.owner!.performAction(node.id, SemanticsAction.paste);
        } else {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        }
        await tester.pump();
        expect(reads, 1);
        await tester.pumpWidget(app('replacement'));
        clipboard.complete(<String, String>{'text': 'Delayed clipboard'});
        await tester.pump();
        await tester.pump();
        expect(changes, isEmpty);
        expect(find.text('Delayed clipboard'), findsNothing);
        expect(find.text('Something else…'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }

  testWidgets('200% RTL long content resizes and scrolls around keyboard', (
    tester,
  ) async {
    const longLabel = '审批选项 نص عربي طويل A long localized answer for review';
    final question = BeautifulApprovalQuestion(
      id: 'long',
      title: '请确认最终发布计划 ومراجعة تفاصيل الخطة بالكامل before continuing',
      options: const [BeautifulApprovalOption(id: 'one', label: longLabel)],
      type: BeautifulApprovalQuestionType.multipleChoice,
    );
    List<BeautifulApprovalAnswer>? submitted;
    for (final width in <double>[320, 599, 600, 1023, 1024]) {
      await tester.binding.setSurfaceSize(Size(width, 650));
      await tester.pumpWidget(
        _approvalApp(
          size: Size(width, 650),
          disableAnimations: true,
          highContrast: true,
          brightness: Brightness.dark,
          textScaler: TextScaler.linear(2),
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 650),
              textScaler: TextScaler.linear(2),
              viewInsets: const EdgeInsets.only(bottom: 200),
              padding: const EdgeInsets.only(top: 24, bottom: 20),
              disableAnimations: true,
            ),
            child: BeautifulApprovalCard(
              id: 'long',
              questions: [question],
              onSubmit: (answers) => submitted = answers,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (width == 320) {
        await _tap(tester, longLabel);
        await tester.ensureVisible(find.byType(EditableText));
        await tester.enterText(find.byType(EditableText), '保留草稿');
      }
      expect(find.text('保留草稿'), findsOneWidget);
    }
    await _tap(tester, 'Send');
    expect(submitted!.single.optionIds, <String>['one']);
    expect(submitted!.single.customText, '保留草稿');
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}

extension<T> on List<T> {
  Iterable<T> takeLast(int count) => skip(length - count);
}
