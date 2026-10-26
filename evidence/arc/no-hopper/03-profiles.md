# Profiles（配置文件）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
SpaceModel.profile 将工作区与浏览配置关联；主窗口 changeProfileForCurrentSpace: 已定位到可执行代码。命令栏搜索管理器另有 profileSpecificStates，profile 内有 mostVisitedSites/siteEngagementScores。结合已保存的应用说明，Cookie/登录/历史/扩展隔离属于明确产品契约。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `ADKModels.Profile`

enum descriptor: `0x103bb874c`；field descriptor: `0x103ce55d8`

`custom`, `initial`

### `BaseModels.SpaceModel`

struct descriptor: `0x103bcab30`；field descriptor: `0x103cf3ed8`

`id`, `title`, `containerIDs`, `customInfo`, `profile`

### `SearchClientManager.SearchClientManager`

class descriptor: `0x103c273f4`；field descriptor: `0x103d54010`

`dependencies`, `$__lazy_storage_$_backgroundQueue`, `$__lazy_storage_$_providers`, `profileSpecificStates`, `cacheMaxCount`, `$__lazy_storage_$_fuzzyMatchScoreCache`, `$__lazy_storage_$_tokenizedTextMatchInfoCache`

### `SearchClientManager.SearchClientManager.ProfileSpecificState`

struct descriptor: `0x103c2756c`；field descriptor: `0x103d54174`

`mostVisitedSites`, `siteEngagementScores`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| changeProfileForCurrentSpace: | _TtC3Arc20MainWindowController | 0x10031d3ac | [assembly](assembly/_TtC3Arc20MainWindowController--changeProfileForCurrentSpace.asm) |
| newProfile: | _TtC3Arc20MainWindowController | 0x10031b7a4 | [assembly](assembly/_TtC3Arc20MainWindowController--newProfile.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Arc for macOS - 2023 Release Notes — ## November 30, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 68 行）

> * Performance improvement: each Little Arc window will perform fewer per-profile actions when first opening.

### Arc for macOS - 2024 - 2026 Release Notes — ## January 18, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 1046 行）

> * Introducing per-Profile Archive settings! You can edit your Archive timing per Profile (and adjust all other per-Profile settings) in the new Arc > Settings > Profile menu.

### Arc for macOS - 2024 - 2026 Release Notes — ## January 25, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 1036 行）

> * We've polished the UX in the new Arc > Settings > Profiles menu.

### Arc for macOS - 2024 - 2026 Release Notes — ## January 25, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 1035 行）

> * We've improved the look and feel of the UX when you have no Favorites.

## 残留未知
没有审计 ArcCore 内部存储实现，也没有跨 Profile 的 Cookie/登录实验；不能把静态字段当成完整隔离安全证明。

[首轮证据](../03-profiles.md) · [本轮完整 JSON](03-profiles.json) · [总报告](README.md)
