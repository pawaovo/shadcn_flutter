import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'p3_performance_measurement.dart';

final p3PerformanceWorkloadFactories = <P3PerformanceWorkload Function()>[
  _prompt,
  _diff,
  _records,
  _sidebar,
  _flowchart,
  _insights,
  _selection,
];

Finder _key(String key) => find.byKey(ValueKey<String>(key));
Finder _editable() => find.byType(EditableText).first;
Finder _semanticWidget(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

int _realizedPrefix(String prefix) => find
    .byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(prefix),
    )
    .evaluate()
    .length;

bool _selectedControl(WidgetTester tester, Finder target) => tester
    .widget<Semantics>(
      find
          .descendant(
            of: target,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.selected != null,
            ),
          )
          .first,
    )
    .properties
    .selected!;

P3PerformanceWorkload _prompt() {
  final sources = List.generate(
    1000,
    (index) => BeautifulPromptSource(
      id: 's$index',
      label: 'Source $index',
      description: 'Details $index',
    ),
  );
  final draft = List.filled(1000, 'long text ').join();
  var sent = 0;
  var sentLength = 0;
  var maximumRealizedOptions = 0;
  return P3PerformanceWorkload(
    id: 'prompt_bar',
    description: 'Filter 1,000 sources, wrap keyboard selection to the last source, edit/scroll/send an exact 10,000-character draft.',
    dataset: <String, Object?>{
      'sources': 1000,
      'draft_utf16_length': draft.length,
    },
    child: BeautifulPromptBar(
      composerId: 'p3-profile-prompt',
      sources: sources,
      initialDraft: draft,
      onSend: (submission) {
        expect(submission.text, draft.trim());
        sent++;
        sentLength = submission.text.length;
      },
    ),
    exercise: (actions) async {
      final tester = actions.tester;
      await actions.step('source_filter_and_keyboard_selection', () async {
        await actions.enter(_editable(), '@');
        await actions.settle();
        maximumRealizedOptions = math.max(
          maximumRealizedOptions,
          _realizedPrefix('beautiful-prompt-option-'),
        );
        expect(maximumRealizedOptions, lessThan(50));
        await actions.key(
          LogicalKeyboardKey.arrowUp,
          PhysicalKeyboardKey.arrowUp,
        );
        await actions.settle();
        expect(find.text('Source 999\nDetails 999'), findsOneWidget);
        await actions.key(LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter);
        await actions.settle();
        expect(
          tester.widget<EditableText>(_editable()).controller.text,
          '@Source 999 ',
        );
      });
      await actions.step(
        'edit_10000_character_draft',
        () => actions.enter(_editable(), draft),
      );
      await actions.step(
        'scroll_long_draft',
        () => actions.drag(_editable(), const Offset(0, 90)),
      );
      await actions.step('send_exact_long_draft', () async {
        await actions.tap(_key('beautiful-prompt-send'));
        await actions.settle();
        expect(sentLength, draft.trim().length);
        expect(
          tester.widget<EditableText>(_editable()).controller.text,
          isEmpty,
        );
      });
    },
    outcomes: () => <String, Object?>{
      'send_callback_count': sent,
      'last_sent_utf16_length': sentLength,
      'maximum_realized_suggestion_controls': maximumRealizedOptions,
    },
  );
}

