import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_harness.dart';

const _sources = [
  BeautifulStreamingSource(id: 'guide', title: 'Guide', detail: 'guide.md'),
  BeautifulStreamingSource(id: 'notes', title: 'Notes', detail: 'notes.md'),
];
const _followUps = [
  BeautifulStreamingFollowUp(id: 'example', label: 'Show an example'),
];

Finder get _answerText => find.descendant(
  of: find.byType(BeautifulStreamingText),
  matching: find.byWidgetPredicate(
    (widget) => widget is Text && widget.textSpan != null,
  ),
);

String _renderedAnswer(WidgetTester tester) => tester
    .widget<Text>(_answerText)
    .textSpan!
    .toPlainText(includeSemanticsLabels: false);

BeautifulStreamingText _answer({
  String id = 'answer-1',
  BeautifulStreamingStatus status = BeautifulStreamingStatus.complete,
  Iterable<BeautifulStreamingPart> content = const [
    BeautifulStreamingPart.text('The received answer.'),
  ],
  Iterable<BeautifulStreamingSource> sources = const [],
  Iterable<BeautifulStreamingFollowUp> followUps = const [],
  FutureOr<void> Function(String)? onCopy,
  FutureOr<void> Function()? onRetry,
  ValueChanged<BeautifulStreamingSource>? onSourcePressed,
  ValueChanged<BeautifulStreamingFollowUp>? onFollowUp,
  ValueChanged<BeautifulStreamingFeedback>? onFeedback,
  String? errorMessage,
}) => BeautifulStreamingText(
  id: id,
  status: status,
  content: content,
  sources: sources,
  followUps: followUps,
  onCopy: onCopy,
  onRetry: onRetry,
  onSourcePressed: onSourcePressed,
  onFollowUp: onFollowUp,
  onFeedback: onFeedback,
  errorMessage: errorMessage,
);

Widget _failureApp({
  required Widget child,
  required BeautifulUiFailureHandler onFailure,
}) => MediaQuery(
  data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: BeautifulUiScope(
      onFailure: onFailure,
      child: SizedBox(
        width: 390,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

Widget _selectionApp(Widget child) => WidgetsApp(
  color: const Color(0xffffffff),
  builder: (context, route) => BeautifulUiScope(child: route!),
  onGenerateRoute: (settings) => PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 390, child: child),
    ),
  ),
);

