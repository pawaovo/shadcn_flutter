# AI 工作台客户端 UI、UX 与组件改造研究

核验日期：2026-10-19（Asia/Shanghai）。对象：Codex、智谱 ZCode、DeepSeek Harness、Qoder 当前桌面客户端及其官方资料。

**决定：继续使用现有组件库，扩展桌面紧凑样式、嵌入式表面和内容插槽，在应用层重组工作台。** 输入、焦点、键盘、草稿和无障碍基础值得保留；目前页面把展示型组件直接堆成产品界面，导致卡片重复、操作过重、宽度受限、任务与工具割裂。只改颜色、阴影和圆角不能解决这些问题。

本文是设计依据和改造方案，尚未实施下述 UI 改造。产品范围继续是可交互的前端壳，后续由外部内核接入。

## 1. 检查范围与证据

| 客户端 | 实际进入的范围 | 补充依据 | 未实测范围 |
|---|---|---|---|
| Qoder | 新任务、已有会话、审阅、终端、搜索、输入区菜单、自动化及新建表单、扩展市场与详情、知识中心、Sites、25 个设置入口 | 当前桌面版官方文档；自定义 Agent 官方截图 | 企业项目/讨论、运行中审批和异常全流程、所有文件格式和插件配置；模型设置只到加载状态 |
| ZCode | 新任务、已有会话、搜索/命令中心、归档、自动化/工作流、新建定时任务及自定义重复弹层、插件市场与详情、右侧标签、审查空状态、浏览器空页/网页/失败状态、底部终端、14 个设置页、引导首步 | 官方文档、公开 UI 源码 | 当前未打开项目，文件树、真实 Git Diff、项目工作流等依赖项目的状态未实测；未发送新任务 |
| DeepSeek Harness | 本地欢迎/登录入口；官方首页、新任务、插件管理、轨迹界面的官方图片 | 官方客户端源码、组件 README 与用户文档 | 本地登录后的全流程没有进入；源码定义不等于安装版本运行测量 |
| Codex | 本轮原生自动化访问被工具的应用访问限制阻止 | 官方项目、输入、浏览器、审阅、终端、自动化、通知、设置等文档 | 没有完成原生逐页操作，也没有核实精确动画参数 |

“已进入”表示检查页面入口、可见结构和当时状态，不表示穷尽所有数据、权限、错误和子弹层。研究过程中未安装插件、修改设置、提交自动化或发送任务。客户端截图包含现有本地内容，因此不随文档保存。

