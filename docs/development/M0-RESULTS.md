# M0 技术验证结果

日期：2026-10-26。状态：**原型已实现，自动化子集通过；M0 完整门槛仍 pending。**

本次不继续逆向 Arc，不安装依赖工具，不读取个人浏览记录，不改变默认浏览器。代码独立编写，只访问本地受控测试站。

## 1. 已交付内容

- Swift Package 工程、5 个纯逻辑 XCTest、1 个 HTTP fixture 契约测试。
- SwiftUI 主界面 + AppKit 主窗口/单实验小窗 + 按逻辑身份持有的 WKWebView。
- A1/A2 → Profile A、B1 → Profile B；每轮生成独立 UUID，写入 JSON 清单后启动网页，跨测试进程复用清单。不是把同一个内存对象误当持久化。
- 两个不同 loopback 端口的 origin：Cookie、HttpOnly Cookie、localStorage、IndexedDB、302、POST、target=_blank、下载端点。
- ad-hoc 签名的 Sandbox `.app`：`dev.arclake.M0Probe`，权限只有 app-sandbox / network.client；不是已公证发行版。
- seed → 正常退出 → verify → 隔离负对照 → 新写入 → 强制结束本轮 App → verify-force-quit → cleanup。

M0 是能力探针：未实现 SQLite 工作区、持久 Tab/Space 模型、正式错误页和完整 11 项 UI。测试中 Profile 身份直接使用 store UUID 是简化，不能据此把产品领域 ID 与存储 ID 永久合并。

## 2. 实际环境和结果

主报告：[20261026T201609-bbb9236b/summary.json](../../test-results/m0/20261026T201609-bbb9236b/summary.json)。

前一次相同核心流程也通过：[20261026T201412-e416e609/summary.json](../../test-results/m0/20261026T201412-e416e609/summary.json)。

- Apple Silicon arm64；macOS 27.0.1；Xcode 27.0 / Swift 6.4。
- Swift Package 与 Mach-O 最低部署目标 14.0；这不等于在 macOS 14 运行过。
- Swift 单测：5/5；Python fixture 测试：1/1；逐轮日志随报告保存。
- 最近一轮非负对照阶段：**39 个 pass 检查点**（seed 25、正常重启 5、强退信号确认 1、强退恢复 5、清理 3）；这些不是 ACCEPTANCE.md 全部用例通过。
- 负对照故意把 B 的运行 store 指向 A：读取到了 A 标记，断言失败且进程返回 1。这是预期结果，证明测试能检出真实串数据，而非只比较 UUID。

| 能力 | 实测结论 | 边界 |
|---|---|---|
| T01 Profile 隔离 | A1/A2 共享；A/B 的四类标记隔离，两 origin 都验证 | 不代表所有网站认证/凭据服务都隔离 |
| T02 正常退出恢复 | 独立进程读取同 UUID、相同测试 origin 的持久数据成功 | 不是仅关窗重开 |
| T02 强退恢复 | 新写入并回读后，只 SIGKILL 本轮 App PID；新进程回读成功 | 不模拟断电、不杀系统服务/其他 App，不承诺尚未确认写入的持久性 |
| T03 实例稳定 | 50 次侧栏 + 50 次主题变化；实测 representable 更新100次，实例/文档/load计数/输入未变化 | 不是只修改一个不影响UI的测试变量 |
| T04 小窗移交 | 同一实例 main → little → main，旧宿主释放；JS计数42、表单、DOM焦点保留 | 原生 responder已观察，但真实键盘/输入法及非零滚动待验证 |
| T05 跨 Profile | 所有权检查拒绝直接移交；显式URL复制产生新身份，使用B存储，不复制表单 | 未实现产品拖拽UI |
| 删除 store | 释放WebView→显式清空网站数据→删除namespace；同UUID重建后四类标记为空 | 当前系统有额外注意事项，见下文；持久pending删除日志留给M1 |
| T29 旧回调 | 旧generation事件被拒绝；当前代终止事件进入可恢复状态，URL重载成功 | 终止事件是注入，不是真实内容进程崩溃 |
| 测试站 | 真实WKWebView跟随302、fetch POST；HTTP契约含popup链接/下载端点 | popup/download原生delegate流程未验收 |

