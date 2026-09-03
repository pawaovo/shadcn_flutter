# 真机与实际读屏验收包

本包复用现有 `integration_test/catalog_journey_test.dart`，用于设备接入后留下
可复核的构建、程序化交互、真实输入和读屏证据。准备命令不会安装应用；
`journey` 会构建并安装 Catalog 测试应用。自动测试通过后，仍需用普通 Catalog
完成下列人工流程。工具不会自动接受人工项目或改写平台支持状态。

## 当前可执行部分与硬依赖

2026-09-03 本机盘点只发现 macOS 与 Chrome，未发现可用 Android/iOS 真机。
运行准备命令可以重新取得当前状态，旧盘点不能替代接入后的检测。

| 目标 | 必需环境 | 实际读屏入口 |
|---|---|---|
| Android 真机 | 实体手机/平板；USB 或已配对无线调试；用户解锁并接受调试授权；支持该设备的 SDK | 设置 → 无障碍 → TalkBack；先在教程中确认该设备手势。通过读屏前后导航、双击激活及读屏滚动完成流程。 |
| iPhone/iPad 真机 | Mac + Xcode；设备信任；Developer Mode；可用开发签名/团队；设备与 Xcode 的 OS 支持兼容 | 设置 → 辅助功能 → 旁白。使用左右轻扫导航、双击激活，以及对应滚动、转子和文本编辑操作。 |
| macOS | 已解锁的交互式桌面，能听到 VoiceOver 输出 | 系统设置 → 辅助功能 → 旁白，或 Command-F5；按当前 VO 修饰键配置导航、交互与激活。 |
| Windows | 对应 Windows 交互式桌面、Flutter Windows 开发环境和真实输出设备 | Windows-Ctrl-Enter 启动 Narrator；使用实际配置的 Narrator 导航、扫描和文本编辑命令。 |
| Linux | 对应 GNOME/兼容桌面会话，Orca 与 AT-SPI 可用，能听到语音 | 设置 → 辅助功能 → 屏幕阅读器，或 GNOME 的 Super-Alt-S；使用当前 Orca 桌面/笔记本键位。 |

设备授权与账户签名需要持有人在系统界面完成。此包不请求密码、不改全局
`xcode-select`、不替用户启用调试或辅助功能。iOS 工程目前使用
`dev.beautifulai.beautifulAiUiCatalog`；若 Xcode 要求设置个人 Team，在
`packages/beautiful_ai_ui_catalog/ios/Runner.xcworkspace` 的 Runner 签名页面操作，
并保留工程变化记录。没有签名时记录 `blocked`，不以模拟器冒充真机。

