import 'package:beautiful_ai_ui/beautiful_ai_ui.dart';
import 'package:flutter/widgets.dart';

/// Real host-authored copy used by the finite P3 acceptance matrix.
enum P3ReviewLanguage { english, chinese, arabic }

/// Keeps fixture translations independent of package implementation strings.
final class P3ReviewCopy {
  const P3ReviewCopy(this.language);
  final P3ReviewLanguage language;

  String t(String english, String chinese, String arabic) => switch (language) {
    P3ReviewLanguage.english => english,
    P3ReviewLanguage.chinese => chinese,
    P3ReviewLanguage.arabic => arabic,
  };

  TextDirection get direction => language == P3ReviewLanguage.arabic
      ? TextDirection.rtl
      : TextDirection.ltr;
  String get title => t(
    'Regional supplier delivery planning',
    '区域供应商交付计划',
    'خطة التسليم للموردين المحليين',
  );
  String get supplier =>
      t('Northern Orchard cooperative', '北方果园合作社', 'تعاونية البستان الشمالي');
  String get alternate => t(
    'Riverbank seasonal growers',
    '河畔季节性种植合作社',
    'تعاونية المزارعين الموسميين',
  );
  String get body => t(
    'Review the updated supplier delivery plan, preserve the original quantities, and confirm the arrival date before Friday.',
    '请核对供应商更新后的交付计划，保留原始采购数量，并在星期五之前确认到货日期。',
    'راجع خطة التسليم المحدّثة للمورد، واحتفظ بالكميات الأصلية، ثم أكّد موعد الوصول قبل يوم الجمعة.',
  );
  String get shortBody => t(
    'Confirm delivery before Friday.',
    '请在星期五之前确认交付。',
    'أكّد موعد التسليم قبل يوم الجمعة.',
  );
  String get replacement => t(
    'Confirm the revised delivery date today.',
    '请今天确认调整后的交付日期。',
    'أكّد موعد التسليم المعدّل اليوم.',
  );
  String get error => t(
    'The delivery review is unavailable; verify the supplier record and request a new calculation.',
    '暂时无法获取交付审核结果；请核实供应商记录，然后重新发起计算。',
    'تعذّرت مراجعة التسليم؛ تحقّق من سجل المورد ثم اطلب إجراء الحساب مجددًا.',
  );
  String get category => t('Delivery category', '交付类别', 'فئة التسليم');
  String get seasonal => t('Seasonal produce', '时令产品', 'المنتجات الموسمية');
  String get regular =>
      t('Regular deliveries', '常规交付', 'عمليات التسليم المعتادة');
  String get improve =>
      t('Improve selected wording', '改善所选文字表述', 'تحسين صياغة النص المحدّد');
  String get apply => t(
    'Apply reviewed changes',
    '应用已审核的变更',
    'تطبيق التغييرات التي تمت مراجعتها',
  );

  BeautifulSelectionLabels get selectionLabels => BeautifulSelectionLabels(
    document: t(
      'Supplier planning document',
      '供应商计划文档',
      'مستند تخطيط الموردين',
    ),
    chooseText: t(
      'Select a passage to see editing actions',
      '选择一段文字以显示编辑操作',
      'حدّد مقطعًا لعرض إجراءات التحرير',
    ),
    selectedText: t('Selected passage', '已选择的段落', 'المقطع المحدّد'),
    instruction: t(
      'Describe the intended edit',
      '描述希望进行的修改',
      'صِف التعديل المطلوب',
    ),
    send: t('Send edit instruction', '发送修改说明', 'إرسال تعليمات التعديل'),
    more: t('More editing actions', '更多编辑操作', 'المزيد من إجراءات التحرير'),
    fewer: t(
      'Fewer editing actions',
      '收起编辑操作',
      'إخفاء إجراءات التحرير الإضافية',
    ),
    working: t(
      'Preparing the selected passage',
      '正在处理所选段落',
      'جارٍ إعداد المقطع المحدّد',
    ),
    ready: t(
      'Suggestion ready for review',
      '建议已就绪，等待审核',
      'الاقتراح جاهز للمراجعة',
    ),
    applying: t(
      'Applying the reviewed edit',
      '正在应用已审核的修改',
      'جارٍ تطبيق التعديل الذي تمت مراجعته',
    ),
    applied: t(
      'The host accepted the edit',
      '宿主已接受这项修改',
      'قبل التطبيق هذا التعديل',
    ),
    before: t('Original passage', '原始段落', 'المقطع الأصلي'),
    after: t('Suggested passage', '建议段落', 'المقطع المقترح'),
    explanation: t('Explanation of the passage', '段落说明', 'شرح المقطع'),
    keep: t('Keep this change', '保留这项修改', 'الاحتفاظ بهذا التغيير'),
    discard: t('Discard this suggestion', '放弃这条建议', 'تجاهل هذا الاقتراح'),
    retry: t('Request another suggestion', '重新请求建议', 'طلب اقتراح آخر'),
    requestFailed: t(
      'A suggestion could not be prepared',
      '暂时无法生成建议',
      'تعذّر إعداد الاقتراح',
    ),
    applyFailed: t(
      'The edit could not be applied',
      '暂时无法应用修改',
      'تعذّر تطبيق التعديل',
    ),
  );