命名核对：本机安装、且可由 DeepSeek 官方网站核实的是 **DeepSeek Harness**；Hermes 是另一项 Agent 集成，本报告不把两者当作同一客户端。[Harness 官网](https://www.deepseek.com/harness/)、[官方 Hermes 集成说明](https://api-docs.deepseek.com/quick_start/agent_integrations/hermes/)

### Qoder 原生页面清单

| 页面组 | 本轮逐项进入的页面/弹层 | 观察到的设计特点 |
|---|---|---|
| 任务 | 新任务、已有会话、搜索结果弹层 | 首页突出输入区；搜索结果用选中行、辅助时间和键盘提示组织，任务列表保持稳定 |
| 输入区 | 模型、权限、添加上下文、执行者选择菜单 | 模型菜单区分禁用项、选中项和成本；权限项附一行解释；子菜单用箭头，次要入口收在底部 |
| 工作面 | 审阅、审阅视图菜单、底部终端 | 审阅有范围、文件导航、增删统计及视图控制；终端有标签、分屏和关闭工具栏 |
| 自动化 | 自动化列表、新建表单、模板、运行历史入口 | 表单指令区复用聊天输入的上下文/模型操作；计划配置和指令分列，模板使用克制的边框 |
| 扩展 | 插件市场、技能市场、连接器市场、插件详情、已安装管理 | 市场是两列轻量目录项；详情用路径导航、版本/作者、能力分组与说明正文 |
| 知识与站点 | 知识库、Repo Wiki、Sites | 筛选和视图控制位置一致；空状态与内容列表有各自呈现 |
| 个人设置（13） | 个人资料、通用、模式配置、任务监视器、快捷键、外观、语音、模型、Agent、Agent 团队、桌面宠物、记忆、数据导入 | 统一标题/说明/控件对齐；复杂内容进入分组列表或二级面板；模型页只观察到加载状态 |
| 集成设置（4） | 扩展管理、Hooks、电脑控制、移动端 | 引导插图服务于实际设置；权限和连接状态附在相应区域 |
| 编码设置（4） | Git、Worktrees、连接、安全 | 表单、开关、空列表沿用同一行式结构 |
| 归档（1） | 已归档 | 搜索、项目过滤、空状态和不可用操作有清楚区分 |
| 其他设置（3） | 实验功能、网络、QQQ Playground | 实验开关、诊断/代理字段、独立趣味页面，未执行诊断或修改配置 |

外观页实见主题预览、浅深模式、字体、内容宽度和模糊/玻璃效果选项；通用页实见思考状态动画配置入口。这能证明存在这些入口，不能证明所有主题或运行中动画已经体验。当前账户没有显示企业项目/讨论入口；官方文档里的 Workspace Index 也未出现在本机设置导航。[当前桌面版概览](https://docs.qoder.com/qoder/overview)、[设置文档](https://docs.qoder.com/qoder/settings)

### ZCode 原生页面清单

| 页面组 | 本轮进入的页面/弹层 | 观察到的设计特点 |
|---|---|---|
| 任务与导航 | 新任务、已有长会话、搜索/命令中心、归档空状态 | 少量全局入口；项目/分组视图；命令面板按全部/操作/任务/文件切换 |
| 输入区 | 首页项目、上下文、模式、电脑操作、模型区域 | 项目是输入区上方附着的一行；工具栏较轻；模型不可用提示靠近输入区 |
| 工作面 | 右侧初始选择、审查标签、浏览器标签、底部终端 | 右侧统一标签外壳；审查按范围选择；浏览器地址/导航/选择工具沿同一工具栏排列 |
| 自动化 | 自动化、工作流、新建表单、历史空状态、计划菜单、自定义重复弹层 | 列表→编辑页→小型重复设置弹层；日期结束条件按需显露；保留面包屑和设置/历史切换 |
| 插件 | 市场、GitHub 插件详情 | 两列平面目录；已安装能力用图标集合；详情保持全页排版和能力分组 |
| 基础设置（6） | 常规、外观、模型设置、浏览器控制、电脑控制、键盘快捷键 | 成组行式设置；界面与代码字体分别设置；快捷键是可搜索表格 |
| Agent 设置（7） | 记忆、子智能体、插件、MCP 服务器、技能、命令、钩子 | 作用域/计数/搜索在统一头部；已安装、内置、来源分组；空状态给具体下一步 |
| 数据设置（1） | 使用统计 | 摘要、热力图、时间范围和趋势图分层；无数据区域有局部空状态 |
| 引导 | 首步及退出 | 三步进度、选项网格和右侧品牌区域；未继续提交偏好 |

当前安装版的自动化第二页是“工作流”；公开文档中的闲时任务、远程设备、归档设置等入口与本机导航并非完全一致，不能拿文档清单冒充原生已访问清单。[任务管理](https://zcode.z.ai/en/docs/task-management)、[自动化](https://zcode.z.ai/en/docs/automations)、[插件](https://zcode.z.ai/en/docs/plugin)

### Codex 官方资料覆盖的页面与流程

| 页面/流程 | 学习内容与来源 |
|---|---|
| 项目、聊天、最近项 | 项目与聊天的层级、固定、归档和搜索。[Projects](https://learn.chatgpt.com/docs/projects) |
| 工作区与 Worktree | 输入区选择环境、分支入口、Open/Hand Off。[Git worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees) |
| 输入与跟进 | 上下文、Slash、队列放在输入区附近，可编辑/重排/删除；Steer 与排队有不同意图。[Prompting](https://learn.chatgpt.com/docs/prompting)、[Slash commands](https://learn.chatgpt.com/docs/reference/slash-commands) |
| 长任务 | 目标进度靠近输入区，保留暂停/恢复等控制。[Long-running work](https://learn.chatgpt.com/docs/long-running-work) |
| 浏览器 | 标签、分屏/全屏、地址历史、元素/区域标注。[Browser](https://learn.chatgpt.com/docs/browser) |
| 本地与 PR 审阅 | 比较范围、文件折叠、行评论、暂存/撤销、PR 活动和检查。[Code review](https://learn.chatgpt.com/docs/code-review) |
| 终端 | 项目上下文内的终端与标签，不需要离开当前聊天。[Integrated terminal](https://learn.chatgpt.com/docs/integrated-terminal) |
| 插件、自动化 | 搜索/详情/连接状态；计划和运行状态分别表达。[Plugins](https://learn.chatgpt.com/docs/plugins)、[Automations](https://learn.chatgpt.com/docs/automations) |
| 通知、设置、命令 | 运行/未读/待响应的活动入口；界面和代码字体分离；命令面板与聊天查找分工。[Notifications](https://learn.chatgpt.com/docs/notifications)、[Settings](https://learn.chatgpt.com/docs/reference/settings)、[Commands](https://learn.chatgpt.com/docs/reference/commands)、[Developer settings](https://learn.chatgpt.com/docs/developer-settings) |

这些资料能支持工作流组织决策；没有足够证据给 Codex 下拉菜单、面板和消息转场指定精确毫秒或曲线。[官方更新记录](https://learn.chatgpt.com/docs/changelog)中关于滚动、侧栏和浮层稳定性的修复，说明这些细节值得验收，但不能代替动画实测。

### DeepSeek Harness 官方源码覆盖的页面与流程

以下源码固定在提交 `687f282e8625c6b8d11ff58211a90524be2e4317`。本轮另实际查看了官方[桌面首页图](https://www.deepseek.com/images/download/desktop-zh-1066.webp)、[插件管理图](https://www.deepseek.com/harness/images/feat-plugins-zh.webp)、[轨迹图](https://www.deepseek.com/harness/images/feat-trace-zh.webp)。图片支持视觉观察，源码支持行为和参数，二者都不能当作登录后的原生全流程验证。

| 页面/流程 | 已核对的内容与源码 |
|---|---|
| 欢迎、登录与引导 | 返回/跳过、等待浏览器登录、超时/失败/重试，以及办公/开发偏好。[Account UI](https://github.com/deepseek-ai/deepseek-harness/tree/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-settings-account) |
| 首页、会话、过程区 | 工作区与输入区；过程可折叠，正文与结果保留；操作在 hover/focus 显露。[Conversation](https://github.com/deepseek-ai/deepseek-harness/tree/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-conversation)、[Chat README](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-chat/README.zh.md) |
| 工作区与目录 | 分组/树/平铺、内联搜索、排序、归档/恢复；目录选择独立浏览流程。[Workspace](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-workspace/README.zh.md)、[Directory picker](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-directory-picker-browse/README.zh.md) |
| 插件管理与市场 | 已安装配置与市场发现分开；来源、筛选、详情、安装确认分别处理。[Plugin manager](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-plugin-manager/README.zh.md)、[Plugin market](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-plugin-market/README.zh.md) |
| 自动化 | 概览筛选、规则/运行历史、日期时间/重复/时区、未保存状态。[Schedule guide](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/docs/user/guide/schedule.zh.md) |
| 轨迹与工具详情 | 时间线、分组记录、局部检查器、缩放、选择区间；上滚暂停自动跟随。[Trajectory](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-trajectory/README.zh.md) |
| 右侧工作面 | 标签与分屏外壳，文件树、文档预览、浏览器、终端分别提供内容。[Right sidebar](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-sidebar-right/README.zh.md)、[Files](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-sidebar-files/README.zh.md) |
| 文件与交付物 | 多格式 renderer、统一换行/路径/刷新/滚动控制；Diff 单栏/并列，在侧栏中打开完整文件。[Document preview](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-sidebar-documentpreview/README.zh.md)、[Deliverables](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-deliverables/README.zh.md#L49) |
| 浏览器、终端 | 导航与预览；终端标签、重命名、恢复、关闭和折叠的区别。[Browser](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-sidebar-browser/README.zh.md)、[Terminal](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-sidebar-terminal/README.zh.md) |
| 子任务、后台任务、审批 | 子 Agent 树；后台任务按需出现并折叠完成项；审批/问题暂时占用输入区附近空间，历史只读。[Subagent](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-subagent/README.zh.md)、[Jobs](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-jobs/README.zh.md)、[User questions](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-user-questions/README.zh.md) |
| 目标、Todo、队列 | 仅在有内容时形成输入区上方的控制栈。[Goal](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-goal/README.zh.md) |
| 设置 | 通用/账户/模型/内置插件；设置导航与内容独立滚动；插件专用配置归插件自身管理。[General settings](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-settings-general/README.zh.md) |

## 2. 值得采用的 UI 和 UX 规则

以下是对原生观察和官方资料的设计归纳，属于本项目建议。

| 区域 | 建议采用的规则 | 对当前页面的具体改变 |
|---|---|---|
| 导航 | 项目/任务占主要空间；全局能力入口少而稳定；设置集中管理 | 调整当前先列出多项功能页再列任务的结构；终端、文件、Diff 与当前任务关联 |
| 空首页 | 一处主输入区、清楚的工作区、少量建议 | 去掉重复介绍、统计和多组竞争主视觉的入口 |
| 消息 | 按 turn 组织说明、过程、结果和变更；正文有连续阅读节奏 | 工具结果跟随所属回复；停止把全部 runs/审批统一追加到所有消息之后 |
| 工具过程 | 单行摘要、稳定状态槽、路径省略、按需展开 | 工具名称左对齐；完成后降低视觉重量；详细日志进入展开区或工作面 |
| 操作 | hover 与键盘 focus 都能显露；移动端有稳定可发现入口 | 复制/重试不再每次占据大行；显露操作不推动正文或状态的位置 |
| 输入区 | 项目、上下文、模型、模式沿一套紧凑工具栏组织 | 复用 PromptBar 行为，定制上下文与工具栏插槽；队列和待处理项靠近输入区 |
| 右侧工作面 | 统一 tabs、工具栏、空/错状态；内容自己伸展 | 文件、Diff、浏览器不再使用固定宽度的小卡片；支持收起、放大与返回 |
| 设置 | 左侧分类；标题/说明/控件成行；高级设置渐进展开 | 统一控件右对齐和内容宽度，长列表局部搜索；不用一页一套卡片语法 |
| 市场 | 轻量目录→能力详情→安装/连接状态 | 列表只保留必要摘要；详情保留路径返回和来源信息 |
| 自动化 | 计划、指令、运行历史各有位置；自然语言摘要优先 | 复用输入区；列表状态与单次运行状态区分；本地演示可切换空/加载/失败 |
| 空与错 | 空数据、无结果、不可用、失败、部分失败分别表达 | 提示出现在相应区域，保留可操作上下文；错误不靠 Toast 一闪而过 |
| 连续性 | 切换/关闭工作面不丢草稿、滚动、选中文件和当前范围 | 状态由稳定的应用模型保存，布局模式仅改变呈现 |

不要机械统一四家的品牌皮肤。它们的磨砂、主题、插图和装饰存在差异；我们更需要一致的密度、对齐、显露规则和状态连续性。

## 3. 动效：核实到什么，如何使用

原生点击确认了展开前后的布局、弹层内容和导航结果，本轮没有进行逐帧录制、帧率或曲线测量。Qoder 官方视频已定位，但播放请求出现 `ERR_CONNECTION_CLOSED`，不能写成“已看完演示”。Codex 视频目录也不能当作已观看记录。[Qoder 官方发布页](https://docs.qoder.com/release-notes/qoder)、[OpenAI 官方视频目录](https://learn.chatgpt.com/videos)

### 可核实的公开源码参数

| 客户端/场景 | 源码定义 | 设计意义与来源 |
|---|---|---|
| ZCode 下拉菜单 | 100ms；淡入淡出、95% 缩放、按方向的小幅位移 | 小浮层反馈快速；属于源码定义。[dropdown-menu.tsx](https://github.com/zai-org/ZCode/blob/0a1fc56d279fd1001f78387bd81aec1c26767411/packages/ui/src/components/ui/dropdown-menu.tsx) |
| Harness 右侧面板 | 300ms，`cubic-bezier(.4,0,.2,1)`；拖动分隔线时关闭 transition | 开关动画和直接拖动应采用不同规则。[面板样式](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-sidebar-right/src/client/shell/SidebarRight.module.css)、[时长与曲线变量](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-theme/src/styles/base.css)、[拖动样式](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-layout/src/client/AppFrame.module.css#L19) |
| Harness 任务行 | 增删透明度 100ms；重排 200ms；首屏不播放入场 | 仅动画实际变化的可见项，避免任务列表反复闪动。[AnimatedRows.tsx](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-workspace/src/client/rows/AnimatedRows.tsx) |
| Harness 内联搜索 | 宽度/位置 180ms，辅助元素淡入 120ms | 保持工具栏位置关系，不让整个侧栏重排。[WorkspaceBrowser.module.css](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-workspace/src/client/rows/WorkspaceBrowser.module.css) |
| Harness Modal | 透明度 200ms，配合背景遮罩 | 对话框不依赖明显弹跳表达层级。[Modal.module.css](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-primitives/src/Modal.module.css) |
| Harness 工具行 | Inspect 显露 100ms，预留操作槽 | 显露按钮时不推动名称、路径与状态。[ToolRow.module.css](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-tool/src/client/tool/components/ToolRow.module.css) |
| Harness 减少动态效果 | 多个组件在 reduced motion 下停用位移、shimmer 和 skeleton 动画 | 同一用户偏好由相应组件落实降级。[面板样式](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-sidebar-right/src/client/shell/SidebarRight.module.css)、[TextShimmer](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-primitives/src/TextShimmer.module.css#L79)、[PluginManagerPage](https://github.com/deepseek-ai/deepseek-harness/blob/687f282e8625c6b8d11ff58211a90524be2e4317/packages/client/ui-plugin-manager/src/client/PluginManagerPage.module.css#L393) |

### 本项目动效建议

库内已有 `BeautifulUiMotion` 与 `BeautifulMotionPolicy`：quick **120ms**、standard **220ms**、slow **420ms**、loop **1400ms**，以及 system/reduced/none 策略，见 `packages/beautiful_ai_ui/lib/src/foundation/motion.dart`。这些是我们现有的参数，不是竞品测量结果。

| 场景 | 建议消费现有 token | 必须同时满足的行为 |
|---|---|---|
| hover、focus、图标动作、短菜单 | quick | 不改变行高和正文布局；Esc 返回触发点 |
| 工具展开、标签内容、抽屉与工作面开关 | standard | 内容尺寸变化与外壳同步；中断/反向切换没有闪烁和溢出 |
| 分隔线拖动、用户主动滚动 | 无补间，直接跟随 | 松手后保持尺寸；不要在拖动过程中缓动 |
| 持续运行提示 | loop，仅局部使用 | 完成后停止；后台隐藏页不继续无意义循环；避免整段文字持续闪动 |
| 首次展示、切换已有聊天 | 默认不做逐项入场 | 保持滚动锚点；不因重建 Widget 把历史消息再次动画 |
| reduced/none | 复用已有策略 | 去掉非必要位移/循环，仍清楚传达选中、运行与失败 |

本轮没有发现需要直接复制竞品所有毫秒数的依据。先统一场景和状态衔接，再在真实预览中调整现有 token；slow 不应成为日常菜单或侧栏的默认速度。

## 4. 现有组件：哪些保留，哪些修改

以下代码路径均相对仓库根目录。调查时尚未修改这些实现。

| 对象 | 现状依据 | 决定与边界 |
|---|---|---|
| Theme 与 Motion | `foundation/theme.dart`、`foundation/motion.dart` | 继续使用，增加有限的 density、surface、control size 语义；不另外建立主题/动效体系 |
| ActionControl | `implementation/controls/action_control.dart:117`：现有文字规格与居中布局 | 增加 compact/comfortable、左对齐与 icon action；视觉尺寸和触控目标分别配置 |
| PromptBar | `components/prompt_bar.dart:135`、`:693`：输入法、草稿、异步结果归属保护 | 保留行为契约；最小增加上下文/工具栏插槽；项目、模型和队列意图由应用层处理 |
| SidebarNav | `components/sidebar_nav.dart:650`、`:1036`：固定编排和行规格 | 增加分组、紧凑行、平面变体及 rail Tooltip；项目/任务模型与路由在应用层 |
| StreamingText | `components/streaming_text.dart:395`、`:446`：完成状态和较大的动作区域 | 增加 quiet transcript 和紧凑动作显露；保留选择、复制、citation、Semantics |
| ToolChips / TaskRows | `components/tool_chips.dart:638`；`components/task_rows.dart:232` | 增加左对齐工具行、嵌入样式、父级宽度；复用展开、状态与焦点行为 |
| CodeBlock / Diff | `components/code_block.dart:229`：固定最大 420 与自带阴影 | 保留 typed diff 与复制行为；支持 stretch/embedded，由工作面决定外壳与宽度 |
| 控件点击区域 | `components/code_block.dart:593` 已区分 24 视觉按钮与 48 点击区域 | 延续此做法：桌面可紧凑，手机仍有合适的触控面积；不全局粗暴缩小到 24 |
| Chat 内容接口 | `components/chat.dart:39`、`:747`：当前消息以文本为主 | 实际页面需要时最小扩展内容 builder；turn 的过程、交付物和审批关联在应用层 |
| 应用外层卡片 | `packages/ade_workbench/lib/workspace_widgets.dart:29`；`workspace_extra.dart:55` | 去掉重复 Surface、边框和 shadow，统一工作面层级；不让所有功能都变成卡片 |
| 消息与运行顺序 | `packages/ade_workbench/lib/workspace_pages.dart:169`、`:213` | 按 turn 渲染说明→过程→结果→待处理；修正消息与 runs 分开堆叠的结构 |
| 全局导航 | `packages/ade_workbench/lib/workbench.dart:564`、`:650` | 应用层减少同级入口，保留全局页，把任务工具放回上下文；设置只保留清楚的一套入口 |

不直接把 Codex、ZCode、Harness、Qoder 的业务模型搬进组件库。可复用的视觉/交互原语进入库；工作区、turn、文件导航、审阅工具栏、自动化编辑和移动路由属于应用。

## 5. 页面与响应式方案

| 页面族 | 电脑端 | 手机端 |
|---|---|---|
| 任务与聊天 | 稳定的项目/任务侧栏；中央 turn；输入区固定在工作区底部 | 单列聊天；项目/任务抽屉；保留未发送草稿与当前任务 |
| 文件、Diff、浏览器 | 统一可调整工作面、tabs 和工具栏；可以收起或放大 | 独立全屏详情，返回恢复聊天位置；Diff 文件列表→文件内容逐级进入 |
| 终端 | 底部 dock 或工具 tab，避免与聊天争主视觉 | 全屏工具页，横向内容在自身区域滚动；前端壳展示可切换状态 |
| 搜索与选择 | 锚定弹层/命令面板，键盘上下、Enter、Esc | 搜索页或底部弹层，选中后回到调用位置 |
| 设置 | 分类导航与内容分别滚动；统一行、分组和高级区 | 分类列表→子页；保留表单编辑状态，固定必要的保存/取消位置 |
| 市场与详情 | 两列目录、可搜索和分类；详情有返回路径 | 单列目录与独立详情，能力描述按需展开 |
| 自动化 | 列表/模板/历史；指令与计划在足够宽度时分列 | 分段表单，计划选择用底部弹层；摘要始终可读 |
| 目标、审批、队列 | 靠近输入区，只有存在时出现；细节可展开 | 紧凑状态条进入详情，不遮住键盘、输入区或主要决定按钮 |

断点由内容所需宽度决定，并沿用现有 compact/medium/expanded 适配基础。桌面密度与手机触控密度分别定义；不能把桌面三栏等比例压缩后宣称完成移动适配。

建议的初始规格：桌面普通行 28–32、工具行 24–28、常用图标 14–16、按钮视觉高 28–32；正文 14、辅助 12；常用间距从 4/8/12/16/24/32 选择。这些是实现起点，需与现有 typography/spacing token 合并，经过中文长文、缩放和手机预览验收后再确定。

## 6. 实施顺序与验收

1. **先完成一个完整工作区切片**：任务列表→聊天→内联工具过程→文件 Diff→输入区；同时出电脑/手机、浅/深色和不同状态。先证明整页品质，再向其他页面推广。
2. **改组件的表现接口**：紧凑/舒适密度、flat/embedded、内容伸展、quiet transcript、紧凑动作栏、输入工具栏插槽。保持现有行为契约和默认兼容。
3. **重组应用布局**：项目/任务导航、turn 关联、工作面 tabs/放大/收起、手机详情路由与返回恢复；集中管理草稿、选择、滚动和工作面状态。
4. **推广到现有全部路由**：设置、市场、自动化、文件、Git 等按同一语法改造；逐页与原 `.pen` 的页面清单对照。竞品研究不代替原设计覆盖检查。
5. **检查实际交互与动态效果**：所有菜单、弹层、展开、返回、取消、复制和本地演示状态可用；再补齐下面的状态验收。

| 验收维度 | 通过条件 |
|---|---|
| 视觉 | 没有重复卡片外壳、无目的阴影、固定 420/440 宽度挤压；标题、控件、辅助信息有统一基线；手机长标签与中文换行不截断主操作 |
| 交互 | 键盘可进入与退出菜单；焦点返回触发点；图标有 Tooltip/语义；无 hover 设备仍能找到操作 |
| 状态 | 空、加载、运行、完成、失败、待确认、禁用、部分失败各有可演示路径；关闭局部详情不等于终止任务 |
| 连续性 | 切任务、开关工具面、调整宽度、手机进入/返回详情后，草稿、滚动和文件选择保持；新内容不会强行把正在回看的用户拉到底部 |
| 动效 | 使用库内 token；拖动直接跟随；退出可中断；历史内容不重复入场；减少动态效果模式可用 |
| 前端边界 | 所有演示由明确的本地状态驱动；回调为后续内核保留；不会显示虚假的真实执行或连接成功 |

下一步具体改造重点是：**导航骨架、桌面密度、turn/工具过程、统一工作面、输入区与状态动效**。研究并不要求新增竞品的全部功能；当前设计已有页面先达到同一套质量标准。