两个 origin 同 host 不同 port；localStorage/IndexedDB 按 origin 分离，**Cookie 不按端口隔离**。测试 Cookie 名含端口，防止两个端点互相覆盖；不能把这里的结果误述为 Cookie 同源端口隔离。

## 3. 本次捕获并处理的问题

### 3.1 SwiftUI 的迟到更新会抢回网页

最初窗口移交后，旧 representable 仍收到 update，再被 dismantle，导致新窗失去网页。失败记录：[初始归属检查](../../test-results/m0/20261026T200451-0fcdfcd8/seed.json)。

修复：BrowserSession 保存逻辑 owner，宿主带 role；mount 前检查 owner。移交先修改 owner，再 detach/attach；旧宿主无权重新挂载。回归测试还主动向旧宿主发送 mount/unmount，保证新窗不被影响。这是运行时归属规则，不靠延迟若干毫秒“等UI稳定”。

### 3.2 冷进程直接删除发生 WebKit 崩溃

只调用静态 `remove(forIdentifier:)` 的清理进程，当前系统出现 SIGSEGV；栈位于 `WebsiteDataStore::removeDataStoreWithIdentifierImpl` 的 run-loop dispatch。

探针现在先创建并释放一个无网页加载的 nonPersistent WebView 初始化 WebKit，再清理本轮具名 stores。清理进程恢复成功。见[脱敏栈摘要](../../test-results/m0/diagnostics/cold-delete-crash.json)。这是**当前环境观察到的兼容性处理**，不是 Apple 文档保证的通用必需步骤；不能据此推断所有系统都有同一缺陷。

### 3.3 释放网页不等于网络进程立即释放 store

弱引用确认 WKWebView 已销毁后，首次删除曾返回：
`WKWebSiteDataStore/1: Data store is in use (by network process)`。

删除采用有界退避（最多10次），记录失败原因与次数；仍失败就报失败并保留清单，不伪装成功。见[相关结果](../../test-results/m0/20261026T201012-47a288ed/seed.json)。产品M1还需要持久 PendingOperation，当前重试器不是其替代品。

### 3.4 只删 namespace，立即复用 UUID 仍读到旧 Cookie

同一进程中，删除API成功后用原UUID重建，localStorage/IndexedDB已空，但Cookie/HttpOnly Cookie仍可读到旧测试值。失败记录同上。此观察不足以断定具体缓存/系统服务根因。

现在先用公开 `removeData(ofTypes: allWebsiteDataTypes(), modifiedSince: .distantPast)` 清空该store的网站数据，再删除store；原断言全部通过。产品仍应为新Profile生成新UUID，不复用已删除UUID；清空和删除都必须在删除状态内进行，禁止新导航写回。

### 3.5 隐藏窗口里的滚动不能冒充真实验证

测试页实际高度大于viewport，但隐藏窗口中 `scrollTo(0,400)` 后 `scrollY` 仍是0。已将非零滚动移交记为 pending，而不是以“移交前后都是0”宣称滚动保持成功。

## 4. 仍未关闭的门槛

1. 可见窗口中滚到非零位置，往返移交并验证；真实点击/键盘输入、中文输入法、焦点恢复。
2. 真实 WebKit 内容进程终止，而非手动调用事件处理函数；不能杀用户其他网页进程来冒充测试。
3. macOS 14 真机/测试机；当前部署目标检查不能替代。
4. 原生 popup/download 的 delegate 路径（测试资源已准备，完整实现属后续阶段）。

因此不把 T04/T29 全部标记为通过，也不将 M0 总门槛标为完成。可以据此继续收敛架构，但在补齐关键验证前，不宣称基础浏览器已完成。

## 5. 复现与安全清理

项目根目录：
```bash
python3 scripts/run_m0.py --test
python3 scripts/run_m0.py --demo
```

运行说明见[项目 README](../../README.md)。每轮保存 `run-config.json`、环境、二进制SHA、阶段JSON/原始stdout/stderr；故障记录保留，不覆盖成成功。最初两轮清理失败的store已用修复后的程序重试清理，对应目录保留 `cleanup-retry.stdout.log`。

演示仅供本地验证；窗口退出后脚本移除该轮测试store。脚本和测试服务没有访问Arc配置目录、默认浏览器设置或真实账号。没有使用私有 WebKit API 或绕过系统证书验证。