  BeautifulDiffTableLabels get diffLabels => BeautifulDiffTableLabels(
    change: t('Change description', '变更说明', 'وصف التغيير'),
    before: t('Previous value', '原有值', 'القيمة السابقة'),
    after: t('Proposed value', '建议值', 'القيمة المقترحة'),
    added: t('Added record', '新增记录', 'سجل مضاف'),
    removed: t('Removed record', '删除记录', 'سجل محذوف'),
    modified: t('Modified record', '修改记录', 'سجل معدّل'),
    unchanged: t('Unchanged record', '未变更记录', 'سجل دون تغيير'),
    absent: t('Record not present', '记录不存在', 'السجل غير موجود'),
    missingValue: t('Value not provided', '未提供值', 'القيمة غير متوفرة'),
    include: t('Include this change', '包括这项变更', 'تضمين هذا التغيير'),
    included: t('Included', '已包括', 'مُضمّن'),
    excluded: t('Excluded', '已排除', 'مُستبعد'),
    selected: t(
      'Changes selected for review',
      '已选择的待审变更',
      'التغييرات المحدّدة للمراجعة',
    ),
    apply: apply,
    applying: t(
      'Applying reviewed changes',
      '正在应用已审核变更',
      'جارٍ تطبيق التغييرات التي تمت مراجعتها',
    ),
    applied: t(
      'Changes accepted by the host',
      '宿主已接受变更',
      'قبل التطبيق التغييرات',
    ),
    applyFailed: error,
    empty: t('No records to compare', '没有可比较的记录', 'لا توجد سجلات للمقارنة'),
    previous: t('Previous review page', '上一页审核记录', 'صفحة المراجعة السابقة'),
    next: t('Next review page', '下一页审核记录', 'صفحة المراجعة التالية'),
    page: t('Review page', '审核页', 'صفحة المراجعة'),
  );

