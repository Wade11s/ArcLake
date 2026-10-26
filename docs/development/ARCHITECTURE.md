# ArcLake 实现方案

本方案为 [SPEC](SPEC.md) 的实现建议，不是 Arc 源码还原。先阅读 [领域词汇](../../GLOSSARY.md)。

## 1. 技术基线

- 最低 macOS 27.0；Xcode 27 / Swift 6.4 工具链、Swift 6 语言模式、严格并发检查；当前开发机 macOS 27.0.1 即最低系统基线。
- SwiftUI：Sidebar、设置、命令栏、Library、状态展示。
- AppKit：主窗口/小窗所有权、焦点、键盘响应、文件选择与 NSView 挂载；窗口控制器承载 NSHostingController。
- WebKit：使用 macOS 27 SDK 的 WKWebView + WKNavigationDelegate + WKUIDelegate + WKDownloadDelegate。通过 NSViewRepresentable 嵌入稳定的宿主 NSView，不在 SwiftUI body 中创建浏览实例。
- Foundation + 系统 SQLite：使用 macOS 27 SDK 的值模型、URL 解析、元数据事务、迁移、查询。首版不引入通用 Redux 框架、第三方 ORM 或 Chromium。
- SwiftUI、AppKit 与 WebKit 全部跟随当前 macOS 27 SDK，不保留旧系统 fallback。SwiftUI 更新型 WebView/WebPage 只有在能覆盖当前 delegate、store 与生命周期 Interface 时才替代现有 WKWebView 宿主。参见 [API 核实](API-NOTES.md)。

## 2. 模块与依赖方向

```text
SwiftUI Views / AppKit menus / URL events
                |
      AppController (@MainActor)
          | commands / events
          v
  Workspace Module (pure value transitions)
     |          |             |
     v          v             v
 Persistence  Browsing     Windowing
 Module       Module       Module
 (actor)      (@MainActor)  (@MainActor)
     |          |             |
   SQLite   WebKit adapter  AppKit

CommandSearch Module -> read-only Profile-scoped snapshot/history
Routing + Archive policies -> Workspace 内部纯函数
```

每个 **Module** 以小 **Interface** 隐藏状态机和副作用。结构变化应集中在 Workspace，禁止拖拽、菜单、命令栏各自实现一份移动/固定逻辑。

| Module | Interface 责任 | Implementation 隐藏的复杂度 | 测试 Seam |
|---|---|---|---|
| Workspace | `decide(state, command, context) -> decision`；返回新值/变更/效果，不直接写库 | 树、Profile、分屏、归档、路由的不变量与冲突 | 值模型 + 固定时钟；真实生产逻辑直接测试 |
| Persistence | `loadSnapshot / commit(expectedRevision, mutation) / queryHistory(scope)` | SQLite、事务、版本、迁移、删除任务 | 内存 adapter 与磁盘 SQLite adapter；隔离/迁移一定测磁盘 |
| Browsing | `apply(effect)`、`attach(tabID, host)`、`detach`、输出 BrowserEvent | WebView 注册、store 选择、导航、进程死亡、回调代际校验 | 测试替身用于业务流程，真实 WebKit 用于隔离/生命周期 |
| Windowing | 主窗口/小窗创建、呈现、移交、关闭与恢复 | NSWindow 生命周期、first responder、NSView 独占挂载 | UI 自动化 + 所有权检查 |
| CommandSearch | `search(query, context, generation)`、选择 commandID | 候选合并、限额、排序、取消、Profile 过滤 | 固定输入/历史 adapter，结果应确定可重复 |
| AppController | 串行接受 command/event，协调提交和效果 | 保存失败、revision、异步返回、错误展示 | 用两个真实/测试 adapter 覆盖完整流程 |

这里只在真实变化的地方放 Seam：SQLite/内存、WebKit/测试替身、实际时钟/固定时钟。Routing 和 Archive 不必拆成十几个仅转发调用的 protocol。

## 3. 数据模型（设计，不是照搬二进制字段）

