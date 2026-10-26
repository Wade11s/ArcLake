# ArcLake macOS 功能规格 v0.1

本文是实现目标，不是对 Arc 所有运行行为的断言。除标为 E/O 的来源事实外，精确边界、默认数值、失败处理均为 **[D] ArcLake 设计决定**。技术验证项标为 V。

## 1. 范围与证据追踪

| ID | 功能 | 基础功能版承诺 | 证据 | 不承诺 |
|---|---|---|---|---|
| F01 | Sidebar | 左侧组织、导航区、地址入口、⌘S 隐藏/恢复 | [E01](../../evidence/arc/no-hopper/01-sidebar.md) | 像素级复刻、所有 Arc 顶栏变体 |
| F02 | Spaces | 创建/命名/主题/图标/排序/切换；独立固定区与 Today | [E02](../../evidence/arc/no-hopper/02-spaces.md) | 云同步、共享 Space |
| F03 | Profiles | 网站数据持久隔离、应用历史隔离；Space 选择 Profile | [E03](../../evidence/arc/no-hopper/03-profiles.md) | Chrome 扩展隔离、跨 Profile 密码迁移 |
| F04 | Favorites | Profile 内跨 Space 共享；拖拽添加、排序、移除 | [E04](../../evidence/arc/no-hopper/04-favorites.md) | 固定数量上限、实时站点预览、Favorite 分屏组合 |
| F05 | Pinned | 固定/取消、重命名、保存并重置原始 URL、不自动归档 | [E05](../../evidence/arc/no-hopper/05-pinned-tabs.md) | 跨站自动 Peek |
| F06 | Folders | 固定区嵌套、拖拽、重命名、展开/折叠；URL 清单导入导出 | [E06](../../evidence/arc/no-hopper/06-folders.md) | 公网分享链接及协作；导入不执行脚本 |
| F07 | Auto-Archive | Profile 阈值、12 小时默认、恢复/清除、Library 入口 | [E07](../../evidence/arc/no-hopper/07-auto-archive.md) | Arc 多设备归档一致性 |
| F08 | Routing | 包含/精确匹配；规则排序；Space/Little 目标；默认行为 | [E08](../../evidence/arc/no-hopper/08-air-traffic-control.md) | 正则、自动学习、重定向重路由 |
| F09 | Split | 2–4 网页、横/纵布局、调比例、焦点、分离、整体固定 | [E09](../../evidence/arc/no-hopper/09-split-view.md) | 嵌套分屏、无限布局 |
| F10 | Little Window | 独立小窗、外部 URL 入口、关闭、移入主窗口 | [E10](../../evidence/arc/no-hopper/10-little-arc.md) | 系统全局快捷键、强制跨全屏置顶 |
| F11 | Command Bar | URL/搜索/当前 Profile 历史/标签/Space/应用命令 | [E11](../../evidence/arc/no-hopper/11-command-bar.md) | AI、联网联想、Arc 排名算法 |

基础浏览同时必须有：HTTP(S) 加载、后退/前进/刷新/停止、加载失败页、窗口标题、复制 URL、基础下载、上传文件选择、显式权限提示。无痕窗口、密码管理器、扩展商店不纳入首版。

## 2. 界面与焦点

### F01 主窗口

从上到下：窗口控制区 → 前进/后退/刷新 → 地址按钮 → Favorites 图标区 → Space 名称 → Pinned/Folder/Split 区 → 分隔线 → Today 区 → 底部 Space 切换、加号、Library。

