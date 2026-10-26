# Arc 全面特性分析：无 Hopper 版

本轮覆盖用户列出的全部 **11 项特性**。目标仍是本机 **Arc 1.135.0（75383），macOS / arm64**。**范围仅 macOS；Windows 版本不在本项目范围内。**

**已完成：逐项静态结构分析、关键菜单入口的机器码定位、可取得的官方规范交叉核验。**
**未完成：端到端运行验证、全程序反编译、服务端实现。**（Windows 二进制不在范围。） “全面”指需求覆盖，而不是声称每一条行为均已实测。

## 阅读入口

| 特性 | 本轮新增、可复核的证据 | 结论与边界 |
|---|---|---|
| [1. 垂直侧边栏](01-sidebar.md) | `toggleArcSidebar:` 实现地址 `0x10031dedc`；WindowState 有 sidebarMode/sidebarWidth 与独立 toolbar 配置 | ⌘S 入口成立；不能说地址栏/导航永远只能在左侧，Arc 还有可选顶部 Toolbar |
| [2. Spaces](02-spaces.md) | `SpaceModel{id,title,containerIDs,customInfo,profile}`；pinned/unpinned 容器；theme/icon 字段 | 官方确认底部图标切换；数字快捷键 macOS **Control+数字**；深浅色模式是全局设置 |
| [3. Profiles](03-profiles.md) | `changeProfileForCurrentSpace:` 的实际入口；Space.profile；搜索管理器 profileSpecificStates | 配置关联明确；Cookie/登录/历史/扩展隔离有本地产品说明，但未做存储或安全隔离实验 |
| [4. Favorites](04-favorites.md) | SidebarContainer 分开保存 spaces 和 topAppsContainerIDs；topApps/spaceItems 容器分类 | 官方跨 Space 共享说明 + 本地不同 Profile 不同 Favorites 文案，支持同 Profile 共享的模型；未解出完整字典键类型 |
| [5. Pinned Tabs](05-pinned-tabs.md) | `toggleSelectedItemsPinned:` 位于 `0x10031d71c`；customTitle；pinned/unpinned 分类 | 官方明确不自动归档、只属于一个 Space、可分组；发布记录说明双击/右键重命名 |
| [6. Folders](06-folders.md) | `newList:` 真实入口；SidebarItem.parentID/childrenIds；拖拽事件 | 文件夹是侧栏树中的 list 项；官方确认共享、嵌套与共享项加入固定区；未调用分享服务 |
| [7. Auto-Archive / Today](07-auto-archive.md) | ArchiveFeature 的调度动作、itemsToExclude、todayTabs/littleArc、按 Profile 阈值 | 官方默认 **闲置 12 小时，查看/点击重置计时**；可在 Archive 恢复；`never` 枚举≠正常 UI 可禁用 |
| [8. Air Traffic Control](08-air-traffic-control.md) | Rule、sourceComponents、matches/contains、space/littleArc、持久化模型 | 包含/精确匹配和目标 Space 不是只靠名字猜测；优先级、规范化与多条件组合算法仍未知 |
| [9. Split View](09-split-view.md) | sidebar.splitView、itemWidthFactors/layoutOrientation/focusItemID、isResizingPanes，4 个实际操作入口 | 水平/垂直、尺寸状态、复合侧栏项有结构证据；官方 2024-03-07 修复“超过四个”边界问题，支持四面板设计上限；未验证限制分支 |
| [10. Little Arc](10-little-arc.md) | 独立 LittleBrowserWindow；moveContentToStandardGlobalWindow；目标 spaceID/pinned/unpinned | 外部链接入口及移入主窗口的架构明确；未测“轻量”性能或浮动层级 |
| [11. Command Bar](11-command-bar.md) | query/searchOutput、多个候选提供器；history/focusSpace/moveToFolder/menuItem/openPreferencePane 枚举 | 不是普通 URL 输入框：有导航、历史、侧栏和动作候选；⌘L/⌘T 是两个原生入口；完整排序与执行路径未知 |