  BeautifulRecordsTableLabels get recordLabels => BeautifulRecordsTableLabels(
    table: t('Supplier records', '供应商记录', 'سجلات الموردين'),
    record: t('Supplier', '供应商', 'المورد'),
    search: t('Search supplier records', '搜索供应商记录', 'البحث في سجلات الموردين'),
    results: t('Matching records', '匹配的记录', 'السجلات المطابقة'),
    selected: t('Selected records', '已选择记录', 'السجلات المحدّدة'),
    select: t('Select record', '选择记录', 'تحديد السجل'),
    selectAll: t(
      'Select matching records',
      '选择全部匹配记录',
      'تحديد السجلات المطابقة',
    ),
    clearSelection: t(
      'Clear selected records',
      '清除已选择记录',
      'إلغاء تحديد السجلات',
    ),
    empty: t('No matching records', '没有匹配的记录', 'لا توجد سجلات مطابقة'),
    details: t('Read full details', '阅读完整详情', 'قراءة التفاصيل الكاملة'),
    close: t('Close details', '关闭详情', 'إغلاق التفاصيل'),
    properties: t('Record properties', '记录属性', 'خصائص السجل'),
    addProperty: t('Add a new property', '添加新属性', 'إضافة خاصية جديدة'),
    propertyName: t('Property name', '属性名称', 'اسم الخاصية'),
    configure: t('Configure property', '配置属性', 'إعداد الخاصية'),
    type: t('Value type', '值类型', 'نوع القيمة'),
    tool: t('Calculation tool', '计算工具', 'أداة الحساب'),
    manual: t('Enter values manually', '手动输入数值', 'إدخال القيم يدويًا'),
    inputs: t('Input properties', '输入属性', 'خصائص الإدخال'),
    prompt: t('Calculation instructions', '计算说明', 'تعليمات الحساب'),
    grounding: t('Verify with sources', '使用来源核验', 'التحقّق باستخدام المصادر'),
    groundingHelp: t(
      'Verify generated values against connected sources.',
      '依据已连接来源核验生成的数值。',
      'تحقّق من القيم المُولّدة بالرجوع إلى المصادر المتصلة.',
    ),
    moreSettings: t('Additional settings', '更多设置', 'إعدادات إضافية'),
    requiredValue: t('Require a value', '必须提供数值', 'اشتراط وجود قيمة'),
    allowEmpty: t('Allow an empty result', '允许空结果', 'السماح بنتيجة فارغة'),
    showConfidence: t('Display confidence', '显示置信度', 'عرض مستوى الثقة'),
    save: t('Save property settings', '保存属性设置', 'حفظ إعدادات الخاصية'),
    run: t('Calculate the property', '计算这项属性', 'حساب الخاصية'),
    running: t('Calculating values', '正在计算数值', 'جارٍ حساب القيم'),
    failed: t('Calculation unavailable', '暂时无法计算', 'الحساب غير متاح'),
    pending: t('Calculation in progress', '计算进行中', 'الحساب قيد التنفيذ'),
    actionFailed: error,
    saved: t('Request completed', '请求已完成', 'اكتمل الطلب'),
    invalidName: t('Enter a property name', '请输入属性名称', 'أدخل اسم الخاصية'),
    noValue: t('No value available', '暂无可用值', 'لا توجد قيمة متاحة'),
    sort: t('Sort records', '排序记录', 'ترتيب السجلات'),
    ascending: t('Ascending order', '升序', 'ترتيب تصاعدي'),
    descending: t('Descending order', '降序', 'ترتيب تنازلي'),
    pin: t('Pin this property first', '将属性固定在首位', 'تثبيت هذه الخاصية أولًا'),
    unpin: t('Unpin this property', '取消固定属性', 'إلغاء تثبيت الخاصية'),
    hide: t('Hide this property', '隐藏这项属性', 'إخفاء هذه الخاصية'),
    show: t('Show this property', '显示这项属性', 'إظهار هذه الخاصية'),
    compactColumns: t('Use compact columns', '使用紧凑列', 'استخدام أعمدة مدمجة'),
    resetWidths: t('Restore column widths', '恢复列宽', 'استعادة عرض الأعمدة'),
    resize: t('Adjust column width', '调整列宽', 'تعديل عرض العمود'),
    increaseWidth: t('Widen the column', '增大列宽', 'توسيع العمود'),
    decreaseWidth: t('Narrow the column', '减小列宽', 'تضييق العمود'),
    typeLabels: {
      BeautifulRecordPropertyType.text: t('Text', '文本', 'نص'),
      BeautifulRecordPropertyType.file: t('File', '文件', 'ملف'),
      BeautifulRecordPropertyType.collection: t('Collection', '集合', 'مجموعة'),
      BeautifulRecordPropertyType.singleSelect: t(
        'Single choice',
        '单选',
        'اختيار واحد',
      ),
      BeautifulRecordPropertyType.multiSelect: t(
        'Multiple choices',
        '多选',
        'اختيارات متعددة',
      ),
      BeautifulRecordPropertyType.url: t('Web address', '网址', 'عنوان ويب'),
      BeautifulRecordPropertyType.reference: t('Reference', '引用', 'مرجع'),
      BeautifulRecordPropertyType.json: 'JSON',
      BeautifulRecordPropertyType.fileSplitter: t(
        'Split file',
        '拆分文件',
        'تقسيم الملف',
      ),
      BeautifulRecordPropertyType.date: t('Date', '日期', 'تاريخ'),
    },
  );