- 初始侧栏宽 260pt，可调 200–420pt；这是设计起点，不是逆向测量结果。
- 内容区只展示被选中的 Tab 或 Split。页面仍在加载时可以切换 Space。
- ⌘S 只隐藏侧栏，不销毁网页实例；隐藏时保留可发现的恢复按钮。⌘L/⌘T 均仍可用。
- 地址按钮显示当前焦点网页的 host；点击或 ⌘L 打开命令栏并预填当前完整 URL。小窗有自己的地址/关闭/移入按钮。
- Escape 先取消命令栏/重命名/拖拽，再交给网页；不默默退出全屏。
- SwiftUI 视图刷新不得重新加载网页。系统浅色/深色跟随全局设置；Space 主题影响浏览器壳，不向网页注入 CSS。[E/O] Arc 存在可选 Toolbar；本版不声称“侧栏是唯一可能的浏览器栏”。

### 快捷键（macOS）

| 快捷键 | 行为 | 来源 |
|---|---|---|
| ⌘S | 显示/隐藏侧栏 | E |
| ⌘T | 打开命令栏，新标签模式；提交前不创建空标签 | E/O + D |
| ⌘L | 打开命令栏，当前网页导航模式 | E |
| ⌘D | 固定/取消当前顶层项；当前 Split 则作用于整个 Split | E + D |
| ⌘W | 关闭焦点网页；Pinned/Favorite 保留条目，Today 移入归档；Little 关闭小窗 | E + D |
| ⌘⇧T | 恢复当前 Profile 最近一条手动关闭归档，不恢复其他 Profile | E + D |
| Control+1…9 | 按侧栏顺序切换前九个 Space | O |
| ⌘⌥← / → | 上/下一个 Space | E |
| ⌘⌥N | 新建 Little Window，等待输入 URL | E + D |
| ⌘O | Little 的网页移入主窗口当前同 Profile Space，否则选择目标 | E + D |
| ⌘⇧C | 复制焦点 URL | E |
| ⌘, | 设置 | E |

应用快捷键仅在对应窗口内处理；编辑框的文本操作与输入法组合不能被误拦截。首版不提供全局热键注册或自定义快捷键编辑器。

## 3. Space、Profile 与组织规则

### F02 Spaces

- 新安装原子创建 Default Profile 和一个默认 Space；永远至少保留一个 Profile、一个 Space。
- 每个 Space 恰好属于一个 Profile；拥有独立主题、图标、Pinned 和 Today 根区域。[E/O]
- 切换 Space 更新 Favorites 来源和命令栏查询范围；不得修改网页的 Cookie store 来“伪装切换 Profile”。
- 每个 Space 保存最近选择项；该项失效时按 Today 首项 → Pinned 首项 → 空白占位恢复。
- 删除 Space：展示项目数量并确认；删除该 Space 的路由规则，将固定区和 Today 项目打包归档到原 Profile，保留其历史。Favorites 不受影响；最后一个 Space 不允许删除。

### F03 Profiles

- 创建 Profile 分配唯一、非零且持久的 store UUID。重启后必须复用，不得每次新建 store。[V]
- 共享 Profile 的多个 Space 共享网站登录；不同 Profile 的 Cookie/localStorage/IndexedDB 和 ArcLake 历史分开。
- 不是 OS 用户/进程级安全沙箱：不承诺隔离系统钥匙串、网络 IP、系统认证或指纹。
- **普通拖拽仅允许同 Profile 移动。** 跨 Profile 操作必须显式选择“复制链接到另一 Profile”：复制 URL/标题/组织结构，不复制 Cookie、历史、网页内存和表单。
- 更换整个 Space 的 Profile 是独立操作：提示需要重新登录，先阻止新导航并关闭所有相关 WebView，事务更新 Space/Tab 的 Profile，清空该 Space 的窗口选择后重建目标 store 网页。Favorites 换成新 Profile 的列表；原 Profile 的历史和归档保持原归属。元数据提交失败保持原 Profile，不允许半迁移；已释放的网页只能在原 store 按 URL 重建，不能承诺恢复其 JS 内存或未提交表单，所以释放前必须提示并处理离开页面确认。
- 同一 Profile 的 UUID 不可随重命名改变。
- 删除 Profile 仅允许其无 Space、无 Little Window 引用时执行；其 Favorites 可存在，但必须一并确认删除并释放关联运行实例。明确确认会删除其 Favorites、归档、历史及 WebKit 数据。异步失败保留“删除待重试”状态，不能显示删除成功后偷偷保留数据。流程见 ARCHITECTURE。

