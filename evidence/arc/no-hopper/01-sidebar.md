# 垂直侧边栏

**范围：仅 macOS（本机 arm64 构建）。Windows 版本不在本项目范围内；下方引用的官方页面多为 macOS+Windows 合并页面，其中的 Windows 表述仅属原文摘录，不构成本项目的分析对象。**

## 本轮结论
侧边栏隐藏入口已有实际代码，不再仅是菜单文本。WindowState 同时声明 sidebarMode/sidebarWidth 和 topBarDisplayedPreference/toolbarShowFullURLsEnabledPreference，说明侧边栏与可选顶部工具栏并存；“全部控件只能在左侧”需要修正。

## Swift 静态结构
下面是实际字段/枚举成员及 descriptor 虚拟地址。来自自建 ABI 子集解析器；未解析的符号类型引用保持未知，不是源代码恢复。

### `Arc.WindowState`

struct descriptor: `0x103ba2844`；field descriptor: `0x103cd2178`

`id`, `appearancePhase`, `initialAppearanceActions`, `initialAnimation`, `isKey`, `isMain`, `focusedSpaceID`, `layoutPresentation`, `sidebarWidth`, `localHomeState`, `windowContentsState`, `highlightedItemID`, `renameHintItemID`, `sidebarMode`, `persistedLiveFoldersState`, `sidebarItemDragState`, `expandedItems`, `spacesWithCollapsedPinnedSections`, `showSpaceHeaderOnSingleUnnamedSpaces`, `referrerPool`, `multiSelectedItems`, `editingItem`, `currentlyEditedHeaderSpaceID`, `previouslySelectedItem`, `sidebarItemUserAttentionRequest`, `itemLastActiveDates`, `lastActiveTabsPerSpace`, `itemCreatedDates`, `sidebarHoverRegionActive`, `sidebarItemPreviewHoveredState`, `previewHovered`, `fullscreen`, `fullscreenRequest`, `commandBarIntegrationPresentationInfo`, `isDismissingCommandBarViaNewTabSelection`, `spaceCreationState`, `spaceStyleEditorPresentation`, `sidebarHoverInfo`, `sidebarScrollToItemRequest`, `closingState`, `closedProfiles`, `isPulsingNewTabButton`, `sidebarWrapper`, `appSidebarContext`, `featureFlags`, `authSession`, `deselectedItemsState`, `mousedownSelectionRevertItem`, `currentWebDialog`, `browserExtensionPopup`, `sidePanel`, `webContentsLifecycleHistory`, `restorableSplitViewLayout`, `style`, `backForwardListState`, `toasts`, `queuedHotkey`, `captureState`, `restorableSessionIDs`, `webContentExternalProtocolLaunchPrompt`, `topAppsEmptyStateDismissedForProfiles`, `topAppsSubtitleDisabledHosts`, `topAppsBadgingDisabledHosts`, `stayOnTop`, `dragToCaptureDisabled`, `webContentBehaviorConfiguration`, `browserExtensions`, `toolbarActions`, `activeWindowArcMenuType`, `modalItemSwitcherPresentation`, `findInPageQuery`, `softwareUpdateState`, `sidebarBannerState`, `keyBindingsState`, `pictureInPictureState`, `currentThemeEditorPresetPage`, `allowThemeToCSSSharing`, `shouldShowEaselExportPanel`, `lastRefreshedTime`, `developerModeState`, `liveCalendarsState`, `topBarDisplayedPreference`, `boostsDialogState`, `highlightedSwitchToSuggestion`, `aiRenameTabsFeature`, `keyboardShortcutsEducationState`, `newDefaultBrowserPromptType`, `isReadyToDisplayDebugModeEnabled`, `shareQuoteLinkEnabledPreference`, `tabReorderingHapticsDisabled`, `toolbarShowFullURLsEnabledPreference`, `isPreviewingGestureHiddenSidebar`, `dividerSquiggleActiveSpaceIDs`, `iconPickerState`, `liveFolderPopoverState`, `liveCalendarPopoverState`, `appTrayKeyboardShortcutsShown`, `isRestoringSession`, `ignoredWebContents`, `linearTabSwitcherState`, `showOnboardingEmptyStateWindow`, `pushOneTriggeredWebContents`, `pushTwoTriggeredWebContents`, `areBoostsEnabled`

### `BaseModels.SidebarContainer`

struct descriptor: `0x103bca630`；field descriptor: `0x103cf3530`

`items`, `spaces`, `topAppsContainerIDs`

### `SharedWindowFeature.SidebarSpaceState`

struct descriptor: `0x103c22cd4`；field descriptor: `0x103d4e5a4`

