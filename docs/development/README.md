# ArcLake macOS 开发文档与复现方案

状态：**v1.2：M0、M1、M2 Gate 均已通过；进入 M3 Archive/Library。**

目标：用 SwiftUI + AppKit + WebKit 独立实现 Arc 的基础组织方式与浏览交互，而非复制 Arc 内核、品牌或全部历史功能。分析对象仅 macOS；不开展 Windows 复现。

## 文档导航

1. [功能规格 SPEC.md](SPEC.md)：11 项功能、确定的产品规则、冲突处理、首版范围。
2. [实现方案 ARCHITECTURE.md](ARCHITECTURE.md)：模型、不变量、模块 Interface、WebKit 生命周期、隔离与持久化。
3. [实施计划 ROADMAP.md](ROADMAP.md)：阶段、依赖、技术验证和每阶段交付门槛。
4. [验收方案 ACCEPTANCE.md](ACCEPTANCE.md)：可重复的场景与失败判定。
5. [技术核实 API-NOTES.md](API-NOTES.md)：Apple 文档、当前 SDK 核实结果与限制。
6. [M0 实测报告](M0-RESULTS.md)：通过项目、真实失败与修复、待验证门槛；[运行原型](../../README.md)。
7. [M1 实施结果](M1-RESULTS.md)：领域模型、I01–I12、SQLite schema v1、迁移与启动恢复。
8. [M2 实施结果](M2-RESULTS.md)：真实浏览、Sidebar、Space/Profile、拖拽与命令栏。
9. [领域词汇](../../GLOSSARY.md)；[平台/内核决策](../adr/0001-macos-webkit-shell.md)。

## 证据与规格的关系

- [首轮证据](../../evidence/arc/README.md)：菜单、快捷键、发行物文案。
- [无 Hopper 分析](../../evidence/arc/no-hopper/README.md)：方法入口、Swift 结构、官方规则。
- 证据描述“发现了什么”；本目录规定“ArcLake 要做什么”。遇到差异，以本目录明确列出的设计决定为 ArcLake 的验收标准，不能反向宣称 Arc 就这样实现。

标记：**[E]** 发行物静态证据；**[O]** 官方说明/历史发布记录；**[D]** ArcLake 的设计决定；**[V]** 实施前必须验证的可行性。未经运行验证的 E/O 不是实测证明。

## 推荐默认值（均可评审，不是隐藏前提）

| 项目 | 基线 |
|---|---|
| 产品名 | ArcLake；独立图标、配色与资源 |
| 最低系统 | macOS 27.0；Apple Silicon 优先验证，Intel 不作首轮交付承诺 |
| 工具链 | Xcode 27 / Swift 6.4；SwiftUI、AppKit、WebKit、Foundation、SQLite 使用 macOS 27 SDK 系统版本，不保留旧系统兼容分支 |
| 技术 | SwiftUI + AppKit + WKWebView；不用 Hopper，不依赖 Arc 私有框架，无第三方 Swift 包 |
| 窗口范围 | 首版一个主窗口 + 多个 Little Window；多个主窗口及 Tab Handoff 后续再做 |
| 网站数据 | 每个 Profile 一个独立、稳定 UUID 的持久 WebKit data store |
| 本地元数据 | SQLite 单写者事务；不存 Cookie、密码、网页正文 |
| 联网 | 页面加载、用户明确提交的搜索和下载；无账号系统、云同步、遥测 |
| 发布形态 | 首版开发构建；发布签名、公证、默认浏览器注册另设验收 |

## 交付层次

- **Foundation Demo（M0–M2）**：真实网页 + Profile 隔离 + 数据模型 + 标签/Space/固定/收藏/文件夹，可重启恢复。不是 11 项全部完成。
- **基础功能版（M0–M5）**：11 项均有明确实现范围；分屏、小窗口、命令栏、路由、归档可操作。
- **候选发布版（M6）**：崩溃恢复、权限、下载、隔离回归、可访问性和分发检查通过。

主动简化：文件夹分享先做本地 URL 清单导出/导入，不提供公网分享链接；Favorites 首版只容纳独立的单 Tab 条目、不能嵌套 Folder/Split，但可以有多个；不实现 Chrome 扩展、Peek、云同步、AI 功能。完整范围表见 SPEC。

## 建议马上做的工作

M0 已通过浏览器能力验证，M1 完成了领域/持久化/命令骨架，M2 已完成真实 WebKit 浏览、Sidebar、Space/Profile 管理、Favorites/Pinned/Folder、拖拽、跨 Profile 复制和统一命令栏。下一阶段为 M3：Auto Archive、Library、Profile-scoped History 和完整命令搜索。详见 [M2 报告](M2-RESULTS.md)。