全部 ID 为不同的强类型 UUID 包装，不用可混淆的 String。时间统一 UTC，显示再本地化。URL 以原始用户可导航值保存，规范化匹配值另算，不覆盖 fragment。

| 实体 | 必需字段 |
|---|---|
| Profile | id, name, websiteStoreID, archiveInterval, searchEngine, lifecycle(active/deleting), createdAt |
| Space | id, profileID, name, icon, theme, order, pinnedRootID, todayRootID |
| RootContainer | id, kind(profileFavorites/spacePinned/spaceToday), ownerID |
| SidebarItem | id, parent(rootID 或 itemID 二选一), orderKey, kind(tab/folder/split), customTitle? |
| Tab | id, profileID, currentURL?, savedURL?, pageTitle?, lastActiveAt, createdAt, ownership(sidebarItemID 或 littleWindowID) |
| SplitConfiguration | itemID, orientation, weights, focusedChildItemID |
| WindowSession | id, kind(main/little), selectedSpaceID?, selectedItemID?, selectedPaneID?, sidebarVisible, sidebarWidth, frame, lastSelectionsPerSpace |
| ArchiveEntry | id, profileID, originSpaceID?, originParentHint?, originalRegion, payloadVersion, subtreeSnapshot, reason, archivedAt, restoredAt? |
| HistoryVisit | id, profileID, url, title, visitedAt；不以活动 Tab 外键作为保留条件 |
| RouteRule | id, order, enabled, matchingStyle, pattern, destination(spaceID 或 littleProfileID) |
| ApplicationSettings | defaultProfileID, externalDefaultDestination, appearance, retentionSettings, schemaVersion |
| PendingOperation | id, kind(profileDataDeletion), targetID/storeID, phase, lastError?, attemptAt |

运行时另外持有：loading/progress/canGoBack/canGoForward、navigationGeneration、WKWebView、KVO/delegate tokens、下载任务、UI 查询代际。**这些不进入通用 Codable/SQLite 对象图。**

### 3.1 拓扑和归属

- 每个活动 Tab 恰好有一个 owner：单标签 SidebarItem，或 Little Window；Split 的面板也是单标签 SidebarItem，parent 是 Split。
- Root 自带类型和 owner；不能靠数组位置猜是 Favorites 还是 Today。
- Folder 只能在固定根下；Split 只有 2–4 个 Tab 子项；Favorite 根只有单 Tab；同一子树 profileID 一致。
- SidebarItem 采用一个 parent 字段与 orderKey，不同时维护容易分歧的可变 parentID/childrenIds 双份真相；children 从索引派生。
- SidebarItem.kind=tab 时恰好一个 Tab 引用；folder/split 本身不是网页；移除组必须正确处理所有叶 Tab。
- Pinned/Today 身份由根容器继承；不再为同一 Tab 设置独立 isPinned/isFavorite 布尔值，以免出现矛盾组合。
- Profile Favorites 根与 Space 根分开存储。同 Profile Space 切换显示同一 Favorite Tab，不克隆网页或 Cookie。
- ArchiveEntry 保存独立值快照；归档后删除活动 Tab/Item 行，历史访问保留；恢复使用新 ID，原 ID 仅用于审计/映射，避免重用旧回调目标。

### 3.2 必须守住的不变量

I01 有效 Profile/Space 至少各一个；I02 Space.profileID 有效；I03 全部树无环、parent 唯一；I04 子树 Profile 一致；I05 Tab owner 唯一；I06 Split 2–4 叶、正比例总和为 1；I07 可见选择指向有效项；I08 Favorite 根仅单 Tab；I09 Archive 不含可执行脚本/系统凭据；I10 history/search 始终显式 Profile 过滤；I11 active 与 archive 的 ownership 不重复；I12 WebView 唯一宿主且 store 与 Tab/Profile 一致。

每个 command 在提交前验证这些条件；失败返回可展示的 typed error，而不是 assertion 后继续运行。

## 4. 提交、异步与效果

