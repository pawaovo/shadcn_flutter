import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';

/// Complementary locale fixtures; business labels and package labels are host supplied.
Map<String, Widget Function()> buildP1P2MatrixScenarios(
  MatrixCopy copy,
) => <String, Widget Function()>{
  'loading-state': () => _matrixVariantSections(<(String, Widget)>[
    for (final variant in BeautifulLoadingVariant.values)
      (
        variant.name,
        BeautifulLoadingState(
          label: copy.text('Preparing sources'),
          elapsedSemanticLabel: copy.text('Elapsed time'),
          surferFallbackLabel: copy.text('Media unavailable'),
          variant: variant,
          elapsed: Duration(seconds: 12),
        ),
      ),
  ]),
  'thinking': () => _matrixVariantSections(<(String, Widget)>[
    (
      'Reasoning / working / expanded',
      BeautifulThinking(
        variant: BeautifulThinkingVariant.reasoning,
        status: BeautifulThinkingStatus.working,
        workingLabel: copy.text('Checking stock'),
        completedLabel: copy.text('Stock checked'),
        initiallyExpanded: true,
        expandLabel: copy.text('Show details'),
        collapseLabel: copy.text('Hide details'),
        items: <BeautifulThinkingItem>[
          BeautifulThinkingItem(
            id: 'read',
            label: copy.text('Read stock report'),
          ),
          BeautifulThinkingItem(
            id: 'verify',
            label: copy.text('Verify supplier'),
            detail: copy.text('2 records'),
          ),
        ],
        onExpandedChanged: (_) {},
      ),
    ),
    (
      'Search / complete / expanded',
      BeautifulThinking(
        variant: BeautifulThinkingVariant.search,
        status: BeautifulThinkingStatus.complete,
        workingLabel: copy.text('Updating plan'),
        completedLabel: copy.text('Plan updated'),
        initiallyExpanded: true,
        expandLabel: copy.text('Show details'),
        collapseLabel: copy.text('Hide details'),
        items: <BeautifulThinkingItem>[
          BeautifulThinkingItem(
            id: 'edit',
            label: copy.text('Update stock.ts'),
            detail: 'stock.ts',
            additions: 2,
            deletions: 1,
          ),
          BeautifulThinkingItem(
            id: 'test',
            label: copy.text('Verify output'),
            detail: copy.text('Tests passed'),
          ),
        ],
        onExpandedChanged: (_) {},
        onItemPressed: (_) {},
      ),
    ),
  ]),
  'context-cards': () => BeautifulContextCards(
    headerLabel: copy.text('Reference notes'),
    expandLabel: copy.text('Show more'),
    collapseLabel: copy.text('Show less'),
    openSourceLabel: copy.text('Open source'),
    chunks: <BeautifulContextChunk>[
      BeautifulContextChunk(
        id: 'stock',
        title: copy.text('Stock report'),
        characterCountLabel: copy.text('34 characters'),
        body: copy.text('Stock covers the weekend forecast.'),
        sourceLabel: 'stock.csv',
        sourceBadge: 'CSV',
        tone: BeautifulContextTone.success,
      ),
      BeautifulContextChunk(
        id: 'supplier',
        title: copy.text('Supplier check'),
        characterCountLabel: copy.text('42 characters'),
        body: copy.text('Verify cold storage before the next order.'),
        sourceLabel: 'supplier.pdf',
        sourceBadge: 'PDF',
        tone: BeautifulContextTone.destructive,
      ),
    ],
    onSourcePressed: (_) {},
  ),
  'recommendation-card': () => BeautifulRecommendationCard(
    title: copy.text('Prepare the next order?'),
    initialOptionId: 'draft',
    alternativesLabel: copy.text('Alternatives'),
    otherOptionsLabel: copy.text('Other options'),
    pendingLabel: copy.text('Accepting'),
    acceptedLabel: copy.text('Accepted'),
    options: <BeautifulRecommendationOption>[
      BeautifulRecommendationOption(
        id: 'draft',
        body: copy.text('Draft an order for the weekly stock review.'),
        shortLabel: copy.text('Draft the stock order'),
        signal: 3,
        tone: BeautifulRecommendationTone.success,
        confidenceLabel: copy.text('High confidence'),
        actionLabel: copy.text('Accept'),
      ),
      BeautifulRecommendationOption(
        id: 'review',
        body: copy.text('Check supplier lead times before ordering.'),
        shortLabel: copy.text('Review lead times'),
        signal: 2,
        tone: BeautifulRecommendationTone.warning,
        confidenceLabel: copy.text('Needs review'),
        actionLabel: copy.text('Review'),
      ),
    ],
    onAccept: (_) {},
  ),
  'search': () => BeautifulSearch(
    initialQuery: copy.text('plan'),
    placeholder: copy.text('Search stock plans'),
    clearLabel: copy.text('Clear search'),
    emptyTitle: copy.text('No results'),
    emptyHint: copy.text('Try another query'),
    searchLabel: copy.text('Search stock plans'),
    items: <BeautifulSearchItem>[
      BeautifulSearchItem(id: 'draft', title: copy.text('Draft stock plan')),
      BeautifulSearchItem(id: 'review', title: copy.text('Review stock plan')),
    ],
    onSelected: (_) {},
    onQueryChanged: (_) {},
  ),
  'code-block': () => _matrixVariantSections(<(String, Widget)>[
    (
      'Code',
      BeautifulCodeBlock.code(
        filename: 'stock.ts',
        copyLabel: copy.text('Copy'),
        copyingLabel: copy.text('Copying'),
        copiedLabel: copy.text('Copied'),
        copyFailedLabel: copy.text('Copy failed'),
        code: 'stock = 12;\nreturn stock;',
        onCopy: (_) {},
      ),
    ),
    (
      'Diff',
      BeautifulCodeBlock.diff(
        filename: 'stock.ts',
        lines: <BeautifulDiffLine>[
          BeautifulDiffLine(
            oldLineNumber: 1,
            kind: BeautifulDiffLineKind.removed,
            pieces: <BeautifulCodePiece>[
              BeautifulCodePiece(
                text: 'stock = 8;',
                change: BeautifulDiffLineKind.removed,
              ),
            ],
          ),
          BeautifulDiffLine(
            newLineNumber: 1,
            kind: BeautifulDiffLineKind.added,
            pieces: <BeautifulCodePiece>[
              BeautifulCodePiece(
                text: 'stock = 12;',
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
    labels: BeautifulStreamingLabels(
      streaming: copy.text('Working'),
      complete: copy.text('Completed'),
      failed: copy.text('Failed'),
      copy: copy.text('Copy'),
      copying: copy.text('Copying'),
      copied: copy.text('Copied'),
      copyFailed: copy.text('Copy failed'),
      retry: copy.text('Retry'),
      retrying: copy.text('Retrying'),
      sources: copy.text('Sources'),
      followUps: copy.text('Follow-ups'),
      positiveFeedback: copy.text('Helpful'),
      negativeFeedback: copy.text('Unhelpful'),
    ),
    status: BeautifulStreamingStatus.complete,
    content: <BeautifulStreamingPart>[
      BeautifulStreamingPart.text(
        copy.text(
          'Stock covers the weekend. Review supplier lead times today. ',
        ),
      ),
      BeautifulStreamingPart.citation('stock'),
    ],
    sources: <BeautifulStreamingSource>[
      BeautifulStreamingSource(
        id: 'stock',
        title: 'stock.csv',
        detail: copy.text('Daily export'),
      ),
    ],
    followUps: <BeautifulStreamingFollowUp>[
      BeautifulStreamingFollowUp(id: 'draft', label: copy.text('Draft order')),
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
    skipLabel: copy.text('Skip'),
    continueLabel: copy.text('Continue'),
    sendLabel: copy.text('Send'),
    pendingLabel: copy.text('Sending'),
    sentLabel: copy.text('Answers sent'),
    resetLabel: copy.text('Start over'),
    dismissLabel: copy.text('Dismiss'),
    openLabel: copy.text('Open approval'),
    previousLabel: copy.text('Previous'),
    nextLabel: copy.text('Next'),
    customPlaceholder: copy.text('Custom answer'),
    autoAdvance: false,
    questions: <BeautifulApprovalQuestion>[
      BeautifulApprovalQuestion(
        id: 'details',
        title: copy.text('Choose order details'),
        type: BeautifulApprovalQuestionType.multipleChoice,
        options: <BeautifulApprovalOption>[
          BeautifulApprovalOption(
            id: 'stock',
            label: copy.text('Stock report'),
          ),
          BeautifulApprovalOption(
            id: 'lead-time',
            label: copy.text('Lead times'),
          ),
        ],
      ),
      BeautifulApprovalQuestion(
        id: 'delivery',
        title: copy.text('Prepare a draft?'),
        allowCustomAnswer: false,
        options: <BeautifulApprovalOption>[
          BeautifulApprovalOption(
            id: 'draft',
            label: copy.text('Save for review'),
          ),
          BeautifulApprovalOption(
            id: 'send',
            label: copy.text('Send to supplier'),
          ),
        ],
      ),
    ],
    initialAnswers: <BeautifulApprovalAnswer>[
      BeautifulApprovalAnswer(
        questionId: 'details',
        optionIds: <String>['stock'],
      ),
    ],
    onAnswerChanged: (_) {},
    onSubmit: (_) {},
  ),
  'tool-chips': () => BeautifulToolChips(
    headerLabel: copy.text('2 tool calls'),
    showMoreLabel: copy.text('Show more'),
    showLessLabel: copy.text('Show less'),
    initiallyExpanded: true,
    steps: <BeautifulToolStep>[
      BeautifulToolStep(
        id: 'read',
        label: copy.text('Read stock'),
        chip: 'stock.csv',
        kind: BeautifulToolKind.read,
        statusLabel: copy.text('Completed'),
        mono: false,
        detailMono: false,
        details: <BeautifulToolDetailLine>[
          BeautifulToolDetailLine(text: copy.text('2 records matched.')),
        ],
      ),
      BeautifulToolStep(
        id: 'write',
        label: copy.text('Save order'),
        chip: 'order.md',
        kind: BeautifulToolKind.write,
        status: BeautifulToolStatus.failed,
        statusLabel: copy.text('Failed'),
        mono: false,
        detailMono: false,
        details: <BeautifulToolDetailLine>[
          BeautifulToolDetailLine(text: copy.text('Save requires retry.')),
        ],
      ),
    ],
    diffs: <BeautifulToolDiff>[
      BeautifulToolDiff(
        id: 'order',
        file: 'order.md',
        additions: 1,
        deletions: 1,
        lines: <BeautifulToolDetailLine>[
          BeautifulToolDetailLine(
            text: copy.text('Order 8 units.'),
            tone: BeautifulToolLineTone.deletion,
          ),
          BeautifulToolDetailLine(
            text: copy.text('Order 12 units.'),
            tone: BeautifulToolLineTone.addition,
          ),
        ],
      ),
    ],
    onExpandedChanged: (_) {},
    onStepExpandedChanged: (_, _) {},
    onDiffExpandedChanged: (_, _) {},
  ),
  'task-rows': () => _matrixVariantSections(<(String, Widget)>[
    (
      'Capsules / complete and running',
      BeautifulTaskRows(
        pendingLabel: copy.text('Pending'),
        runningLabel: copy.text('Working'),
        completedLabel: copy.text('Completed'),
        failedLabel: copy.text('Failed'),
        retryLabel: copy.text('Retry'),
        retryingLabel: copy.text('Retrying'),
        stepLabel: copy.text('Step'),
        emptyLabel: copy.text('No tasks'),
        rows: <BeautifulTaskRow>[
          BeautifulTaskRow(
            id: 'verify',
            label: copy.text('Verify stock'),
            amountLabel: copy.text('2 records'),
            status: BeautifulTaskStatus.completed,
          ),
          BeautifulTaskRow(
            id: 'prepare',
            label: copy.text('Prepare order'),
            amountLabel: copy.text('12 units'),
            status: BeautifulTaskStatus.running,
            step: 2,
            progress: 0.65,
            details: <BeautifulTaskDetail>[
              BeautifulTaskDetail(
                id: 'lead-time',
                label: copy.text('Check lead time'),
                meta: copy.text('7 days'),
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
        pendingLabel: copy.text('Pending'),
        runningLabel: copy.text('Working'),
        completedLabel: copy.text('Completed'),
        failedLabel: copy.text('Failed'),
        retryLabel: copy.text('Retry'),
        retryingLabel: copy.text('Retrying'),
        stepLabel: copy.text('Step'),
        emptyLabel: copy.text('No tasks'),
        variant: BeautifulTaskRowsVariant.list,
        rows: <BeautifulTaskRow>[
          BeautifulTaskRow(
            id: 'review',
            label: copy.text('Review draft'),
            amountLabel: copy.text('1 order'),
            status: BeautifulTaskStatus.pending,
            step: 3,
          ),
          BeautifulTaskRow(
            id: 'save',
            label: copy.text('Save order'),
            amountLabel: copy.text('1 file'),
            status: BeautifulTaskStatus.failed,
          ),
        ],
        onRetry: (_) {},
      ),
    ),
  ]),
  'chat': () => BeautifulChat(
    conversationId: 'stock-review',
    placeholder: copy.text('Write a message'),
    composerLabel: copy.text('Chat prompt'),
    sendLabel: copy.text('Send'),
    sendingLabel: copy.text('Sending'),
    stopLabel: copy.text('Stop'),
    stoppingLabel: copy.text('Stopping'),
    respondingLabel: copy.text('Working'),
    emptyLabel: copy.text('No messages'),
    latestLabel: copy.text('Latest'),
    userLabel: copy.text('You'),
    assistantLabel: copy.text('Assistant'),
    systemLabel: copy.text('System'),
    resolvingLabel: copy.text('Working'),
    height: 620,
    initialDraft: copy.text('Prepare a draft.'),
    tabs: <BeautifulChatTab>[
      BeautifulChatTab(id: 'stock', label: copy.text('Stock')),
      BeautifulChatTab(id: 'suppliers', label: copy.text('Suppliers')),
    ],
    selectedTabId: 'stock',
    messages: <BeautifulChatMessage>[
      BeautifulChatMessage(
        id: 'question',
        role: BeautifulChatRole.user,
        text: copy.text('What needs ordering?'),
      ),
      BeautifulChatMessage(
        id: 'answer',
        role: BeautifulChatRole.assistant,
        title: copy.text('Stock review'),
        subtitle: copy.text('Daily export'),
        detailLabel: copy.text('4 seconds'),
        text: copy.text('Order 12 units for next week.'),
      ),
    ],
    onTabChanged: (_) {},
    onSend: (_) {},
    onStop: (_) {},
  ),
  'filter-table': () => BeautifulFilterTable(
    labels: BeautifulFilterTableLabels(
      all: copy.text('All'),
      todo: copy.text('Pending'),
      inProgress: copy.text('Working'),
      completed: copy.text('Completed'),
      taskColumn: copy.text('Task'),
      dateColumn: copy.text('Date'),
      statusColumn: copy.text('Status'),
      ownerColumn: copy.text('Owner'),
      table: copy.text('Tasks'),
      results: copy.text('Results'),
      empty: copy.text('No tasks'),
    ),
    rows: <BeautifulFilterTableRow>[
      BeautifulFilterTableRow(
        id: 'check',
        task: copy.text('Verify stock'),
        date: copy.text('Sep 03'),
        status: BeautifulFilterTableStatus.completed,
        owner: copy.text('Operations'),
      ),
      BeautifulFilterTableRow(
        id: 'draft',
        task: copy.text('Draft order'),
        date: copy.text('Sep 04'),
        status: BeautifulFilterTableStatus.inProgress,
        owner: copy.text('Purchasing'),
      ),
    ],
    onFilterChanged: (_) {},
  ),
  'fine-tune-card': () => BeautifulFineTuneCard(
    labels: BeautifulFineTuneLabels(
      title: copy.text('Stock card'),
      layout: copy.text('Layout'),
      type: copy.text('Type'),
      placeholder: copy.text('Select type'),
      adjust: copy.text('Adjust'),
      edited: copy.text('Edited'),
      row: copy.text('Row'),
      column: copy.text('Column'),
      grid: copy.text('Grid'),
      increase: copy.text('Increase'),
      decrease: copy.text('Decrease'),
      value: copy.text('Value'),
      invalidNumber: copy.text('Invalid number'),
    ),
    settings: BeautifulFineTuneSettings(
      layout: BeautifulFineTuneLayout.grid,
      typeId: 'standard',
      fields: <BeautifulFineTuneField>[
        BeautifulFineTuneField(
          id: 'width',
          label: copy.text('Width'),
          value: 160,
          min: 40,
          max: 400,
        ),
        BeautifulFineTuneField(
          id: 'opacity',
          label: copy.text('Opacity'),
          value: 80,
          min: 0,
          max: 100,
          suffix: '%',
        ),
      ],
    ),
    options: <BeautifulFineTuneOption>[
      BeautifulFineTuneOption(id: 'standard', label: copy.text('Standard')),
      BeautifulFineTuneOption(id: 'compact', label: copy.text('Compact')),
    ],
    onChanged: (_) {},
  ),
};

Widget _matrixVariantSections(List<(String, Widget)> sections) => Builder(
  builder: (context) {
    final theme = BeautifulUiTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < sections.length; index++) ...<Widget>[
          if (index > 0) SizedBox(height: 24),
          Text(
            sections[index].$1,
            style: theme.typography.caption.copyWith(
              color: theme.colors.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          sections[index].$2,
        ],
      ],
    );
  },
);

/// Host-supplied localized strings for the complementary acceptance matrix.
final class MatrixCopy {
  const MatrixCopy(this.language);
  final String language;
  String text(String key) {
    final values = _matrixText[key];
    if (values == null) return key;
    return values[switch (language) {
      'zh' => 1,
      'ar' => 2,
      _ => 0,
    }];
  }
}

const _matrixText = <String, List<String>>{
  "Preparing sources": [
    "Preparing supplier sources for the complete seasonal inventory review",
    "正在准备季节性库存审核所需的供应商资料",
    "جارٍ إعداد مصادر الموردين لمراجعة المخزون الموسمي بالكامل",
  ],
  "Checking stock": [
    "Checking stock against the upcoming seasonal demand forecast",
    "正在按下季度的需求预测检查现有库存",
    "جارٍ التحقق من المخزون وفق توقعات الطلب للموسم القادم",
  ],
  "Stock checked": [
    "Seasonal stock verification completed",
    "已完成季节性库存核验",
    "اكتمل التحقق من المخزون الموسمي",
  ],
  "Read stock report": [
    "Read the regional inventory report before preparing the next order",
    "请先阅读各地区的库存报告，再准备下一份采购订单",
    "اقرأ تقرير المخزون الإقليمي قبل إعداد طلب الشراء التالي",
  ],
  "Verify supplier": [
    "Verify supplier availability and delivery constraints before approval",
    "批准采购前，请核对供应商供货能力及交付限制",
    "تحقق من توافر المورد وقيود التسليم قبل الموافقة",
  ],
  "2 records": [
    "Two supplier records require a detailed review",
    "两条供应商记录需要详细复核",
    "سجلان للموردين يحتاجان إلى مراجعة تفصيلية",
  ],
  "Updating plan": [
    "Searching the supplier directory for verified delivery options",
    "正在供应商目录中查找已经验证的交付方案",
    "جارٍ البحث في دليل الموردين عن خيارات تسليم موثوقة",
  ],
  "Plan updated": [
    "Supplier search completed with two matching records",
    "供应商搜索完成，找到两条匹配记录",
    "اكتمل البحث عن الموردين مع العثور على سجلين مطابقين",
  ],
  "Update stock.ts": [
    "Compare the supplier availability for the seasonal launch",
    "比较各供应商为季节性产品发布提供的供货能力",
    "قارن توافر الموردين من أجل إطلاق المنتجات الموسمية",
  ],
  "Verify output": [
    "Verify the returned supplier evidence before accepting the result",
    "接受搜索结果之前，请核对返回的供应商依据",
    "تحقق من أدلة الموردين قبل قبول النتيجة",
  ],
  "Tests passed": [
    "Verification checks passed for both supplier records",
    "两条供应商记录均已通过核验",
    "نجحت فحوص التحقق لكلا سجلي الموردين",
  ],
  "Reference notes": [
    "Reference notes supporting the regional purchasing decision",
    "支持地区采购决策的参考资料",
    "ملاحظات مرجعية تدعم قرار الشراء الإقليمي",
  ],
  "Stock report": [
    "Seasonal inventory report for the regional purchasing team",
    "供地区采购团队使用的季节性库存报告",
    "تقرير المخزون الموسمي لفريق المشتريات الإقليمي",
  ],
  "34 characters": [
    "Updated September 3 · 34 characters",
    "9月3日更新 · 34个字符",
    "تم التحديث في ٣ سبتمبر · ٣٤ حرفًا",
  ],
  "Stock covers the weekend forecast.": [
    "Current stock covers the weekend forecast. Check the colder storage requirements and the remaining shelf life before assigning inventory to the next supplier order.",
    "现有库存能够满足本周末的需求预测。分配下一份供应商订单之前，请核对低温储存要求和剩余保质期，确保交付计划与门店实际需求一致。",
    "يغطي المخزون الحالي توقعات عطلة نهاية الأسبوع. راجع متطلبات التخزين المبرد والمدة المتبقية للصلاحية قبل تخصيص المخزون لطلب المورد التالي.",
  ],
  "Supplier check": [
    "Supplier compliance and delivery-window verification",
    "供应商合规性与交付时段核验",
    "التحقق من امتثال المورد وموعد التسليم",
  ],
  "42 characters": [
    "Updated September 4 · 42 characters",
    "9月4日更新 · 42个字符",
    "تم التحديث في ٤ سبتمبر · ٤٢ حرفًا",
  ],
  "Verify cold storage before the next order.": [
    "Verify cold storage before the next order. The receiving team needs the full delivery window and a valid temperature certificate, including notes about any exceptions.",
    "下单前请核对冷链储存条件。收货团队需要完整的交付时段、有效的温度证明，以及任何例外情况的说明，以便安排核验和入库。",
    "تحقق من التخزين المبرد قبل الطلب التالي. يحتاج فريق الاستلام إلى موعد التسليم الكامل وشهادة حرارة سارية، مع توضيح أي حالات استثنائية.",
  ],
  "Prepare the next order?": [
    "Prepare the next seasonal stock order for a final purchasing review?",
    "是否准备下一份季节性库存订单，供采购团队进行最终审核？",
    "هل تريد إعداد طلب المخزون الموسمي التالي للمراجعة النهائية؟",
  ],
  "Draft an order for the weekly stock review.": [
    "Draft the order for the weekly stock review, keeping the supplier quantities and expected delivery dates available for the purchasing team to confirm.",
    "为每周库存审核起草订单，保留供应商数量和预计交付日期，方便采购团队逐项确认。",
    "أنشئ مسودة الطلب للمراجعة الأسبوعية، مع إبقاء كميات الموردين ومواعيد التسليم المتوقعة متاحة للتأكيد.",
  ],
  "Draft the stock order": [
    "Draft the seasonal stock order for final review",
    "起草季节性库存订单，提交最终审核",
    "إعداد مسودة طلب المخزون للمراجعة النهائية",
  ],
  "High confidence": [
    "High confidence from verified supplier evidence",
    "依据已验证的供应商资料，可信度较高",
    "ثقة عالية استنادًا إلى أدلة الموردين الموثقة",
  ],
  "Accept": [
    "Accept the recommended order",
    "接受推荐的采购订单",
    "قبول طلب الشراء المقترح",
  ],
  "Check supplier lead times before ordering.": [
    "Check the complete supplier lead times and delivery exceptions before creating an order that the receiving team will need to schedule.",
    "创建订单前，请核对完整的供应商备货周期和交付例外，便于收货团队安排接收。",
    "تحقق من مهلة التوريد والاستثناءات المتعلقة بالتسليم قبل إنشاء الطلب الذي سيجدوله فريق الاستلام.",
  ],
  "Review lead times": [
    "Review supplier lead times and delivery exceptions",
    "审核供应商备货周期及交付例外",
    "مراجعة مهلة المورد والاستثناءات في التسليم",
  ],
  "Needs review": [
    "Needs an additional purchasing review",
    "仍需采购团队进一步审核",
    "يحتاج إلى مراجعة إضافية من فريق المشتريات",
  ],
  "Review": ["Review the supplier evidence", "审核供应商依据", "مراجعة أدلة الموردين"],
  "plan": ["plan", "计划", "خطة"],
  "Search stock plans": [
    "Search the complete regional inventory plans",
    "搜索完整的地区库存计划",
    "البحث في خطط المخزون الإقليمية الكاملة",
  ],
  "Draft stock plan": [
    "Draft stock plan for the northern stores and delivery team",
    "为北部门店及配送团队起草库存计划",
    "إعداد خطة المخزون للمتاجر الشمالية وفريق التسليم",
  ],
  "Review stock plan": [
    "Review stock plan for seasonal demand and delivery exceptions",
    "审核季节性需求与交付例外的库存计划",
    "مراجعة خطة المخزون للطلب الموسمي واستثناءات التسليم",
  ],
  "Stock covers the weekend. Review supplier lead times today. ": [
    "Stock covers the coming weekend. Review the complete supplier lead times and the temperature requirements before confirming the next delivery. ",
    "现有库存能够满足本周末的需求。确认下次交付之前，请核对完整的供应商备货周期和冷链温度要求。",
    "يغطي المخزون عطلة نهاية الأسبوع القادمة. راجع مهلة التوريد الكاملة ومتطلبات الحرارة قبل تأكيد موعد التسليم التالي. ",
  ],
  "Daily export": [
    "Daily export from the regional inventory system",
    "地区库存系统每日导出数据",
    "تصدير يومي من نظام المخزون الإقليمي",
  ],
  "Draft order": [
    "Draft a purchase order from this evidence",
    "根据这些资料起草采购订单",
    "إعداد طلب شراء استنادًا إلى هذه الأدلة",
  ],
  "Choose order details": [
    "Choose the order details that the purchasing team should review",
    "请选择采购团队需要审核的订单明细",
    "اختر تفاصيل الطلب التي يجب أن يراجعها فريق المشتريات",
  ],
  "Lead times": [
    "Supplier lead times and receiving windows",
    "供应商备货周期与收货时段",
    "مهلة الموردين وفترات الاستلام",
  ],
  "Prepare a draft?": [
    "Prepare a draft for another person to review before sending?",
    "是否先准备草稿，让其他人员审核后再发送？",
    "هل تريد إعداد مسودة ليراجعها شخص آخر قبل الإرسال؟",
  ],
  "Save for review": [
    "Save the draft for purchasing review",
    "保存草稿，等待采购审核",
    "حفظ المسودة لمراجعة المشتريات",
  ],
  "Send to supplier": [
    "Send the approved order to the selected supplier",
    "将已批准订单发送给选定供应商",
    "إرسال الطلب المعتمد إلى المورد المحدد",
  ],
  "2 tool calls": [
    "Two tool calls supporting the inventory review",
    "支持库存审核的两次工具调用",
    "استدعاءان للأدوات لدعم مراجعة المخزون",
  ],
  "Read stock": [
    "Read the latest regional inventory export",
    "读取最新的地区库存导出数据",
    "قراءة أحدث بيانات المخزون الإقليمي",
  ],
  "2 records matched.": [
    "Two records matched the exact supplier and delivery constraints. Both original values remain available for review.",
    "两条记录完全符合供应商和交付限制，原始数据均保留供审核使用。",
    "تطابق سجلان مع قيود المورد والتسليم بدقة. تظل القيم الأصلية متاحة للمراجعة.",
  ],
  "Save order": [
    "Save the approved seasonal purchase order",
    "保存已批准的季节性采购订单",
    "حفظ طلب الشراء الموسمي المعتمد",
  ],
  "Save requires retry.": [
    "Saving was interrupted. Review the existing draft and retry without duplicating the supplier order.",
    "保存过程已中断。请检查现有草稿后重试，避免重复创建供应商订单。",
    "توقفت عملية الحفظ. راجع المسودة الحالية وأعد المحاولة دون تكرار طلب المورد.",
  ],
  "Order 8 units.": [
    "Order 8 units for the next delivery window.",
    "为下一交付时段订购8件。",
    "طلب ٨ وحدات لموعد التسليم التالي.",
  ],
  "Order 12 units.": [
    "Order 12 units for the next delivery window.",
    "为下一交付时段订购12件。",
    "طلب ١٢ وحدة لموعد التسليم التالي.",
  ],
  "Verify stock": [
    "Verify regional stock and remaining shelf life",
    "核对地区库存和剩余保质期",
    "التحقق من المخزون الإقليمي والصلاحية المتبقية",
  ],
  "Prepare order": [
    "Prepare the next seasonal supplier order",
    "准备下一份季节性供应商订单",
    "إعداد طلب المورد الموسمي التالي",
  ],
  "12 units": [
    "12 units across the regional stores",
    "共12件，分配至各地区门店",
    "١٢ وحدة موزعة على المتاجر الإقليمية",
  ],
  "Check lead time": [
    "Check the receiving window and supplier lead time",
    "核对收货时段及供应商备货周期",
    "التحقق من وقت الاستلام ومهلة المورد",
  ],
  "7 days": [
    "Seven working days before the requested delivery",
    "距预计交付日期还有7个工作日",
    "سبعة أيام عمل قبل موعد التسليم المطلوب",
  ],
  "Review draft": [
    "Review the full purchasing draft before submission",
    "提交前审核完整采购草稿",
    "مراجعة مسودة المشتريات كاملة قبل الإرسال",
  ],
  "1 order": [
    "One seasonal purchase order",
    "一份季节性采购订单",
    "طلب شراء موسمي واحد",
  ],
  "1 file": [
    "One supplier order document",
    "一份供应商订单文档",
    "مستند واحد لطلب المورد",
  ],
  "Prepare a draft.": [
    "Prepare a draft with supplier quantities and delivery notes.",
    "请准备一份包含供应商数量及交付备注的草稿。",
    "أعد مسودة تتضمن كميات الموردين وملاحظات التسليم.",
  ],
  "Stock": ["Regional stock", "地区库存", "المخزون الإقليمي"],
  "Suppliers": ["Verified suppliers", "已验证供应商", "الموردون الموثقون"],
  "What needs ordering?": [
    "Which products need ordering before the next seasonal launch?",
    "下次季节性产品发布前，需要订购哪些产品？",
    "ما المنتجات التي يجب طلبها قبل الإطلاق الموسمي التالي؟",
  ],
  "Stock review": [
    "Regional inventory and purchasing review",
    "地区库存与采购审核",
    "مراجعة المخزون والمشتريات الإقليمية",
  ],
  "4 seconds": [
    "Prepared in four seconds",
    "用时4秒完成",
    "تم الإعداد خلال أربع ثوانٍ",
  ],
  "Order 12 units for next week.": [
    "Order 12 units for next week. Keep the supplier lead time and storage certificate attached for the receiving team.",
    "为下周订购12件商品，并保留供应商备货周期和储存证明，供收货团队核验。",
    "اطلب ١٢ وحدة للأسبوع القادم، وأرفق مهلة المورد وشهادة التخزين ليتحقق منهما فريق الاستلام.",
  ],
  "Sep 03": ["September 03, 2026", "2026年9月3日", "٣ سبتمبر ٢٠٢٦"],
  "Sep 04": ["September 04, 2026", "2026年9月4日", "٤ سبتمبر ٢٠٢٦"],
  "Operations": [
    "Regional operations coordinator",
    "地区运营协调人员",
    "منسق العمليات الإقليمية",
  ],
  "Purchasing": [
    "Purchasing review coordinator",
    "采购审核协调人员",
    "منسق مراجعة المشتريات",
  ],
  "Stock card": [
    "Regional inventory card settings",
    "地区库存卡片设置",
    "إعدادات بطاقة المخزون الإقليمي",
  ],
  "Width": ["Preferred card width", "卡片首选宽度", "العرض المفضل للبطاقة"],
  "Opacity": ["Background opacity", "背景不透明度", "عتامة الخلفية"],
  "Standard": ["Standard inventory summary", "标准库存摘要", "ملخص المخزون القياسي"],
  "Compact": ["Compact inventory summary", "紧凑库存摘要", "ملخص المخزون المختصر"],
  "Elapsed time": ["Elapsed time", "已用时间", "الوقت المنقضي"],
  "Media unavailable": [
    "Licensed media is unavailable",
    "暂无获授权的媒体内容",
    "الوسائط المرخصة غير متاحة",
  ],
  "Show details": ["Show complete details", "显示完整详情", "عرض التفاصيل كاملة"],
  "Hide details": ["Hide complete details", "收起完整详情", "إخفاء التفاصيل الكاملة"],
  "Show more": ["Show the complete content", "显示完整内容", "عرض المحتوى الكامل"],
  "Show less": ["Show less content", "收起部分内容", "عرض محتوى أقل"],
  "Open source": ["Open the source document", "打开来源文档", "فتح المستند المصدر"],
  "Alternatives": [
    "Compare alternative proposals",
    "比较其他备选方案",
    "مقارنة المقترحات البديلة",
  ],
  "Other options": [
    "Alternative purchasing proposals",
    "其他采购备选方案",
    "مقترحات شراء بديلة",
  ],
  "Accepting": ["Accepting the proposal…", "正在接受方案…", "جارٍ قبول المقترح…"],
  "Accepted": ["Proposal accepted", "方案已接受", "تم قبول المقترح"],
  "Clear search": ["Clear the search query", "清除搜索条件", "مسح استعلام البحث"],
  "No results": [
    "No matching results found",
    "没有找到匹配结果",
    "لم يتم العثور على نتائج مطابقة",
  ],
  "Try another query": [
    "Try another supplier or inventory query",
    "请尝试其他供应商或库存条件",
    "جرّب استعلامًا آخر عن المورد أو المخزون",
  ],
  "Copy": ["Copy complete content", "复制完整内容", "نسخ المحتوى الكامل"],
  "Copying": ["Copying content…", "正在复制内容…", "جارٍ نسخ المحتوى…"],
  "Copied": ["Content copied", "内容已复制", "تم نسخ المحتوى"],
  "Copy failed": ["Could not copy content", "无法复制内容", "تعذر نسخ المحتوى"],
  "Working": ["Work in progress", "正在处理中", "العمل قيد التنفيذ"],
  "Completed": ["Work completed", "已完成处理", "اكتمل العمل"],
  "Failed": ["Action requires review", "操作需要复核", "الإجراء يحتاج إلى مراجعة"],
  "Retry": [
    "Retry the interrupted action",
    "重试已中断操作",
    "إعادة محاولة الإجراء المتوقف",
  ],
  "Retrying": ["Retrying action…", "正在重试操作…", "جارٍ إعادة المحاولة…"],
  "Sources": ["Reference sources", "参考来源", "المصادر المرجعية"],
  "Follow-ups": [
    "Suggested next actions",
    "建议的下一步操作",
    "الإجراءات التالية المقترحة",
  ],
  "Helpful": ["This answer was helpful", "这条回答有帮助", "كانت هذه الإجابة مفيدة"],
  "Unhelpful": [
    "This answer needs improvement",
    "这条回答需要改进",
    "هذه الإجابة تحتاج إلى تحسين",
  ],
  "Skip": ["Skip this question", "跳过此问题", "تخطي هذا السؤال"],
  "Continue": [
    "Continue to the next question",
    "继续下一问题",
    "المتابعة إلى السؤال التالي",
  ],
  "Send": ["Send for purchasing review", "发送至采购审核", "إرسال لمراجعة المشتريات"],
  "Sending": ["Sending answers…", "正在发送答案…", "جارٍ إرسال الإجابات…"],
  "Answers sent": [
    "Answers successfully submitted",
    "答案已成功提交",
    "تم إرسال الإجابات بنجاح",
  ],
  "Start over": ["Start a new review", "开始新一轮审核", "بدء مراجعة جديدة"],
  "Dismiss": ["Dismiss this review", "关闭此次审核", "إغلاق هذه المراجعة"],
  "Open approval": [
    "Open the approval questions",
    "打开审核问题",
    "فتح أسئلة الموافقة",
  ],
  "Previous": ["Previous question", "上一问题", "السؤال السابق"],
  "Next": ["Next question", "下一问题", "السؤال التالي"],
  "Custom answer": ["Enter a different answer", "输入其他答案", "أدخل إجابة مختلفة"],
  "Pending": ["Awaiting review", "等待审核", "في انتظار المراجعة"],
  "Step": ["Workflow step", "工作流步骤", "خطوة سير العمل"],
  "No tasks": ["No matching tasks", "没有匹配的任务", "لا توجد مهام مطابقة"],
  "Write a message": [
    "Write a message for the purchasing team",
    "给采购团队留言",
    "اكتب رسالة لفريق المشتريات",
  ],
  "Chat prompt": [
    "Purchasing conversation prompt",
    "采购会话输入",
    "رسالة محادثة المشتريات",
  ],
  "Stop": ["Stop the current response", "停止当前回答", "إيقاف الإجابة الحالية"],
  "Stopping": ["Stopping response…", "正在停止回答…", "جارٍ إيقاف الإجابة…"],
  "No messages": [
    "Start a purchasing conversation",
    "开始采购会话",
    "بدء محادثة المشتريات",
  ],
  "Latest": ["Return to the latest message", "返回最新消息", "العودة إلى أحدث رسالة"],
  "You": ["You", "你", "أنت"],
  "Assistant": ["Assistant", "助手", "المساعد"],
  "System": ["System", "系统", "النظام"],
  "All": ["All tasks", "全部任务", "جميع المهام"],
  "Task": ["Task description", "任务说明", "وصف المهمة"],
  "Date": ["Delivery date", "交付日期", "تاريخ التسليم"],
  "Status": ["Current status", "当前状态", "الحالة الحالية"],
  "Owner": ["Responsible team", "负责团队", "الفريق المسؤول"],
  "Tasks": ["Purchasing tasks", "采购任务", "مهام المشتريات"],
  "Results": ["Matching tasks", "匹配任务", "المهام المطابقة"],
  "Layout": ["Card arrangement", "卡片排列", "ترتيب البطاقات"],
  "Type": ["Inventory card type", "库存卡片类型", "نوع بطاقة المخزون"],
  "Select type": [
    "Select the inventory card type",
    "选择库存卡片类型",
    "اختر نوع بطاقة المخزون",
  ],
  "Adjust": ["Adjust the settings", "调整设置", "تعديل الإعدادات"],
  "Edited": ["Settings have changed", "设置已更改", "تم تغيير الإعدادات"],
  "Row": ["Horizontal row", "水平行排列", "صف أفقي"],
  "Column": ["Vertical column", "垂直列排列", "عمود رأسي"],
  "Grid": ["Grid arrangement", "网格排列", "ترتيب شبكي"],
  "Increase": ["Increase", "增加", "زيادة"],
  "Decrease": ["Decrease", "减少", "تقليل"],
  "Value": ["Numeric value", "数值", "القيمة الرقمية"],
  "Invalid number": [
    "Enter a valid finite number",
    "请输入有效的有限数值",
    "أدخل رقمًا صحيحًا محدودًا",
  ],
};
