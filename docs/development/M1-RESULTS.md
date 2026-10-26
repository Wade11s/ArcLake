# M1 技术验证与实施结果

日期：2026-10-27。状态：**M1 Gate 通过。**

环境：Apple Silicon arm64；macOS 27.0.1；Xcode 27.0 / Swift 6.4；Swift tools 6.4；Mach-O 最低部署目标 macOS 27.0；SQLite 来自 macOS 27 系统 SDK。

主报告：[latest.json](../../test-results/m1/latest.json)。最近一次完整证据为 `test-results/m1/20261027T000459-ddec914a/`。

## 1. 已交付

- `ArcLakeCore`：强类型 UUID、Profile/Space/Root/SidebarItem/Tab/Split/Window/Archive/History/Route/Pending 值模型。
- I01–I12 验证器，包括树环、Profile 一致性、Tab 唯一 owner、Split 比例、选择指针、Favorites 仅含单 Tab 子项、不安全归档 URL、History Profile 过滤、active/archive 冲突和 WebView 唯一宿主/store 校验。
- Workspace 纯值命令：创建 Profile/Space/Tab/Folder、移动、Pin/Unpin、Favorite/Unfavorite、重命名、Space 切换、选择/激活、导航、固定 Tab 释放与 savedURL 重置。
- SQLite schema v1：profiles、spaces、roots、items、tabs、split_configurations、window_sessions、archive_entries、history_visits、route_rules、application_settings、pending_operations、processed_open_requests、meta。
- SQLite 单写者 actor：WAL、foreign keys、FULL synchronous、单事务整快照提交、revision 校验、历史 Profile 作用域查询。
- 迁移框架：事务内迁移、迁移前 SQLite backup、未来 schema 只读拒绝、失败回滚。
- `AppController`：启动/bootstrap、选择修复、冷启动惰性恢复、串行命令门禁、提交后发布、效果顺序、BrowserEvent generation 校验、错误恢复状态。
- `ArcLakeM1` SwiftUI 启动壳：Loading、Ready、Recovery 三态；Default Profile/Space 首次引导和同一数据库冷启动。

## 2. 测试结果

- Swift 测试总计 **40/40 通过**：M0 回归 5；M1 Core 26、M1 Persistence 9，全部使用 Swift Testing。
- M1 要求的 14 个具名场景全部通过：T06–T10、100 次随机合法树操作、非法移动零写入、T25–T28。
- SwiftUI 冷启动烟测通过两次：
  - 第一次：schema 1、Profile 1、Space 1、revision 1、WAL。
  - 第二次复用同一数据库：仍是 Profile 1、Space 1、revision 1，没有重复 bootstrap。
- M1 二进制 `LC_BUILD_VERSION.minos = 27.0`，与最低系统目标一致。

## 3. 覆盖映射

| 场景 | 结果 |
|---|---|
| T06 首次启动 | Default Profile/Space/roots 一次事务提交后才发布 ready；store UUID 已先持久化 |
| T07 Spaces | 独立 Pinned/Today roots；窗口切换和选择恢复；Favorites 按 Profile 共享 |
| T08 Favorites | 跨 Space 共享；其他 Profile 不可见；取消收藏回到当前 Space Today，无重复 Tab |
| T09 Pinned | savedURL 不被导航覆盖；自定义标题保留；释放后重新激活加载 savedURL；Reset 回到 savedURL |
| T10 Folders | 自身/后代/Today/跨 Profile 移动均拒绝；合法重排保留叶 Tab；8 层限制生效 |
| 随机树操作 | 100 次合法移动，每一步 I01–I12 成立，Tab/Item 数量及 Profile 恒定 |
| T25 原子性 | 未提交 SQLite 事务在重新打开后不可见；故障写入整笔回滚 |
| T26 错误 | 只读库明确失败；注入 SQLite FULL 后原树完整保留；revision 不匹配拒绝覆盖 |
| T27 迁移 | v1 创建成功；中断 migration 回滚并保留一致性 backup；未来 schema 原样保留并拒绝打开 |
| T28 并发/陈旧写入 | 陈旧 decision 的 expectedRevision 被拒绝，已提交新状态不被覆盖 |

## 4. 明确边界

- M1 不加载真实网页，不实现 M2 的 Sidebar、导航和完整 Space UI。
- `ArcLakeM1` 是启动与恢复骨架，不是可日用浏览器。
- 磁盘满使用受控 `SQLITE_FULL` 故障注入，在部分行写入后验证真实 SQLite 事务回滚。
- 错误恢复页面已实现且 controller recovery 路径有单测；M1 Gate 的 GUI 烟测覆盖正常首次启动和冷启动，不覆盖人为破坏数据库后的视觉操作。

下一阶段为 M2：在已通过的 Workspace/Persistence/AppController 基础上接入真实浏览、Sidebar、命令栏最小版和可重启恢复的 Foundation Demo。