设计流程（非可编译接口代码）：

```text
command + immutable state + current clock/protection snapshot
 -> Workspace.decide
 -> invariant validation
 -> Persistence.commit(expectedRevision, mutation)
 -> publish committed state
 -> Browsing / Windowing effects
 -> callback -> BrowserEvent(profileID, tabID, generation)
 -> validate identity + accept or drop -> next command
```

- 结构命令按序处理，等待事务期间禁用冲突操作或排队；不能让慢数据库提交覆盖更新的状态。
- 新 Tab 创建先提交记录，再加载网页。加载失败保留错误页，不悄悄撤销用户已经创建的标签。
- 归档/删除先提交快照，再释放网页。存储失败时保留原页面和原树。
- 可见进度/鼠标 hover 不写磁盘。URL/标题/最近访问可合并约 500ms 写入；结构变更立即事务。突然断电可能丢最后少量非结构元数据，需明确承认。
- 浏览器回调携带 tabID/profileID/generation；Tab 被恢复、换 Profile、销毁或替换后旧回调必须丢弃。
- openRequestID 使用短期持久去重表/窗口，事务中与打开记录一起提交；网络加载本身不是“exactly once”，崩溃恢复仅允许安全 GET 重载，不重放 POST。
- 效果失败报告为可恢复错误；不能承诺数据库事务与 WebKit/系统窗口跨进程原子一致。启动修复只基于已提交模型。

## 5. 浏览实例和 Profile 隔离

### 5.1 配置创建

`Profile.websiteStoreID -> WKWebsiteDataStore(forIdentifier:)`，并在初始化 WKWebView 前设置到 WKWebViewConfiguration.websiteDataStore。[V API 已核实；macOS 27 基线上的 M0 隔离、重启、强退、删除和负对照均已实测，见 M0-RESULTS.md]

- Default Profile 也使用具名 store，不用 `.default()` 与其他 Profile 混杂。
- store UUID 非零、只生成一次，并在首次创建任何网页前写库。store 初始化不接受来自网页或导入文件的 UUID。
- WKProcessPool 不是 Profile 隔离方案；SDK 声明多个实例已无效，不按进程池宣称 Cookie 隔离。
- 同 Profile 复用相同的 data-store 身份；不同 Profile 不复制 httpCookieStore 内容，也不共享任意应用侧认证缓存。
- App 自己的 History、Favorites、Archive 同样按 Profile 划分；WebKit store 不会替你保存 ArcLake 的命令栏历史索引。

### 5.2 身份稳定与生命周期

运行注册表以 TabID 定位 WebViewSession，记录 profileID/storeUUID/generation/hostID。Tab 换 Profile 时必须销毁旧 session 并重建，不可修改既有 webView.configuration 后假定生效。

```text
Dormant -> Creating -> Loading -> Ready
                    \-> Failed (可重试)
Ready/Loading -> Detaching -> Dormant
Ready/Loading -> ProcessTerminated -> Failed
任意状态 -> Closing -> Released
```

NSViewRepresentable 的 `makeNSView` 只建宿主；update 时按 TabID/hostID attach，不再次 load。dismantle 只解除该宿主的挂载与观察，不等于删除逻辑 Tab；逻辑存活由注册表持有。

- 一张网页只挂载一个 NSView 层级。Split/小窗移交先更新逻辑 owner，再 detach 旧 host、attach 新 host，并迁移焦点。mount 必须检查归属令牌：M0 实测中 SwiftUI 的迟到 update 曾从新窗抢回网页，不能只依赖 dismantle 顺序。
- Reparent 保留同一 `WKWebView`、JS 内存和表单值，但当前 M0 实测会重置视口滚动与 DOM 焦点。窗口移交必须捕获 `scrollY`/焦点元素，在目标 host 完成布局后显式恢复，并用可见窗口验证非零滚动；不能把“文档实例没变”误当作全部交互状态保持。
- 改变侧栏、主题、Space、窗口尺寸，除非真的需要创建新的 session，不生成新 WKWebView。
- 初始惰性恢复：只加载选中单 Tab/最多四个面板；其余仅恢复元数据。
- 初始后台 session 软预算为 8 个，超预算按最近使用释放可安全释放的后台页；可见页面、下载、权限交互不能为了预算被驱逐。受保护页超预算时提示，不做错误的硬上限承诺。
- 首版不自动卸载无法确定安全状态的复杂后台页；如 beforeunload 要求确认，保留并提示，不能强制丢表单。
- WebKit 进程终止由事件转换成用户可见错误；手动重载只恢复 URL，不能承诺 JS 内存或表单恢复。M0 已用测试编排器校验 PID 后向 WebContent 发送真实 `SIGKILL`，确认终止 delegate、可恢复错误态和新内容进程重载均成立。

