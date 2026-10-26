// Documentation-only compile probe. Not an application implementation.
// Never executed; checks Swift import names at the macOS 27 deployment target.
import AppKit
import SwiftUI
import WebKit

@MainActor
func makeProfileWebView(storeID: UUID) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: storeID)
    return WKWebView(frame: .zero, configuration: configuration)
}

@MainActor
func removeUnusedProfileStore(storeID: UUID) async throws {
    // Caller MUST first release all WKWebViews that use this store.
    try await WKWebsiteDataStore.remove(forIdentifier: storeID)
}

struct BrowserHostProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {}
}
