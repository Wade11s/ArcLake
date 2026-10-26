# Little Arc（小窗口）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
独立 LittleBrowserWindow 有真实 openInCurrentSpace: 实现；LittleBrowser.Action 明确 moveContentToStandardGlobalWindow；目标携带 spaceID 和 absolute/pinned/unpinned。入口枚举包含 externalLink/internalLink/globalHotkey，状态单独持有 profile/session。官方历史记录还说明多小窗、外部重复链接复用与按域名记忆 Profile。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `LittleBrowser.LittleBrowser.State`

struct descriptor: `0x103c14a28`；field descriptor: `0x103d3e05c`

`id`, `downloads`, `session`, `moveToDestinationInfo`, `profile`, `shouldShowProfileIndicators`, `activeMenuType`, `moveMenuState`, `modalState`, `nuxState`

### `LittleBrowser.LittleBrowser.Action`

enum descriptor: `0x103c14a50`；field descriptor: `0x103d3e0e4`

`downloadsManager`, `downloadsTray`, `moveContentToStandardGlobalWindow`, `toolbar`, `permissionRequest`, `extensions`, `modalStateChanged`, `moveMenu`, `setProfile`, `setupSubscriptions`, `presentNUXView`, `onCloseNUXViewClicked`, `toggleMoveMenu`

### `LittleBrowser.LittleBrowserEntryPoint`

enum descriptor: `0x103c14bc8`；field descriptor: `0x103d3e364`

`internalLink`, `externalLink`, `floatingWindow`, `mainMenu`, `statusItem`, `globalHotkey`, `sidebarPlusButton`, `browserPopup`, `draggedTab`

### `LittleBrowser.LittleBrowserMoveToStandardWindowDestination`

struct descriptor: `0x103c14ce0`；field descriptor: `0x103d3e59c`

`spaceID`, `type`

### `LittleBrowser.LittleBrowserMoveToStandardWindowDestination.DestinationType`

enum descriptor: `0x103c14cfc`；field descriptor: `0x103d3e5c4`

`absolute`, `pinned`, `unpinned`

### `LittleBrowser.LittleBrowserSession`

struct descriptor: `0x103c14d50`；field descriptor: `0x103d3e66c`

`id`, `entryPoint`, `preferredFrame`, `startTime`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| openInCurrentSpace: | _TtC3Arc13BrowserWindow | 0x10014c4f0 | [assembly](assembly/_TtC3Arc13BrowserWindow--openInCurrentSpace.asm) |
| newLittleBrowserWindow: | _TtC3Arc11AppDelegate | 0x1002358d0 | [assembly](assembly/_TtC3Arc11AppDelegate--newLittleBrowserWindow.asm) |
| openInCurrentSpace: | _TtC3Arc19LittleBrowserWindow | 0x1002c51d4 | [assembly](assembly/_TtC3Arc19LittleBrowserWindow--openInCurrentSpace.asm) |
| openInCurrentSpace: | _TtC3Arc20MainWindowController | 0x1003207b0 | [assembly](assembly/_TtC3Arc20MainWindowController--openInCurrentSpace.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Arc for macOS - 2023 Release Notes — ## November 30, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 48 行）

> * Little Arc Windows now auto-archive every 6 hours by default. You can edit this setting in Arc > Settings > General. You can view all archived tabs by hitting CMD T and typing "View Archive". Filter for Little Arc.

### Arc for macOS - 2023 Release Notes — ## November 2, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 96 行）

> * If you click the same link within an external app, we'll simply resurface the existing Little Arc window instead of creating a duplicate one.

### Arc for macOS - 2023 Release Notes — ## November 2, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 97 行）

> * Little Arc will now remember the profile you select for a given domain. New links within that domain will have the profile automatically selected.

### Arc for macOS - 2023 Release Notes — ## October 12, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 144 行）

> * You can now have multiple Little Arc windows open at once! You'll also notice improvements to design and Little Arc opening animations.

### Arc for macOS - 2023 Release Notes — ## Jan 19, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 690 行）

> * Little Arc will now always appear above your full screen window, that way it won't get lost.

## 残留未知
Little Arc 6 小时归档来自 2023 历史发布说明，不是本机当前默认值实测；性能“轻量”、层级和主工作区无干扰没有测量。

[首轮证据](../10-little-arc.md) · [本轮完整 JSON](10-little-arc.json) · [总报告](README.md)
