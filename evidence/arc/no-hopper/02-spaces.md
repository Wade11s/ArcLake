# Spaces（空间）

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
SpaceModel 直接包含 id/title/containerIDs/customInfo/profile；容器枚举分 pinned/unpinned，customInfo 包含 iconType/windowTheme。官方说明确认底部图标、滑动和数字快捷键；macOS 为 Control+数字。深浅色模式是全局的，不等于每个 Space 独立的颜色主题。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `BaseModels.SpaceModel`

struct descriptor: `0x103bcab30`；field descriptor: `0x103cf3ed8`

`id`, `title`, `containerIDs`, `customInfo`, `profile`

### `BaseModels.SpaceModel.ContainerType`

enum descriptor: `0x103bcab4c`；field descriptor: `0x103cf3f24`

`unpinned`, `pinned`

### `BaseModels.SpaceModel.CustomInfo`

struct descriptor: `0x103bcab84`；field descriptor: `0x103cf3f74`

`iconType`, `windowTheme`

### `Arc.WindowState`

struct descriptor: `0x103ba2844`；field descriptor: `0x103cd2178`

`id`, `appearancePhase`, `initialAppearanceActions`, `initialAnimation`, `isKey`, `isMain`, `focusedSpaceID`, `layoutPresentation`, `sidebarWidth`, `localHomeState`, `windowContentsState`, `highlightedItemID`, `renameHintItemID`, `sidebarMode`, `persistedLiveFoldersState`, `sidebarItemDragState`, `expandedItems`, `spacesWithCollapsedPinnedSections`, `showSpaceHeaderOnSingleUnnamedSpaces`, `referrerPool`, `multiSelectedItems`, `editingItem`, `currentlyEditedHeaderSpaceID`, `previouslySelectedItem`, `sidebarItemUserAttentionRequest`, `itemLastActiveDates`, `lastActiveTabsPerSpace`, `itemCreatedDates`, `sidebarHoverRegionActive`, `sidebarItemPreviewHoveredState`, `previewHovered`, `fullscreen`, `fullscreenRequest`, `commandBarIntegrationPresentationInfo`, `isDismissingCommandBarViaNewTabSelection`, `spaceCreationState`, `spaceStyleEditorPresentation`, `sidebarHoverInfo`, `sidebarScrollToItemRequest`, `closingState`, `closedProfiles`, `isPulsingNewTabButton`, `sidebarWrapper`, `appSidebarContext`, `featureFlags`, `authSession`, `deselectedItemsState`, `mousedownSelectionRevertItem`, `currentWebDialog`, `browserExtensionPopup`, `sidePanel`, `webContentsLifecycleHistory`, `restorableSplitViewLayout`, `style`, `backForwardListState`, `toasts`, `queuedHotkey`, `captureState`, `restorableSessionIDs`, `webContentExternalProtocolLaunchPrompt`, `topAppsEmptyStateDismissedForProfiles`, `topAppsSubtitleDisabledHosts`, `topAppsBadgingDisabledHosts`, `stayOnTop`, `dragToCaptureDisabled`, `webContentBehaviorConfiguration`, `browserExtensions`, `toolbarActions`, `activeWindowArcMenuType`, `modalItemSwitcherPresentation`, `findInPageQuery`, `softwareUpdateState`, `sidebarBannerState`, `keyBindingsState`, `pictureInPictureState`, `currentThemeEditorPresetPage`, `allowThemeToCSSSharing`, `shouldShowEaselExportPanel`, `lastRefreshedTime`, `developerModeState`, `liveCalendarsState`, `topBarDisplayedPreference`, `boostsDialogState`, `highlightedSwitchToSuggestion`, `aiRenameTabsFeature`, `keyboardShortcutsEducationState`, `newDefaultBrowserPromptType`, `isReadyToDisplayDebugModeEnabled`, `shareQuoteLinkEnabledPreference`, `tabReorderingHapticsDisabled`, `toolbarShowFullURLsEnabledPreference`, `isPreviewingGestureHiddenSidebar`, `dividerSquiggleActiveSpaceIDs`, `iconPickerState`, `liveFolderPopoverState`, `liveCalendarPopoverState`, `appTrayKeyboardShortcutsShown`, `isRestoringSession`, `ignoredWebContents`, `linearTabSwitcherState`, `showOnboardingEmptyStateWindow`, `pushOneTriggeredWebContents`, `pushTwoTriggeredWebContents`, `areBoostsEnabled`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| nextSpace: | _TtC3Arc13BrowserWindow | 0x10014c4e0 | [assembly](assembly/_TtC3Arc13BrowserWindow--nextSpace.asm) |
| previousSpace: | _TtC3Arc13BrowserWindow | 0x10014c4e8 | [assembly](assembly/_TtC3Arc13BrowserWindow--previousSpace.asm) |
| toggleSpaceManager: | _TtC3Arc20MainWindowController | 0x10031d398 | [assembly](assembly/_TtC3Arc20MainWindowController--toggleSpaceManager.asm) |
| newSpace: | _TtC3Arc20MainWindowController | 0x10031f9d4 | [assembly](assembly/_TtC3Arc20MainWindowController--newSpace.asm) |
| renameFocusedSpace: | _TtC3Arc20MainWindowController | 0x10031fb18 | [assembly](assembly/_TtC3Arc20MainWindowController--renameFocusedSpace.asm) |
| editSpaceTheme: | _TtC3Arc20MainWindowController | 0x10031fc6c | [assembly](assembly/_TtC3Arc20MainWindowController--editSpaceTheme.asm) |
| resetVisiblePinnedTabs: | _TtC3Arc20MainWindowController | 0x1003207a8 | [assembly](assembly/_TtC3Arc20MainWindowController--resetVisiblePinnedTabs.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Spaces: Distinct Browsing Areas — 

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 3 行）

> **Spaces** are distinct browsing areas in Arc, created to separate different contexts. Each Space has its own Pinned section, Unpinned section, Theme, and Icon.

### Spaces: Distinct Browsing Areas — ## How to Create and Switch Spaces

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 15 行）

> * **`Control-Space number (ex. 1, 2, etc)`**on macOS or **`Alt-Space number (ex. 1, 2, etc)`**on Windows

### Spaces: Distinct Browsing Areas — ## How to Create and Switch Spaces

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 13 行）

> * **Click on the Space’s icon** at the bottom of the Sidebar

### Spaces: Distinct Browsing Areas — ### How do I put Arc in Dark or Light Mode?

[官方来源](https://resources.arc.net/hc/en-us/articles/19228064149143-Spaces-Distinct-Browsing-Areas) / [已保存正文](official-docs/19228064149143.md)（抽取正文第 73 行）

> On **Arc for macOS** you can also change Arc's theme to Light, Dark, or Automatic (Arc’s theme will match your device’s theme) from the same Theme Picker. Simply select either the stars (automatic), sun (light), or moon (dark) at the top. Just remember - this applies to all of your Spaces, not just the one you’re currently in.

## 残留未知
主题与快捷键属于静态结构/官方规范；未操作用户的现有 Spaces。

[首轮证据](../02-spaces.md) · [本轮完整 JSON](02-spaces.json) · [总报告](README.md)
