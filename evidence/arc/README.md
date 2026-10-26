# Arc Browser 特性证据报告

> **已更新：请优先阅读 [无 Hopper 版完整特性分析](no-hopper/README.md)。** 新增 REA Mach-O/Swift 名称证据、Swift 数据结构、38 个方法入口的局部反汇编及官方规范交叉验证。下文保留首轮调查状态，不代表最新覆盖程度。

## 范围与结论

目标：本机 **macOS Arc 1.135.0，build 75383，arm64 选择架构**。Info.plist 声明构建时间为 19 Feb 2026, 06:07。**本项目范围仅 macOS；Windows 版本不在分析范围内。**

**11 项均已建立证据档案，但都只是部分证实，不能称为完整行为验证。**
- REA 成功取得发行包身份和 Interface Builder 归档图，包含菜单标题、键位、modifier mask、对象与 target-action 连接。
- 补充只读脚本取得同一发行二进制中的文字、内部标识及原始字节偏移。这部分明确不是 REA Evidence，更不是反编译。
- 没有成功取得函数反编译、运行轨迹或截图。没有读取个人浏览记录、Cookie、密码、账号或用户 Profile 数据。
- 每项文档同时列出证据原文与尚未验证的用户描述。

## 特性与证据索引

| 特性 | 实际取得的关键证据 | 仍不能确认 |
|---|---|---|
| [1. 垂直侧边栏](01-sidebar.md) | REA: Show/Hide Sidebar → toggleArcSidebar:，⌘S；Reveal Tab in Sidebar | 左侧布局截图、全部导航/地址栏位置 |
| [2. Spaces](02-spaces.md) | REA: 新建/管理/重命名、editSpaceTheme:、nextSpace:/previousSpace:；文本：当前空间的固定标签与文件夹 | 底部切换 UI、Ctrl+数字具体映射、独立状态实测 |
| [3. Profiles](03-profiles.md) | REA: changeProfileForCurrentSpace:；文本明确隔离 history/logins/cookies/extensions，一个 Profile 可用于多个 Spaces | 存储隔离、登录与扩展隔离的运行测试 |
| [4. Favorites](04-favorites.md) | 二进制文本：Favorites at the top；不同 Profile 会有不同 Favorites | 同 Profile 的跨 Space 共享状态；无本项独立 REA 行为证据 |
| [5. Pinned Tabs](05-pinned-tabs.md) | REA: toggleSelectedItemsPinned:，⌘D；固定区展开/折叠；通用 Rename；文本：固定到 Space/Folder | 永不自动归档规则；固定标签重命名操作实测 |
| [6. Folders](06-folders.md) | REA: New Folder → newList:、展开/折叠；文本明确 Share a folder via context menu | 拖拽、实际分享与当前分享服务可用性 |
| [7. Auto-Archive / Today](07-auto-archive.md) | 文案：过去 12 小时未使用；可调整；1/6/12/24 小时、7/30 天、never；REA: Archive/Library/恢复关闭标签入口 | 当前设置、真实计时执行、Pinned 豁免、Library 中恢复链路 |
| [8. Air Traffic Control](08-air-traffic-control.md) | 文案明确 Routes 决定特定网站打开位置，以 Spotify → Personal space 为例 | 匹配算法/优先级/链接来源覆盖范围；无独立 REA 路由实现证据 |
| [9. Split View](09-split-view.md) | REA: 添加/关闭/最大化/分离分屏；文案：水平/垂直；第四面板描述与最大面板数错误标识 | “最多恰好 4 个”、可调整大小的实际行为、整个分屏作为一个固定标签 |
| [10. Little Arc](10-little-arc.md) | REA: newLittleBrowserWindow:，⌘⌥N；openInCurrentSpace:，⌘O；文案：其他应用链接打开到 Little Arc | 浮动层级/轻量性能/不干扰主区 |
| [11. Command Bar](11-command-bar.md) | REA: ⌘L → toggleOpenOmnibox:；⌘T → newWindowForTab:；文案明确 ⌘T 打开命令栏；搜索/最近标签/扩展说明 | 历史搜索数据源、动作执行与排序、完整候选集合 |

## 值得修正或保留的细节