每项均有 Markdown 展示页及同名 JSON，列出结构地址、字段、方法地址、汇编文件、官方原文和残留未知。首轮菜单及字符串证据继续保留在上级目录。

## 本轮最重要的纠正

### 1. 侧边栏不是唯一可能出现的浏览器栏

WindowState 同时声明：
- sidebarMode / sidebarWidth
- topBarDisplayedPreference
- toolbarShowFullURLsEnabledPreference

2023 官方发布记录还明确支持 `View > Show Toolbar` 和工具栏显示完整 URL。因此，“侧边栏是主要组织中心”比“所有控件永远只在左侧、完全没有顶栏”更准确。

### 2. Space 与 Profile 是两个不同维度

- Space：上下文组织，拥有固定/未固定容器、主题和图标。
- Profile：浏览身份与数据范围；SpaceModel 持有 profile。
- Favorites/Top Apps 在 SidebarContainer 中与 spaces 分开存放。
- 搜索管理器也保留 profileSpecificStates，不是简单把所有空间当作相同浏览身份。

“另一个 Space”不自动等于“另一个 Cookie 会话”。

### 3. 自动归档不能把枚举直接翻译成当前设置选项

实际类型 `Archive.AutoArchiveInactiveThreshold` 有：
`twentySeconds / oneHour / sixHours / twelveHours / twentyFourHours / sevenDays / thirtyDays / never`。

但是：
- 本地说明把 twentySeconds 标为 debugging only。
- 当前取得的官方 Auto Archive 页面说 **“Auto Archive can't be disabled.”**
- 本地还存在迁移 never 模式的提示文字。

因此，报告不再把 never 当成普通用户当前必然可选的选项；它可能用于历史状态、迁移或内部路径，具体使用分支未验证。枚举存在与 UI 可达是两回事。

### 4. 四面板上限已取得文档支持，不是机器码证明

官方 2024-03-07 发布记录：
> We've patched some edge-cases in trying to open more than four tabs in Split Views.

本地还有第四面板跳转文案、最大面板数错误标识和实际分屏模型。
综合支持“设计上限为四”，但本轮未定位和验证执行上限判断的汇编分支，不能声称已证明任意输入下都无法出现第五面板。

## 实现结构：从发行物恢复出的局部模型

下列是**分析归纳，不是恢复出的完整源码或完整调用图**：

```Arc.AppDelegate
  ├─ 新窗口 / 新标签 / New Little Arc
  ├─ Arc.MainWindowController：菜单 action 入口
  │    ├─ Sidebar / Space / Profile
  │    ├─ Pin / Folder / Archive / Library
  │    └─ Split View / Omnibox
  └─ Arc.LittleBrowserWindow：独立小窗入口

BaseModels.SidebarContainer
  ├─ items
  │    └─ SidebarItem{id,title,parentID,childrenIds,data,...}
  │         └─ data: tab | list | splitView | itemContainer | ...
  ├─ spaces
  │    └─ SpaceModel{containerIDs,customInfo,profile,...}
  │         ├─ pinned / unpinned
  │         └─ customInfo{iconType,windowTheme}
  └─ topAppsContainerIDs

Archive
  ├─ runAutoArchive / autoArchiveItems / removeExpiredItems
  ├─ itemsToExclude
  ├─ todayTabs / littleArc
  └─ AutoArchiveTimeThresholdsPerProfile

LinkRouting
  ├─ Rule{id,sourceComponents,destination}
  ├─ urlMatch + matches / contains
  ├─ space / littleArc
  └─ StorableState{version,rules,defaultDestination}

WindowContents
  └─ SplitViewState{windowContentIDs,layoutOrientation,
                    focusedContentID,interactionState}

CommandBar + SearchClientManager
  ├─ query / searchOutput / scopedSearchType / pendingSelection
  ├─ Chromium / Sidebar / TypeTravel / other candidate providers
  └─ profileSpecificStates / ranking-related caches
```