  BeautifulSidebarLabels get sidebarLabels => BeautifulSidebarLabels(
    navigation: t('Workspace navigation', '工作区导航', 'التنقّل في مساحة العمل'),
    open: t(
      'Open workspace navigation',
      '打开工作区导航',
      'فتح التنقّل في مساحة العمل',
    ),
    close: t(
      'Close workspace navigation',
      '关闭工作区导航',
      'إغلاق التنقّل في مساحة العمل',
    ),
    expand: t('Expand workspace sidebar', '展开工作区侧栏', 'توسيع الشريط الجانبي'),
    collapse: t('Collapse workspace sidebar', '收起工作区侧栏', 'طيّ الشريط الجانبي'),
    workspace: t(
      'Switch active workspace',
      '切换当前工作区',
      'تبديل مساحة العمل الحالية',
    ),
    newChat: t('Start a new conversation', '开始新的对话', 'بدء محادثة جديدة'),
    chats: t('Recent conversations', '最近的对话', 'المحادثات الأخيرة'),
    search: t(
      'Search conversation history',
      '搜索对话历史',
      'البحث في سجل المحادثات',
    ),
    closeSearch: t(
      'Close conversation search',
      '关闭对话搜索',
      'إغلاق البحث في المحادثات',
    ),
    empty: t('No conversations matched', '没有匹配的对话', 'لا توجد محادثات مطابقة'),
    createWorkspace: t('Create a workspace', '创建工作区', 'إنشاء مساحة عمل'),
    workspaceSettings: t(
      'Workspace preferences',
      '工作区偏好设置',
      'تفضيلات مساحة العمل',
    ),
    invite: t(
      'Invite workspace members',
      '邀请工作区成员',
      'دعوة أعضاء إلى مساحة العمل',
    ),
    signOut: t(
      'Sign out of this workspace',
      '退出当前工作区',
      'تسجيل الخروج من مساحة العمل',
    ),
    closeWorkspaceMenu: t(
      'Close workspace menu',
      '关闭工作区菜单',
      'إغلاق قائمة مساحة العمل',
    ),
  );

  BeautifulFlowchartLabels get flowLabels => BeautifulFlowchartLabels(
    title: t('Supplier review workflow', '供应商审核流程', 'سير عمل مراجعة الموردين'),
    empty: t('No workflow steps', '暂无流程步骤', 'لا توجد خطوات لسير العمل'),
    trigger: t('Starting event', '触发事件', 'حدث البدء'),
    condition: t('Conditional branch', '条件分支', 'الفرع الشرطي'),
    steps: t('Ordered workflow steps', '有序流程步骤', 'خطوات سير العمل المرتبة'),
    canvas: t('Workflow canvas', '流程画布', 'لوحة سير العمل'),
    connectedTo: t('Continues to', '连接到', 'يتابع إلى'),
    moveLeft: t('Move step left', '向左移动步骤', 'تحريك الخطوة لليسار'),
    moveRight: t('Move step right', '向右移动步骤', 'تحريك الخطوة لليمين'),
    moveUp: t('Move step upward', '向上移动步骤', 'تحريك الخطوة للأعلى'),
    moveDown: t('Move step downward', '向下移动步骤', 'تحريك الخطوة للأسفل'),
    panLeft: t('Pan canvas left', '向左平移画布', 'تحريك اللوحة لليسار'),
    panRight: t('Pan canvas right', '向右平移画布', 'تحريك اللوحة لليمين'),
    panUp: t('Pan canvas upward', '向上平移画布', 'تحريك اللوحة للأعلى'),
    panDown: t('Pan canvas downward', '向下平移画布', 'تحريك اللوحة للأسفل'),
    zoomIn: t('Zoom into canvas', '放大画布', 'تكبير اللوحة'),
    zoomOut: t('Zoom out of canvas', '缩小画布', 'تصغير اللوحة'),
    resetView: t('Restore canvas view', '恢复画布视图', 'استعادة عرض اللوحة'),
    previousStep: t('Inspect previous step', '查看上一个步骤', 'فحص الخطوة السابقة'),
    nextStep: t('Inspect next step', '查看下一个步骤', 'فحص الخطوة التالية'),
    moveHint: t(
      'Drag or use arrow keys to move this step; hold Shift for larger movements.',
      '拖动或使用方向键移动步骤；按住 Shift 可以移动更远。',
      'اسحب الخطوة أو استخدم مفاتيح الأسهم؛ اضغط Shift للتحريك لمسافة أكبر.',
    ),
    readOnly: t('Read-only workflow', '只读流程', 'سير عمل للقراءة فقط'),
  );

