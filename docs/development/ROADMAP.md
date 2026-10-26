# 实施计划与复现路径

各阶段以验收门槛推进，不以界面截图代替功能交付。M0、M1 均已在 macOS 27 上通过，当前进入 M2，见 [M0 报告](M0-RESULTS.md) 与 [M1 报告](M1-RESULTS.md)。平台假设见 [README](README.md)，功能契约见 [SPEC](SPEC.md)。

## M0 — 关键能力验证（先做，阻塞后续）

**目标**：证明选定技术能承担浏览器，而不是先堆 UI。

任务：
1. 创建独立 bundle ID 的最小 macOS App，主窗口通过 SwiftUI + AppKit 承载 WKWebView。
2. 两个固定 store UUID、三个测试 Space（A1/A2 同 Profile，B1 不同 Profile）。
3. 本地两 origin 测试站：Cookie、localStorage、IndexedDB、HTTP 跳转、target=_blank、POST/表单与下载；不用个人账号。
4. 设置不同 Profile 标记，应用退出重启，核实同 Profile 共享、不同 Profile 分离、UUID 不变。
5. 切换 Sidebar/主题 50 次，检查 WebView 对象身份和测试页 load counter，不能重复加载。
6. 试验同 Profile 主窗/小窗之间 detach/attach，观察 JS 内存计数器、滚动、表单和 first responder；确保没有双宿主。
7. 试验 WebKit store 删除条件、进程终止响应，以及最低系统支持。

当前实现另含：原生 HTML 表单 POST、`WKUIDelegate` target=_blank、`WKDownload` 本地附件、可见窗口真实滚动、AppKit keyDown/keyUp 路径，以及测试编排器校验 PID 后对 WebContent 发送真实 `SIGKILL`。

**产物**：可运行能力演示、测试日志（脱敏）、已验证/失败 API 清单、更新后的架构决定。

**门槛**：T01–T05、T29 的相关子项通过。若持久隔离失败，禁止以每次新建临时 store 或 WKProcessPool 替代后宣称 Profile 完成。若 reparent 不可靠，需正式改成“提示后 URL 重开”的小窗移交方案，并修改规格和验收，不隐瞒状态丢失。M0 Gate 已在 macOS 27.0.1 上执行 `python3 scripts/run_m0.py --test --require-minimum-os` 并通过。

## M1 — 领域模型、持久化与命令骨架

依赖：M0 隔离方向成立。

**状态：完成。** `ArcLakeCore`、`ArcLakePersistence`、SQLite schema v1、I01–I12、Workspace 命令、AppController 和 `ArcLakeM1` 启动壳已实现；T06–T10、T25–T28 及 100 次随机合法树操作通过。

- 实现强类型 ID、Root/Item/Tab/Space/Profile/Split 值模型及 I01–I12 校验。
- 创建 SQLite schema v1、迁移工具、单写者事务、内存 adapter、revision。
- 实现 Workspace 的 create/move/pin/unpin/rename/switchSpace 基本命令；所有操作先走领域逻辑再渲染。
- 定义 BrowserEvent 与 generation 校验，建立 AppController 提交/效果循环。
- 完成初始 Default Profile/Space 引导、冷启动惰性恢复、错误恢复页。

**门槛**：T06–T10、T25–T28；100 次随机合法树操作后所有不变量成立；非法移动无部分写入。

## M2 — 可日用的组织核心（Foundation Demo）

依赖：M1。

**下一阶段。** M1 的 Store/AppController Interface 作为唯一持久化与命令入口，不在 UI 中复制移动/固定/收藏规则。

- Sidebar、地址输入、前进/后退/刷新、真实网页、⌘S/⌘L/⌘T/⌘W。
- Space 编辑/排序/主题与 Control+数字切换。
- Profile 创建/选择/删除与删除失败重试、Favorites、Pinned、Folder、拖拽和可用的上下文菜单。
- 定义并执行跨 Profile “复制链接”与 Space 更换 Profile 的确认流程。
- 先做命令栏最小版：URL/搜索/活动项，命令 registry 已统一，不临时塞独立事件路径。

**产物**：真实浏览、隔离与组织可以重启恢复的应用；标记为 Foundation Demo，不宣称 11 项全部实现。

