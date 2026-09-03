import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';

/// Independent module fixtures for release screenshot inspection.
///
/// Builders create a fresh widget tree for each environment. Latin text is
/// deliberate: an RTL capture checks layout direction, not translation or
/// Arabic/Hebrew font coverage. The exporter supplies theme and text scaling.
Map<String, Widget Function()> buildP1P2ReviewScenarios() =>
    <String, Widget Function()>{
      'loading-state': () => _variantSections(<(String, Widget)>[
        for (final variant in BeautifulLoadingVariant.values)
          (
            variant.name,
            BeautifulLoadingState(
              label: 'Preparing sources',
              variant: variant,
              elapsed: const Duration(seconds: 12),
            ),
          ),
      ]),
      'thinking': () => _variantSections(<(String, Widget)>[
        (
          'Steps / working / expanded',
          BeautifulThinking(
            variant: BeautifulThinkingVariant.steps,
            status: BeautifulThinkingStatus.working,
            workingLabel: 'Checking stock',
            completedLabel: 'Stock checked',
            initiallyExpanded: true,
            items: const <BeautifulThinkingItem>[
              BeautifulThinkingItem(id: 'read', label: 'Read stock report'),
              BeautifulThinkingItem(
                id: 'verify',
                label: 'Verify supplier',
                detail: '2 records',
              ),
            ],
            onExpandedChanged: (_) {},
          ),
        ),
        (
          'Coding / complete / expanded',
          BeautifulThinking(
            variant: BeautifulThinkingVariant.coding,
            status: BeautifulThinkingStatus.complete,
            workingLabel: 'Updating plan',
            completedLabel: 'Plan updated',
            initiallyExpanded: true,
            items: const <BeautifulThinkingItem>[
              BeautifulThinkingItem(
                id: 'edit',
                label: 'Update stock.ts',
                detail: 'stock.ts',
                additions: 2,
                deletions: 1,
              ),
              BeautifulThinkingItem(
                id: 'test',
                label: 'Verify output',
                detail: 'Tests passed',
              ),
            ],
            onExpandedChanged: (_) {},
            onItemPressed: (_) {},
          ),
        ),
      ]),
      'context-cards': () => BeautifulContextCards(
        headerLabel: 'Reference notes',
        chunks: const <BeautifulContextChunk>[
          BeautifulContextChunk(
            id: 'stock',
            title: 'Stock report',
            characterCountLabel: '34 characters',
            body: 'Stock covers the weekend forecast.',
            sourceLabel: 'stock.csv',
            sourceBadge: 'CSV',
            tone: BeautifulContextTone.success,
          ),
          BeautifulContextChunk(
            id: 'supplier',
            title: 'Supplier check',
            characterCountLabel: '42 characters',
            body: 'Verify cold storage before the next order.',
            sourceLabel: 'supplier.pdf',
            sourceBadge: 'PDF',
            tone: BeautifulContextTone.destructive,
          ),
        ],
        onSourcePressed: (_) {},
      ),
      'recommendation-card': () => BeautifulRecommendationCard(
        title: 'Prepare the next order?',
        initialOptionId: 'draft',
        options: const <BeautifulRecommendationOption>[
          BeautifulRecommendationOption(
            id: 'draft',
            body: 'Draft an order for the weekly stock review.',
            shortLabel: 'Draft the stock order',
            signal: 3,
            tone: BeautifulRecommendationTone.success,
            confidenceLabel: 'High confidence',
            actionLabel: 'Accept',
          ),
          BeautifulRecommendationOption(
            id: 'review',
            body: 'Check supplier lead times before ordering.',
            shortLabel: 'Review lead times',
            signal: 2,
            tone: BeautifulRecommendationTone.warning,
            confidenceLabel: 'Needs review',
            actionLabel: 'Review',
          ),
        ],
        onAccept: (_) {},
      ),
      'search': () => BeautifulSearch(
        initialQuery: 'plan',
        placeholder: 'Search stock plans',
        searchLabel: 'Search stock plans',
        items: const <BeautifulSearchItem>[
          BeautifulSearchItem(id: 'draft', title: 'Draft stock plan'),
          BeautifulSearchItem(id: 'review', title: 'Review stock plan'),
        ],
        onSelected: (_) {},
        onQueryChanged: (_) {},
      ),
      'code-block': () => _variantSections(<(String, Widget)>[
        (
          'Code',
          BeautifulCodeBlock.code(
            filename: 'stock.ts',
            code: 'const stock = 12;\nreturn stock;',
            onCopy: (_) {},
          ),
        ),
        (
          'Diff',
          BeautifulCodeBlock.diff(
            filename: 'stock.ts',
            lines: const <BeautifulDiffLine>[
              BeautifulDiffLine(
                oldLineNumber: 1,
                kind: BeautifulDiffLineKind.removed,
                pieces: <BeautifulCodePiece>[
                  BeautifulCodePiece(
                    text: 'const stock = 8;',
                    change: BeautifulDiffLineKind.removed,
                  ),
                ],
              ),
              BeautifulDiffLine(
                newLineNumber: 1,
                kind: BeautifulDiffLineKind.added,
                pieces: <BeautifulCodePiece>[
                  BeautifulCodePiece(
                    text: 'const stock = 12;',
                    change: BeautifulDiffLineKind.added,
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
      'streaming-text': () => BeautifulStreamingText(
        id: 'stock-answer',
        status: BeautifulStreamingStatus.complete,
        content: const <BeautifulStreamingPart>[
          BeautifulStreamingPart.text(
            'Stock covers the weekend. Review supplier lead times today. ',
          ),
          BeautifulStreamingPart.citation('stock'),
        ],
        sources: const <BeautifulStreamingSource>[
          BeautifulStreamingSource(
            id: 'stock',
            title: 'stock.csv',
            detail: 'Daily export',
          ),
        ],
        followUps: const <BeautifulStreamingFollowUp>[
          BeautifulStreamingFollowUp(id: 'draft', label: 'Draft order'),
        ],
        feedback: BeautifulStreamingFeedback.positive,
        onSourcePressed: (_) {},
        onFollowUp: (_) {},
        onFeedback: (_) {},
        onCopy: (_) {},
        onRetry: () {},
      ),
      'approval-card': () => BeautifulApprovalCard(
        id: 'stock-approval',
        autoAdvance: false,
        questions: <BeautifulApprovalQuestion>[
          BeautifulApprovalQuestion(
            id: 'details',
            title: 'Choose order details',
            type: BeautifulApprovalQuestionType.multipleChoice,
            options: const <BeautifulApprovalOption>[
              BeautifulApprovalOption(id: 'stock', label: 'Stock report'),
              BeautifulApprovalOption(id: 'lead-time', label: 'Lead times'),
            ],
          ),
          BeautifulApprovalQuestion(
            id: 'delivery',
            title: 'Prepare a draft?',
            allowCustomAnswer: false,
            options: const <BeautifulApprovalOption>[
              BeautifulApprovalOption(id: 'draft', label: 'Save for review'),
              BeautifulApprovalOption(id: 'send', label: 'Send to supplier'),
            ],
          ),
        ],
        initialAnswers: <BeautifulApprovalAnswer>[
          BeautifulApprovalAnswer(
            questionId: 'details',
            optionIds: const <String>['stock'],
          ),
        ],
        onAnswerChanged: (_) {},
        onSubmit: (_) {},
      ),
      'tool-chips': () => BeautifulToolChips(
        headerLabel: '2 tool calls',
        initiallyExpanded: true,
        steps: <BeautifulToolStep>[
          BeautifulToolStep(
            id: 'read',
            label: 'Read stock',
            chip: 'stock.csv',
            kind: BeautifulToolKind.read,
            details: const <BeautifulToolDetailLine>[
              BeautifulToolDetailLine(text: '2 records matched.'),
            ],
          ),
          BeautifulToolStep(
            id: 'write',
            label: 'Save order',
            chip: 'order.md',
            kind: BeautifulToolKind.write,
            status: BeautifulToolStatus.failed,
            details: const <BeautifulToolDetailLine>[
              BeautifulToolDetailLine(text: 'Save requires retry.'),
            ],
          ),
        ],
        diffs: <BeautifulToolDiff>[
          BeautifulToolDiff(
            id: 'order',
            file: 'order.md',
            additions: 1,
            deletions: 1,
            lines: const <BeautifulToolDetailLine>[
              BeautifulToolDetailLine(
                text: 'Order 8 units.',
                tone: BeautifulToolLineTone.deletion,
              ),
              BeautifulToolDetailLine(
                text: 'Order 12 units.',
                tone: BeautifulToolLineTone.addition,
              ),
            ],
          ),
        ],
        onExpandedChanged: (_) {},
        onStepExpandedChanged: (_, _) {},
        onDiffExpandedChanged: (_, _) {},
      ),
      'task-rows': () => _variantSections(<(String, Widget)>[
        (
          'Capsules / complete and running',
          BeautifulTaskRows(
            rows: <BeautifulTaskRow>[
              BeautifulTaskRow(
                id: 'verify',
                label: 'Verify stock',
                amountLabel: '2 records',
                status: BeautifulTaskStatus.completed,
              ),
              BeautifulTaskRow(
                id: 'prepare',
                label: 'Prepare order',
                amountLabel: '12 units',
                status: BeautifulTaskStatus.running,
                step: 2,
                progress: 0.65,
                details: const <BeautifulTaskDetail>[
                  BeautifulTaskDetail(
                    id: 'lead-time',
                    label: 'Check lead time',
                    meta: '7 days',
                  ),
                ],
              ),
            ],
            onRetry: (_) {},
          ),
        ),
        (
          'List / pending and failed',
          BeautifulTaskRows(
            variant: BeautifulTaskRowsVariant.list,
            rows: <BeautifulTaskRow>[
              BeautifulTaskRow(
                id: 'review',
                label: 'Review draft',
                amountLabel: '1 order',
                status: BeautifulTaskStatus.pending,
                step: 3,
              ),
              BeautifulTaskRow(
                id: 'save',
                label: 'Save order',
                amountLabel: '1 file',
                status: BeautifulTaskStatus.failed,
              ),
            ],
            onRetry: (_) {},
          ),
        ),
      ]),
      'chat': () => BeautifulChat(
        conversationId: 'stock-review',
        height: 620,
        initialDraft: 'Prepare a draft.',
        tabs: const <BeautifulChatTab>[
          BeautifulChatTab(id: 'stock', label: 'Stock'),
          BeautifulChatTab(id: 'suppliers', label: 'Suppliers'),
        ],
        selectedTabId: 'stock',
        messages: const <BeautifulChatMessage>[
          BeautifulChatMessage(
            id: 'question',
            role: BeautifulChatRole.user,
            text: 'What needs ordering?',
          ),
          BeautifulChatMessage(
            id: 'answer',
            role: BeautifulChatRole.assistant,
            title: 'Stock review',
            subtitle: 'Daily export',
            detailLabel: '4 seconds',
            text: 'Order 12 units for next week.',
          ),
        ],
        onTabChanged: (_) {},
        onSend: (_) {},
        onStop: (_) {},
      ),
      'filter-table': () => BeautifulFilterTable(
        rows: const <BeautifulFilterTableRow>[
          BeautifulFilterTableRow(
            id: 'check',
            task: 'Verify stock',
            date: 'Sep 03',
            status: BeautifulFilterTableStatus.completed,
            owner: 'Operations',
          ),
          BeautifulFilterTableRow(
            id: 'draft',
            task: 'Draft order',
            date: 'Sep 04',
            status: BeautifulFilterTableStatus.inProgress,
            owner: 'Purchasing',
          ),
        ],
        onFilterChanged: (_) {},
      ),
      'fine-tune-card': () => BeautifulFineTuneCard(
        labels: const BeautifulFineTuneLabels(title: 'Stock card'),
        settings: BeautifulFineTuneSettings(
          layout: BeautifulFineTuneLayout.grid,
          typeId: 'standard',
          fields: const <BeautifulFineTuneField>[
            BeautifulFineTuneField(
              id: 'width',
              label: 'Width',
              value: 160,
              min: 40,
              max: 400,
            ),
            BeautifulFineTuneField(
              id: 'opacity',
              label: 'Opacity',
              value: 80,
              min: 0,
              max: 100,
              suffix: '%',
            ),
          ],
        ),
        options: const <BeautifulFineTuneOption>[
          BeautifulFineTuneOption(id: 'standard', label: 'Standard'),
          BeautifulFineTuneOption(id: 'compact', label: 'Compact'),
        ],
        onChanged: (_) {},
      ),
    };

Widget _variantSections(List<(String, Widget)> sections) => Builder(
  builder: (context) {
    final theme = BeautifulUiTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < sections.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 24),
          Text(
            sections[index].$1,
            style: theme.typography.caption.copyWith(
              color: theme.colors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          sections[index].$2,
        ],
      ],
    );
  },
);
