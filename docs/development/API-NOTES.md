# 技术依据、API 核实与限制

核实方式：Context7 查询 Apple 官方 WebKit/SwiftUI 文档 + 本机最新 macOS 27 SDK 头文件 + macOS 27 部署目标的类型检查。项目不维护旧 SDK 兼容分支。**API 存在/可编译不等于运行行为已验收。**

## 1. 多 Profile 的可行基础

Apple 文档：
- [WKWebsiteDataStore](https://developer.apple.com/documentation/webkit/wkwebsitedatastore)
- [init(forIdentifier:)](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/init%28foridentifier%3A%29)
- [remove(forIdentifier:completionHandler:)](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/remove%28foridentifier%3Acompletionhandler%3A%29)

核实结论：
1. `WKWebsiteDataStore(forIdentifier: UUID)` 从 **macOS 14.0** 可用，返回该标识的持久 store，不存在时创建。ArcLake 当前最低系统为 macOS 27.0，因此直接使用该 API。零 UUID 不合法。
2. 创建 WKWebView **之前**把 store 赋给 `WKWebViewConfiguration.websiteDataStore`。
3. `.default()` 是默认持久 store，不用它承载所有 Profile。
4. `.nonPersistent()` 是非持久存储，不满足“重启仍保持 Profile 登录”的需求。
5. `remove(forIdentifier:)` 有 async throws 形式；必须先释放使用该 store 的 WKWebView；删除可失败，需重试与可见状态。
6. store 管理 Cookie/网站数据，不替代 ArcLake 自己的 History/Archive/Favorites 数据模型，也不是 OS 用户隔离证明。

SDK 交叉核实文件：
`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/WebKit.framework/Headers/WKWebsiteDataStore.h`

其中 `dataStoreForIdentifier:` / `removeDataStoreForIdentifier:` / `identifier` 均标注 macOS(14.0)，明确要求先释放 WebView，再删除 store。

## 2. 不使用 WKProcessPool 假冒隔离

SDK `WKWebViewConfiguration.h` 对 processPool 标注：
> Creating and using multiple instances of WKProcessPool no longer has any effect.

因此不采用“一个 Profile 一个 processPool，所以已经隔离”的方案。使用具名 data store，并对 Cookie/localStorage/IndexedDB 做 M0 实测。

同一头文件 webExtensionController 的可用系统高于本方案最低系统；且 WebKit extension controller 不能直接等价为完整 Chrome 扩展兼容。扩展不属于首版承诺。

## 3. SwiftUI 和 AppKit 的生命周期

Apple 文档：
- [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)
- [makeNSView(context:)](https://developer.apple.com/documentation/swiftui/nsviewrepresentable/makensview%28context%3A%29)
- [dismantleNSView(_:coordinator:)](https://developer.apple.com/documentation/swiftui/nsviewrepresentable/dismantlensview%28_%3Acoordinator%3A%29-21agq)

makeNSView 创建该次 representable 实例的 AppKit 视图，后续更新走 updateNSView，移除走 dismantleNSView。SwiftUI 的 identity 改变仍会重建 representable，所以不能将“make只调用一次”错误理解为应用生命周期里只会创建一次网页。

方案：独立 Browsing registry 持有网页实例；representable 只持有可替换宿主。update 不无条件 load；dismantle 解除挂载，不直接删除 Tab。主线程/actor 规则由 Swift 6 编译检查与运行测试一起保证。

## 4. 已执行的编译验证

示例：[API-PROBE.swift](API-PROBE.swift)，结果：[API-PROBE-result.txt](API-PROBE-result.txt)。

执行命令：
```bash
xcrun swiftc -typecheck -swift-version 6 \
  -target arm64-apple-macos27.0 docs/development/API-PROBE.swift
```

结果：成功，未执行任何网页加载、store 创建/删除或 UI 操作。仅证明这些 Swift 导入名、actor 标注和最低部署目标能通过当前工具链检查。

本次工具链：Xcode 27.0（27A266a），Apple Swift 6.4。`Package.swift` 使用 Swift tools 6.4、`.macOS(.v27)` 与 Swift 6 语言模式；ArcLake 最低系统为 macOS 27.0，当前验证环境是 macOS 27.0.1。

## 5. M0 运行验证与剩余项

已有独立 Sandbox/ad-hoc 应用的真实运行记录，见 [M0 实测报告](M0-RESULTS.md)。上文 API-PROBE 仍只是编译探针，不能与新建的运行应用混为一谈。

- 在最低系统基线 macOS 27 上，具名 store 的 Cookie/HttpOnly Cookie/localStorage/IndexedDB 隔离、正常退出、强退保持、删除与负对照已通过；发行签名环境仍待测。
- WKWebView reparent 的实例、表单、JS 内存、可见窗口非零滚动、DOM 焦点和 AppKit 键盘路径已通过。Reparent 本身会重置滚动与 DOM 焦点，因此应用必须在目标 host 完成布局后显式恢复；中文输入法属于后续 T24，不是 M0 的明确门槛。
- 删除测试发现冷调用崩溃、网络进程短暂占用和即时同UUID复用的Cookie残留；当前探针初始化WebKit、显式清空网站数据、有界重试后通过，不能省略失败恢复设计。
- 清空数据 API：[removeData(ofTypes:modifiedSince:)](https://developer.apple.com/documentation/webkit/wkwebsitedatastore/removedata%28oftypes%3Amodifiedsince%3Acompletionhandler%3A%29)，使用 `WKWebsiteDataStore.allWebsiteDataTypes()` 和 `.distantPast`。
- 当前系统已验证原生 HTML form POST、`WKUIDelegate` target=_blank、`WKDownload` 附件写入及真实 WebContent `SIGKILL` 的终止/重载回调。文件选择、权限、取消/失败下载与更完整下载管理仍在后续阶段。
- WebKit 进程终止无法由公开 API 主动制造；M0 测试编排器读取 WebView 的测试进程 PID，校验其命令名为 `WebKit.WebContent` 后发送 `SIGKILL`。该读取仅用于探针，不进入产品路径。
- WebKit 的网站兼容、媒体/DRM、WebAuthn/通行密钥、系统认证等不因静态 API 可用而得到保证。
- 系统 HTTP(S) 默认浏览器注册与实际 URL 事件；不以不必要的辅助功能权限作为普通应用运行前提。

需要辅助功能/录屏权限的是外部 GUI 测试工具，不是为了让用户运行 ArcLake 而申请这些权限。

## 6. 证据使用边界

Context7 使用 `/websites/developer_apple_webkit` 与 `/websites/developer_apple_swiftui`；SDK 是本地工具链的实际声明。实施时仍要以所选 SDK、最低系统 availability 与构建结果为准。

Arc 的原生数据结构和 selector 可以启发设计，但不能推出 WebKit 必然支持 Chromium 的全部能力。应用代码独立编写，不链接 ArcCore.framework，不复制 Arc 编译资源，不继续使用已卸载的 Hopper。
