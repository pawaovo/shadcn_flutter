# 本机设备与 VoiceOver 观测能力 · 2026-09-03

本次实际尝试确认：本机可启动 VoiceOver，但当前控制工具无法读取它的字幕窗口，
因此没有接受任何新的实际读屏任务。此记录是能力探测，不是组件读屏通过证据。

`flutter devices --machine` 只列出 macOS 和 Chrome；
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl list devices`
返回 `No devices found.`。没有用模拟器替代真机验收。

系统设置的旁白开关最初为关闭。通过界面暂时开启后，开关显示开启，并实际观察到
VoiceOver 进程；旁白实用工具的“显示字幕面板”原本已勾选，没有修改该偏好。
两次读取 `com.apple.VoiceOver` 窗口均返回
`Computer Use server error -10005: timeoutReached`。Safari 的 AX 树仍可读取，
但它不能证明 VoiceOver 实际朗读了哪些内容。没有录入名称、角色、状态或任务通过结论。

最后通过原设置开关关闭旁白，并重新观察到 `off`，恢复了测试前状态。
设备接入与实际读屏操作的可运行入口见
[真机与读屏验收包](../device-acceptance/README.md)。机器记录见
[local-at-capability.json](./2026-09-03-local-at-capability.json)。

开启及字幕面板操作依据 Apple 的
[VoiceOver 开关说明](https://support.apple.com/en-gb/guide/voiceover/vo2682/mac)和
[VoiceOver 通用命令](https://support.apple.com/en-ie/guide/voiceover/cpvokys01/mac)。
当前限制是本次工具无法观测实际读屏输出；没有据此断言 VoiceOver 或组件存在缺陷。