P3PerformanceWorkload _diff() {
  const columns = <BeautifulDiffColumn>[
    BeautifulDiffColumn(id: 'name', label: 'Name'),
    BeautifulDiffColumn(id: 'category', label: 'Category'),
    BeautifulDiffColumn(id: 'owner', label: 'Owner'),
  ];
  final rows = List.generate(
    500,
    (index) => BeautifulDiffRow(
      id: 'r$index',
      before: <String, String>{
        'name': 'Record $index',
        'category': 'Prior',
        'owner': 'Operations',
      },
      after: <String, String>{
        'name': 'Record $index',
        'category': 'Proposed',
        'owner': 'Operations',
      },
    ),
  );
  var completedRounds = 0;
  var maxRows = 0;
  return P3PerformanceWorkload(
    id: 'diff_table',
    description: 'Review and toggle a 500-record, three-field change set; scroll between records and paginate the 20-row window.',
    dataset: <String, Object?>{'records': 500, 'fields': 3, 'page_size': 20},
    child: BeautifulDiffTable(
      id: 'p3-profile-diff',
      title: '500 proposed updates',
      columns: columns,
      rows: rows,
      pageSize: 20,
    ),
    exercise: (actions) async {
      maxRows = math.max(maxRows, _realizedPrefix('diff-table-row-'));
      expect(maxRows, 20);
      await actions.step('toggle_first_row', () async {
        final control = _key('diff-table-include-r0');
        final before = _selectedControl(actions.tester, control);
        await actions.tap(control);
        expect(_selectedControl(actions.tester, control), !before);
      });
      await actions.step(
        'scroll_review_page',
        () => actions.drag(
          find.byKey(p3PerformanceOuterScrollKey),
          const Offset(0, -450),
        ),
      );
      await actions.step('next_page_and_toggle_row', () async {
        await actions.tap(_key('diff-table-next'));
        await actions.settle();
        expect(_key('diff-table-row-r0'), findsNothing);
        expect(_key('diff-table-row-r20'), findsOneWidget);
        final control = _key('diff-table-include-r20');
        final before = _selectedControl(actions.tester, control);
        await actions.tap(control);
        expect(_selectedControl(actions.tester, control), !before);
      });
      await actions.step('return_previous_page', () async {
        await actions.tap(_key('diff-table-previous'));
        await actions.settle();
        expect(_key('diff-table-row-r0'), findsOneWidget);
      });
      completedRounds++;
    },
    outcomes: () => <String, Object?>{
      'completed_review_rounds': completedRounds,
      'maximum_realized_rows': maxRows,
    },
  );
}

P3PerformanceWorkload _records() {
  final columns = List.generate(
    20,
    (index) => BeautifulRecordColumn(
      id: 'c$index',
      label: 'Property $index',
      width: 180,
      property: BeautifulRecordPropertyConfig(),
    ),
  );
  final rows = List.generate(
    1000,
    (row) => BeautifulRecordRow(
      id: 'r$row',
      label: 'Unique record ${row.toString().padLeft(4, '0')}',
      cells: <String, BeautifulRecordCell>{
        for (var column = 0; column < 20; column++)
          'c$column': BeautifulRecordCell(
            text: 'r$row.c$column',
            number: row * 20 + column,
          ),
      },
    ),
  );
  var selections = 0;
  var sortChanges = 0;
  var queryChanges = 0;
  var maxRows = 0;
  return P3PerformanceWorkload(
    id: 'records_table',
    description: 'Scroll a 1,000×20 lazy grid vertically and horizontally, sort twice, filter to one record and toggle its selection.',
    dataset: <String, Object?>{
      'records': 1000,
      'columns': 20,
      'typed_cells': 20000,
      'viewport_height_dp': 400,
    },
    child: BeautifulRecordsTable(
      id: 'p3-profile-records',
      columns: columns,
      rows: rows,
      height: 400,
      onSelectionChanged: (_) => selections++,
      onSortChanged: (_) => sortChanges++,
      onQueryChanged: (_) => queryChanges++,
    ),
    exercise: (actions) async {
      final tester = actions.tester;
      final list = _key('records-list');
      final viewport = _key('records-viewport');
      await actions.step('scroll_lazy_rows', () async {
        final vertical = tester.widget<CustomScrollView>(list).controller!;
        final before = vertical.offset;
        await actions.drag(viewport, const Offset(0, -280));
        await actions.settle();
        expect(vertical.offset, greaterThan(before));
        await actions.drag(viewport, const Offset(0, 280));
        maxRows = math.max(maxRows, _realizedPrefix('records-row-'));
        expect(maxRows, lessThan(40));
      });
      await actions.step('scroll_twenty_columns', () async {
        final horizontal = tester
            .widget<SingleChildScrollView>(
              find
                  .descendant(
                    of: viewport,
                    matching: find.byType(SingleChildScrollView),
                  )
                  .first,
            )
            .controller!;
        final before = horizontal.offset;
        await actions.drag(viewport, const Offset(-320, 0));
        await actions.settle();
        expect(horizontal.offset, greaterThan(before));
        await actions.drag(viewport, const Offset(320, 0));
      });
      await actions.step('sort_numeric_property_twice', () async {
        await actions.tap(_key('records-sort-c0'));
        await actions.settle();
        await actions.tap(_key('records-sort-c0'));
        await actions.settle();
        expect(_key('records-row-r999'), findsOneWidget);
      });
      await actions.step('filter_and_select_one_of_1000', () async {
        await actions.enter(_editable(), 'Unique record 0999');
        await actions.settle();
        expect(_key('records-row-r999'), findsOneWidget);
        expect(_key('records-row-r998'), findsNothing);
        final beforeCallbacks = selections;
        final beforeSelected = tester
            .widget<Semantics>(_key('records-row-r999'))
            .properties
            .selected;
        await actions.tap(_semanticWidget('Select: Unique record 0999'));
        expect(selections, beforeCallbacks + 1);
        expect(
          tester
              .widget<Semantics>(_key('records-row-r999'))
              .properties
              .selected,
          !beforeSelected!,
        );
        await actions.enter(_editable(), '');
        await actions.settle();
        expect(
          tester
              .widget<BeautifulRecordsTable>(find.byType(BeautifulRecordsTable))
              .columns
              .length,
          20,
        );
      });
    },
    outcomes: () => <String, Object?>{
      'selection_callback_count': selections,
      'sort_callback_count': sortChanges,
      'query_callback_count': queryChanges,
      'maximum_realized_rows': maxRows,
    },
  );
}