依赖加载记录还显示 AppKit、Foundation、Combine 和 ArcCore.framework。前述主程序类型/方法来自原生 Swift/Objective-C 数据，而不是拿网页 DOM 来替代 Arc 的原生侧边栏分析。本轮没有深入分析 ArcCore/Chromium 的全部实现。

## 菜单到真实机器码：示例

原始 REA 菜单证据：
`Show/Hide Sidebar → toggleArcSidebar:`，key=s，Command modifier。

补充 Objective-C 元数据把它定位到：
`Arc.MainWindowController`，`0x10031dedc`。

[实际汇编](assembly/_TtC3Arc20MainWindowController--toggleArcSidebar.asm)：
```asm
10031dedc: mov w3, #0x37
10031dee0: b   0x10031a8e4
```

另两个入口：
- [addSplitPanel:](assembly/_TtC3Arc20MainWindowController--addSplitPanel.asm)：传入 `w3=0x22`，跳到同一地址。
- [toggleSelectedItemsPinned:](assembly/_TtC3Arc20MainWindowController--toggleSelectedItemsPinned.asm)：传入 `w3=0x17`，跳到同一地址。

共同目标 [0x10031a8e4](assembly/shared-action-dispatch.asm) 会继续调用 `0x10032097c`。这证明这些入口不是只有文本声明，并呈现共享处理结构。把参数解释为“动作标识”是分析推论；没有恢复完整的枚举/分发表，也没有观察执行。

注意：LLVM 在 stripped binary 的外部桩旁可能输出误导性的最近符号标签（例如 `_xmlXPathRegisterNs+...`）。本报告不依赖这些标签命名函数，只引用已核实的数值地址、元数据关联和指令。

## 证据层次与可复核文件

### A. 真正的 REA 输出：无需 Hopper

独立 CLI 成功绕开旧 MCP 的 Hopper 清理残留，不修改 MCP 配置，不安装新工具：

- [rea-macho.json](rea-macho.json)
  - operation: inspect_macho
  - Evidence: `ev_780f75cfcf14debdafbfe9e1804e72b246ee98aec3b9d598bd724a307a89fd1f`
- [rea-demangle-cli.json](rea-demangle-cli.json)
  - operation: demangle_swift
  - Evidence: `ev_a8b579e7109bdbcdce065ad690522e3207b610f39f6faf57a3f9922a346b32aa`
  - 确认 MainWindowController、LittleBrowserWindow、BrowserWindow、AppDelegate、CommandBarInputContainer 的名称解码。

MCP 的 demangle 尝试返回 No app is open，保存在 [rea-demangled-classes.json](rea-demangled-classes.json)，**它是失败日志，不是成功证据**。成功结果是 CLI 文件。

### B. 补充本地静态解析与 LLVM 汇编：不是 REA 结果

- [methods.json](methods.json)：解析到 10,414 条 Objective-C 方法记录、3,679 个去重类名；这些不代表全部 Swift 函数。
- [swift-fields.json](swift-fields.json)：解析到 10,814 个 nominal 类型记录及字段/枚举成员。
- [method-assembly-index.json](method-assembly-index.json)：选取 38 个相关方法入口的范围、指令文件和命令。
- [assembly/](assembly/)：局部 ARM64 机器码反汇编。
- [validation.json](validation.json)：372 条选中方法的指令编码逐条与原始字节核对；arm64 slice 与 universal 原件完全一致。
- LC_FUNCTION_STARTS 中读到 270,675 个入口：用于确定方法边界，**不是对 270,675 个函数完成了分析**。
- 解析器覆盖的记录没有解码错误，但不意味着未实现的 metadata 格式、Swift-only 方法、动态生成 UI 或运行路径都已覆盖。

### C. 官方说明：不是本机运行轨迹

正文已保存到 [official-docs/](official-docs/)，包括：
- Pinned Tabs
- Spaces
- Auto Archive
- macOS 2023 发布记录
- macOS 2024–2026 发布记录

