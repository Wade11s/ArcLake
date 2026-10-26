# 自动归档 / Today

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
Archive 模块具有 runAutoArchive/autoArchiveItems/removeExpiredItems 生命周期动作；状态带 itemsToExclude，类型区分 todayTabs/littleArc，并有 per-profile thresholds。官方明确默认 12 小时、查看/点击重置计时、可从 Archive 恢复，Library 有 Archive 入口。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `Archive.ArchiveFeatureAction`

enum descriptor: `0x103beb8f4`；field descriptor: `0x103d185a0`

`simulateAutoArchive`, `autoArchiveItems`, `didLaunch`, `runAutoArchive`, `removeExpiredItems`, `willTerminate`

### `Archive.ArchiveFeature.State`

struct descriptor: `0x103beb92c`；field descriptor: `0x103d18644`

`autoArchiveStartTime`, `itemsToExclude`, `sidebar`, `autoArchiveLittleArcWindowsEnabled`, `perProfileAutoArchivePrefAvailable`

### `Archive.AutoArchiveType`

enum descriptor: `0x103beb980`；field descriptor: `0x103d186b8`

`todayTabs`, `littleArc`

### `Archive.AutoArchiveInactiveThreshold`

enum descriptor: `0x103beb99c`；field descriptor: `0x103d186e0`

`twentySeconds`, `oneHour`, `sixHours`, `twelveHours`, `twentyFourHours`, `sevenDays`, `thirtyDays`, `never`

### `Archive.AutoArchiveTimeThresholdsPerProfile`

struct descriptor: `0x103beb9d4`；field descriptor: `0x103d18760`

`thresholds`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| showArchive: | _TtC3Arc20MainWindowController | 0x10031ffe8 | [assembly](assembly/_TtC3Arc20MainWindowController--showArchive.asm) |
| clearExplore: | _TtC3Arc20MainWindowController | 0x100320444 | [assembly](assembly/_TtC3Arc20MainWindowController--clearExplore.asm) |
| toggleLibrary: | _TtC3Arc20MainWindowController | 0x1003208ac | [assembly](assembly/_TtC3Arc20MainWindowController--toggleLibrary.asm) |
| reopenLastTab: | _TtC3Arc20MainWindowController | 0x10031cf00 | [assembly](assembly/_TtC3Arc20MainWindowController--reopenLastTab.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Auto Archive: Clean as you go — ## Adjust Auto Archive Timing

[官方来源](https://resources.arc.net/hc/en-us/articles/19228855311127-Auto-Archive-Clean-as-you-go) / [已保存正文](official-docs/19228855311127.md)（抽取正文第 21 行）

> By default, idle Unpinned Tabs archive every 12 hours. Viewing or clicking on a tab will always reset the timer! You can select a different Archive timing for each Profile you have, if you like. By default, all Profiles will share the same timing as your "Default" Profile.

### Auto Archive: Clean as you go — ## Can Auto Archive be disabled?

[官方来源](https://resources.arc.net/hc/en-us/articles/19228855311127-Auto-Archive-Clean-as-you-go) / [已保存正文](official-docs/19228855311127.md)（抽取正文第 45 行）

> Auto Archive can't be disabled.

### Auto Archive: Clean as you go — ## View & Restore Archived Tabs

[官方来源](https://resources.arc.net/hc/en-us/articles/19228855311127-Auto-Archive-Clean-as-you-go) / [已保存正文](official-docs/19228855311127.md)（抽取正文第 7 行）

> **View Archived Tabs:** hit Command-T (macOS) or Control-T (Windows) and type "View Archive."

### Auto Archive: Clean as you go — ## Restore Archived Tabs

[官方来源](https://resources.arc.net/hc/en-us/articles/19228855311127-Auto-Archive-Clean-as-you-go) / [已保存正文](official-docs/19228855311127.md)（抽取正文第 13 行）

> You can restore tabs by heading to the Archive (Command-T / View Archive) and hitting the Restore icon next to any archived tab.

### Auto Archive: Clean as you go — ## Restore Archived Tabs

[官方来源](https://resources.arc.net/hc/en-us/articles/19228855311127-Auto-Archive-Clean-as-you-go) / [已保存正文](official-docs/19228855311127.md)（抽取正文第 17 行）

> You can restore tabs by heading to the Archive (Control-T / View Archive) and clicking on any archived tab.

### Auto Archive: Clean as you go — ## Clear the Archive

[官方来源](https://resources.arc.net/hc/en-us/articles/19228855311127-Auto-Archive-Clean-as-you-go) / [已保存正文](official-docs/19228855311127.md)（抽取正文第 37 行）

> To remove all archived tabs at once, just right-click the Archive Tabs box in the Library and select "Clear Archive." You can also do this from the Command Bar (Command-T) by typing "clear archive" and hitting enter.

## 残留未知
never 和 twentySeconds 确实是枚举项，但当前官方说不能禁用，20 秒又被本地文案标为调试用途；不可把所有枚举成员都列为正常 UI 选项。当前设置、定时执行条件仍未知。

[首轮证据](../07-auto-archive.md) · [本轮完整 JSON](07-auto-archive.json) · [总报告](README.md)