P3PerformanceWorkload _sidebar() {
  final recents = List.generate(
    1000,
    (index) => BeautifulSidebarRecent(
      id: 'r$index',
      label: 'History ${index.toString().padLeft(4, '0')}',
    ),
  );
  var activations = 0;
  var maxRows = 0;
  return P3PerformanceWorkload(
    id: 'sidebar_nav',
    description: 'Scroll 1,000 lazy recent items, search a unique last item, activate it and clear the query.',
    dataset: <String, Object?>{
      'recent_items': 1000,
      'presentation': 'expanded',
      'height_dp': 480,
      'width_dp': 288,
    },
    child: Align(
      alignment: Alignment.topLeft,
      child: BeautifulSidebarNav(
        workspaces: <BeautifulSidebarWorkspace>[
          BeautifulSidebarWorkspace(
            id: 'workspace',
            label: 'Profile workspace',
          ),
        ],
        selectedWorkspaceId: 'workspace',
        items: <BeautifulSidebarItem>[
          BeautifulSidebarItem(id: 'home', label: 'Home'),
        ],
        recents: recents,
        presentation: BeautifulSidebarPresentation.expanded,
        height: 480,
        onRecentSelected: (_) => activations++,
      ),
    ),
    exercise: (actions) async {
      final history = find.byKey(
        const PageStorageKey<String>('beautiful-sidebar-history'),
      );
      await actions.step('scroll_lazy_recents', () async {
        final scroll = actions.tester
            .widget<CustomScrollView>(history)
            .controller!;
        final before = scroll.offset;
        await actions.drag(history, const Offset(0, -280));
        await actions.settle();
        expect(scroll.offset, greaterThan(before));
        await actions.drag(history, const Offset(0, 280));
        maxRows = math.max(
          maxRows,
          _realizedPrefix('beautiful-sidebar-recent-'),
        );
        expect(maxRows, lessThan(40));
      });
      await actions.step('filter_activate_and_clear', () async {
        final trigger = _key('beautiful-sidebar-search-trigger');
        if (trigger.evaluate().isNotEmpty) await actions.tap(trigger);
        await actions.enter(_editable(), 'History 0999');
        await actions.settle();
        expect(_key('beautiful-sidebar-recent-r999'), findsOneWidget);
        final beforeActivations = activations;
        await actions.tap(_key('beautiful-sidebar-recent-r999'));
        expect(activations, beforeActivations + 1);
        await actions.enter(_editable(), '');
      });
    },
    outcomes: () => <String, Object?>{
      'recent_activation_count': activations,
      'maximum_realized_recent_rows': maxRows,
    },
  );
}