入口与设备设置依据：
[Flutter iOS 设备设置](https://docs.flutter.dev/platform-integration/ios/setup)、
[Android 真机调试](https://developer.android.com/studio/run/device)、
[TalkBack 开启](https://support.google.com/accessibility/android/answer/6007100?hl=en)、
[TalkBack 手势](https://support.google.com/accessibility/android/answer/6151827?hl=en)、
[iPhone 旁白](https://support.apple.com/guide/iphone/turn-on-and-practice-voiceover-iph3e2e415f/26/ios/26)、
[Mac 旁白](https://support.apple.com/guide/voiceover/turn-voiceover-on-or-off-vo2682/mac)、
[Narrator 指南](https://support.microsoft.com/en-us/windows/complete-guide-to-narrator-e4397a0d-ef4f-b386-d8ae-c172f109bdb1)、
[GNOME 屏幕阅读器](https://help.gnome.org/gnome-help/a11y-screen-reader.html)。
菜单、键位和声音取决于实际 OS/读屏版本，须记录实际值。

## 直接运行

在仓库根目录运行。需要 Python 3 与仓库锁定的 Flutter 3.47.0 / Dart 3.13.0；
默认通过 `mise exec -- flutter` 调用，Mac 上也识别 `/opt/homebrew/bin/mise`。
Windows 可将 `python3` 换为 `python`；没有 mise 时附加
`--flutter-bin "实际 Flutter 可执行文件绝对路径"`。

```bash
# 没有设备也可以准备；每次生成独立记录，不安装或启动应用。
python3 tool/run_device_acceptance.py prepare --platform android
python3 tool/run_device_acceptance.py prepare --platform ios

# 设备接入后，先从输出的 Eligible device IDs 获取精确 ID，再执行：
python3 tool/run_device_acceptance.py journey --platform android --device "实际 Android ID"
python3 tool/run_device_acceptance.py journey --platform ios --device "实际 iPhone 或 iPad ID"

# 在对应主机运行桌面基线；这不代表已运行读屏。
python3 tool/run_device_acceptance.py journey --platform macos --device macos
python3 tool/run_device_acceptance.py journey --platform windows --device windows
python3 tool/run_device_acceptance.py journey --platform linux --device linux
```

输出默认写到 `packages/beautiful_ai_ui_catalog/build/device-acceptance/<UTC>-<platform>/`。
`--output` 可指定一个尚不存在的目录；任何已有记录都不会覆盖。
目录中有 `record.json`、Flutter 版本、设备清单、Git SHA/工作区状态，以及实际运行的
命令、完整 `journey.log`、日志 SHA256、退出码和耗时。Android/iOS 只接受 Flutter
明确标识 `emulator: false` 的对应平台设备，Chrome 或模拟器不能通过筛选。

默认构建、安装及测试共用 30 分钟期限，可通过 `--timeout` 设置秒数。
退出码 0 **并且**实际输出 `All tests passed.` 或 `All tests passed!` 才记为
程序化 journey 通过；超时、错误或缺少成功输出都不通过。重复运行创建新记录，
保留失败原因。屏幕阅读器和人工项目始终由实际操作证据决定。

## 普通应用与读屏操作

完成 journey 后，启动正常应用入口。不要使用测试入口做读屏验收，原生端也不要
加入 Web semantics define。在 Catalog 包目录运行以下命令并换成实际设备 ID；
Windows/Linux 使用各自的桌面设备 ID：

```bash
cd packages/beautiful_ai_ui_catalog
mise exec -- flutter run --release --target=lib/main.dart --device-id "实际设备 ID"
```

这台 Mac 的全局开发目录为 CLT；iOS/macOS 普通启动命令需要在该终端设置
`export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`。
记录应用编译模式与命令，将安装后的普通应用冷启动一次，再开启或使用已开启的
系统读屏。首次验收从新会话开始，避免前一次自动测试的状态影响预期。

### 实际文件宿主入口

Catalog 已提供显式开启的系统文件选择入口。在 Catalog 包目录中运行：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  mise exec -- flutter run --release --device-id macos --target=lib/main.dart \
  --dart-define=CATALOG_REAL_FILES=true
```

其它平台替换 device ID，并按平台移除不适用的 `DEVELOPER_DIR`。此开关仅影响
Prompt 文件回调；默认未开启时，现有自动 journey 仍使用样例附件。

在 Prompt Bar 的 Add sources and files 菜单中选择 **Choose files from device**，
用系统对话框一次选中两个自建文件。宿主实际读取字节，显示完整文件名、字节数与
SHA-256；核对本机原文件摘要后再发送，确认只包含当前选中、未删除的附件 receipts。
重复选择同名文件会产生独立附件 ID。再次打开后取消，原附件应保留；文件读取失败
会显示错误并拒绝本次整批附件，可再次选择重试。内容按流读取，不上传或持久化；
发送仍是本地演示接收回调。

`host_file_attachments_test.dart` 已验证多文件内容、空文件、原始文件名、取消、
同名独立 ID、picker 异常、实际临时文件的部分失败/重试及无来源附件拒绝。
这些回调测试不代替系统对话框的实际操作证据。`host-file-input` 需要在真实模式
完成选择、取消、删除、发送和原文件摘要核对后填写，不能用默认样例模式通过。

依赖只加入不可发布的 Catalog：`file_selector 1.1.0` 与原已解析的 `crypto 3.0.7`，
组件库 API 与发布依赖未变。macOS Debug/Profile、Release 只增加用户所选文件的
只读 sandbox entitlement。精确版本、包归档与许可证摘要见
[文件宿主依赖记录](./file-selector-dependencies.json)。Android 插件附带 aFileChooser
Apache-2.0；Catalog 的 `NOTICES` 保留其完整 BSD/Apache 正文并补正确包名 header。
现有生产 `LicenseRegistry` probe 已验证 11 个完整标签；此结果对应生成的测试
assets，实际发布构建仍需保留相同 notices。

每个设备/OS/读屏/窗口配置独立使用一份 `record.json`。如果只准备人工记录，先运行
`prepare --platform <平台> --device <ID>`。原始设备标识和日志保留在本地 build
目录，发布报告使用设备别名并保留可追溯映射。若工作区包含源码变化，Git SHA
不足以单独定位测试对象，须提交源码后重跑，或另附实际测试源码补丁。

录制能听到实际读屏输出的短视频或音频，并同步记录操作与结果；可补充读屏字幕、
截图和 AX/语义树。仅截图或语义树不能证明听到的名称、顺序或状态。记录应包括：

- 操作人、时间、设备型号、OS 和读屏版本、声音语言、输入法、键位和输入硬件。
- 每次焦点移动读出的名称/角色/状态，以及激活后真实焦点落点和实际任务结果。
- `evidence` 内写相对文件名、对应时间段和 SHA256；例如
  `{"path":"voiceover-chat.mp4","range":"00:12-00:38","sha256":"实际摘要"}`。
- 失败项目写复现动作、实际输出、预期输出、对应片段和问题链接；不要删去失败记录。

## 20 个组件的操作与成功条件

下表来自现有 Catalog 演示与共享 journey，是待执行脚本，不是已通过结果。
每行都要使用当前读屏的导航/激活方式完成，而非只用鼠标找到控件。
除实际状态结果外，还需验证可读名称、角色、选中/禁用/展开状态与操作后的焦点。

| 记录 ID | 操作 → 应能观察/听到的结果 |
|---|---|
| `loading-state` | 找到 Drive、Dots、Orbit、Surfer；加载含义可感知；切换 reduced motion 后动态减少，状态朗读不持续打断用户。 |
| `thinking-state` | Hide steps → 收起且入口变为 Show steps；再次激活恢复详情。 |
| `context-cards` | 打开 Dairy Onboarding SOP.pdf → 本地反馈 `Opened source: vendor-rule` 可感知。 |
| `recommendation-card` | Alternatives → Other options；Accept → Accepted，读屏能辨别结果。 |
| `search` | 输入 `waffle`，导航并选择候选 → `Find waffle cone suppliers` 写回输入框。 |
| `code-block` | Copy → Copied 本地反馈；代码与 diff 新增/删除含义可读。系统剪贴板另验。 |
| `streaming-text` | 来源展开及首条来源可读；Retry answer → Response recovered；Run stream demo → 完成状态，流式更新不反复朗读全文。 |
| `approval-card` | Scoop shops → Pistachio 与 Vanilla → Continue → This Friday → Submitted 3 approval answers；单选、多选状态可区分。 |
| `tool-chips` | Plan restock → 输出说明；Show more files → restock.json；forecast diff → pistachio,100 可读；收起后焦点有效。 |
| `task-rows` | capsules 和 list 分别 Retry → Supplier email draft recovered、完成状态；失败与完成不只靠颜色区分。 |
| `chat-composer` | 输入 Check cone inventory → Send → 消息出现；Stop response → Demonstration response stopped.；Suppliers 切换正确上下文。 |
| `filter-table` | completed 过滤 → Review seasonal forecast 保留、Count waffle cone stock 隐藏，过滤选中状态可读。 |
| `fine-tune-card` | Grid → Accepted layout: grid；Select type → Seasonal；Width 输入 360 确认后保留，调整动作读出当前值。 |
| `prompt-bar` | /rest 选择 /restock；模型 Precise；添加样例文件；输入 Prepare the seasonal restock 并发送 → Prompt received 且 draft 清空，模型/附件状态可读。 |
| `diff-table` | 排除 sorbet，翻页读 Unchanged，再 Apply → Applied inventory changes: pistachio, rocky-road；before/after、包含状态可辨别。 |
| `records-table` | 搜索 Cone → Properties 配置 summary 并 Run → Calculated 1 supplier records；Save → Saved supplier property: summary；cone 详情包含 7 days lead time。 |
| `sidebar-nav` | 紧凑模式 Open navigation；Seasonal 工作区 → Inventory → Selected workspace: seasonal · destination: inventory；关闭回到逻辑入口。 |
| `flowchart` | Steps 中将 stock threshold 设为 60 → Accepted stock threshold: 60 tubs；扩展模式另验证真实指针移动节点与键盘替代操作。 |
| `insight-cards` | 展开 comparison chart data 可读精确值；选 delay → Selected delivery metric: delay；选 sorbet → Selected order allocation: sorbet；follow-up 可达。 |
| `selection-actions` | Improve → Suggested text → Keep change → Accepted document edit: improve；再 Reset 后实际建立新选区并重复，确认只替换所选范围。 |

## 跨组件实际输入与读屏检查

| 记录 ID | 必须执行的操作与证据 |
|---|---|
| `focus-order-dismissal` | 不依赖鼠标坐标遍历入口、表单、弹层、滚动内容；读屏前后导航和 Tab/Shift-Tab（有键盘时）顺序合理；Escape、系统返回/关闭后焦点回到有效入口，不陷入循环。 |
| `native-ime-editing` | 使用实际中文拼音输入法在 Chat、Prompt、Search 完成组合、候选选择、编辑和提交；未提交的组合不得误发送；记录实际键盘遮挡情况。英文长文本和本机可用 RTL 输入法也保留独立记录。 |
| `native-selection-clipboard` | Reset 后用实际触摸/键盘/读屏创建非默认选区，修改边界并执行操作；用系统文本编辑菜单复制输入内容，到另一普通应用粘贴后核对，再反向粘回；不得只看 Copied 标签。 |
| `resize-rotation-keyboard` | 留有草稿、已选记录与筛选条件时旋转/分屏/调整窗口、打开并关闭软件键盘，确认任务和状态保留、主要操作可达；平板/键盘能力缺失必须记录边界。 |
| `large-text-rtl-contrast-motion` | 记录 200% 文本、长中文/英文、RTL、高对比、light/dark、正常/减少动态的实际配置；逐组件确认关键任务可完成；每种配置独立记录，不能用单个宽度覆盖全部布局。 |
| `host-file-input` | 开启 CATALOG_REAL_FILES，用系统文件选择器多选真实文件、取消、删除、发送并核对文件字节数/摘要；默认样例附件不能关闭此项。真实平台尚未操作时保持 not_run。 |
| `host-dictation` | 在真实消费者宿主中处理系统麦克风/语音权限，实际说话、停止/取消并核对转写；Catalog 的 Insert sample dictation 不能关闭此项。 |

**当前演示边界：** Code Block 与 Streaming Text 的 Copy 回调现已等待系统
`Clipboard.setData` 完成后再给成功反馈；各平台仍要完成真实跨应用粘贴验收，
不能只看 Copied 标签。Prompt 默认附件是样例元数据，真实文件入口需显式开启；
听写仍返回固定文本，来源连接只更新本地状态。AI 回复、重试、审批、应用变更与
数据计算也在本地完成。上述演示成功只能证明对应 UI 契约，真实宿主集成应另有
可复现入口；不能把它们记成系统剪贴板、文件、语音、外部资料或服务端验收通过。

## 接受记录

`manual_cases[].status` 使用 `not_run`、`passed`、`failed`、`blocked`；只有确实
不适用的功能才使用 `not_applicable`，并在 `observed` 与
`decision.scope_exclusions_with_reason` 说明原因。缺设备、缺读屏或未执行属于
`blocked`/`not_run`。所有适用项目均有真实证据且独立复核后才填写
`decision.status: accepted` 与复核人/时间；脚本永远不会生成这个决定。

一个记录只接受其声明的设备、构建、输入和显示配置。手机记录不能代替 iPad
分屏、Windows Narrator 或 Linux Orca；程序化性能 workload 也不能替代真实
IME/触摸/读屏输入。平台升为 Verified 仍需合并支持矩阵中的其它独立发布门槛。