### F04 Favorites

- Profile 级容器，首版只接受单个 Tab；所有同 Profile Space 展示同一顺序。
- 添加已有单标签到 Favorites 是移动归属，不保留另一个侧栏副本；内部 URL 相同不强制合并。
- 默认保存加入时的 URL；可以编辑标题与保存 URL；后续导航不覆盖 savedURL。
- “取消收藏”移动到当前同 Profile Space 的 Today，并重置闲置时间；“删除收藏”是单独确认操作，不等于 ⌘W。
- 超出可见图标数量时滚动/溢出，不用固定 8 或 12 的推测限制用户数据。

### F05 Pinned

- 固定顶层 Today Tab/Split 会移动到当前 Space Pinned 末尾；Folder 内的项天然属于固定区。
- 固定时为各叶 Tab 记录 savedURL；点击图标或“重置到保存网址”加载 savedURL，保留自定义标题。
- 取消固定将该项从 Folder/固定根移到 Today 末尾，结构不变，更新时间为当前时间。
- ⌘W 关闭已固定单标签只释放运行实例、保留条目；重新选择时加载 savedURL。明确“移除固定项”才删除，删除前进入手动归档以支持恢复。
- 网页可自由导航，不实现 Arc 的自动 Peek；这是有意简化。

### F06 Folders

- 只允许位于 Pinned 根或另一 Folder 下；可包含 Tab、Folder、Split。
- 拖拽目标为自身或后代时拒绝；不允许将 Folder 放入 Today/Favorites/Split。树结构最大 8 层，首版自定限制并显示原因。
- 移动 Folder 保持子树及 sibling 顺序，事务内完成，不产生孤儿 Tab。
- 删除 Folder 将整棵子树作为一条归档记录，恢复时保留层次。
- 本地分享格式：版本化 JSON，包含标题、HTTP(S) URL、Folder 层级与 Split 方向；不包含 Profile UUID、历史、Cookie、窗口或机器标识。
- 导出预览提醒 URL 的查询参数可能包含私密信息；只有用户确认后才写入文件。导入限制 1MB/500 个叶 Tab/8 层，验证 schema 与 URL；导入后不自动批量打开网页。不是公网分享服务。

## 4. F07 归档与 Library

### 归档资格

默认 Today 闲置 12 小时。[O] 阈值按 Profile 设置，首版 UI 提供 1/6/12/24 小时、7/30 天，不提供 never 或调试 20 秒。

- 自动归档只处理 Today 顶层项；Pinned/Favorite/Folder 永不被自动归档。
- 当前显示的 Tab、可见 Split 的全部面板、正在导航或下载的 Tab 均保护；有原生权限/文件选择交互的 Tab 也保护。首版不依据未经可靠核实的“媒体播放检测”作保证。
- 查看、激活或用户点击对应网页区域更新 lastActiveAt；网页的计时器、广告刷新、重定向不能刷新用户活动时间。
- 可见项一直受保护；离开可见状态时再次记录当前时间，因此长时间阅读不会刚切走就被归档。这是 D。
- Today Split 作为一个单位自动归档，只有全部叶 Tab 都超时且无保护才合格；使用最晚 lastActiveAt 计算。
- 以当前绝对时间与 lastActiveAt 的差值判断，每分钟扫描一次，在启动/唤醒时补扫；不会创建“必须运行 12 小时”的内存倒计时。时钟倒退时将负时差视为零。
- 启动先恢复选择和可见项保护，再执行扫描；暂停时钟/关闭应用不暂停闲置时长。

### 归档/恢复事务