P3PerformanceWorkload _flowchart() {
  final nodes = List.generate(
    24,
    (index) => BeautifulFlowchartNode(
      id: 'n$index',
      kind: BeautifulFlowchartNodeKind.trigger,
      title: 'Step $index',
      position: Offset(48 + (index % 4) * 420, 48 + (index ~/ 4) * 200),
    ),
  );
  final edges = <BeautifulFlowchartEdge>[
    for (var gap = 1; gap <= 3; gap++)
      for (var from = 0; from + gap < 24; from++)
        BeautifulFlowchartEdge(
          id: '$from-${from + gap}',
          from: 'n$from',
          to: 'n${from + gap}',
        ),
  ].take(48).toList();
  var accepted = BeautifulFlowchartData(
    id: 'p3-profile-flow',
    nodes: nodes,
    edges: edges,
  );
  var edits = 0;
  return P3PerformanceWorkload(
    id: 'flowchart',
    description: 'Render a 24-node / 48-edge DAG; accept keyboard and drag moves, then pan and zoom the native canvas.',
    dataset: <String, Object?>{
      'nodes': 24,
      'edges': 48,
      'viewport_height_dp': 420,
      'presentation': 'expanded canvas',
    },
    child: StatefulBuilder(
      builder: (context, setState) => BeautifulFlowchart(
        data: accepted,
        viewportHeight: 420,
        onChanged: (next) {
          edits++;
          setState(() => accepted = next);
        },
      ),
    ),
    exercise: (actions) async {
      final tester = actions.tester;
      final node = _key('beautiful-flowchart-node-n0');
      expect(_key('beautiful-flowchart-connectors'), findsOneWidget);
      await actions.step('keyboard_node_movement', () async {
        await actions.tap(_key('beautiful-flowchart-reset'));
        await actions.tap(node);
        final before = accepted.nodes.first.position;
        final beforeEdits = edits;
        for (var index = 0; index < 4; index++) {
          await actions.key(
            LogicalKeyboardKey.arrowRight,
            PhysicalKeyboardKey.arrowRight,
          );
          await actions.pump();
        }
        expect(accepted.nodes.first.position, before + const Offset(64, 0));
        expect(edits, greaterThanOrEqualTo(beforeEdits + 4));
        for (var index = 0; index < 4; index++) {
          await actions.key(
            LogicalKeyboardKey.arrowLeft,
            PhysicalKeyboardKey.arrowLeft,
          );
          await actions.pump();
        }
        expect(accepted.nodes.first.position, before);
        expect(edits, greaterThanOrEqualTo(beforeEdits + 8));
      });
      await actions.step('drag_node_and_connectors', () async {
        final before = accepted.nodes.first.position;
        final beforeEdits = edits;
        await actions.drag(node, const Offset(64, 0));
        await actions.settle();
        final afterRight = accepted.nodes.first.position;
        expect(afterRight.dx, greaterThan(before.dx));
        expect(edits, greaterThan(beforeEdits));
        final afterRightEdits = edits;
        await actions.drag(node, const Offset(-64, 0));
        await actions.settle();
        expect(accepted.nodes.first.position.dx, lessThan(afterRight.dx));
        expect(edits, greaterThan(afterRightEdits));
      });
      await actions.step('canvas_pan_and_zoom', () async {
        final transform = tester
            .widget<InteractiveViewer>(_key('beautiful-flowchart-viewer'))
            .transformationController!;
        final beforePan = transform.value.getTranslation().x;
        await actions.tap(_key('beautiful-flowchart-pan-right'));
        await actions.settle();
        final afterRight = transform.value.getTranslation().x;
        expect(afterRight, lessThan(beforePan));
        await actions.tap(_key('beautiful-flowchart-pan-left'));
        await actions.settle();
        expect(transform.value.getTranslation().x, greaterThan(afterRight));
        final beforeScale = transform.value.getMaxScaleOnAxis();
        await actions.tap(_key('beautiful-flowchart-zoom-in'));
        await actions.settle();
        final afterScale = transform.value.getMaxScaleOnAxis();
        expect(afterScale, greaterThan(beforeScale));
        await actions.tap(_key('beautiful-flowchart-zoom-out'));
        await actions.settle();
        expect(transform.value.getMaxScaleOnAxis(), lessThan(afterScale));
        expect(accepted.nodes, hasLength(24));
        expect(accepted.edges, hasLength(48));
      });
    },
    outcomes: () => <String, Object?>{
      'accepted_graph_edit_count': edits,
      'first_node_x_dp': accepted.nodes.first.position.dx,
      'first_node_y_dp': accepted.nodes.first.position.dy,
    },
  );
}

