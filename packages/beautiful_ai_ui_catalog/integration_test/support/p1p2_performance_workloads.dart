import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p3_performance_measurement.dart';

/// Representative finite fixtures, not universal supported size limits.
/// All data, snapshot updates and callback results belong to this harness.
final p1p2PerformanceWorkloadFactories = <P3PerformanceWorkload Function()>[
  _search,
  _code,
  _thinking,
  _streaming,
  _tools,
  _chat,
  _filter,
  _tasks,
];

Finder _key(String value) => find.byKey(ValueKey<String>(value));
Finder _editable() => find.byType(EditableText).first;
Finder _outer() => find.byKey(p3PerformanceOuterScrollKey);

Future<void> _scrollOuter(P3PerformanceActions actions) async {
  final scroll = actions.tester.widget<SingleChildScrollView>(_outer());
  final state = actions.tester.state<ScrollableState>(
    find.descendant(of: _outer(), matching: find.byType(Scrollable)).first,
  );
  // Observe the actual host-provided scrolling extent; do not fake viewport
  // metrics or use a synthetic duration as performance evidence.
  expect(scroll.scrollDirection, Axis.vertical);
  expect(state.position.maxScrollExtent, greaterThan(0));
  await actions.drag(_outer(), const Offset(0, -420));
  await actions.settle();
  expect(state.position.pixels, greaterThan(0));
  state.position.jumpTo(0);
  await actions.settle();
}

