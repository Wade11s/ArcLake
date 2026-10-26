# Split View（分屏）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
分屏不是几个无关联窗口：SidebarItemData 包含 splitView；SidebarSplitViewData 持久化 itemWidthFactors/layoutOrientation/focusItemID/timeLastActiveAt，运行态声明 windowContentIDs/focusedContentID/isResizingPanes。真实 add/close/separate/maximize 入口存在。官方“patched ... more than four tabs”支持设计上限四个；Favored Split Tabs 与共享 Split 发布记录支持分屏作为侧栏复合项保存。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `BaseModels.SidebarSplitViewData`

struct descriptor: `0x103bca050`；field descriptor: `0x103cf2cf4`

`itemWidthFactors`, `layoutOrientation`, `timeLastActiveAt`, `customInfo`, `focusItemID`

### `BaseModels.SidebarSplitViewData.LayoutOrientation`

enum descriptor: `0x103bca094`；field descriptor: `0x103cf2d5c`

`horizontal`, `vertical`

### `BaseModels.SidebarItemData`

enum descriptor: `0x103bc9c00`；field descriptor: `0x103cf276c`

`tab`, `list`, `arcDocument`, `easel`, `itemContainer`, `welcomeToArc`, `splitView`, `sharedObject`, `instantLinks`, `tabGroup`

### `BaseModels.SplitViewPaneMenuOperation`

enum descriptor: `0x103bcae38`；field descriptor: `0x103cf42b0`

`moveLeft`, `moveRight`, `addPaneLeft`, `addPaneRight`, `addPaneTop`, `addPaneBottom`, `separate`, `copyLink`, `flipLayoutOrientation`

### `WindowContents.SplitViewState`

struct descriptor: `0x103c104f8`；field descriptor: `0x103d385ec`

`windowContentIDs`, `layoutOrientation`, `interactionState`, `focusedContentID`

### `WindowContents.SplitViewState.InteractionState`

struct descriptor: `0x103c10530`；field descriptor: `0x103d38654`

`activePaneEditStyles`, `proposedWindowContentDropTarget`, `isResizingPanes`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| addSplitPanel: | _TtC3Arc20MainWindowController | 0x10031d3c0 | [assembly](assembly/_TtC3Arc20MainWindowController--addSplitPanel.asm) |
| closeFocusedSplitViewPanel: | _TtC3Arc20MainWindowController | 0x10031d6fc | [assembly](assembly/_TtC3Arc20MainWindowController--closeFocusedSplitViewPanel.asm) |
| separateTabFromSplitView: | _TtC3Arc20MainWindowController | 0x10031d70c | [assembly](assembly/_TtC3Arc20MainWindowController--separateTabFromSplitView.asm) |
| maximizeCurrentSplitViewPane: | _TtC3Arc20MainWindowController | 0x10031b6cc | [assembly](assembly/_TtC3Arc20MainWindowController--maximizeCurrentSplitViewPane.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Arc for macOS - 2024 - 2026 Release Notes — ## Mar 7, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 954 行）

> * We've patched some edge-cases in trying to open more than four tabs in Split Views.

### Arc for macOS - 2023 Release Notes — ## November 2, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 102 行）

> * We've fixed a bug where Favorited Split Tabs were not focused correctly after Space switching.

### Arc for macOS - 2023 Release Notes — ## November 30, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 56 行）

> * It's now possible to mute a tab in Split View by right-clicking on the split and selecting "Mute" under the tab's name. It's also now possible to duplicate a split in the tab's right-click menu.

### Arc for macOS - 2023 Release Notes — ## October 26, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 113 行）

> * Introducing Shared Collections! You can now share perma-links to Spaces, Folders, Split Views, and selected tabs to anyone, on any browser. Right click on any Folder, Split View, or selected tab group in your sidebar and click the "Share" option. To share Spaces, hover over your Space title and click "Share". Anyone, with any browser, can view the link. Arc members can add the Shared Collection to their sidebar.

### Arc for macOS - 2023 Release Notes — ## December 14, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 7 行）

> * You can now flip Split View orientation (top to bottom vs left to right) through the Split Controls button at the top of your split panel.

## 残留未知
没有找到并验证“>=4 拒绝”的机器码分支；分屏整体 Pin 操作与调整尺寸未运行。复合项模型支持固定的推论，不冒充已成功固定操作。

[首轮证据](../09-split-view.md) · [本轮完整 JSON](09-split-view.json) · [总报告](README.md)