P3PerformanceWorkload _insights() {
  final series = List.generate(
    4,
    (seriesIndex) => BeautifulInsightSeries(
      id: 's$seriesIndex',
      label: 'Series $seriesIndex',
      valueLabel: 'Host snapshot $seriesIndex',
      points: List.generate(
        512,
        (index) => BeautifulInsightPoint(
          id: 'p$index',
          label: 'Observation $index',
          value: math.sin(index / 20 + seriesIndex) * 100 + seriesIndex * 30,
          formattedValue:
              '${(math.sin(index / 20 + seriesIndex) * 100 + seriesIndex * 30).toStringAsFixed(2)} units',
        ),
      ),
      tone: BeautifulInsightTone.values[seriesIndex],
    ),
  );
  var rounds = 0;
  var maximumRealizedTextRows = 0;
  return P3PerformanceWorkload(
    id: 'insight_cards',
    description: 'Inspect four exact 512-point series using pointer and keys, then disclose their complete lazy text list, scroll to and verify the final observation in every series, return to the first row and hide the data.',
    dataset: <String, Object?>{
      'series': 4,
      'observations_per_series': 512,
      'text_rows_when_expanded': 512,
    },
    child: BeautifulInsightCards(
      pages: <BeautifulInsightPage>[
        BeautifulInsightPage(
          id: 'comparison',
          title: 'Bounded chart workload',
          prose:
              'Deterministic fixture observations generated by this harness.',
          chart: BeautifulInsightComparison(
            title: 'Four series',
            summary: 'Four deterministic waves with distinct offsets.',
            series: series,
          ),
        ),
      ],
      selectedPageId: 'comparison',
    ),
    exercise: (actions) async {
      final tester = actions.tester;
      final plot = _key('beautiful-insight-plot-comparison');
      int inspectedPoint() => int.parse(
        RegExp(r'^Observation (\d+)')
            .firstMatch(
              tester
                  .widget<Text>(
                    _key('beautiful-insight-observation-comparison'),
                  )
                  .data!,
            )!
            .group(1)!,
      );
      expect(_key('beautiful-insight-datum-comparison-p0'), findsNothing);
      await actions.step('pointer_and_keyboard_inspection', () async {
        final beforeTap = inspectedPoint();
        await actions.tap(plot);
        final afterTap = inspectedPoint();
        expect(afterTap, isNot(beforeTap));
        for (var index = 0; index < 8; index++) {
          await actions.key(
            LogicalKeyboardKey.arrowRight,
            PhysicalKeyboardKey.arrowRight,
          );
          await actions.pump();
        }
        expect(inspectedPoint(), afterTap + 8);
        final afterKeys = inspectedPoint();
        await actions.drag(
          plot,
          const Offset(-260, 0),
          duration: const Duration(milliseconds: 650),
        );
        await actions.settle();
        expect(inspectedPoint(), lessThan(afterKeys));
      });
      await actions.step('disclose_and_scroll_512_text_rows', () async {
        await actions.tap(_key('beautiful-insight-data-comparison'));
        await actions.settle();
        final data = _key('beautiful-insight-data-scroll-comparison');
        final scroll = tester.widget<ListView>(data).controller!;
        void verifyRow(int index) {
          final text = tester
              .widget<Text>(_key('beautiful-insight-datum-comparison-p$index'))
              .data!;
          expect(text, startsWith('Observation $index.'));
          for (final item in series) {
            expect(
              text,
              contains('${item.label}: ${item.points[index].formattedValue}'),
            );
          }
          maximumRealizedTextRows = math.max(
            maximumRealizedTextRows,
            _realizedPrefix('beautiful-insight-datum-comparison-'),
          );
          expect(maximumRealizedTextRows, lessThan(64));
        }

        verifyRow(0);
        expect(_key('beautiful-insight-datum-comparison-p511'), findsNothing);
        await actions.drag(data, const Offset(0, -240));
        await actions.settle();
        expect(scroll.offset, greaterThan(0));
        // Exercise the real scrolling list. A lazy list estimates extent
        // until rows are laid out, so finish at its observed end if needed.
        for (var attempt = 0; attempt < 4; attempt++) {
          final movement = scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.linear,
          );
          await actions.settle();
          await actions.guard.wait('insight.scroll_animation', () => movement);
          if (_key('beautiful-insight-datum-comparison-p511')
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
        expect(_key('beautiful-insight-datum-comparison-p511'), findsOneWidget);
        verifyRow(511);
        final back = scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.linear,
        );
        await actions.settle();
        await actions.guard.wait('insight.return_scroll_animation', () => back);
        verifyRow(0);
      });
      await actions.step('collapse_text_data', () async {
        await actions.tap(_key('beautiful-insight-data-comparison'));
        await actions.settle();
        expect(_key('beautiful-insight-datum-comparison-p0'), findsNothing);
      });
      rounds++;
    },
    outcomes: () => <String, Object?>{
      'completed_inspection_rounds': rounds,
      'active_plot_count': _realizedPrefix('beautiful-insight-plot-'),
      'maximum_realized_text_rows': maximumRealizedTextRows,
    },
  );
}