`windowID`, `windowLayoutPresentation`, `spaceID`, `unpinnedContainerID`, `selectedItemInfo`, `windowContentsState`, `presentedItemIDs`, `highlightedItemID`, `renameHintItemID`, `sidebarMode`, `sidebarPresentation`, `expandedItems`, `editingItem`, `sidebar`, `sidebarContext`, `sidebarHoverInfo`, `sidebarScrollToItemRequest`, `webContentsLifecycleHistory`, `multiSelectedItems`, `sidebarItemDragState`, `displayHeaderView`, `tidyTabTitles`, `sidebarWidth`, `spaceStyleEditor`, `themeContext`, `isCommandBarNewTabPlaceholderActive`, `isPulsingNewTabButton`, `shouldDim`, `context`, `profile`, `hasTopApps`, `sidebarItemUserAttentionRequest`, `shouldShowProfileIndicators`, `developerModeState`, `keyBindingsState`, `aiRenameTabsFeature`, `tabReorderingHapticsDisabled`, `sidebarItemForPreviewHovered`, `tabSuspensionStateIndicatorsEnabled`, `colorCodedSyncedSidebarItemsEnabled`, `optionClickSplitTabCloseButtonToUnsplitEnabled`, `collapsePinnedSectionEnabled`, `dragToCombineTabsIntoSplitEnabled`, `sidebarDragToSplitPreviewUIEnabled`, `pinnedSectionExpansionState`, `peekedPinnedSidebarItemID`, `showSpaceHeaderOnSingleUnnamedSpaces`, `currentUserID`, `newSplitSeparationMechanismsEnabled`, `autoOrgTabsEnabled`, `canAutoOrganizeTodayTabs`, `isDividerSquiggleActive`, `isEditingSpaceHeader`, `isEditingSpaceIcon`, `iconPickerState`, `liveFolderPopoverState`, `featureFlags`, `liveItemsData`, `liveCalendarEvent`, `gitHubLiveFoldersEnabled`, `slackLiveFolderEnabled`

## 菜单 → 方法 → 机器码

| selector | 所属类型 | 实现地址 | 机器码 |
|---|---|---|---|
| toggleArcSidebar: | _TtC3Arc20MainWindowController | 0x10031dedc | [assembly](assembly/_TtC3Arc20MainWindowController--toggleArcSidebar.asm) |
| toggleArcToolbar: | _TtC3Arc20MainWindowController | 0x10031deec | [assembly](assembly/_TtC3Arc20MainWindowController--toggleArcToolbar.asm) |
| navigateTabBack: | _TtC3Arc20MainWindowController | 0x10031f22c | [assembly](assembly/_TtC3Arc20MainWindowController--navigateTabBack.asm) |
| navigateTabForward: | _TtC3Arc20MainWindowController | 0x10031f794 | [assembly](assembly/_TtC3Arc20MainWindowController--navigateTabForward.asm) |
| revealCurrentTabInSidebar: | _TtC3Arc20MainWindowController | 0x100320814 | [assembly](assembly/_TtC3Arc20MainWindowController--revealCurrentTabInSidebar.asm) |

## 官方文档/发布记录原文
历史发布记录不是当前本机运行测试；来源若包含后续版本也不自动外推到本机版本。

### Arc for macOS - 2023 Release Notes — ## December 7, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 24 行）

> * You can now opt in to show the Full URL in Toolbar. Start by turning on Toolbar in View > Show Toolbar. Then right-click on Toolbar to "Show Full URL".

### Arc for macOS - 2023 Release Notes — ## September 28, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 171 行）

> * The Arc Toolbar (View > Show Toolbar) will now show translation prompts on sites not in your primary language.

### Arc for macOS - 2023 Release Notes — ## August 17, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 270 行）

> * We've improved our Toolbar color logic (View > Show Toolbar).

### Arc for macOS - 2023 Release Notes — ## July 21, 2023 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498377604887-Arc-for-macOS-2023-Release-Notes) / [已保存正文](official-docs/20498377604887.md)（抽取正文第 318 行）

> * You can opt into viewing a full URL Bar and pinned Extensions at all times by enabling the Toolbar! Head to View > Show Toolbar to turn on.

### Arc for macOS - 2024 - 2026 Release Notes — ## Apr 18, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 900 行）

> * The Toolbar now renders in Peeked tabs! To toggle on the setting, hit Command T and type "Show Toolbar."

### Arc for macOS - 2024 - 2026 Release Notes — ## Mar 28, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 918 行）

> * For Arc Toolbar users, we've added a subtle divider separating the toolbar from your web content. You can turn on the Arc Toolbar by going to View > Show Toolbar. You can turn it off by going to View > Hide Toolbar.

### Arc for macOS - 2024 - 2026 Release Notes — ## January 25, 2024 —

[官方来源](https://resources.arc.net/hc/en-us/articles/20498293324823-Arc-for-macOS-2024-2026-Release-Notes) / [已保存正文](official-docs/20498293324823.md)（抽取正文第 1028 行）

> * The Sidebar now responds to clicks even when the Command Bar (Cmd + T) is open. You can interact with it without having to dismiss the Command Bar first.

## 残留未知
没有当前 UI 截图，不能报告控件的像素位置或用户当前隐藏状态。

[首轮证据](../01-sidebar.md) · [本轮完整 JSON](01-sidebar.json) · [总报告](README.md)