  BeautifulInsightLabels get insightLabels => BeautifulInsightLabels(
    title: t('Supplier performance insights', '供应商表现洞察', 'رؤى أداء الموردين'),
    previous: t(
      'Previous performance insight',
      '上一条表现洞察',
      'الرؤية السابقة للأداء',
    ),
    next: t('Next performance insight', '下一条表现洞察', 'الرؤية التالية للأداء'),
    showData: t(
      'Read all chart observations',
      '阅读全部图表数据',
      'قراءة جميع ملاحظات الرسم البياني',
    ),
    hideData: t(
      'Hide chart observations',
      '隐藏图表数据',
      'إخفاء ملاحظات الرسم البياني',
    ),
    previousPoint: t(
      'Inspect previous observation',
      '查看上一个数据点',
      'فحص الملاحظة السابقة',
    ),
    nextPoint: t(
      'Inspect next observation',
      '查看下一个数据点',
      'فحص الملاحظة التالية',
    ),
    inspectHint: t(
      'Use arrow keys to inspect observations. Home and End reach the first and last.',
      '使用方向键查看数据点；Home 和 End 可到达首尾。',
      'استخدم مفاتيح الأسهم لفحص الملاحظات؛ استخدم Home وEnd للوصول إلى البداية والنهاية.',
    ),
    empty: t('No performance insights', '暂无表现洞察', 'لا توجد رؤى للأداء'),
  );
}

