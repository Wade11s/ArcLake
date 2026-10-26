# Folders（文件夹）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
Folder 在模型中使用 list 项；SidebarItem 的 parentID/childrenIds 提供树关系，另有 dragEnter/dragOver/dragExit 事件。REA 的 New Folder → newList: 已连接到真实方法地址。官方发布说明确认共享文件夹、嵌套文件夹和共享内容插入固定区域。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `BaseModels.SidebarItem`

struct descriptor: `0x103bca8f0`；field descriptor: `0x103cf3b48`

`id`, `title`, `childrenIds`, `parentID`, `data`, `createdAt`, `isUnread`, `originatingDevice`

### `BaseModels.SidebarItemData`

enum descriptor: `0x103bc9c00`；field descriptor: `0x103cf276c`

`tab`, `list`, `arcDocument`, `easel`, `itemContainer`, `welcomeToArc`, `splitView`, `sharedObject`, `instantLinks`, `tabGroup`

### `SidebarItemUI.DragReceivedEvent`

enum descriptor: `0x103c117e8`；field descriptor: `0x103d39f44`

`dragEnter`, `dragOver`, `dragExit`

### `SidebarItemUI.TablistItemDragReceivedEvent`

struct descriptor: `0x103c11820`；field descriptor: `0x103d39fa0`

`item`, `event`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| newList: | _TtC3Arc20MainWindowController | 0x10031f8a0 | [assembly](assembly/_TtC3Arc20MainWindowController--newList.asm) |
| collapseAllFolders: | _TtC3Arc20MainWindowController | 0x10031f8a8 | [assembly](assembly/_TtC3Arc20MainWindowController--collapseAllFolders.asm) |
| expandAllFolders: | _TtC3Arc20MainWindowController | 0x10031f9c4 | [assembly](assembly/_TtC3Arc20MainWindowController--expandAllFolders.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Arc for macOS - 2023 Release Notes — ## October 26, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 113 行）

> * Introducing Shared Collections! You can now share perma-links to Spaces, Folders, Split Views, and selected tabs to anyone, on any browser. Right click on any Folder, Split View, or selected tab group in your sidebar and click the "Share" option. To share Spaces, hover over your Space title and click "Share". Anyone, with any browser, can view the link. Arc members can add the Shared Collection to their sidebar.

### Arc for macOS - 2023 Release Notes — ## November 30, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 57 行）

> * Adding Shared Folders to your sidebar will now always insert at the bottom of your Pinned Tabs section.

### Arc for macOS - 2023 Release Notes — ## Jan 19, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 692 行）

> * Right clicking on a Folder and selecting Copy All Links will now include URLs in nested Folders.

### Arc for macOS - 2024 - 2026 Release Notes — ## January 25, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 1031 行）

> * Clicking outside of the text input field while renaming Folders will now save your new name.

## 残留未知
拖拽落点和树重排算法未完整追踪；分享服务没有现场调用，不能保证旧分享服务当前仍可用。

[首轮证据](../06-folders.md) · [本轮完整 JSON](06-folders.json) · [总报告](README.md)