P3PerformanceWorkload _search() {
  final items = List.generate(
    1000,
    (index) => BeautifulSearchItem(
      id: 'entry-$index',
      title: 'Search entry ${index.toString().padLeft(4, '0')}',
      subtitle: 'A deterministic searchable catalog entry with supporting text',
    ),
  );
  var selected = 0;
  return P3PerformanceWorkload(
    id: 'search_long_catalog',
    description: 'Filter 1,000 command entries through twelve unique queries, traverse ten broad-match results by keyboard, select the last unique result, and restore the empty query.',
    dataset: <String, Object?>{
      'entries': items.length,
      'unique_queries_per_round': 12,
      'broad_match_keyboard_moves_per_round': 10,
    },
    child: BeautifulSearch(
      items: items,
      onSelected: (item) {
        expect(item.id, 'entry-999');
        selected++;
      },
    ),
    exercise: (actions) async {
      await actions.step('filter_1000_and_select_last', () async {
        final before = selected;
        for (var query = 0; query < 12; query++) {
          await actions.enter(
            _editable(),
            'Search entry ${query.toString().padLeft(4, '0')}',
          );
          await actions.settle();
        }
        await actions.enter(_editable(), 'Search entry 0');
        await actions.settle();
        for (var move = 0; move < 10; move++) {
          await actions.key(
            LogicalKeyboardKey.arrowDown,
            PhysicalKeyboardKey.arrowDown,
          );
          await actions.settle();
        }
        await actions.enter(_editable(), 'Search entry 0999');
        await actions.settle();
        await actions.key(
          LogicalKeyboardKey.arrowDown,
          PhysicalKeyboardKey.arrowDown,
        );
        await actions.key(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
        await actions.settle();
        expect(selected, before + 1);
        await actions.enter(_editable(), '');
      });
    },
    outcomes: () => <String, Object?>{'selection_callback_count': selected},
  );
}

P3PerformanceWorkload _code() {
  final source = List.generate(
    1000,
    (index) =>
        'final value$index = "source line $index with deterministic content";',
  ).join('\n');
  var copies = 0;
  return P3PerformanceWorkload(
    id: 'code_block_long_source',
    description: 'Render and scroll 1,000 source lines; request an exact full-source copy through the public host callback.',
    dataset: <String, Object?>{
      'lines': 1000,
      'source_utf16_length': source.length,
    },
    child: BeautifulCodeBlock.code(
      filename: 'long_source.dart',
      code: source,
      onCopy: (text) {
        expect(text, source);
        copies++;
      },
    ),
    exercise: (actions) async {
      await actions.step(
        'scroll_1000_source_lines',
        () => _scrollOuter(actions),
      );
      await actions.step('copy_exact_source', () async {
        final before = copies;
        await actions.tap(find.text('Copy'));
        await actions.settle();
        expect(copies, before + 1);
        // The product's existing copy feedback timer must finish before the
        // next repeat. This wall-time wait is not a frame-duration estimate.
        await actions.pump(const Duration(milliseconds: 1600));
      });
    },
    outcomes: () => <String, Object?>{'copy_callback_count': copies},
  );
}

P3PerformanceWorkload _thinking() {
  final items = List.generate(
    200,
    (index) => BeautifulThinkingItem(
      id: 'trace-$index',
      label: 'Reasoning step $index with detailed explanation',
    ),
  );
  var toggles = 0;
  var expanded = false;
  return P3PerformanceWorkload(
    id: 'thinking_long_trace',
    description: 'Open a completed 200-step reasoning trace, scroll the expanded content, and collapse it.',
    dataset: <String, Object?>{'steps': items.length},
    child: BeautifulThinking(
      variant: BeautifulThinkingVariant.steps,
      status: BeautifulThinkingStatus.complete,
      workingLabel: 'Preparing trace',
      completedLabel: 'Completed trace',
      items: items,
      onExpandedChanged: (value) {
        toggles++;
        expanded = value;
      },
    ),
    exercise: (actions) async {
      await actions.step('disclose_and_scroll_200_steps', () async {
        await actions.tap(_key('beautiful-thinking-header'));
        await actions.settle();
        expect(find.text(items.last.label), findsOneWidget);
        expect(expanded, isTrue);
        await _scrollOuter(actions);
        await actions.tap(_key('beautiful-thinking-header'));
        await actions.settle();
        expect(expanded, isFalse);
      });
    },
    outcomes: () => <String, Object?>{'disclosure_callback_count': toggles},
  );
}

P3PerformanceWorkload _streaming() {
  final chunks = List.generate(
    50,
    (index) =>
        'Paragraph $index: deterministic streamed answer.\n'.padRight(400, 'x'),
  );
  final answer = chunks.join();
  var text = '';
  var status = BeautifulStreamingStatus.streaming;
  late StateSetter update;
  var updates = 0;
  var copies = 0;
  return P3PerformanceWorkload(
    id: 'streaming_long_answer',
    description: 'Apply 50 caller snapshots to an exact 20,000-character answer, scroll it, and copy the complete answer through the host.',
    dataset: <String, Object?>{
      'snapshots_per_round': chunks.length,
      'answer_utf16_length': answer.length,
    },
    child: StatefulBuilder(
      builder: (context, setState) {
        update = setState;
        return BeautifulStreamingText(
          id: 'long-profile-answer',
          content: <BeautifulStreamingPart>[BeautifulStreamingPart.text(text)],
          status: status,
          onCopy: (value) {
            expect(value, answer);
            copies++;
          },
        );
      },
    ),
    exercise: (actions) async {
      await actions.step('apply_50_caller_snapshots', () async {
        update(() {
          text = '';
          status = BeautifulStreamingStatus.streaming;
        });
        await actions.pump();
        for (final chunk in chunks) {
          update(() => text += chunk);
          updates++;
          await actions.pump(const Duration(milliseconds: 16));
        }
        update(() => status = BeautifulStreamingStatus.complete);
        await actions.settle();
        expect(text, answer);
      });
      await actions.step('scroll_and_copy_long_answer', () async {
        await _scrollOuter(actions);
        final before = copies;
        await actions.tap(find.text('Copy answer'));
        await actions.settle();
        expect(copies, before + 1);
      });
    },
    outcomes: () => <String, Object?>{
      'snapshot_update_count': updates,
      'copy_callback_count': copies,
      'final_utf16_length': text.length,
    },
  );
}

P3PerformanceWorkload _tools() {
  final lines = List.generate(
    1000,
    (index) => BeautifulToolDetailLine(
      text: 'Output line $index: completed deterministic operation with detail',
    ),
  );
  var disclosures = 0;
  return P3PerformanceWorkload(
    id: 'tool_chips_large_output',
    description: 'Disclose, scroll and collapse 1,000 complete tool-output lines without executing a tool or contacting a server.',
    dataset: <String, Object?>{'operations': 1, 'output_lines': lines.length},
    child: BeautifulToolChips(
      steps: <BeautifulToolStep>[
        BeautifulToolStep(
          id: 'large',
          label: 'Inspect output',
          chip: 'profile-output',
          details: lines,
        ),
      ],
      onStepExpandedChanged: (_, _) => disclosures++,
    ),
    exercise: (actions) async {
      await actions.step('disclose_scroll_and_collapse_1000_lines', () async {
        await actions.tap(_key('beautiful-tool-step-control-large'));
        await actions.settle();
        expect(find.text(lines.last.text), findsOneWidget);
        await _scrollOuter(actions);
        await actions.tap(_key('beautiful-tool-step-control-large'));
        await actions.settle();
        expect(find.text(lines.last.text), findsNothing);
      });
    },
    outcomes: () => <String, Object?>{'disclosure_callback_count': disclosures},
  );
}

P3PerformanceWorkload _chat() {
  final messages = List.generate(
    500,
    (index) => BeautifulChatMessage(
      id: 'message-$index',
      role: index.isEven ? BeautifulChatRole.user : BeautifulChatRole.assistant,
      text:
          'Message $index: ${List.filled(8, 'A long transcript sentence. ').join()}',
    ),
  );
  var sends = 0;
  const draft = 'A deterministic message after a long transcript';
  return P3PerformanceWorkload(
    id: 'chat_long_transcript',
    description: 'Scroll a 500-message transcript away from and back to its latest message, edit and submit a real composer draft.',
    dataset: <String, Object?>{
      'messages': messages.length,
      'transcript_utf16_length': messages.fold<int>(
        0,
        (count, message) => count + message.text.length,
      ),
      'height_dp': 560,
    },
    child: BeautifulChat(
      conversationId: 'long-profile-conversation',
      messages: messages,
      height: 560,
      onSend: (text) {
        expect(text, draft);
        sends++;
      },
    ),
    exercise: (actions) async {
      await actions.step('scroll_long_transcript_and_return_latest', () async {
        final transcript = _key('beautiful-chat-transcript');
        final scroll = actions.tester
            .widget<SingleChildScrollView>(transcript)
            .controller!;
        final before = scroll.offset;
        await actions.drag(transcript, const Offset(0, 350));
        await actions.settle();
        expect(scroll.offset, lessThan(before));
        await actions.tap(_key('beautiful-chat-latest'));
        await actions.settle();
        expect(
          (scroll.offset - scroll.position.maxScrollExtent).abs(),
          lessThan(2),
        );
      });
      await actions.step('edit_and_send_composer', () async {
        final before = sends;
        await actions.enter(_editable(), draft);
        await actions.key(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
        await actions.settle();
        expect(sends, before + 1);
        expect(
          actions.tester.widget<EditableText>(_editable()).controller.text,
          isEmpty,
        );
      });
    },
    outcomes: () => <String, Object?>{'send_callback_count': sends},
  );
}

P3PerformanceWorkload _filter() {
  final rows = List.generate(
    200,
    (index) => BeautifulFilterTableRow(
      id: 'task-$index',
      task: 'Filter task $index',
      date: '2026-09-03',
      status: BeautifulFilterTableStatus.values[index % 3],
      owner: 'Owner $index',
    ),
  );
  var filters = 0;
  return P3PerformanceWorkload(
    id: 'filter_table_large_dataset',
    description: 'Render and scroll 200 non-virtualized rows, filter to the 66 completed rows, and restore the full dataset.',
    dataset: <String, Object?>{
      'rows': rows.length,
      'completed_rows': 66,
      'virtualized': false,
    },
    child: BeautifulFilterTable(rows: rows, onFilterChanged: (_) => filters++),
    exercise: (actions) async {
      await actions.step('scroll_and_filter_200_rows', () async {
        await _scrollOuter(actions);
        await actions.tap(_key('filter-table-filter-completed'));
        await actions.settle();
        expect(find.text('Filter task 2'), findsOneWidget);
        expect(find.text('Filter task 0'), findsNothing);
        expect(find.text('Matching tasks: 66 / 200'), findsOneWidget);
        await actions.tap(_key('filter-table-filter-all'));
        await actions.settle();
        expect(find.text('Filter task 0'), findsOneWidget);
      });
    },
    outcomes: () => <String, Object?>{'filter_callback_count': filters},
  );
}

P3PerformanceWorkload _tasks() {
  final rows = List.generate(
    100,
    (index) => BeautifulTaskRow(
      id: 'workflow-$index',
      label: 'Workflow task $index',
      amountLabel: '10 details',
      status: BeautifulTaskStatus.completed,
      details: List.generate(
        10,
        (detail) => BeautifulTaskDetail(
          id: 'detail-$detail',
          label: 'Task $index detail $detail',
          meta: 'Complete',
        ),
      ),
    ),
  );
  var rounds = 0;
  return P3PerformanceWorkload(
    id: 'task_rows_large_workflow',
    description: 'Scroll 100 completed workflow tasks, disclose ten details in the first task, and collapse them.',
    dataset: <String, Object?>{
      'tasks': rows.length,
      'details_per_task': 10,
      'variant': 'list',
    },
    child: BeautifulTaskRows(
      rows: rows,
      variant: BeautifulTaskRowsVariant.list,
    ),
    exercise: (actions) async {
      await actions.step('scroll_disclose_and_collapse_100_tasks', () async {
        await _scrollOuter(actions);
        await actions.tap(_key('task-toggle-workflow-0'));
        await actions.settle();
        expect(find.text('Task 0 detail 9'), findsOneWidget);
        await actions.tap(_key('task-toggle-workflow-0'));
        await actions.settle();
        expect(find.text('Task 0 detail 9'), findsNothing);
        rounds++;
      });
    },
    outcomes: () => <String, Object?>{'completed_rounds': rounds},
  );
}
