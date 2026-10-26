import AppKit
import WebKit
import M0Core

@MainActor
final class BrowserSession: NSObject, WKNavigationDelegate {
    let identity: BrowserIdentity
    let webView: WKWebView
    enum Owner { case main, little }
    var owner: Owner = .main
    weak var host: BrowserHostView?
    private(set) var finishedNavigations = 0
    private(set) var requestedLoads = 0
    private(set) var state = "created"
    private(set) var lastError: String?
    private(set) var droppedEvents = 0
    private(set) var isReleased = false

    init(profileID: UUID) {
        identity = BrowserIdentity(profileID: profileID)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: profileID)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 780, height: 600), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]
        webView.allowsBackForwardNavigationGestures = true
    }

    func load(_ url: URL) {
        guard !isReleased else { return }
        lastError = nil; state = "loading"; requestedLoads += 1
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isReleased, webView === self.webView else { return }
        finishedNavigations += 1; state = "ready"
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationFailed(error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationFailed(error)
    }
    private func navigationFailed(_ error: Error) {
        guard !isReleased else { return }
        lastError = error.localizedDescription; state = "failed"
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        receiveTermination(for: identity)
    }
    // Same boundary is exercised with synthetic events; this is not a real process-kill test.
    func receiveTermination(for event: BrowserIdentity) {
        guard !isReleased, identity.accepts(event) else { droppedEvents += 1; return }
        state = "process-terminated"; lastError = "Web content process ended; reload to recover."
    }

    func detach() { host?.unmount() }
    func releaseRuntime() {
        guard !isReleased else { return }
        isReleased = true
        detach()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        state = "released"
    }

    func javascript(_ body: String, arguments: [String: Any] = [:]) async throws -> String {
        // The continuation carries only String across concurrency boundaries, never Any.
        try await withCheckedThrowingContinuation { continuation in
            webView.callAsyncJavaScript(body, arguments: arguments, in: nil, in: .page) { result in
                switch result {
                case .success(let value):
                    guard let string = value as? String else {
                        continuation.resume(throwing: ProbeFailure("JavaScript probe must return a JSON string")); return
                    }
                    continuation.resume(returning: string)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }
}

@MainActor
final class BrowserHostView: NSView {
    private(set) var session: BrowserSession?
    private(set) var updates = 0
    var role: BrowserSession.Owner = .main

    func mount(_ next: BrowserSession) {
        // SwiftUI may deliver a final update before dismantling an old host.
        // Logical ownership, not view update order, authorizes attachment.
        guard !next.isReleased, next.owner == role else { return }
        updates += 1
        guard session !== next || next.webView.superview !== self else { return }
        unmount()
        next.detach()
        session = next; next.host = self
        next.webView.frame = bounds
        addSubview(next.webView)
    }
    func unmount() {
        if let current = session, current.host === self {
            current.webView.removeFromSuperview()
            current.host = nil
        }
        session = nil
    }
}

struct ProbeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