1. **⌘T 和 ⌘L 都有证据，但不是相同的归档入口。** 主菜单把 ⌘L 标为 Open Command Bar；引导文案明确 ⌘T 打开 Command Bar 并创建新标签。不能只看其中一个就断言另一个错误。
2. **12 小时是“不再使用”的时间，不是从标签创建开始算。** 原文：`Arc archives tabs that you haven’t used in the past 12 hours. You can adjust this in %@Settings%@.`。它仍然是文案证据，不是当前安装设置或计时器测试。
3. **Space 不等于 Profile。** 应用文字明确一个 Profile 可以分配给一个或多个 Spaces；只有不同 Profile 才有文案所述的数据隔离意义。
4. **第四个分屏面板 ≠ 已证明上限恰好为四。** 发现第四面板跳转说明、最大面板数错误名，但没有取得上限常量或分支逻辑。
5. **不能把“全部控件永远都在侧边栏”当成无条件结论。** 归档还有 Show/Hide Toolbar → toggleArcToolbar:，其归档状态为隐藏；实际动态可见性未知。
6. 编译资源里有隐藏菜单和历史功能字符串。存在文本或 selector 只能证明发行物保留了它，不能证明当前版本会展示、执行或由在线服务支持。

## 原始证据及可复核路径

- [rea-bundle.json](rea-bundle.json)：REA 导出的完整、未裁剪证据包，2 条记录，包含归档图与限制。
- [identity.json](identity.json)：REA inspect_plist 的原始工具回复。
- [menu-items.json](menu-items.json)：从 REA 归档图派生的菜单标题/键位/处理器表。
- [static-text.json](static-text.json)：补充二进制字符串观察，按 11 个主题分组，保留查询边界和偏移。
- 每个主题另有同名 JSON，方便程序消费与逐条复核。
- [blockers.json](blockers.json)：反编译与 GUI 失败边界。
- [extract-static-text.py](extract-static-text.py)、[build-report.py](build-report.py)：只读提取与报告构建/字节验证脚本。

### 身份

发行主程序：
`/Applications/Arc.app/Contents/MacOS/Arc`

SHA-256：
`b192994372b8d0ef7beb465c3cad0f2d02a227c6988238e037d8e026536db688`

MainMenu 归档：
`Contents/Resources/Base.lproj/MainMenu.nib`

归档 SHA-256：
`c05560f6665c062b78dd326c4ce56307154010f981a45f4959671fb460ab1963`

REA 身份 Evidence ID：
`ev_45c8d31c76938850c3dfd16c8d8db08b78321bbcf3e96b79204a00aac5253682`

REA Interface Builder Evidence ID：
`ev_79b3e880589785e95be53245ee4309dc10599f4c85a1b751c10a79e857ef261e`

对象定位：每项 Markdown 中的对象编号对应归档图 node 的 `interface_builder_object_id`；selector 来自同文档 `kind=action` 节点，并按 `source_id` 连接。不是通过字符串相邻关系推定。

快捷键解读：AppKit modifier mask 中 1048576 为 Command、524288 为 Option、262144 为 Control、131072 为 Shift；组合按位相加。原始 key 保留大小写，不把大写键误写成无 Shift。归档绑定可能被运行时代码或用户快捷键覆盖。

验证：报告选取的 **53 个文字引用范围**已重新按偏移读取并与原始字节逐一比较；整文件 SHA-256 与 REA 身份一致。此校验只验证引用忠实，不验证功能运行。

## 工具限制与待继续事项

Hopper 首次 search_strings 在 MCP 60 秒期限超时，没有留下该查询的 Evidence；后续返回 cleanup_incomplete。已导出完整 REA 包并尝试 close_binary，但未收到 Hopper 的认证关闭确认，仍报告 `hopper-document` 与 `/tmp/rea-mKZZnp` 保留。未宣称清理成功，也未继续打开其他原生目标。

cua-driver 返回 macOS Accessibility / Screen Recording permissions_pending，未执行 GUI 操作。需要用户完成相应权限，以及处理 Hopper 的待决窗口/分析文档；若桥接仍不可用，关闭对应 Hopper 文档并重连 MCP。

后续优先验证：
- 自动归档默认初始化、最近使用时间条件及固定标签过滤；
- 分屏面板上限和固定分屏的存储模型；
- Favorites 的 Profile 所属关系与跨 Space 的共享状态；
- Link Routing 的匹配、优先级和 Space 选择路径；
- 在专用测试窗口中做截图及动作前后验证，不使用真实账号资料。

因此，本报告应称为 **“REA 静态资源核验 + 补充发行物文本证据”**，而非“11 项功能全部逆向完成”。
