# Command Bar（命令栏）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
命令栏包含 query/searchOutput/pendingSelection/scopedSearchType，并接入多个候选提供器。CommandBarItemType 枚举确实包含 chromiumHistory/chromiumSearchHistory、focusSpace、moveToSpace、moveToFolder、menuItem、openPreferencePane 等，不再只凭主菜单推断支持动作。⌘L 与 ⌘T 是两个不同的原生入口；官方文档和发布记录验证 ⌘T 可执行固定、切换 Space、分屏与复制等命令。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `CommandBar.CommandBar`

struct descriptor: `0x103c11ffc`；field descriptor: `0x103d3ad8c`

`_analyticsClient`, `_adkClient`, `_searchClient`, `_commandBarInteractionPerformanceTracker`, `_aseConfigurationClient`, `delegatePassthrough`

### `CommandBar.CommandBarState`

struct descriptor: `0x103c12464`；field descriptor: `0x103d3b4a8`

`inputs`, `destinationType`, `displayInfo`, `query`, `searchOutput`, `pendingSelection`, `instanceID`, `windowID`, `isFirstSearchOfVisibleLifecycle`, `scopedSearchType`, `scopedSearchColor`, `postScopedSearchRestoration`, `activeSearchEngines`, `siteSearchSpaceTriggerEnabled`, `pendingWindowContent`, `entryPoint`, `currentHighlightedResultIndex`, `shouldDisplayCloseAccessory`, `searchSuggestionPrivacyState`, `featureFlags`

### `SearchClientManager.SearchClientManager`

class descriptor: `0x103c273f4`；field descriptor: `0x103d54010`

`dependencies`, `$__lazy_storage_$_backgroundQueue`, `$__lazy_storage_$_providers`, `profileSpecificStates`, `cacheMaxCount`, `$__lazy_storage_$_fuzzyMatchScoreCache`, `$__lazy_storage_$_tokenizedTextMatchInfoCache`

### `SearchClientManager.SearchContext`

struct descriptor: `0x103c27378`；field descriptor: `0x103d53eec`

`windowID`, `currentItemInfo`, `destination`, `isFirstSearch`, `state`, `mostVisitedSites`, `documentsSourceClient`, `easelSourceClient`, `uuid`, `date`, `typeTravelContext`, `scopedSearchType`, `maxResults`, `tidyTabTitles`, `featureFlags`

### `SearchClientManager.ChromiumCandidatesProvider`

struct descriptor: `0x103c27250`；field descriptor: `0x103d53e84`

无字段记录

### `SearchClientManager.SidebarCandidatesProvider`

class descriptor: `0x103c27604`；field descriptor: `0x103d541bc`

`cachedTabs`, `cachedVisibleItemIDs`, `previousQuery`, `tabsForPreviousQuery`, `cachedTabTitles`

### `SearchClientManager.TypeTravelCandidatesProvider`

class descriptor: `0x103c27748`；field descriptor: `0x103d54240`

`currentSearchMainMenuSnapshot`

### `AnalyticsClient.AnalyticsEventProperties.CommandBarItemType`

enum descriptor: `0x103bd8df4`；field descriptor: `0x103d04db8`

`chromium`, `navigateWhatYouTyped`, `searchWhatYouTyped`, `askGPTWhatYouTyped`, `tab`, `list`, `document`, `chromiumSearchWhatYouTyped`, `chromiumSearchOtherEngine`, `chromiumNavigateWhatYouTyped`, `chromiumSearchSuggestion`, `chromiumSearchHistory`, `chromiumNavigateSuggestion`, `chromiumHistory`, `chromiumSearchCalculatorAnswer`, `chromiumBookmark`, `project`, `file`, `easel`, `focusSpace`, `moveToSpace`, `moveToTopApps`, `removeFromTopApps`, `moveToFolder`, `moveToNewFolder`, `createNewFolder`, `newVerticalSplitView`, `convertToHorizontalSplitView`, `convertToVerticalSplitView`, `collapseAllFolders`, `expandAllFolders`, `undoAction`, `redoAction`, `joinNextMeeting`, `toggleSidebar`, `renameCurrentTab`, `duplicateCurrentTab`, `resetCurrentTab`, `replacePinnedTab`, `newV1Boost`, `muteAllTabs`, `unmuteAllTabs`, `menuItem`, `browserExtension`, `newWebDocument`, `topDomain`, `openPreferencePane`, `openFolder`, `openPasswordManager`, `openSearchSettings`, `openAirTrafficControl`, `newArcNote`, `addTopSplit`, `addBottomSplit`, `addLeftSplit`, `addRightSplit`, `instantLinks`, `browseForMe`, `sendCurrentTabToDia`, `askAssistant`, `assistantHistory`, `extensionOmnibox`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| showPreferences: | _TtC3Arc11AppDelegate | 0x100235b0c | [assembly](assembly/_TtC3Arc11AppDelegate--showPreferences.asm) |
| newWindowForTab: | _TtC3Arc11AppDelegate | 0x100231fc0 | [assembly](assembly/_TtC3Arc11AppDelegate--newWindowForTab.asm) |
| toggleSelectedItemsPinned: | _TtC3Arc20MainWindowController | 0x10031d71c | [assembly](assembly/_TtC3Arc20MainWindowController--toggleSelectedItemsPinned.asm) |
| copyCurrentURL: | _TtC3Arc20MainWindowController | 0x10031dc9c | [assembly](assembly/_TtC3Arc20MainWindowController--copyCurrentURL.asm) |
| toggleOpenOmnibox: | _TtC3Arc20MainWindowController | 0x10031ee74 | [assembly](assembly/_TtC3Arc20MainWindowController--toggleOpenOmnibox.asm) |
| newWindowForTab: | _TtC3Arc20MainWindowController | 0x10031ce70 | [assembly](assembly/_TtC3Arc20MainWindowController--newWindowForTab.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Arc for macOS - 2023 Release Notes — ## May 18, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 426 行）

> * You can now delete Command Bar suggestions for pages you've visited and searches you've performed! Just hover over a suggestion and you'll see the new 'X' button appear.

### Arc for macOS - 2023 Release Notes — ## August 24, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 256 行）

> * Hit CMD T and type "Copy URL as Markdown", now supported in Peek, too!

### Arc for macOS - 2024 - 2026 Release Notes — ## January 25, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 1030 行）

> * Hands-free collapse your Pinned Tab section by hitting CMD T and typing "Collapse Pinned" or "Expand Pinned".

### Arc for macOS - 2023 Release Notes — ## November 30, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 51 行）

> * Easily create a new split by hitting CMD T and typing "Add Right Split", "Add Left Split", "Add Top Split", or "Add Bottom Split".

## 残留未知
候选类型部分来自统计枚举；不代表所有分支在当前 UI 启用。排序公式、缓存失效、查询完整流程未反编译，也未测试私密数据是否进入远端搜索。

[首轮证据](../11-command-bar.md) · [本轮完整 JSON](11-command-bar.json) · [总报告](README.md)