P3PerformanceWorkload _selection() {
  var text = List.filled(
    1000,
    'line of content 123\n',
  ).join().padRight(20000, 'x');
  var requests = 0;
  var applications = 0;
  String? lastSelection;
  return P3PerformanceWorkload(
    id: 'selection_actions',
    description: 'Scroll a native 20,000-character read-only editor, select its first word with a real pointer drag, request a replacement and accept it through the host.',
    dataset: <String, Object?>{
      'document_utf16_length': text.length,
      'selected_utf16_length': 4,
      'replacement_utf16_length': 4,
    },
    child: StatefulBuilder(
      builder: (context, setState) => BeautifulSelectionActions(
        documentId: 'p3-profile-selection',
        text: text,
        onRequest: (request) {
          requests++;
          lastSelection = request.selectedText;
          expect(request.baseText.length, 20000);
          return request.selectedText == 'line' ? 'word' : 'line';
        },
        onApply: (edit) {
          applications++;
          setState(() => text = edit.updatedText);
        },
      ),
    ),
    exercise: (actions) async {
      final tester = actions.tester;
      final document = _editable();
      await actions.step('scroll_20000_character_native_editor', () async {
        await actions.drag(document, const Offset(0, -160));
        final controller = tester
            .widget<EditableText>(document)
            .scrollController!;
        final scrolling = controller.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.linear,
        );
        await actions.settle();
        await actions.guard.wait(
          'selection.return_scroll_animation',
          () => scrolling,
        );
      });
      await actions.step('native_pointer_selection', () async {
        await actions.guard.wait(
          'selection.ensureVisible',
          () => tester.ensureVisible(document),
        );
        await actions.settle();
        final editor = tester.state<EditableTextState>(document);
        Offset caret(int offset) => editor.renderEditable.localToGlobal(
          editor.renderEditable
              .getLocalRectForCaret(TextPosition(offset: offset))
              .center,
        );
        final start = caret(0);
        final end = caret(4);
        await actions.guard.wait(
          'selection.pointer_drag',
          () => tester.dragFrom(
            start,
            end - start,
            kind: PointerDeviceKind.mouse,
          ),
        );
        await actions.settle();
        expect(
          tester.widget<EditableText>(document).controller.selection,
          const TextSelection(baseOffset: 0, extentOffset: 4),
        );
      });
      await actions.step('request_and_accept_host_replacement', () async {
        Finder inPanel(String label) => find
            .descendant(
              of: find.byType(BeautifulSelectionActions),
              matching: find.text(label),
            )
            .first;
        final expectedSelection = text.substring(0, 4);
        await actions.tap(inPanel('Improve'));
        await actions.settle();
        expect(lastSelection, expectedSelection);
        await actions.tap(inPanel('Keep change'));
        await actions.settle();
        expect(text.length, 20000);
        expect(
          text.substring(0, 4),
          expectedSelection == 'line' ? 'word' : 'line',
        );
      });
    },
    outcomes: () => <String, Object?>{
      'request_callback_count': requests,
      'accepted_replacement_count': applications,
      'document_utf16_length': text.length,
      'last_selected_text': lastSelection,
    },
  );
}
