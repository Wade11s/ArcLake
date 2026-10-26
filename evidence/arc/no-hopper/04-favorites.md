# Favorites（收藏）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
SidebarContainer 把 topAppsContainerIDs 与 spaces 分开保存，容器类别区分 topApps/spaceItems，项目上下文区分 topApp/pinned/unpinned。结合官方“Favorites accessible in every Space”和本地“Each Profile ... different Favorites”文案，支持同 Profile 跨 Space 共享、不同 Profile 各自收藏的产品模型。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `BaseModels.SidebarContainer`

struct descriptor: `0x103bca630`；field descriptor: `0x103cf3530`

`items`, `spaces`, `topAppsContainerIDs`

### `BaseModels.SidebarItemContainer.ContainerType`

enum descriptor: `0x103bc9adc`；field descriptor: `0x103cf264c`

`topApps`, `spaceItems`

### `BaseModels.SidebarItemContextType`

enum descriptor: `0x103bca93c`；field descriptor: `0x103cf3c28`

`topApp`, `pinned`, `unpinned`

### `SharedWindowFeature.SidebarSpaceState`

struct descriptor: `0x103c22cd4`；field descriptor: `0x103d4e5a4`

`windowID`, `windowLayoutPresentation`, `spaceID`, `unpinnedContainerID`, `selectedItemInfo`, `windowContentsState`, `presentedItemIDs`, `highlightedItemID`, `renameHintItemID`, `sidebarMode`, `sidebarPresentation`, `expandedItems`, `editingItem`, `sidebar`, `sidebarContext`, `sidebarHoverInfo`, `sidebarScrollToItemRequest`, `webContentsLifecycleHistory`, `multiSelectedItems`, `sidebarItemDragState`, `displayHeaderView`, `tidyTabTitles`, `sidebarWidth`, `spaceStyleEditor`, `themeContext`, `isCommandBarNewTabPlaceholderActive`, `isPulsingNewTabButton`, `shouldDim`, `context`, `profile`, `hasTopApps`, `sidebarItemUserAttentionRequest`, `shouldShowProfileIndicators`, `developerModeState`, `keyBindingsState`, `aiRenameTabsFeature`, `tabReorderingHapticsDisabled`, `sidebarItemForPreviewHovered`, `tabSuspensionStateIndicatorsEnabled`, `colorCodedSyncedSidebarItemsEnabled`, `optionClickSplitTabCloseButtonToUnsplitEnabled`, `collapsePinnedSectionEnabled`, `dragToCombineTabsIntoSplitEnabled`, `sidebarDragToSplitPreviewUIEnabled`, `pinnedSectionExpansionState`, `peekedPinnedSidebarItemID`, `showSpaceHeaderOnSingleUnnamedSpaces`, `currentUserID`, `newSplitSeparationMechanismsEnabled`, `autoOrgTabsEnabled`, `canAutoOrganizeTodayTabs`, `isDividerSquiggleActive`, `isEditingSpaceHeader`, `isEditingSpaceIcon`, `iconPickerState`, `liveFolderPopoverState`, `featureFlags`, `liveItemsData`, `liveCalendarEvent`, `gitHubLiveFoldersEnabled`, `slackLiveFolderEnabled`

### `SidebarSyncCloudKit.SyncedContainer`

struct descriptor: `0x103bf0d34`；field descriptor: `0x103d1d7b4`

`topAppsContainerIDs`, `orderedSpaceIDs`, `version`

## 菜单 → 方法 → 机器码

本项未选择直接菜单 selector；结构证据见上。没有据此声称完成了方法调用链验证。

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Pinned Tabs: Tabs you want to stick around — ## What are Pinned Tabs?

[官方来源](https://resources.arc.net/hc/en-us/articles/19231060187159-Pinned-Tabs-Tabs-you-want-to-stick-around) / [已保存正文](official-docs/19231060187159.md)（抽取正文第 24 行）

> Pinned Tabs are only accessible in one Space. Favorites are accessible in every Space. Learn more about Favorites here!

### Arc for macOS - 2023 Release Notes — ## Jan 12, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 701 行）

> * The max number of Favorites in any Profile is now 12 (up from 8)!

## 残留未知
尚未解出 topAppsContainerIDs 的完整泛型键类型，Profile → Favorites 的共享机制仍是多源综合推论，不是读取了实际用户状态；图标样式未截图。

[首轮证据](../04-favorites.md) · [本轮完整 JSON](04-favorites.json) · [总报告](README.md)
