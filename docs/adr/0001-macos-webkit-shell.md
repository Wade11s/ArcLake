---
status: accepted
---

# macOS 27+，SwiftUI 界面，AppKit 窗口，WebKit 网页承载

ArcLake 首版采用 SwiftUI + AppKit + WKWebView，最低 macOS 27.0，工具链为 Xcode 27 / Swift 6.4。Apple 的具名持久 WKWebsiteDataStore 从 macOS 14 开始可用，适合以稳定 UUID 绑定 Profile；当前基线直接使用该系统能力，并以 macOS 27.0.1 完成 M0 运行验证。SwiftUI 负责产品界面，AppKit 管理窗口、焦点与 WKWebView 挂载。

没有选择 Chromium/CEF：首版目标是复现组织与交互，不是维护另一套浏览器内核及 Chrome 扩展宿主。代价是网站兼容、扩展、密码填充和部分网页能力不与 Arc 等价。项目始终链接当前 macOS 27 SDK 的系统 SwiftUI/AppKit/WebKit/Foundation/SQLite，不引入旧版本替代包，但仍以实际运行验收为准。

该决定由用户确认：开发机为 macOS 27.0.1，产品最低系统按 macOS 27 执行。若未来需要支持更早系统或 Chrome 扩展，需要重新评估平台和 WebKit 能力边界。详细 API 依据见 [技术核实](../development/API-NOTES.md)。
