# Pinned Tabs（固定标签）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
真实固定/取消固定入口存在；模型明确 pinned/unpinned 与 customTitle，文档确认固定标签永不 Auto Archive、仅属于一个 Space、可分组，官方发布说明确认双击或右键重命名。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `BaseModels.SidebarItem`

struct descriptor: `0x103bca8f0`；field descriptor: `0x103cf3b48`

`id`, `title`, `childrenIds`, `parentID`, `data`, `createdAt`, `isUnread`, `originatingDevice`

### `BaseModels.SidebarItemContextType`

enum descriptor: `0x103bca93c`；field descriptor: `0x103cf3c28`

`topApp`, `pinned`, `unpinned`

### `BaseModels.SpaceModel.ContainerType`

enum descriptor: `0x103bcab4c`；field descriptor: `0x103cf3f24`

`unpinned`, `pinned`

### `SidebarItemUI.TabTitleSourceInfo`

class descriptor: `0x103c117a0`；field descriptor: `0x103d39eec`

`customTitle`, `webContentTitle`, `webContentURL`, `savedTitle`, `savedURL`, `tidyTabTitles`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| toggleSelectedItemsPinned: | _TtC3Arc20MainWindowController | 0x10031d71c | [assembly](assembly/_TtC3Arc20MainWindowController--toggleSelectedItemsPinned.asm) |
| expandPinnedSection: | _TtC3Arc20MainWindowController | 0x10031defc | [assembly](assembly/_TtC3Arc20MainWindowController--expandPinnedSection.asm) |
| collapsePinnedSection: | _TtC3Arc20MainWindowController | 0x10031df0c | [assembly](assembly/_TtC3Arc20MainWindowController--collapsePinnedSection.asm) |
| resetVisiblePinnedTabs: | _TtC3Arc20MainWindowController | 0x1003207a8 | [assembly](assembly/_TtC3Arc20MainWindowController--resetVisiblePinnedTabs.asm) |
| rename: | _TtC3Arc20MainWindowController | 0x1003208dc | [assembly](assembly/_TtC3Arc20MainWindowController--rename.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Pinned Tabs: Tabs you want to stick around — ## What are Pinned Tabs?

[官方来源](https://resources.arc.net/hc/en-us/articles/19231060187159-Pinned-Tabs-Tabs-you-want-to-stick-around) / [已保存正文](official-docs/19231060187159.md)（抽取正文第 13 行）

> One major difference between Pinned and Unpinned Tabs is that Pinned Tabs never Auto Archive. You can read about Auto Archive here.

### Pinned Tabs: Tabs you want to stick around — ## What are Pinned Tabs?

[官方来源](https://resources.arc.net/hc/en-us/articles/19231060187159-Pinned-Tabs-Tabs-you-want-to-stick-around) / [已保存正文](official-docs/19231060187159.md)（抽取正文第 11 行）

> **Pinned Tabs** are tabs saved to particular Space. Pinned Tabs live in the top half of your sidebar, above the horizontal line. Pinned Tabs can be grouped into folders or exist on their own.

### Arc for macOS - 2024 - 2026 Release Notes — ## Mar 7, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 952 行）

> * We are unshipping the rename prompt that opens immediately when pinning a tab! Double-click or right-click on any tab to rename it.

### Pinned Tabs: Tabs you want to stick around — ## What are Pinned Tabs?

[官方来源](https://resources.arc.net/hc/en-us/articles/19231060187159-Pinned-Tabs-Tabs-you-want-to-stick-around) / [已保存正文](official-docs/19231060187159.md)（抽取正文第 24 行）

> Pinned Tabs are only accessible in one Space. Favorites are accessible in every Space. Learn more about Favorites here!

## 残留未知
尚未追踪归档筛选函数如何实现 pinned 豁免；文档声明和本地机器码入口不能替代计时测试。

[首轮证据](../05-pinned-tabs.md) · [本轮完整 JSON](05-pinned-tabs.json) · [总报告](README.md)