**门槛**：T01–T12、T21 基本输入路径；每个页面有加载/失败/重试状态，无功能空按钮。

## M3 — 归档、Library 和完整命令栏

依赖：M2。

- Archive clock/protection policy、按 Profile 阈值、周期/启动/唤醒扫描。
- 单项、Folder、Split 快照结构及恢复（Split UI 未上线也能测试纯模型）。
- Profile 限定 History 与 Library 的 Archive/History 两页。
- ⌘⇧T、清除、保留期、磁盘失败、来源 Space 已删除时的恢复选择。
- 异步候选取消、排序、当前 Profile 过滤、registry 动作与 enabled 条件。

**门槛**：T13–T16、T21–T23；使用固定时钟，无需等 12 小时；旧 Profile 搜索结果绝不能闪现。

## M4 — 分屏与 Little Window

依赖：M2/M3，M0 移交试验通过。

- 2–4 面板、横/纵布局、比例、焦点、整体固定、面板分离与关闭。
- 小窗 UI、多个小窗所有权、同 Profile 移交、跨 Profile 显式复制。
- 资源预算/惰性恢复、页面进程死亡、窗口关闭与应用退出的区别。
- 完成键盘焦点、输入法、原生弹窗/文件选择下的稳定性验证。

**门槛**：T17–T20、T24、T29–T30；第五个面板请求不能改变树；关闭小窗与退出 App 的归档行为不同。

## M5 — Routing、系统集成和本地导入导出

依赖：M4（因为目标可能是 Little Window）。

- 规则编辑、匹配预览、优先级、默认目标、坏目标处理和 requestID 去重。
- 系统 HTTP(S) 打开事件，和应用内模拟器共用 OpenRequest Interface。
- target=_blank/user gesture policy；重定向不重路由。
- Folder 清单导入/导出、大小/深度/URL 限制与隐私提示。
- 下载列表、取消/重试、文件保存/上传、系统权限错误；开发模式不篡改默认浏览器。

**产物**：完整基础功能版，11 项均达到 SPEC 的明确范围。

**门槛**：T31–T37，及 F01–F11 映射全部通过；不以打开自定义 scheme 代替真正 HTTP(S) URL 事件验收。

## M6 — 稳定性、可访问性与候选发布

- 在 macOS 27 及后续支持系统跑 Profile 持久化、迁移、窗口和安全回归。
- 验证 VoiceOver 标签、键盘全流程、焦点环、中文输入法与较小屏幕布局。
- 1000 个侧栏项目、10000 条 History 基准数据；目标：本地命令候选 p95 <150ms，侧栏开合不触发网络重载。记录硬件/系统/样本，不把目标当已测结论。
- 连续开关 100 次小窗并切换 Profile，检查观察器/引用释放；内存测试关注趋势与保留 session 数，不对 WebKit 全局进程内存给虚假定额。
- 磁盘满、只读目录、坏 migration、未知 schema、崩溃恢复、权限拒绝、离线和证书错误测试。
- 发布签名、公证、Sandbox entitlements、退出保存、卸载和数据删除提示。

**门槛**：全部 P0 用例通过，无跨 Profile 数据泄漏、持久数据损坏、TLS 绕过；P1 限制有明确 UI 文案与发布说明。

## 工作拆分建议

可并行：Core 模型/政策测试；SQLite adapter/迁移；SwiftUI 无浏览器数据的视图；测试站 fixtures。

必须串行确认：Profile/store 身份 → 稳定运行注册表 → 小窗移交；树不变量 → 分屏/归档；事务协议 → 删除/恢复。不要让 UI 先自行定义第二套标签归属。

每个实现 PR 需附：对应 F/T 编号、设计决定、测试结果、运行截图（如相关）、数据迁移影响、已知偏差。任何超出 SPEC 的功能先更新规格，不从遗留 Arc 字符串自动扩大范围。

## 何时才追加逆向

仅在如下情况下追加定点调查：
- 产品要求与 Arc 精确一致，而当前存在影响用户体验的歧义；
- 多个合理设计会造成不同数据丢失/恢复语义，且用户不接受自定义规则；
- 实际 Arc UI 与官方说明矛盾，需确定目标版本行为。

API 能力不足、WebKit 网站兼容性、我们的数据库 bug 不靠继续逆向 Arc 解决。默认先修实现或评审范围。
