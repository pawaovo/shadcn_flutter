/// Stable scenario contracts shared by the native entrypoint and host driver.
/// Keep historical P3 IDs unchanged so old evidence remains readable.
const performanceScenarioIds = <String, List<String>>{
  'p3': <String>[
    'prompt_bar',
    'diff_table',
    'records_table',
    'sidebar_nav',
    'flowchart',
    'insight_cards',
    'selection_actions',
  ],
  'p1p2': <String>[
    'search_long_catalog',
    'code_block_long_source',
    'thinking_long_trace',
    'streaming_long_answer',
    'tool_chips_large_output',
    'chat_long_transcript',
    'filter_table_large_dataset',
    'task_rows_large_workflow',
  ],
};

List<String> expectedPerformanceScenarios(String suite) => switch (suite) {
  'all' => <String>[
    ...performanceScenarioIds['p3']!,
    ...performanceScenarioIds['p1p2']!,
  ],
  'p3' || 'p1p2' => performanceScenarioIds[suite]!,
  _ => throw ArgumentError.value(suite, 'suite', 'must be p3, p1p2 or all'),
};