/// Every fixture supplies actual translated business copy and public labels.
Map<String, Widget Function()> buildP3AcceptanceScenarios(P3ReviewCopy c) => {
  'prompt-bar': () => BeautifulPromptBar(
    composerId: 'p3-accept-prompt',
    initialDraft: '${c.body}\n${c.shortBody}',
    initialAttachments: [
      BeautifulPromptAttachment(
        id: 'plan',
        label: c.t(
          'supplier-delivery-review.csv',
          '供应商交付审核.csv',
          'مراجعة-تسليم-المورد.csv',
        ),
      ),
    ],
    sources: [
      BeautifulPromptSource(
        id: 'source',
        label: c.supplier,
        description: c.shortBody,
      ),
    ],
    models: [
      BeautifulPromptModel(
        id: 'daily',
        label: c.t(
          'Daily planning assistant',
          '日常计划助手',
          'مساعد التخطيط اليومي',
        ),
      ),
    ],
    selectedModelId: 'daily',
    onModelChanged: (_) {},
    onSend: (_) {},
    onAttach: () => const [],
    onDictate: () => null,
    tall: true,
    placeholder: c.t(
      'Describe the supplier planning request',
      '描述供应商计划需求',
      'صِف طلب تخطيط الموردين',
    ),
    composerLabel: c.t(
      'Supplier planning prompt',
      '供应商计划提示词',
      'طلب تخطيط الموردين',
    ),
    addLabel: c.t('Add sources and files', '添加来源与文件', 'إضافة مصادر وملفات'),
    attachLabel: c.t(
      'Add planning documents',
      '添加计划文档',
      'إضافة مستندات التخطيط',
    ),
    attachingLabel: c.t(
      'Adding planning documents',
      '正在添加计划文档',
      'جارٍ إضافة مستندات التخطيط',
    ),
    removeLabel: c.t('Remove attachment', '移除附件', 'إزالة المرفق'),
    modelsLabel: c.t(
      'Choose an assistant model',
      '选择助手模型',
      'اختيار نموذج المساعد',
    ),
    sourcesLabel: c.t(
      'Connected sources and files',
      '已连接来源与文件',
      'المصادر والملفات المتصلة',
    ),
    commandsLabel: c.t('Available commands', '可用命令', 'الأوامر المتاحة'),
    connectLabel: c.t('Connect this source', '连接这个来源', 'الاتصال بهذا المصدر'),
    connectingLabel: c.t(
      'Connecting this source',
      '正在连接来源',
      'جارٍ الاتصال بالمصدر',
    ),
    dictateLabel: c.t(
      'Start dictating the request',
      '开始口述请求',
      'بدء إملاء الطلب',
    ),
    dictatingLabel: c.t(
      'Listening to the request',
      '正在聆听请求',
      'جارٍ الاستماع إلى الطلب',
    ),
    stopDictationLabel: c.t('Stop dictating', '停止口述', 'إيقاف الإملاء'),
    stoppingDictationLabel: c.t(
      'Stopping dictation',
      '正在停止口述',
      'جارٍ إيقاف الإملاء',
    ),
    sendLabel: c.t('Send planning request', '发送计划请求', 'إرسال طلب التخطيط'),
    sendingLabel: c.t(
      'Sending planning request',
      '正在发送计划请求',
      'جارٍ إرسال طلب التخطيط',
    ),
    noMatchesLabel: c.t(
      'No matching planning sources',
      '没有匹配的计划来源',
      'لا توجد مصادر تخطيط مطابقة',
    ),
  ),
  'diff-table': () => BeautifulDiffTable(
    id: 'p3-accept-diff',
    title: c.title,
    labels: c.diffLabels,
    columns: [
      BeautifulDiffColumn(
        id: 'name',
        label: c.t('Supplier organisation', '供应商组织', 'مؤسسة المورد'),
      ),
      BeautifulDiffColumn(
        id: 'lead',
        label: c.t('Confirmed delivery', '已确认交付', 'التسليم المؤكّد'),
      ),
    ],
    rows: [
      BeautifulDiffRow(
        id: 'old',
        before: {
          'name': c.supplier,
          'lead': c.t('Seven working days', '七个工作日', 'سبعة أيام عمل'),
        },
      ),
      BeautifulDiffRow(
        id: 'new',
        after: {
          'name': c.alternate,
          'lead': c.t('Three working days', '三个工作日', 'ثلاثة أيام عمل'),
        },
      ),
      BeautifulDiffRow(
        id: 'changed',
        before: {
          'name': c.supplier,
          'lead': c.t('Five working days', '五个工作日', 'خمسة أيام عمل'),
        },
        after: {
          'name': c.supplier,
          'lead': c.t('Four working days', '四个工作日', 'أربعة أيام عمل'),
        },
      ),
    ],
    initialIncludedRowIds: const {'old', 'new'},
    onApply: (_) async {},
  ),
  'records-table': () => BeautifulRecordsTable(
    id: 'p3-accept-records',
    height: 550,
    labels: c.recordLabels,
    columns: [
      BeautifulRecordColumn(
        id: 'category',
        label: c.category,
        property: BeautifulRecordPropertyConfig(
          type: BeautifulRecordPropertyType.multiSelect,
        ),
      ),
      BeautifulRecordColumn(
        id: 'review',
        label: c.t(
          'Delivery reliability review',
          '交付可靠性审核',
          'مراجعة موثوقية التسليم',
        ),
        property: BeautifulRecordPropertyConfig(
          toolId: 'summary',
          inputColumnIds: const ['category'],
          prompt: c.shortBody,
        ),
      ),
    ],
    tools: [
      BeautifulRecordTool(
        id: 'summary',
        label: c.t(
          'Delivery review assistant',
          '交付审核助手',
          'مساعد مراجعة التسليم',
        ),
      ),
    ],
    rows: [
      BeautifulRecordRow(
        id: 'aurora',
        label: c.supplier,
        cells: {
          'category': BeautifulRecordCell(text: c.regular, tags: [c.regular]),
          'review': BeautifulRecordCell(text: c.shortBody),
        },
      ),
      BeautifulRecordRow(
        id: 'maple',
        label: c.alternate,
        cells: {
          'category': BeautifulRecordCell(text: c.seasonal),
          'review': BeautifulRecordCell(
            text: c.error,
            status: BeautifulRecordCellStatus.failed,
            error: c.error,
          ),
        },
      ),
    ],
    initialSelectedIds: const {'aurora'},
    onSelectionChanged: (_) {},
    onPropertyChanged: (_, _) {},
    onPropertyAdded: (_) {},
    onRun: (_) {},
  ),
  'sidebar-nav': () => Align(
    alignment: AlignmentDirectional.topStart,
    child: BeautifulSidebarNav(
      height: 700,
      labels: c.sidebarLabels,
      workspaces: [
        BeautifulSidebarWorkspace(id: 'ops', label: c.title),
        BeautifulSidebarWorkspace(
          id: 'other',
          label: c.t(
            'Seasonal procurement planning',
            '季节性采购计划',
            'تخطيط المشتريات الموسمية',
          ),
        ),
      ],
      selectedWorkspaceId: 'ops',
      selectedItemId: 'suppliers',
      items: [
        BeautifulSidebarItem(
          id: 'overview',
          label: c.t('Planning overview', '计划概览', 'نظرة عامة على التخطيط'),
        ),
        BeautifulSidebarItem(
          id: 'suppliers',
          label: c.t(
            'Supplier delivery records',
            '供应商交付记录',
            'سجلات تسليم الموردين',
          ),
          count: c.t('12', '12', '١٢'),
        ),
      ],
      recents: [
        BeautifulSidebarRecent(
          id: 'restock',
          label: c.t(
            'Prepare weekend replenishment',
            '准备周末补货计划',
            'إعداد خطة تجديد المخزون في عطلة الأسبوع',
          ),
        ),
        BeautifulSidebarRecent(
          id: 'delivery',
          label: c.t(
            'Confirm the revised delivery date',
            '确认调整后的交付日期',
            'تأكيد موعد التسليم المعدّل',
          ),
        ),
      ],
      onWorkspaceSelected: (_) {},
      onWorkspaceAction: (_) {},
      onItemSelected: (_) {},
      onRecentSelected: (_) {},
      onNewChat: () {},
      footerLabel: c.t(
        'Workspace settings and preferences',
        '工作区设置与偏好',
        'إعدادات مساحة العمل وتفضيلاتها',
      ),
      onFooterPressed: () {},
    ),
  ),
  'flowchart': () => BeautifulFlowchart(
    labels: c.flowLabels,
    data: BeautifulFlowchartData(
      id: 'p3-accept-flow',
      nodes: [
        BeautifulFlowchartNode(
          id: 'trigger',
          kind: BeautifulFlowchartNodeKind.trigger,
          title: c.t(
            'Supplier inventory was updated',
            '供应商库存已更新',
            'تم تحديث مخزون المورد',
          ),
          caption: c.shortBody,
          position: const Offset(32, 24),
        ),
        BeautifulFlowchartNode(
          id: 'condition',
          kind: BeautifulFlowchartNodeKind.condition,
          title: c.t(
            'Check the replenishment category',
            '核验补货类别',
            'التحقّق من فئة تجديد المخزون',
          ),
          position: const Offset(520, 24),
          conditions: [
            BeautifulFlowchartCondition(
              id: 'if',
              label: c.t('If', '如果', 'إذا'),
              sourceLabel: c.t(
                'Supplier inventory record',
                '供应商库存记录',
                'سجل مخزون المورد',
              ),
              fields: [
                BeautifulFlowchartField(
                  id: 'category',
                  label: c.category,
                  valueId: 'seasonal',
                  options: [
                    BeautifulFlowchartOption(id: 'seasonal', label: c.seasonal),
                    BeautifulFlowchartOption(id: 'classic', label: c.regular),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      edges: [
        BeautifulFlowchartEdge(
          id: 'next',
          from: 'trigger',
          to: 'condition',
          label: c.t(
            'Updated supplier record',
            '已更新供应商记录',
            'سجل المورد المحدّث',
          ),
        ),
      ],
    ),
    onChanged: (_) {},
    viewportHeight: 560,
  ),
  'insight-cards': () => _AcceptanceInsights(copy: c),
  'selection-actions': () => BeautifulSelectionActions(
    documentId: 'p3-accept-selection',
    text: '${c.shortBody} ${c.body}',
    initialSelection: TextSelection(
      baseOffset: 0,
      extentOffset: c.shortBody.length,
    ),
    labels: c.selectionLabels,
    actions: [
      BeautifulSelectionAction(
        id: 'explain',
        label: c.t(
          'Explain the selected passage',
          '解释所选段落',
          'شرح المقطع المحدّد',
        ),
        kind: BeautifulSelectionActionKind.explain,
      ),
      BeautifulSelectionAction(id: 'improve', label: c.improve),
      BeautifulSelectionAction(
        id: 'shorten',
        label: c.t(
          'Shorten the selected passage',
          '缩短所选段落',
          'اختصار المقطع المحدّد',
        ),
        secondary: true,
      ),
    ],
    onRequest: (_) => c.replacement,
    onApply: (_) {},
    documentMaxLines: 4,
  ),
};

final class _AcceptanceInsights extends StatefulWidget {
  const _AcceptanceInsights({required this.copy});
  final P3ReviewCopy copy;
  @override
  State<_AcceptanceInsights> createState() => _AcceptanceInsightsState();
}

final class _AcceptanceInsightsState extends State<_AcceptanceInsights> {
  String _page = 'comparison';
  String _metric = 'demand';
  String _segment = 'regular';

  @override
  Widget build(BuildContext context) {
    final c = widget.copy;
    final points = [
      BeautifulInsightPoint(
        id: 'mon',
        label: c.t('Monday delivery', '星期一交付', 'تسليم يوم الاثنين'),
        value: 12,
        formattedValue: c.t('12%', '12%', '١٢٪'),
      ),
      BeautifulInsightPoint(
        id: 'tue',
        label: c.t('Tuesday delivery', '星期二交付', 'تسليم يوم الثلاثاء'),
        value: 26,
        formattedValue: c.t('26%', '26%', '٢٦٪'),
      ),
    ];
    return BeautifulInsightCards(
      labels: c.insightLabels,
      pagePositionLabel: c.t(
        'Review of three supplied insights',
        '查看三条已提供的洞察',
        'مراجعة ثلاث رؤى مقدّمة',
      ),
      selectedPageId: _page,
      onPageChanged: (value) => setState(() => _page = value),
      onMetricChanged: (_, value) => setState(() => _metric = value),
      onSegmentChanged: (_, value) => setState(() => _segment = value),
      onFollowUp: (_) {},
      pages: [
        BeautifulInsightPage(
          id: 'comparison',
          title: c.title,
          prose: c.body,
          followUpLabel: c.t(
            'Open supplier delivery records',
            '打开供应商交付记录',
            'فتح سجلات تسليم الموردين',
          ),
          chart: BeautifulInsightComparison(
            title: c.t(
              'On-time delivery improvement',
              '准时交付的改善情况',
              'تحسّن التسليم في الموعد المحدّد',
            ),
            summary: c.t(
              'Both suppliers improved from twelve to twenty-six percent.',
              '两家供应商都从百分之十二提高到了百分之二十六。',
              'تحسّن كلا الموردين من اثني عشر إلى ستة وعشرين بالمئة.',
            ),
            series: [
              BeautifulInsightSeries(
                id: 'first',
                label: c.supplier,
                valueLabel: c.t('+26%', '+26%', '+٢٦٪'),
                points: points,
              ),
              BeautifulInsightSeries(
                id: 'second',
                label: c.alternate,
                valueLabel: c.t('+26%', '+26%', '+٢٦٪'),
                points: points,
                tone: BeautifulInsightTone.positive,
              ),
            ],
          ),
        ),
        BeautifulInsightPage(
          id: 'anomaly',
          title: c.t(
            'Unusual replenishment demand',
            '异常补货需求',
            'طلب غير معتاد لتجديد المخزون',
          ),
          prose: c.shortBody,
          chart: BeautifulInsightAnomaly(
            title: c.t(
              'Demand exceeded the plan',
              '需求超出了计划',
              'تجاوز الطلب الخطة',
            ),
            summary: c.t(
              'The last observation exceeded the agreed threshold.',
              '最后一个数据点超出了约定的阈值。',
              'تجاوزت الملاحظة الأخيرة الحدّ المتفق عليه.',
            ),
            selectedMetricId: _metric,
            metrics: [
              for (final id in ['demand', 'orders'])
                BeautifulInsightMetric(
                  id: id,
                  label: id == 'demand'
                      ? c.t('Procurement demand', '采购需求', 'طلب المشتريات')
                      : c.t('Confirmed orders', '已确认订单', 'الطلبات المؤكّدة'),
                  valueLabel: c.t('+26%', '+26%', '+٢٦٪'),
                  points: points,
                  thresholdValue: 20,
                  thresholdLabel: c.t(
                    '20% planning threshold',
                    '20% 计划阈值',
                    'حد التخطيط ٢٠٪',
                  ),
                ),
            ],
          ),
        ),
        BeautifulInsightPage(
          id: 'allocation',
          title: c.t(
            'Supplier inventory allocation',
            '供应商库存分配',
            'توزيع مخزون الموردين',
          ),
          prose: c.shortBody,
          chart: BeautifulInsightAllocation(
            title: c.t(
              'Confirmed inventory value',
              '已确认库存价值',
              'قيمة المخزون المؤكّدة',
            ),
            summary: c.t(
              'Regular deliveries account for sixty percent of inventory.',
              '常规交付占库存总量的百分之六十。',
              'تمثّل عمليات التسليم المعتادة ستين بالمئة من المخزون.',
            ),
            selectedSegmentId: _segment,
            segments: [
              BeautifulInsightAllocationSegment(
                id: 'regular',
                label: c.regular,
                share: .6,
                shareLabel: c.t('60%', '60%', '٦٠٪'),
                valueLabel: c.t('1,200 units', '1,200 件', '١٬٢٠٠ وحدة'),
                detail: c.shortBody,
              ),
              BeautifulInsightAllocationSegment(
                id: 'seasonal',
                label: c.seasonal,
                share: .4,
                shareLabel: c.t('40%', '40%', '٤٠٪'),
                valueLabel: c.t('800 units', '800 件', '٨٠٠ وحدة'),
                detail: c.shortBody,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