### 5.3 Profile 删除状态机

1. 确认没有 Space/Little Window 引用；允许尚有独立 Favorites，但需确认一并删除。事务把 Profile 标成 deleting，保存 storeUUID 的 PendingOperation，禁止新建网页引用。
2. 取消该 Profile 的查询/导航/下载，清理注册表与所有 WKWebView 引用；等待 delegate/token 持有关系释放。
3. 在禁止新网页引用的删除状态内，显式清空该store的 `allWebsiteDataTypes()`（since `.distantPast`），再调用 `WKWebsiteDataStore.remove(forIdentifier:)`；不能仅清 SQLite，不能删除系统 WebKit 目录。M0 当前系统观察到网络进程短暂占用，需有界重试；只删除namespace后立即复用UUID曾残留Cookie，因此新Profile不得复用已删UUID。冷启动删除还需验证WebKit初始化条件，详见 M0-RESULTS.md。
4. 成功后事务删除 Favorites/归档/历史和 Profile，完成 operation；失败保留待重试条目与错误，不隐匿数据残留。
5. 崩溃后从 PendingOperation 恢复删除流程。删除操作幂等；“已不存在”的具体返回要按当前 API 行为验证，不预设错误码。

## 6. 窗口与路由集成

- Windowing 是 NSWindow 的唯一所有者；不要同时让 WindowGroup 和自建 NSWindowController 争夺同一主窗口。
- SwiftUI 用于窗口内容和命令菜单；初始化方案在 M0 的最小壳中编译验证。
- 首版一个主窗口，多个小窗；打开主窗口命令在已存在时激活它，不创建第二个主浏览状态。关闭主窗口不删 Space/标签，重新打开恢复原选择。
- 应用退出/系统终止时保存 WindowSession 并释放实例，不把所有 Today/小窗误当作用户逐一按 ⌘W 归档。
- 仅当前活跃窗口处理菜单命令；命令上下文包含 WindowID、ProfileID 和选择快照，执行前再验证。
- 外部 URL 经 AppKit URL 打开事件进入统一 OpenRequest，调用纯 Routing policy。应用内模拟入口与正式系统事件共用 Interface。
- WKUIDelegate 的 target=_blank/window.open 首先区分用户交互和自动弹窗：没有用户授权的弹窗默认拦截；禁止后台站点无限创建小窗。
- 当前导航的 redirect 不进入新打开路由。自定义 URL scheme 与 http/https 的系统注册不是同一件事；开发验收不能用自定义 scheme 冒充默认浏览器支持。

## 7. 归档和命令搜索

Archive policy 输入：当前时间、Profile 阈值、Today 叶 lastActiveAt、可见/导航/下载/交互保护集合。输出候选顶层 ItemID，不直接删除。AppController 对最新 revision 再验证后一次事务归档，避免用户刚固定的 Tab 被旧扫描结果删掉。

命令搜索输入：query + generation + ProfileID + WindowID + mode。每个候选的最终结果是 typed Command，不是可执行字符串；后端和 UI 使用同一 enabled 规则。

