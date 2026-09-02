# Beautiful UI → shadcn_flutter 响应式多端组件库可行性研究

> 本文作为项目立项时的研究基线归档；实际实施状态以后续 parity manifest、架构决策记录和质量证据为准。

> 核验日期：2026-09-02（Asia/Shanghai）
> Beautiful UI 官方仓库快照：`dd1ba4f323c29ef6c383b2dbf1d7100f2c26ccac`
> shadcn_flutter 正式上游快照：`5a2376e416fca6c8cc5feb2b5fcf5bf160fa5f73`

## 一句话结论

**可行，而且值得先做一个小型 MVP。**

正确路线不是把 React/Tailwind 源码逐行“翻译”成 Dart，而是：

```text
Beautiful UI 的视觉、状态和交互意图（MIT）
                  ↓ 重新设计 Flutter API 并手工实现
你自己的 AI UI 复合 Widget + Compact/Medium/Expanded 布局
                  ↓ 复用行为基础
shadcn_flutter 的 Theme、Button、Card、Input、Table、Overlay、Navigation
                  ↓
Flutter 的 LayoutBuilder、MediaQuery、Focus、Semantics、Pointer/Keyboard
```

Beautiful UI 的公开物当前不是传统的 Button/Input 基础库，而是 **20 个面向 AI 产品的复合界面 primitive**，另有 6 个内部共用 UI building blocks 和 1 套 foundation 样式；官方 registry 总计 27 项，且没有 `registry:block`、`registry:page` 或 template 项。[官方 registry 索引](https://www.beautifului.dev/r/registry.json) 直接给出了类型、依赖与文件清单。[官网首页](https://www.beautifului.dev/)则列出了全部 20 个演示组件。

## 核心判断

| 问题 | 结论 |
|---|---|
| 能不能做成 Flutter？ | 能，但必须重写 Dart Widget、状态机、动画和输入行为，TSX 不能直接复用。 |
| shadcn_flutter 适不适合做底层？ | 适合。它已有 84 个组件，官方声明覆盖 Android、iOS、Web、macOS、Windows、Linux，并提供 Theme、表单、弹层、导航、表格、Chat、CodeSnippet 等基础能力。[官方 README](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/README.md) |
| Beautiful UI 已经是响应式多端库吗？ | 不是。现成实现是 Web/React；整页 Gallery/Harness 有断点，但大部分单个 primitive 没有手机、平板、桌面三套布局。 |
| 能否复制、修改、商用、再发布？ | 可以。Beautiful UI 官方采用 MIT；需要在副本或实质部分中保留原版权与许可文本。[官方 LICENSE](https://github.com/slev12397/beautiful-ui/blob/main/LICENSE) |
| 是否适合一次搬完？ | 不适合。20 个源码连同组件 CSS 约 8,000 行，而且复杂度差异极大；先做 6 个低/中难度组件，验证设计系统、响应式和无障碍链路。 |
| 是否应直接大改 shadcn_flutter 核心？ | 不建议。建立自己的 package 依赖/包裹 shadcn_flutter，更容易同步上游。 |

## 1. Beautiful UI 官方内容到底是什么

### 1.1 官方定位与技术栈

官方 README 把项目定义为面向 AI-native 产品的 copy-paste interface primitives，并明确写出技术栈为 **Next.js App Router、React、Tailwind CSS v4、TypeScript**；官方还说明 `/harness` 是把 primitives 组合起来的 scripted agent-chat demo，而不是已经接上 AI 后端的产品。[官方 README](https://github.com/slev12397/beautiful-ui/blob/main/README.md)

每个展示组件可以通过 shadcn registry 安装，例如：

```bash
npx shadcn add https://www.beautifului.dev/r/approval-card.json
```

registry JSON 会交付 TSX/CSS 文件，并列出内部 `registryDependencies` 和 npm `dependencies`；[Approval Card registry](https://www.beautifului.dev/r/approval-card.json)、[Prompt Bar registry](https://www.beautifului.dev/r/prompt-bar.json)和[Records Table registry](https://www.beautifului.dev/r/records-table.json)可直接核验这种格式。

所有组件都依赖一次性安装的 [foundation registry](https://www.beautifului.dev/r/foundation.json)。它包含 light/dark 语义颜色、字体映射、圆角、阴影、focus-visible、共享 keyframes 和 `prefers-reduced-motion` 降级；因此所谓“单文件 copy-paste”仍然不是完全零依赖。[官方 globals.css](https://github.com/slev12397/beautiful-ui/blob/main/app/globals.css)对此有完整源代码。

### 1.2 20 个展示组件 + 6 个共用 building blocks

按产品职责，20 个展示组件可以分成四组：

| 分类 | 官方组件 |
|---|---|
| Agent 运行与反馈 | Loading State、Thinking、Streaming Text、Tool Chips、Task Rows |
| 对话、确认与编辑 | Approval Card、Chat、Prompt Bar、Recommendation Card、Selection Actions |
| 知识与数据 | Context Cards、Diff Table、Records Table、Filter Table、Search、Insight Cards、Code Block |
| 导航与可视化编辑 | Sidebar Nav、Flowchart、Fine-tune Card |

官方 registry 还提供 6 个未单独列在 Gallery 导航中的共用单元：[Button](https://www.beautifului.dev/r/button.json)、[GlideMenu](https://www.beautifului.dev/r/glide-menu.json)、[EntityChip](https://www.beautifului.dev/r/entity-chip.json)、[ValuePill](https://www.beautifului.dev/r/value-pill.json)、[Shimmer](https://www.beautifului.dev/r/shimmer.json)、[StreamText](https://www.beautifului.dev/r/stream-text.json)。这些单元应在 Flutter 版中优先对应到 shadcn_flutter 的基础控件，而不是逐个复制一层浅 wrapper。

### 1.3 这些源码含有大量“演示状态”，不是现成业务能力

官方 README 明确说明 Harness 的 `SCENARIOS` 是 fake prompts + scripted replies，生产接入时需要换成真实的 agent request、token stream、tool-call、approval、memory 和 data source。[Harness 接入说明](https://github.com/slev12397/beautiful-ui/blob/main/README.md#wiring-the-harness-to-a-real-agent)

因此 Flutter 版要分开两件事：

1. **组件库负责展示和交互：** 接收数据、状态、controller 和 callback；
2. **产品项目负责业务：** LLM、SSE/WebSocket、录音、网络请求、数据库、审批提交。

例如不要把网页 Demo 中的定时假回复照搬进 `AiChat`；应设计成类似：

```dart
AiThinking(
  status: thinkingStatus,
  steps: steps,
  expanded: expanded,
  onExpandedChanged: onExpandedChanged,
)
```

## 2. 当前响应式与多端现状

### 2.1 已有的部分

- Gallery 外壳会在 `lg` 宽度变成 288px 侧栏 + 内容两列，小屏则把侧栏放回顶部并隐藏长组件导航；这是**展示网站外壳**的响应式，不等于每个 primitive 已完成多端设计。[Gallery 页面源码](https://github.com/slev12397/beautiful-ui/blob/main/app/page.tsx)
- Harness 在 `< lg` 时隐藏 Sidebar 和右侧 inspector，并改变内容 padding、让部分 tabs 横向滚动；这证明官方考虑了窄屏展示，但小屏并没有提供完整的 Drawer/Bottom Navigation 替代。[Harness 源码](https://github.com/slev12397/beautiful-ui/blob/main/components/site/IceCreamHarness.tsx)
- Records Table 的工具栏在 640px 以下改为纵向，但表格本身仍约有 `990px` 最小宽度，窄屏主要靠横向滚动。[Records Table registry](https://www.beautifului.dev/r/records-table.json)

### 2.2 还缺的部分

官方当前只交付 Web/DOM/CSS 实现，没有 Flutter/Dart、iOS、Android 或桌面原生 package。[官方 package.json](https://github.com/slev12397/beautiful-ui/blob/main/package.json)和[官方 README](https://github.com/slev12397/beautiful-ui/blob/main/README.md)都只描述 Web 技术栈。

源码审计显示，20 个 primitive 的 TSX 主体主要靠 `w-full`、`max-w-*`、flex、overflow 保持弹性，基本没有组件级 `sm:/md:/lg:/xl:` 分支；复杂窄屏体验因此必须在 Flutter 版重新设计。尤其：

- Records Table：手机不应只是缩小 990px 表格，应该提供 Card/List 或“关键列 + 详情页”；
- Sidebar Nav：手机应切换 Drawer 或底部导航；
- Hover tooltip/menu：必须同时有 tap/long-press 和 keyboard 入口；
- Flowchart/Fine-tune：触摸拖动要扩大 hit target，并避免与页面滚动冲突；
- Prompt Bar：软键盘、SafeArea、语音权限、横竖屏和窄宽工具栏都要单独处理。

Flutter 官方把“responsive”定义为能装进当前空间，把“adaptive”定义为在当前空间中真正可用；这项工作需要两者都做。[Flutter 响应式与自适应总览](https://docs.flutter.dev/ui/adaptive-responsive)

## 3. 为什么 shadcn_flutter 是合适底层

shadcn_flutter 的公开源码中已经包含以下关键能力：

- 主题、颜色、字体、radius、scaling、density：[Theme 源码](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/theme/theme.dart)；
- hover、pressed、focused、disabled、keyboard activation 与 focus outline：[Clickable 源码](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/components/control/clickable.dart)；
- Button、Card、Badge、Chip、Input、TextArea、Select、Checkbox、Form；完整导出表见[官方 barrel](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/shadcn_flutter.dart)；
- Dialog、Drawer、Popover、Tooltip、Context Menu 和自适应 overlay：[OverlayConfiguration 源码](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/components/overlay/overlay_configuration.dart)；
- NavigationBar/Rail/Sidebar、Tabs、Command、Table、Resizable、Sortable、Chat、CodeSnippet；文件入口可由[官方组件源码目录](https://github.com/sunarya-thito/shadcn_flutter/tree/master/packages/shadcn_flutter/lib/src/components)核验。

这能让你的 Flutter 版复用焦点、键盘、弹层关闭、表单和主题等难点，把主要精力放在 Beautiful UI 的复合结构与动效上。

但不要假定 shadcn_flutter 自动解决全部多端问题：局部组件应以父级实际约束为准使用 `LayoutBuilder`，页面级布局才使用 `MediaQuery.sizeOf(context)`；Flutter 官方也明确建议按可用空间，而不是按“手机/平板”硬件类型或单纯 orientation 做分支。[Flutter 自适应最佳实践](https://docs.flutter.dev/ui/adaptive-responsive/best-practices)

## 4. 20 个组件逐项映射与难度

下面的难度是**本报告估算**，前提为：一个熟练 Flutter 工程师、包含 Compact/Expanded 布局、基础键盘/触摸/Semantics、Widget tests 和 Catalog 示例。

- 低：约 2–4 人日；
- 中：约 5–10 人日；
- 高：约 12–25 人日；
- Records Table 可能超过 25 人日，取决于是否要求虚拟化、列配置与复杂编辑全部对齐。

| Beautiful UI 项 | shadcn_flutter / Flutter 实现底座 | 手机/窄屏策略 | 难度 |
|---|---|---|---:|
| [Loading State](https://www.beautifului.dev/r/loading-state.json) | `Spinner`、`Progress`、`NumberTicker` + 自定义 3×3 pixel animation | 单行可换行；隐藏非关键 elapsed；尊重 reduced motion；不要沿用未单独授权的外部 Surfer 视频 | 低 |
| [Thinking](https://www.beautifului.dev/r/thinking-state.json) | `Collapsible`/`Accordion`、`Timeline`/`Steps`、`Spinner` | 默认收起；展开内容自然增高；保持展开状态不因 resize 重置 | 中 |
| [Streaming Text](https://www.beautifului.dev/r/streaming-text.json) | `SelectableText`、shadcn text、`FadeScroll` + 自定义 token controller | 文本可选；sources/actions 折叠为 bottom sheet 或 wrap；长文避免固定高度 | 中 |
| [Approval Card](https://www.beautifului.dev/r/approval-card.json) | `Card`、`MultipleChoice`/`RadioGroup`、`TextField`、`Button`、`Stepper` | actions 全宽或底部固定；44/48px 触控目标；软键盘下可见 | 中 |
| [Tool Chips](https://www.beautifului.dev/r/tool-chips.json) | `Chip`/`Badge`、`Collapsible`、`Popover`/`Drawer`、`CodeSnippet` | 不依赖 hover；tap 展开详情；窄屏 tooltip 改 sheet/dialog | 中 |
| [Task Rows](https://www.beautifului.dev/r/task-rows.json) | `Timeline`/`Steps`、`Progress`、`Collapsible`、`Badge` | 每行允许两行文字；详情纵向；进度状态有文字而非仅颜色 | 低～中 |
| [Chat](https://www.beautifului.dev/r/chat-composer.json) | shadcn `Chat`、`Tabs`、`TextArea`、`Button`、`ScrollView` | composer 固定在 SafeArea 上方；处理软键盘、滚动到底和横向 tabs | 中 |
| [Prompt Bar](https://www.beautifului.dev/r/prompt-bar.json) | `TextArea`、`ChipInput`、`Autocomplete`、`Popover`/`Drawer`、`Select`；真实语音另接平台 plugin | compact 只留核心按钮，更多操作进 menu/sheet；录音权限与输入法单独实现 | 高 |
| [Recommendation Card](https://www.beautifului.dev/r/recommendation-card.json) | `Card`、`Badge`、`Progress`、`Button`、`Collapsible` | 主按钮全宽；alternatives 折叠；置信度同时显示文本 | 低 |
| [Context Cards](https://www.beautifului.dev/r/context-cards.json) | `Card`、`Chip`/`Badge`、`Scrollable` | 单列列表；长内容截断后可展开；来源链接有明确 label | 低 |
| [Diff Table](https://www.beautifului.dev/r/diff-table.json) | `Table`、`Checkbox`、`Button`、`Badge`；大数据时自定义 builder/list | compact 改“每条修改卡片”；保留 old/new 语义，不只靠红绿 | 中～高 |
| [Records Table](https://www.beautifului.dev/r/records-table.json) | `Table`、`Resizable`、`Sortable`、`Checkbox`、`Scrollbar`、`Popover`/`ContextMenu` | compact 改 Card/List + row detail；medium 只显示关键列；expanded 才开放列宽/列设置 | 很高 |
| [Filter Table](https://www.beautifului.dev/r/filter-table.json) | `Table`、`Chip`/`Toggle`、`Badge`、`Scrollable` | filter chips 横滚或 wrap；表格可转 compact list | 低 |
| [Sidebar Nav](https://www.beautifului.dev/r/sidebar-nav.json) | `NavigationSidebar`/`NavigationRail`/`NavigationBar`、`Drawer`、`Command` | expanded sidebar → medium rail → compact drawer/bottom nav | 中～高 |
| [Search](https://www.beautifului.dev/r/search.json) | `Command`、`TextField`、`KeyboardShortcut`、`Scrollable` | 页面内可全宽；弹层桌面用 dialog/popover、手机用 sheet；处理空状态 | 低 |
| [Flowchart](https://www.beautifului.dev/r/flowchart.json) | `StageContainer` + `CustomPainter`/`InteractiveViewer`、Pointer/Gesture、Menu overlay | 手机先提供只读/纵向 stepper；高级拖拽编辑可只在平板/桌面开放 | 高 |
| [Insight Cards](https://www.beautifului.dev/r/insight-cards.json) | `Card`、`Carousel`、`Pagination` + Flutter chart/custom painter | 图表可横向 scrub；屏幕阅读器提供文字摘要；窄屏单卡 | 高 |
| [Code Block](https://www.beautifului.dev/r/code-block.json) | shadcn `CodeSnippet`、`Tabs`、`Scrollbar`、Clipboard | 保持横滚，不强制换行；copy 有语义和成功反馈 | 低 |
| [Fine-tune Card](https://www.beautifului.dev/r/fine-tune-card.json) | `Card`、`FormattedInput`/`Slider`、`Select`、`GlideMenu` 对应 Popover/Menu | compact 表单纵向；slider 同时支持输入、键盘、触摸；避免小型拖动柄 | 中～高 |
| [Selection Actions](https://www.beautifului.dev/r/selection-actions.json) | shadcn `SelectableText`/selection controls、`Popover`、`TextArea`、`Button` | 手机遵循系统 selection toolbar 或 sheet；桌面才做紧贴选区的浮层 | 高 |

相关 shadcn_flutter 基础实现可直接参照：[Spinner](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/components/display/spinner.dart)、[Chat](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/components/display/chat.dart)、[CodeSnippet](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/components/display/code_snippet.dart)、[Command](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/components/control/command.dart)、[Table](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/components/layout/table.dart)、[Navigation Sidebar](https://github.com/sunarya-thito/shadcn_flutter/tree/master/packages/shadcn_flutter/lib/src/components/navigation/navigation_bar)与[SelectableText](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/src/components/text/selectable.dart)。

## 5. 建议的 Flutter 响应式规范

### 5.1 建议三个布局模式

下面是**项目建议值，不是 Beautiful UI 官方规范**：

| 模式 | 初始建议 | 主要行为 |
|---|---:|---|
| Compact | `< 600dp` | 单列、全宽主操作、Drawer/Sheet、较大触控目标、隐藏非关键列 |
| Medium | `600–1023dp` | 两栏可选、NavigationRail、部分表格列、Popover 或 Sheet 视空间决定 |
| Expanded | `>= 1024dp` | Sidebar、多栏、锚定 Popover、完整表格/编辑器、鼠标和键盘加速 |

断点只是起点；组件应在“内容放不下”的宽度处分支。Flutter 官方建议局部组件使用 `LayoutBuilder`，页面使用 `MediaQuery.sizeOf`，也明确反对用硬件类别替代实际窗口尺寸。[Flutter 自适应最佳实践](https://docs.flutter.dev/ui/adaptive-responsive/best-practices)

```dart
enum AiLayoutMode { compact, medium, expanded }

AiLayoutMode modeFor(double width) {
  if (width < 600) return AiLayoutMode.compact;
  if (width < 1024) return AiLayoutMode.medium;
  return AiLayoutMode.expanded;
}
```

### 5.2 多端不只是换宽度

- 手机/平板：`SafeArea`、软键盘 `viewInsets`、旋转/分屏、tap/long-press、系统返回、足够触控面积；[SafeArea 与 MediaQuery](https://docs.flutter.dev/ui/adaptive-responsive/safearea-mediaquery)还会暴露 text scaling、high contrast 与 fold/hinge 信息。
- Web/桌面：hover、right-click、滚轮、可见滚动条、Tab focus、Enter/Space、快捷键、可选择文字、窗口实时缩放；Flutter 官方说明自定义 Widget 需要主动实现这些输入行为。[User input & accessibility](https://docs.flutter.dev/ui/adaptive-responsive/input)
- iOS/Android/桌面：弹层、button order、context menu、选择文字、滚动等平台惯例不完全相同；Flutter 官方建议在统一品牌下仍尊重平台习惯。[Platform idioms](https://docs.flutter.dev/ui/adaptive-responsive/idioms)

### 5.3 状态必须与布局分支分离

窗口从 compact 变 expanded 时，不应丢失：输入文字、已选项、streaming 进度、滚动位置、focus、table selection。Controller/业务状态放在响应式分支上方，并给可复用子树稳定 Key；Flutter 官方也要求应用在窗口变化、旋转或折叠时保留状态。[自适应最佳实践](https://docs.flutter.dev/ui/adaptive-responsive/best-practices)

## 6. 无障碍结论与验收要求

### 6.1 原网页已有的优点

Beautiful UI 官方源码有真实 `<button>`/`<input>`、`aria-label`、`aria-expanded`、`aria-pressed`、`role="status"`、dialog 语义、focus-visible，以及全局 reduced-motion 降级；[Loading State](https://www.beautifului.dev/r/loading-state.json)、[Thinking](https://www.beautifului.dev/r/thinking-state.json)、[Prompt Bar](https://www.beautifului.dev/r/prompt-bar.json)、[Records Table](https://www.beautifului.dev/r/records-table.json)和[globals.css](https://github.com/slev12397/beautiful-ui/blob/main/app/globals.css)可作为代表证据。

### 6.2 不能直接继承的部分

React DOM 的 ARIA 不会自动变成 Flutter Semantics；自定义绘图、drag handle、chart、selection overlay、streaming status 都需要重新标注。官方仓库的 package scripts 没有发布的 WCAG/axe/Playwright/a11y conformance 测试，因此不能宣称 Beautiful UI 已“完全符合 WCAG”。[官方 package.json](https://github.com/slev12397/beautiful-ui/blob/main/package.json)

每个 Flutter Widget 至少要验收：

- `Semantics` role、label、value、live-region/status；
- TalkBack / VoiceOver / Flutter Web semantics 阅读顺序；
- Tab、Shift+Tab、Enter、Space、Escape、方向键；
- focus ring 和 hover/tap 等价入口；
- Android 48×48、iOS 44×44 触控目标；
- 对比度、深色、高对比度、色盲模式；
- 200% 文本、中文/英文长文、RTL；
- `MediaQuery.disableAnimationsOf(context)` 下关闭或简化动画；
- compact/medium/expanded 切换时状态不丢失。

Flutter 官方的 Accessibility Guideline API 可自动检查 Android/iOS target size、tap label 与文字对比度，[无障碍测试文档](https://docs.flutter.dev/ui/accessibility/accessibility-testing)给出了 `meetsGuideline(...)` 的标准用法；Flutter Web 则把 Semantics tree 映射到可访问 HTML/ARIA，但自定义组件仍需提供正确语义。[Flutter Web accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility)

## 7. 许可、商用与必须替换的资源

### 7.1 Beautiful UI

Beautiful UI 的 MIT 许可允许使用、复制、修改、合并、发布、分发、再许可和销售；必须在软件副本或实质部分中保留版权和许可文本。[官网许可页](https://www.beautifului.dev/license)与[仓库 LICENSE](https://github.com/slev12397/beautiful-ui/blob/main/LICENSE)一致，版权人为 Shane Levine（2026）。

建议自己的仓库至少包含：

```text
LICENSE
THIRD_PARTY_NOTICES.md
```

并在 `THIRD_PARTY_NOTICES.md` 标明哪些组件改编自 Beautiful UI，附上其 MIT 文本。若某个 Dart 文件是实质移植，也可以加简短来源文件头。

MIT 没有自动授予 Beautiful UI 名称、Logo 或 Turbo 品牌的商标权；因此使用自己的 package 名、Logo 和品牌，描述为“部分组件改编自 Beautiful UI”更稳妥。

### 7.2 shadcn_flutter

shadcn_flutter 当前使用 3-Clause BSD，允许源代码/二进制形式修改与再分发，但要求保留版权、条件和免责声明，且不得未经许可用作者/贡献者名称为衍生产品背书。[正式上游 LICENSE](https://github.com/sunarya-thito/shadcn_flutter/blob/master/LICENSE)

### 7.3 第三方资源警告

- `SidebarNav` 依赖的 `@central-icons-react/round-outlined-radius-2-stroke-2` 是需要 license key 的商业包；Beautiful UI 官方 README 明确要求购买/配置或自行替换。[Beautiful UI README 警告](https://github.com/slev12397/beautiful-ui/blob/main/README.md#quick-start)和[该 npm 包说明](https://www.npmjs.com/package/@central-icons-react/round-outlined-radius-2-stroke-2)可核验。Flutter 版建议直接换成 shadcn_flutter 已打包的 Lucide 图标。
- Prompt Bar 的 `glimm`、Insight Cards 的 `liveline`、Selection Actions 的 `iconoir-react` 是 React/npm 依赖，Flutter 端本来也不能复用；从功能意图重新实现，并分别核查所采用 Dart 包的许可证。[官方 meta](https://github.com/slev12397/beautiful-ui/blob/main/lib/meta.ts)
- Loading State 的 Surfer 变体默认指向外部视频；官方源码没有给该远程视频单独列出授权。商用移植时不要捆绑它，换成自有或明确授权资产。[Loading State 源码](https://github.com/slev12397/beautiful-ui/blob/main/components/primitives/LoadingState.tsx)

以上是基于公开许可证的工程合规建议，不是正式法律意见。

## 8. 推荐工程结构

不要把 20 个组件直接塞进 shadcn_flutter 上游核心。建议在 fork 的 monorepo 中保留上游包，并新增自己的包：

```text
packages/
├── shadcn_flutter/        # 尽量跟正式上游保持接近
└── your_ai_ui/            # 你的 token、组件、响应式和 Semantics

apps/
└── catalog/               # 展示每个状态与每种 viewport

docs/
├── third_party_notices.md
└── migrations/
```

`your_ai_ui` 建议再分四层：

```text
foundation/   颜色、字体、圆角、间距、motion policy、breakpoint
atoms/        只补 shadcn_flutter 没有的共用小单元
primitives/   20 个 AI 复合 Widget
responsive/   Compact/Medium/Expanded shell 与策略
```

产品代码只 import `your_ai_ui`；只有这个 package 的内部适配层直接 import shadcn_flutter。这样上游升级和你自己的 API 可以分开演进。

## 9. MVP 顺序与工作量

### P0：地基（约 6–10 人日）

- 把 foundation CSS 的语义颜色、字体、radius、shadow、motion 翻译成 Flutter Theme/ComponentTheme；
- light/dark；
- `AiLayoutMode` 与 `LayoutBuilder` helper；
- motion policy（读取 `MediaQuery.disableAnimationsOf`）；
- Catalog + Widget/Semantics/Golden test 骨架；
- MIT/BSD notices。

### P1：第一个可用 MVP（建议 6 个，约 18–30 人日）

1. Loading State；
2. Thinking；
3. Context Cards；
4. Recommendation Card；
5. Search；
6. Code Block。

这组覆盖 loading、disclosure、card、command search、code 和 actions，却暂时避开复杂大表、拖拽画布、语音和 text-selection overlay。完成后应在 Android、iOS、Web、macOS/Windows 至少各跑一次 smoke test。

### P2：Agent 工作流（约 30–50 人日）

- Streaming Text；
- Approval Card；
- Tool Chips；
- Task Rows；
- Chat；
- Filter Table；
- Fine-tune Card。

### P3：复杂桌面/编辑体验（约 60–110+ 人日）

- Prompt Bar；
- Diff Table；
- Records Table；
- Sidebar Nav；
- Flowchart；
- Insight Cards；
- Selection Actions。

### 总量级

以下仍是工程估算，而非合同报价：

| 目标 | 熟练 Flutter 工程师粗略量级 |
|---|---:|
| 能看的概念验证：Theme + 3 个简单组件 | 8–15 人日 |
| 可在一个真实项目试用的 P0+P1 | 24–40 人日（约 5–8 周） |
| 20 个全量视觉 Demo | 6–10 人周，但还不等于生产级 |
| 20 个生产级多端首版，含测试/A11y/RTL/性能/文档 | 4–7 人月；Records/Flowchart/Selection 等需求越完整越接近上限或超过上限 |

新手不应该从 Records Table 或 Prompt Bar 开始；先完成 P0+一个 Loading State vertical slice，确认 Theme、responsive、Semantics、测试和 Catalog 全部打通，再批量扩展。

## 10. P0+P1 的验收标准

每个 MVP Widget 都应满足：

1. API 接受外部 data/state/callback，不含硬编码 demo business data；
2. Compact、Medium、Expanded 三种宽度无 overflow；
3. touch、mouse、keyboard 都能完成核心任务；
4. light/dark、200% text scale、RTL、reduced motion 可用；
5. Widget test、Semantics test 和至少一组代表性 golden；
6. Catalog 同页展示 normal、hover、focus、disabled、loading、empty、error、long text；
7. 不直接暴露 shadcn_flutter 的内部实现类型作为你的稳定公共 API；
8. 第三方 notices 完整，图标/视频等资产已替换或许可证已核实。

## 最终建议

**批准做，但批准的是“小步重写型项目”，不是“一键搬运项目”。**

最稳妥的下一步是先做一个 2–3 周技术验证：

```text
自己的 Theme
  + Loading State
  + Context Cards
  + Code Block
  + Compact / Expanded Catalog
  + Semantics 与 Golden tests
```

如果这三项在 Web、手机和桌面均稳定，再进入 P1 其余组件。这样能够尽早验证：

- Beautiful UI 视觉能否在 Flutter 渲染中保真；
- shadcn_flutter 的 Theme/Overlay/Focus 是否足够；
- 你的响应式规则是否适合真实产品；
- 动画在 Flutter Web 与低端手机上的性能；
- 组件 API 能否服务多个项目，而不是只复刻官网 Demo。

因此最终判断是：**技术可行、许可可行、产品方向合理；但应以 shadcn_flutter 为行为底座，建立独立的 `your_ai_ui` 包，按 Flutter 的约束与多输入模型重写，先做 6 个 MVP，再决定是否投入全量 20 个。**

## 一手来源索引

- Beautiful UI 官网：[https://www.beautifului.dev/](https://www.beautifului.dev/)
- Beautiful UI 官方仓库：[https://github.com/slev12397/beautiful-ui](https://github.com/slev12397/beautiful-ui)
- Beautiful UI registry：[https://www.beautifului.dev/r/registry.json](https://www.beautifului.dev/r/registry.json)
- Beautiful UI License：[https://www.beautifului.dev/license](https://www.beautifului.dev/license)
- Beautiful UI foundation：[https://www.beautifului.dev/r/foundation.json](https://www.beautifului.dev/r/foundation.json)
- shadcn_flutter 正式上游：[https://github.com/sunarya-thito/shadcn_flutter](https://github.com/sunarya-thito/shadcn_flutter)
- shadcn_flutter public API：[shadcn_flutter.dart](https://github.com/sunarya-thito/shadcn_flutter/blob/master/packages/shadcn_flutter/lib/shadcn_flutter.dart)
- Flutter adaptive/responsive：[https://docs.flutter.dev/ui/adaptive-responsive](https://docs.flutter.dev/ui/adaptive-responsive)
- Flutter accessibility testing：[https://docs.flutter.dev/ui/accessibility/accessibility-testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing)