- 归档保存标题、URL、savedURL、子树、Split 布局、来源 Space/Profile、原因和时间；不是保存网页 HTML/表单/后退栈。
- 先把完整快照写入归档并从活动树删除，事务提交成功后才释放 WebView；失败不得造成页面丢失。
- 恢复始终使用原 Profile，并创建新的活动项/Tab ID；归档记录有 restoredAt 防止重复点击生成重复项。恢复不执行路由。
- 来源 Space 仍属于原 Profile时恢复到原区域；原 Folder 不存在则恢复固定根。Space 已删除/换 Profile 时让用户选择原 Profile 的 Space；若没有则创建“Recovered” Space。
- Library 首版含 Archive 与 History 两页：恢复项不是访问历史恢复；History 仅记录当前 Profile 的顶层成功导航。
- 归档默认保留 30 天，清除/自动清理不会删除 History。History 默认保留 90 天；均可主动清除，清除前确认且按 Profile 限定。
- 手动 ⌘W 归档单面板、删除文件夹等也进入 Archive，但不会绕过 Pinned 的自动归档豁免。

## 5. F08 链接路由

### 输入范围与优先级

只对 **外部应用 URL 打开事件**、用户明确“在新上下文中打开”的 HTTP(S) 链接评估规则；普通网页当前 Tab 导航、服务器重定向、Archive 恢复、会话恢复和手动移动不重新评估。

1. 用户明确指定目标（如在某个 Space 新建）：优先于规则。
2. 否则按用户排列顺序，首个 enabled 且目标有效的规则获胜。
3. 无命中：内部新上下文进入源 Space；外部链接使用设置的默认目标（初始 Little Window + Default Profile）。

此优先级为 D，未从 Arc 反编译恢复。

### 匹配定义

- 首版一条规则一个条件，只支持 contains/exact；不实现多条件逻辑或正则。
- URL 经 Foundation URL 解析，scheme/host 小写、移除默认端口、空路径归为 /；其余路径/查询保留百分号编码与大小写，匹配忽略 fragment。原始 fragment 仍保留用于实际导航。
- contains 在上述完整字符串上执行大小写敏感子串匹配；exact 为完整相等。规则编辑器展示规范化示例并提供“测试链接”预览。
- **contains 不是安全域名匹配**，可能命中查询参数或 example.com.attacker.test。设置页明确警告；该功能不承担安全策略职责。
- 有效目标：Space，或 Little Window + 明确 Profile。Profile 不从网页参数推断。
- Space 删除时删除引用它的规则；Profile/目标处于删除状态时跳过规则并给出可见告警，不悄悄切换浏览身份。
- 一个 openRequestID 最多执行一次，重复事件重放幂等；不同请求即便 URL 相同也不自动去重，避免改变用户意图。
- 不搬运 Cookie；跨 Profile 命中的 URL 在目标 store 新建网页。

## 6. F09 分屏

- Split 是顶层或 Folder 内的 SidebarItem，包含 2–4 个直接叶 Tab；禁止 Folder/Split 嵌套。
- horizontal 表示左右并排，vertical 表示上下堆叠；整个组只使用同一个 Profile。
- 创建可通过选中两项合并、拖到内容区边缘或命令栏添加。已有活动 Tab 被移动进组，不生成隐藏重复节点。
- 新面板请求超过 4 时不改变任何状态，显示“最多 4 个面板”；操作方可另选新 Tab。
- 比例为正数、归一化为 1。水平每面板最小 220pt，垂直最小 160pt；窗口最小尺寸约束随面板数更新。显示区域不足则拒绝增加，不能悄悄丢失面板。
- 方向/比例/顺序/焦点面板持久化。一次拖动结束提交一笔结构事务，不逐像素写数据库。
- 固定/取消固定作用于组；组内 Tab 的保留策略继承组，不独立保留。
- 关闭一个面板：Today 面板手动归档，Pinned 面板仅从组移出到同 Space 固定根并卸载运行实例，避免无声删除固定网址；剩 1 个时原子折叠成单个项并保留组的固定状态，剩 0 个时移除组。
- “分离全部面板”按原顺序放回组所在区域/Folder；不归档、不重新路由。
- Favorites 不接收 Split；从固定 Split 选中一叶添加收藏必须显式分离，界面提示结构变化。