- History 查询必须 `WHERE profile_id = ?`，并设上限；其他 Profile 的记录不能先全量送到 UI 再过滤。
- 初期用 SQLite 索引 + 标题前缀/子串匹配即可，不为几千条历史引入搜索服务。
- Profile 切换同时取消上一代任务并清空候选；迟到的返回因 generation/profile 不匹配而丢弃。
- 路由、排序、归档时间均纯函数化，便于用固定数据测边界，不从当前系统状态隐式取值。

## 8. 持久化、迁移与恢复

建议数据库表：profiles、spaces、roots、items、tabs、split_configs、window_sessions、archive_entries、history_visits、route_rules、settings、pending_operations、processed_open_requests。具体建表在 M1 确定，但上述实体归属与不变量必须保持。

- 持久层使用 SQLite 单写者 actor、事务和外键；设置连接 pragmas 与 busy 处理，结构提交不可静默失败。通过系统 sqlite3 构建实际 adapter，不引入拼接用户输入的 SQL。
- archive payload 单独 schema version；使用受控 Codable 值，不反序列化任意 Objective-C 类图。
- 主状态 revision 单调增长，排序/移动/分离/归档/恢复都是一笔事务。
- PRAGMA user_version 或迁移表跟踪版本；迁移前用 SQLite 一致性备份，不能只复制正在写入的 .db 而丢 WAL。
- 遇到未知未来版本：只读错误页/要求升级，不回退创建空库覆盖。迁移失败保留备份并提供恢复选项。
- 启动验证选择指针、路由目标、parent/root 和 profileID。结构损坏进入恢复模式；修复必须留下报告，不能随意清空孤儿数据。
- WebKit 数据由系统持有，不被 SQLite 事务覆盖；元数据恢复不能暗示恢复了网站登录。
- UI 显示最后保存状态。正常退出等待短时间提交；如超时或磁盘满，提示数据未保存，不无限阻塞退出。

## 9. 安全与质量 Interface

所有 URL 入口统一经过 URLPolicy；下载/上传/外部协议/导入单独授权。默认不接受 javascript/data/file。安全规则必须作用于命令栏、系统 URL 事件、网页新窗口、导入清单，不只在某个输入框过滤。

- App Sandbox 网络 client、用户选择文件读写和必要 usage descriptions 采用最小权限；localhost 测试服务器是外部测试进程，不给生产应用 server entitlement。
- HTTPS 认证挑战遵守系统验证，不无条件接受 serverTrust。
- download/permission 保护状态通过 BrowserEvent 更新，不能依赖 SwiftUI View 是否存在。
- beforeunload、HTTP auth、摄像头/麦克风、文件上传、下载 API 的具体 delegate 在实施时按 API-NOTES 与 SDK 确认；不支持则明确降级，不把浏览器壳当完整 Safari。
- 只记录命令类型、ID 和耗时；URL、搜索词、Cookie、正文不得进入默认日志。诊断导出需要预览与用户同意。

## 10. 当前工程布局

```text
Package.swift                     # Swift tools 6.4、macOS 27、Swift 6
Sources/ArcLakeCore/              # IDs、值模型、I01–I12、commands、AppController、Store Interface
Sources/ArcLakePersistence/       # SQLiteConnection、schema v1、migration、SQLiteWorkspaceStore
Sources/ArcLakeM1/                # Loading/Ready/Recovery SwiftUI 启动壳
Sources/ArcLakeM0/ + M0Core/      # 浏览器能力探针回归资产
Tests/ArcLakeCoreTests/           # Swift Testing：领域、命令、恢复、generation、随机树属性
Tests/ArcLakePersistenceTests/    # Swift Testing：SQLite、WAL、revision、迁移、故障注入
Tests/M0CoreTests/                # XCTest 遗留 M0 配置回归
```

M1 已按上述纵向切片实现。SQLite schema v1 的权威定义在 `SQLiteMigrations.swift`，Workspace 状态的权威值在 `WorkspaceState.swift`；UI 不应绕过 `AppController`/`Workspace.decide` 直接修改这些值。未来引入 Xcode app/UI test target 时继续复用同一 Core/Persistence Interface，不复制第二套树规则。