void main() {
  test('validates identities and citation references at construction', () {
    expect(() => _answer(id: '  '), throwsArgumentError);
    expect(
      () => _answer(
        sources: const [BeautifulStreamingSource(id: '', title: 'Guide')],
      ),
      throwsArgumentError,
    );
    expect(
      () => _answer(
        sources: const [BeautifulStreamingSource(id: 'guide', title: '  ')],
      ),
      throwsArgumentError,
    );
    expect(
      () => _answer(sources: [_sources.first, _sources.first]),
      throwsArgumentError,
    );
    expect(
      () =>
          _answer(content: const [BeautifulStreamingPart.citation('missing')]),
      throwsArgumentError,
    );
    expect(
      () => _answer(
        followUps: const [BeautifulStreamingFollowUp(id: '', label: 'More')],
      ),
      throwsArgumentError,
    );
    expect(
      () => _answer(
        followUps: const [BeautifulStreamingFollowUp(id: 'more', label: '  ')],
      ),
      throwsArgumentError,
    );
    expect(
      () => _answer(followUps: [_followUps.first, _followUps.first]),
      throwsArgumentError,
    );
  });

  test('snapshots defensively copy and expose immutable collections', () {
    final content = [const BeautifulStreamingPart.text('Original')];
    final sources = [..._sources];
    final followUps = [..._followUps];
    final answer = _answer(
      content: content,
      sources: sources,
      followUps: followUps,
    );
    content.clear();
    sources.clear();
    followUps.clear();

    expect(answer.content.single.text, 'Original');
    expect(answer.sources, hasLength(2));
    expect(answer.followUps.single.id, 'example');
    expect(answer.content.clear, throwsUnsupportedError);
    expect(answer.sources.clear, throwsUnsupportedError);
    expect(answer.followUps.clear, throwsUnsupportedError);
  });

  testWidgets('renders exact Unicode chunks immediately without token timers', (
    tester,
  ) async {
    const first = '  你好，世界！\n👩🏽‍💻 e\u0301';
    const second = '\t零空格连接。\n';
    await tester.pumpWidget(
      beautifulTestApp(
        child: _answer(
          status: BeautifulStreamingStatus.streaming,
          content: const [BeautifulStreamingPart.text(first)],
        ),
      ),
    );
    expect(_renderedAnswer(tester), first);
    await tester.pumpWidget(
      beautifulTestApp(
        child: _answer(
          status: BeautifulStreamingStatus.streaming,
          content: const [
            BeautifulStreamingPart.text(first),
            BeautifulStreamingPart.text(second),
          ],
        ),
      ),
    );
    expect(_renderedAnswer(tester), '$first$second');
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides completion actions and follow-ups while streaming', (
    tester,
  ) async {
    await tester.pumpWidget(
      beautifulTestApp(
        child: _answer(
          status: BeautifulStreamingStatus.streaming,
          sources: _sources,
          followUps: _followUps,
          onRetry: () {},
          onFeedback: (_) {},
          onSourcePressed: (_) {},
          onFollowUp: (_) {},
          errorMessage: 'Old failure must disappear',
        ),
      ),
    );
    expect(find.text('Generating answer'), findsOneWidget);
    for (final label in [
      'Copy answer',
      'Retry answer',
      'Helpful answer',
      'Unhelpful answer',
      'Sources (2)',
      'Show an example',
      'Old failure must disappear',
    ]) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('citations use stable source IDs after source list reordering', (
    tester,
  ) async {
    final opened = <String>[];
    final copied = <String>[];
    const content = [
      BeautifulStreamingPart.text('See '),
      BeautifulStreamingPart.citation('notes'),
      BeautifulStreamingPart.text(' then '),
      BeautifulStreamingPart.citation('guide'),
      BeautifulStreamingPart.text('.'),
    ];
    Widget app(List<BeautifulStreamingSource> sources) => beautifulTestApp(
      child: _answer(
        content: content,
        sources: sources,
        onSourcePressed: (source) => opened.add(source.id),
        onCopy: copied.add,
      ),
    );

    await tester.pumpWidget(app(_sources));
    expect(_renderedAnswer(tester), 'See [2] then [1].');
    await tester.tap(find.text('Sources (2)'));
    await tester.pump();
    await tester.tap(find.text('[2] Notes · notes.md'));
    expect(opened, ['notes']);

    await tester.pumpWidget(app(_sources.reversed.toList()));
    expect(_renderedAnswer(tester), 'See [1] then [2].');
    await tester.tap(find.text('[2] Guide · guide.md'));
    await tester.tap(find.text('Copy answer'));
    await tester.pump();
    expect(opened, ['notes', 'guide']);
    expect(copied, ['See [1] then [2].']);
  });

  testWidgets('source disclosure survives same answer updates and resizing', (
    tester,
  ) async {
    Widget app(String id, double width, String body) => beautifulTestApp(
      size: Size(width, 800),
      child: SingleChildScrollView(
        child: _answer(
          id: id,
          content: [BeautifulStreamingPart.text(body)],
          sources: _sources,
        ),
      ),
    );
    await tester.pumpWidget(app('answer-1', 390, 'Initial text'));
    expect(find.text('[1] Guide · guide.md'), findsNothing);
    await tester.tap(find.text('Sources (2)'));
    await tester.pump();
    for (final width in [599.0, 600.0, 1023.0, 1024.0]) {
      await tester.pumpWidget(app('answer-1', width, 'Updated text at $width'));
      expect(find.text('[1] Guide · guide.md'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(app('answer-2', 390, 'New generation'));
    expect(find.text('[1] Guide · guide.md'), findsNothing);
  });

  testWidgets('failed answer retains partial text and deduplicates retry', (
    tester,
  ) async {
    var retries = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(
      beautifulTestApp(
        child: _answer(
          status: BeautifulStreamingStatus.failed,
          content: const [BeautifulStreamingPart.text('Partial answer…')],
          followUps: _followUps,
          errorMessage: 'Connection interrupted. Try again.',
          onRetry: () {
            retries++;
            return pending.future;
          },
          onFeedback: (_) {},
        ),
      ),
    );
    expect(_renderedAnswer(tester), 'Partial answer…');
    expect(find.text('Answer interrupted'), findsOneWidget);
    expect(find.text('Connection interrupted. Try again.'), findsOneWidget);
    expect(find.text('Copy answer'), findsOneWidget);
    expect(find.text('Show an example'), findsNothing);
    expect(find.text('Helpful answer'), findsNothing);
    await tester.tap(find.text('Retry answer'));
    await tester.pump();
    await tester.tap(find.text('Retrying answer'));
    await tester.pump();
    expect(retries, 1);
    pending.complete();
    await tester.pump();
    expect(find.text('Retry answer'), findsOneWidget);
  });

  testWidgets('completion actions return the selected follow-up and feedback', (
    tester,
  ) async {
    final followUps = <BeautifulStreamingFollowUp>[];
    final feedback = <BeautifulStreamingFeedback>[];
    await tester.pumpWidget(
      beautifulTestApp(
        child: _answer(
          followUps: _followUps,
          onFollowUp: followUps.add,
          onFeedback: feedback.add,
        ),
      ),
    );
    await tester.tap(find.text('Show an example'));
    await tester.tap(find.text('Unhelpful answer'));
    expect(followUps.single, same(_followUps.single));
    expect(feedback, [BeautifulStreamingFeedback.negative]);
  });

  testWidgets('uses system clipboard with exact completed text', (
    tester,
  ) async {
    MethodCall? clipboardCall;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') clipboardCall = call;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    const text = '你好 👩🏽‍💻\n  preserve whitespace\t';
    await tester.pumpWidget(
      beautifulTestApp(
        child: _answer(content: const [BeautifulStreamingPart.text(text)]),
      ),
    );
    await tester.tap(find.text('Copy answer'));
    await tester.pump();
    expect(clipboardCall?.arguments, {'text': text});
    expect(find.text('Answer copied'), findsOneWidget);
  });

  testWidgets(
    'deduplicates pending copies and keeps unchanged snapshot state',
    (tester) async {
      final pending = Completer<void>();
      final copied = <String>[];
      Widget app() => beautifulTestApp(
        child: _answer(
          content: [const BeautifulStreamingPart.text('Same snapshot')],
          onCopy: (text) {
            copied.add(text);
            return pending.future;
          },
        ),
      );
      await tester.pumpWidget(app());
      await tester.tap(find.text('Copy answer'));
      await tester.pump();
      await tester.pumpWidget(app());
      expect(find.text('Copying answer'), findsOneWidget);
      await tester.tap(find.text('Copying answer'));
      await tester.pump();
      expect(copied, ['Same snapshot']);
      pending.complete();
      await tester.pump();
      await tester.pumpWidget(app());
      expect(find.text('Answer copied'), findsOneWidget);
    },
  );

  for (final replaceId in [false, true]) {
    testWidgets(
      'ignores a stale copy failure after ${replaceId ? 'generation' : 'content'} changes',
      (tester) async {
        final pending = Completer<void>();
        final failures = <BeautifulUiFailure>[];
        Widget app(String id, String text) => _failureApp(
          onFailure: failures.add,
          child: _answer(
            id: id,
            content: [BeautifulStreamingPart.text(text)],
            onCopy: (_) => pending.future,
          ),
        );
        await tester.pumpWidget(app('answer-1', 'Original'));
        await tester.tap(find.text('Copy answer'));
        await tester.pump();
        await tester.pumpWidget(
          app(replaceId ? 'answer-2' : 'answer-1', 'Current answer'),
        );
        pending.completeError(StateError('Late clipboard error'));
        await tester.pump();
        expect(find.text('Copy answer'), findsOneWidget);
        expect(find.text('Could not copy answer'), findsNothing);
        expect(failures, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('citation numbering changes invalidate a pending copy snapshot', (
    tester,
  ) async {
    final pending = Completer<void>();
    final failures = <BeautifulUiFailure>[];
    Widget app(List<BeautifulStreamingSource> sources) => _failureApp(
      onFailure: failures.add,
      child: _answer(
        content: const [
          BeautifulStreamingPart.text('Citation '),
          BeautifulStreamingPart.citation('guide'),
        ],
        sources: sources,
        onCopy: (_) => pending.future,
      ),
    );
    await tester.pumpWidget(app(_sources));
    await tester.tap(find.text('Copy answer'));
    await tester.pump();
    await tester.pumpWidget(app(_sources.reversed.toList()));
    pending.completeError(StateError('Stale cited snapshot'));
    await tester.pump();
    expect(_renderedAnswer(tester), 'Citation [2]');
    expect(find.text('Copy answer'), findsOneWidget);
    expect(failures, isEmpty);
  });

  testWidgets('normalizes copy and retry failures through the root scope', (
    tester,
  ) async {
    final failures = <BeautifulUiFailure>[];
    final copyError = StateError('Clipboard unavailable');
    final retryError = StateError('Generation unavailable');
    await tester.pumpWidget(
      _failureApp(
        onFailure: failures.add,
        child: _answer(
          status: BeautifulStreamingStatus.failed,
          onCopy: (_) => throw copyError,
          onRetry: () => throw retryError,
        ),
      ),
    );
    await tester.tap(find.text('Copy answer'));
    await tester.pump();
    expect(find.text('Could not copy answer'), findsOneWidget);
    await tester.tap(find.text('Retry answer'));
    await tester.pump();
    expect(find.text('Retry answer'), findsOneWidget);
    expect(failures, hasLength(2));
    expect(failures[0].operation, BeautifulUiOperation.clipboard);
    expect(failures[0].cause, same(copyError));
    expect(failures[1].operation, BeautifulUiOperation.streaming);
    expect(failures[1].cause, same(retryError));
    expect(
      failures.every((failure) => failure.stackTrace.toString().isNotEmpty),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new generation resets pending retry and ignores old failure', (
    tester,
  ) async {
    final pending = Completer<void>();
    final failures = <BeautifulUiFailure>[];
    Widget app(String id) => _failureApp(
      onFailure: failures.add,
      child: _answer(
        id: id,
        status: BeautifulStreamingStatus.failed,
        onRetry: () => pending.future,
      ),
    );
    await tester.pumpWidget(app('answer-1'));
    await tester.tap(find.text('Retry answer'));
    await tester.pump();
    await tester.pumpWidget(app('answer-2'));
    expect(find.text('Retry answer'), findsOneWidget);
    pending.completeError(StateError('Old retry failed'));
    await tester.pump();
    expect(failures, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty snapshots have no copy action in settled states', (
    tester,
  ) async {
    for (final status in BeautifulStreamingStatus.values) {
      await tester.pumpWidget(
        beautifulTestApp(
          child: _answer(status: status, content: const []),
        ),
      );
      expect(find.text('Copy answer'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('supports keyboard copy activation', (tester) async {
    final copied = <String>[];
    await tester.pumpWidget(
      beautifulTestApp(child: _answer(onCopy: copied.add)),
    );
    Focus.of(tester.element(find.text('Copy answer'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(copied, ['The received answer.']);
    expect(find.text('Answer copied'), findsOneWidget);
  });

  testWidgets('real mouse drag selects part of the answer in a WidgetsApp', (
    tester,
  ) async {
    await tester.pumpWidget(
      _selectionApp(
        _answer(
          status: BeautifulStreamingStatus.streaming,
          content: const [BeautifulStreamingPart.text('Hello selected world')],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SelectableRegion), findsOneWidget);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: _answerText, matching: find.byType(RichText)),
    );
    Offset position(int offset) => paragraph.localToGlobal(
      paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero) +
          Offset(0, paragraph.preferredLineHeight / 2),
    );
    final gesture = await tester.startGesture(
      position(0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(position(5));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(paragraph.selections, [
      const TextSelection(baseOffset: 0, extentOffset: 5),
    ]);
    expect(tester.takeException(), isNull);
    await gesture.removePointer();
  });

  testWidgets(
    'selection toolbar copies selected text through the host callback',
    (tester) async {
      final copied = <String>[];
      await tester.pumpWidget(
        _selectionApp(
          _answer(
            status: BeautifulStreamingStatus.streaming,
            content: const [
              BeautifulStreamingPart.text('Hello selected world'),
            ],
            onCopy: copied.add,
          ),
        ),
      );
      await tester.pump();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: _answerText, matching: find.byType(RichText)),
      );
      final point = paragraph.localToGlobal(
        paragraph.getOffsetForCaret(const TextPosition(offset: 2), Rect.zero) +
            Offset(0, paragraph.preferredLineHeight / 2),
      );
      await tester.longPressAt(point);
      await tester.pump();
      expect(find.text('Copy answer'), findsOneWidget);
      await tester.tap(find.text('Copy answer'));
      await tester.pump();
      expect(copied, ['Hello']);
      expect(find.text('Copy answer'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selection keyboard copy uses the host callback', (tester) async {
    final copied = <String>[];
    final systemCopied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          systemCopied.add((call.arguments as Map)['text'] as String);
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
    await tester.pumpWidget(
      _selectionApp(
        _answer(
          status: BeautifulStreamingStatus.streaming,
          content: const [BeautifulStreamingPart.text('Hello selected world')],
          onCopy: copied.add,
        ),
      ),
    );
    await tester.pump();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    Focus.of(tester.element(_answerText)).requestFocus();
    region.selectAll();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(copied, [
      'Hello selected world',
    ], reason: 'Host callback must replace system clipboard: $systemCopied');
    expect(systemCopied, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  for (final brightness in Brightness.values) {
    testWidgets(
      'all lifecycle and width modes support RTL 200 percent ${brightness.name} high contrast',
      (tester) async {
        const longLabel = 'إجراء محلي بعنوان طويل يلتف عبر عدة أسطر';
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        for (final status in BeautifulStreamingStatus.values) {
          for (final width in [320.0, 599.0, 600.0, 1023.0, 1024.0]) {
            tester.view.physicalSize = Size(width, 844);
            await tester.pumpWidget(
              beautifulTestApp(
                size: Size(width, 844),
                brightness: brightness,
                highContrast: true,
                textDirection: TextDirection.rtl,
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
                child: SingleChildScrollView(
                  child: BeautifulStreamingText(
                    key: ValueKey('${status.name}-$width'),
                    id: 'localized',
                    status: status,
                    content: const [
                      BeautifulStreamingPart.text(
                        'هذه إجابة طويلة تحتوي على أحرف عربية و中文 و👩🏽‍💻.\n',
                      ),
                      BeautifulStreamingPart.citation('guide'),
                    ],
                    sources: const [
                      BeautifulStreamingSource(
                        id: 'guide',
                        title: longLabel,
                        detail: longLabel,
                      ),
                    ],
                    followUps: const [
                      BeautifulStreamingFollowUp(id: 'more', label: longLabel),
                    ],
                    labels: const BeautifulStreamingLabels(
                      streaming: longLabel,
                      complete: longLabel,
                      failed: longLabel,
                      copy: longLabel,
                      retry: longLabel,
                      sources: 'المصادر',
                      positiveFeedback: longLabel,
                      negativeFeedback: longLabel,
                      followUps: longLabel,
                    ),
                    errorMessage: longLabel,
                    onCopy: (_) {},
                    onRetry: () {},
                    onFeedback: (_) {},
                    onFollowUp: (_) {},
                    onSourcePressed: (_) {},
                  ),
                ),
              ),
            );
            await tester.pump();
            if (status != BeautifulStreamingStatus.streaming) {
              await tester.ensureVisible(find.text('المصادر (1)'));
              await tester.tap(find.text('المصادر (1)'));
              await tester.pump();
              expect(find.text('[1] $longLabel · $longLabel'), findsOneWidget);
            }
            expect(
              tester.takeException(),
              isNull,
              reason: '${status.name} at width $width',
            );
          }
        }
      },
    );
  }
}
