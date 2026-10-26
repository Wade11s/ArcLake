---
status: proposed
---

# macOS 14+，SwiftUI 界面，AppKit 窗口，WebKit 网页承载

ArcLake 首版采用 SwiftUI + AppKit + WKWebView，最低 macOS 14.0。Apple 的具名持久 WKWebsiteDataStore 从 macOS 14 开始可用，适合以稳定 UUID 绑定 Profile；这比兼容更老系统时拼接 Cookie 或依赖进程池隔离更可靠。SwiftUI 负责产品界面，AppKit 管理窗口、焦点与 WKWebView 挂载。

没有选择 Chromium/CEF：首版目标是复现组织与交互，不是维护另一套浏览器内核及 Chrome 扩展宿主。代价是网站兼容、扩展、密码填充和部分网页能力不与 Arc 等价。也没有选择只用较新的 SwiftUI WebView API：不应为了界面包装提高 macOS 14 的最低系统要求。

该决定是开发基线建议，不是用户已经确认的发布系统范围；若必须支持 macOS 13 或 Chrome 扩展，需要在实施前重新评估。详细 API 依据见 [技术核实](../development/API-NOTES.md)。