## 7. F10 Little Window

- 一个小窗持有一个 Profile 下的 Tab，独立 NSWindowController；可以同时有多个。
- 不使用抢焦点或强制置顶策略；用户点击外部链接时按系统正常激活行为显示。避免声称性能必然“轻量”。
- 用户手动关闭小窗创建原因 littleClosed 的归档记录；应用整体退出只保存窗口会话，不逐窗归档。首版不做 Little 独立自动归档，这与 Arc 历史 6 小时策略有意不同。
- 同 Profile 移入主窗口：以原子所有权迁移复用运行实例，保留页面内存；必须经过 M0 验证。不允许同一 WKWebView 同时挂载在两个窗口。
- 跨 Profile：只提供“复制链接到目标 Profile”，保留小窗；提示不会迁移登录/表单。成功导航确认后用户可自行关小窗。
- 移入同 Profile 但没有合适 Space 时弹出选择/创建 Space；不默默使用另一个 Profile。
- 小窗状态保存 URL/Profile/窗体尺寸；启动先显示恢复清单，不自动打开全部小窗网络内容。
- 不接管用户系统默认浏览器；开发期可用应用内“模拟外部链接”入口测试，正式注册要用户主动操作。

## 8. F11 命令栏

- 模式：newTab、navigateCurrent、addSplitPane；执行目标在打开时捕获，再在提交前重新校验有效性。
- 分类：直接网址、搜索、活动标签/收藏/固定项、当前 Profile 历史、Spaces、应用命令。
- 允许显示所有 Space 的名称用于显式切换；其他 Profile 的标签标题/URL/历史不出现在搜索结果。
- 切换 Profile 或关闭命令栏时使正在运行的查询失效；旧结果不得短暂闪现到新 Profile。
- 确定性初始排序：精确命令/Space 名称 → URL 导航候选 → 活动项标题前缀 → 标题子串 → 当前 Profile 历史（最近优先）→ 普通搜索。每类稳定次序为最近使用时间、最后以 ID 排序。手动选择优先，不让异步历史结果重置选择。
- 输入约 100ms debounce；最多 30 个候选。URL/navigation 候选使用 URL 解析，不仅依赖正则；有空格的普通输入默认搜索。
- 首版搜索引擎配置为 HTTPS URL 模板；只在用户提交搜索时发送 query，不联网取联想；日志不记录 query 原文。
- `javascript:`、`data:`、`file:` 输入拒绝；外部协议单独确认，不送进搜索或静默打开。
- 所有菜单、快捷键、命令栏执行共享同一 command registry 和 enabled 条件。命令栏不能成为绕过权限/Profile/结构校验的入口。

## 9. 安全、数据与异常基线

- 默认启用 App Sandbox 和网络客户端权限，下载/导入/导出由用户选择位置；正式发布另做签名、公证与 URL 事件验收。
- 不读取 Arc 用户资料，不导入密码，不复用 Arc.app 私有代码、素材、商标或在线服务。
- TLS 证书错误不自动放行；摄像头/麦克风等默认拒绝或明确按 origin 请求；不支持的权限要告诉用户。
- 上传必须用户选择文件；下载显示来源 host、状态和失败重试，不自动打开下载文件；取消下载释放任务保护。
- ⌘W/退出/卸载网页前尊重 WebKit 提供的离开页面提示；无法检测全部表单状态，不承诺保存未提交内容。
- 本地 URL/标题/历史是敏感数据；不输出原文调试日志，不上传遥测。SQLite 不声称自行加密，依赖系统账户/磁盘保护，文档必须告知。
- 页面进程终止显示重载入口；存储写入失败显示未保存状态并保留原模型，不能空白初始化覆盖现有数据。