原始 TinyFish fetch JSON 保留 URL、返回内容及错误。部分 Favorites、Split View、Little Arc/路由详情页无法取得：返回 page_not_found 或栏目 login_required。没有把搜索摘要或失效页面冒充已读取正文，也不把页面失效解释为本机功能不存在。这些官方页面多为 macOS+Windows 合并页面，引用仅取 macOS 相关含义；Windows 表述不属于本项目分析对象。

发布记录的日期在逐项摘录中保留。历史发布记录支持历史行为，不自动证明在线服务现在仍可用。

## 工具与身份校验

- 原始 SHA-256：`b192994372b8d0ef7beb465c3cad0f2d02a227c6988238e037d8e026536db688`
- arm64 slice 偏移：83509248；长度：77908992。
- arm64 slice SHA-256：`5be4e80da2d462b719dd1865122f1e34fabc529c0a2f528a4aba4b969042bada`
- Mach-O UUID：`6F058561-2BF1-33E5-B21F-FF140593A36A`。
- REA CLI：`/Users/hwj/.bun/bin/rea`，6.8.0。
- 仅使用已有 Xcode 的 lipo / llvm-objdump / swift-demangle，以及 Python 标准库。
- 没有安装 Java/Ghidra，没有重新安装或启动 Hopper，没有绕过 Demo 限制。
- 原始 Arc.app 未修改；arm64 临时副本位于 `/tmp/arclake-arc-arm64.macho`，可用 lipo 从已核对原件重新生成。

解析注意：
1. LLVM 的 Objective-C 输出对相对方法列表报告 extends past end of file；该显示本身不被当成可信解析结果。
2. 补充解析器读取实际 Mach-O 段映射与 LC_DYLD_CHAINED_FIXUPS，按实际 pointer_format=6 的链定位 selector 引用，再解析 relative method entries。没有随意清除指针高位来“猜地址”。
3. 链格式定义参照本机 Apple SDK 的 mach-o/fixup-chains.h；实际走过 257,158 个 rebase slot。
4. Swift 字段类型中的 symbolic references 未完整解码；未知父上下文显示为 context-kind/indirect-context，不伪造完整限定名。
5. 同一 selector 可以出现在多个类，不能只拿 selector 名称就认定运行时会分派到其中某一个。

## 仍需运行实验的项目

- 第五个分屏是否始终被拒绝、调整分隔线、整体 Pin 的实际操作。
- Favorites 在同/不同 Profile 的多个 Space 中的真实状态变化。
- Cookie/登录/历史/扩展是否按预期隔离，以及各类边界行为。
- 自动归档计时、睡眠/退出影响、固定标签排除条件与恢复目标。
- URL 路由优先级、大小写/编码/重定向和多条件组合。
- 每个 UI 的截图、快捷键响应、菜单启用状态和在线分享是否仍服务。

CuaDriver 当前返回权限状态 unknown，要求用户运行 `cua-driver permissions grant`。因此本轮没有进行 GUI 操作、没有截图，也没有读取个人 Profile。要继续完成运行验收，需要先由用户授予权限，并使用专门测试窗口/无敏感账号的测试配置。

## 复现

```bash
# 不依赖 Hopper 的 REA 检查
/Users/hwj/.bun/bin/rea inspect-macho /Applications/Arc.app --format json

# 创建只读分析副本（不改原件）
xcrun lipo /Applications/Arc.app/Contents/MacOS/Arc \
  -thin arm64 -output /tmp/arclake-arc-arm64.macho

# 生成方法 metadata 的原始观察
xcrun llvm-objdump --macho --objc-meta-data /tmp/arclake-arc-arm64.macho \
  > evidence/arc/no-hopper/objc-arm64.txt

python3 evidence/arc/no-hopper/parse-methods.py
python3 evidence/arc/no-hopper/parse-swift-fields.py
python3 evidence/arc/no-hopper/disassemble-methods.py
python3 evidence/arc/no-hopper/validate-evidence.py
python3 evidence/arc/no-hopper/build-feature-reports.py
```

如果 Arc 已更新，先重新核对版本与 SHA-256，不要混用本报告的地址、已有菜单证据和新版本二进制。
