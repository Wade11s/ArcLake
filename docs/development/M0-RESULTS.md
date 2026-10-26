# M0 技术验证结果

日期：2026-10-26。状态：**M0 Gate 已在最低系统基线 macOS 27 上通过。**

本探针不继续逆向 Arc，不安装依赖工具，不读取个人浏览记录，不改变默认浏览器。代码独立编写，只访问本地受控测试站。

## 1. 已交付内容

- Swift Package 工程、5 个纯逻辑 XCTest、1 个 HTTP fixture 契约测试。
- SwiftUI + AppKit 主窗口、单实验 Little Window，以及按逻辑身份持有的稳定 `WKWebView`。
- A1/A2 → Profile A，B1 → Profile B；每轮生成独立 UUID，跨测试进程复用同一清单。
- 两个 loopback origin：Cookie、HttpOnly Cookie、localStorage、IndexedDB、302、原生 HTML form POST、target=_blank 与下载。
- `WKUIDelegate` 创建并加载弹窗；`WKDownload` 写入选定探针路径并校验文件内容。
- 可见测试窗口：非零滚动、AppKit keyDown/keyUp、DOM focus、主窗 → 小窗 → 主窗往返。
- 独立强退阶段：只对本轮 App PID 发送 `SIGKILL`，新进程回读持久 store。
- 独立 WebContent 崩溃阶段：测试编排器校验 PID 命令名为 `WebKit.WebContent` 后发送 `SIGKILL`，验证真实终止 delegate 和新 PID 重载。
- ad-hoc 签名的 Sandbox `.app`：`dev.arclake.M0Probe`，权限只有 app-sandbox / network.client；不是已公证发行版。

M0 仍是能力探针：没有 SQLite 工作区、持久 Tab/Space 模型、正式错误页和完整 11 项产品 UI。测试中 Profile 身份直接使用 store UUID 是简化，不能据此把产品领域 ID 与存储 ID 永久合并。

## 2. 实际结果

最近通过轮次见 [latest.json](../../test-results/m0/latest.json)，逐阶段报告保存在同目录。

环境：Apple Silicon arm64；macOS 27.0.1；Xcode 27.0 / Swift 6.4。`Package.swift` 使用 Swift tools 6.4、`.macOS(.v27)` 与 Swift 6 语言模式；全部 Apple 框架来自当前 macOS 27 SDK，没有旧系统兼容分支或第三方包。

- Swift 单测：5/5；Python fixture 测试：1/1。
- 正向阶段共 **50 个 pass 检查点**：seed 34、正常重启 5、强退信号确认 1、强退恢复 5、真实 WebContent 崩溃 2、清理 3，pending 为 0。
- 负对照故意把 B 的运行 store 指向 A，读取到 A 标记后按预期失败并返回 1，证明隔离测试能检出真实串数据。
- `seed` 阶段的 `minimum-macOS27-runtime` 通过，没有 pending 检查点；M0 Gate 可标记完成。

| 能力 | 实测结论 |
|---|---|
| T01 Profile 隔离 | A1/A2 共享；A/B 的四类标记在两个 origin 上隔离 |
| T02 正常退出恢复 | 独立进程复用相同 UUID 并读回持久数据 |
| T02 强退恢复 | 确认写入后仅 SIGKILL 本轮 App PID；新进程读回成功 |
| T03 实例稳定 | 50 次侧栏 + 50 次主题变化，实例/文档/load 计数/输入均不变 |
| T04 小窗移交 | 同一实例 main → little → main；JS 内存、表单、非零滚动、DOM 焦点和键盘路径保持 |
| T05 跨 Profile | 直接移交被拒绝；显式 URL 复制使用目标 store，不复制表单 |
| 网页能力 | 302、原生 form POST、target=_blank、原生下载、AppKit 键盘事件均通过 |
| T29 旧回调 | 旧 generation 被拒绝；注入终止态可重载 |
| T29 真实进程终止 | WebContent `SIGKILL` 触发终止 delegate；重载后内容进程 PID 改变且页面可用 |
| 删除 store | 释放 WebView → 清空网站数据 → 删除 namespace；重建后四类标记为空 |

两个 origin 同 host 不同 port；localStorage/IndexedDB 按 origin 分离，**Cookie 不按端口隔离**。测试 Cookie 名含端口，防止两个端点互相覆盖。

## 3. 本次捕获并处理的问题

### 3.1 SwiftUI 的迟到更新会抢回网页

窗口移交后，旧 representable 仍可能收到 update，再被 dismantle，导致新窗失去网页。方案在 BrowserSession 保存逻辑 owner，宿主带 role；mount 前检查 owner。移交先更新 owner，再 detach/attach。回归测试主动向旧宿主发送 mount/unmount，确认新窗不被影响。

### 3.2 Reparent 会重置滚动与 DOM 焦点

同一个 `WKWebView` 跨窗口重挂载后，JS 内存、文档实例和表单值保持，但 WebKit 会把 `scrollY` 和 DOM 焦点重置。M0 在目标 host 完成布局后捕获并恢复 `scrollY`/焦点，重试至稳定；产品窗口移交必须包含这一步，不能只检查实例 identity。

### 3.3 冷进程直接删除发生 WebKit 崩溃

清理进程只调用静态 `remove(forIdentifier:)` 时，当前系统在 `WebsiteDataStore::removeDataStoreWithIdentifierImpl` 的 run-loop dispatch 中 SIGSEGV。探针先创建并释放一个无网页加载的 nonPersistent WebView 初始化 WebKit，再清理具名 store。该处理是当前环境观察，不是 Apple 文档保证的通用必需步骤。

### 3.4 释放网页不等于网络进程立即释放 store

弱引用确认 WKWebView 已销毁后，首次删除仍可能返回 `Data store is in use (by network process)`。删除采用有界退避并记录原因；失败不伪装成功。产品 M1 仍需持久 `PendingOperation`。

### 3.5 只删 namespace 后立即复用 UUID 会残留 Cookie

同进程删除 API 成功后立即用原 UUID 重建，localStorage/IndexedDB 为空，但 Cookie/HttpOnly Cookie 仍可读到旧值。当前探针先清空 `allWebsiteDataTypes()` 再删除。产品仍应为新 Profile 生成新 UUID，禁止复用已删除 UUID。

## 4. M0 结论与下一阶段

M0 的能力方向成立：具名持久 store、稳定 WebView 注册表、窗口移交和真实进程终止均可在 macOS 27 基线上支撑后续产品实现。M0 不是产品应用，下一阶段从 M1 的领域模型、SQLite schema、事务和命令骨架开始。

中文输入法组合不是 M0 门槛，属于后续 M6/T24 验收。当前 M0 已覆盖真实 AppKit keyDown/keyUp 路径与 first responder。

## 5. 复现与清理

```bash
python3 scripts/run_m0.py --test
python3 scripts/run_m0.py --test --require-minimum-os
python3 scripts/run_m0.py --demo
```

每轮保存 `run-config.json`、环境、二进制 SHA、阶段 JSON、原始 stdout/stderr 和下载文件。故障记录保留，不覆盖成成功。强退测试只杀本轮 App PID；WebContent 测试先校验 PID 命令名，再只杀本轮内容进程。脚本没有访问 Arc 配置目录、默认浏览器设置或真实账号。
