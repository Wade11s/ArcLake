import AppKit
import WebKit
import M0Core

struct BrowserInteractionState: Codable, Equatable {
    let scrollY: Double
    let focusedID: String
}

@MainActor
final class BrowserSession: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
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
    private(set) var terminationEvents = 0
    private(set) var popupRequests = 0
    private(set) var popupFinishedNavigations = 0
    private(set) var lastPopupURL: URL?
    private(set) var lastPopupNavigationType = "none"
    private(set) var lastPopupError: String?
    private(set) var downloadsStarted = 0
    private(set) var downloadsFinished = 0
    private(set) var downloadFailures = 0
    private(set) var lastDownloadPath: URL?
    private(set) var lastDownloadText: String?
    private var popupViews: [WKWebView] = []
    private var activeDownloads: [ObjectIdentifier: WKDownload] = [:]
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]
    private let downloadDirectory: URL

    init(profileID: UUID, downloadDirectory: URL? = nil) {
        identity = BrowserIdentity(profileID: profileID)
        self.downloadDirectory = downloadDirectory
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("ArcLakeM0Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.downloadDirectory,
                                                 withIntermediateDirectories: true)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: profileID)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 780, height: 600), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.autoresizingMask = [.width, .height]
        webView.allowsBackForwardNavigationGestures = true
    }

    func load(_ url: URL) {
        guard !isReleased else { return }
        lastError = nil; state = "loading"; requestedLoads += 1
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !isReleased else { return }
        if webView === self.webView {
            finishedNavigations += 1; state = "ready"
        } else if popupViews.contains(where: { $0 === webView }) {
            popupFinishedNavigations += 1
            lastPopupURL = webView.url
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationFailed(webView, error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationFailed(webView, error)
    }

    private func navigationFailed(_ failedView: WKWebView, _ error: Error) {
        guard !isReleased else { return }
        if failedView === webView {
            lastError = error.localizedDescription; state = "failed"
        } else {
            lastPopupError = error.localizedDescription
        }
    }

    func webViewWebContentProcessDidTerminate(_ failedView: WKWebView) {
        guard !isReleased, failedView === webView else { return }
        terminationEvents += 1
        state = "process-terminated"
        lastError = "Web content process ended; reload to recover."
    }

    // Synthetic events exercise generation checks independently from the real
    // WebKit termination test below.
    func receiveTermination(for event: BrowserIdentity) {
        guard !isReleased, identity.accepts(event) else { droppedEvents += 1; return }
        state = "process-terminated"; lastError = "Web content process ended; reload to recover."
    }

    func webProcessIdentifierForProbe() -> Int? {
        let selector = NSSelectorFromString("_webProcessIdentifier")
        guard webView.responds(to: selector) else { return nil }
        return (webView.value(forKey: "_webProcessIdentifier") as? NSNumber)?.intValue
    }

    func captureInteractionState() async throws -> BrowserInteractionState {
        let value = try await javascript("""
        const focused = document.activeElement;
        return JSON.stringify({
          scrollY: window.scrollY,
          focusedID: focused && focused.id ? focused.id : ''
        });
        """)
        return try JSONDecoder().decode(BrowserInteractionState.self, from: Data(value.utf8))
    }

    func restoreInteractionState(_ state: BrowserInteractionState) async throws {
        _ = try await javascript("""
        const focused = focusedID ? document.getElementById(focusedID) : null;
        if (focused) focused.focus({preventScroll:true});
        window.scrollTo(0, scrollY);
        return 'ok';
        """, arguments: ["scrollY": state.scrollY, "focusedID": state.focusedID])
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard !isReleased, webView === self.webView, popupViews.count < 4 else { return nil }
        popupRequests += 1
        lastPopupNavigationType = String(describing: navigationAction.navigationType)
        let popup = WKWebView(frame: NSRect(x: 0, y: 0, width: 640, height: 480),
                              configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popupViews.append(popup)
        return popup
    }

    func webViewDidClose(_ closedView: WKWebView) {
        guard closedView !== webView else { return }
        popupViews.removeAll { $0 === closedView }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        guard !isReleased else { return .cancel }
        if let response = navigationResponse.response as? HTTPURLResponse,
           response.value(forHTTPHeaderField: "Content-Disposition")?
            .lowercased().contains("attachment") == true {
            return .download
        }
        return .allow
    }

    func webView(_ webView: WKWebView,
                 navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        track(download)
    }

    func webView(_ webView: WKWebView,
                 navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        track(download)
    }

    private func track(_ download: WKDownload) {
        guard !isReleased else { return }
        download.delegate = self
        activeDownloads[ObjectIdentifier(download)] = download
        downloadsStarted += 1
    }

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String) async -> URL? {
        let suggested = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        let safeName = suggested.isEmpty ? "download" : suggested
        let destination = downloadDirectory
            .appendingPathComponent(UUID().uuidString + "-" + safeName, isDirectory: false)
        downloadDestinations[ObjectIdentifier(download)] = destination
        return destination
    }

    func downloadDidFinish(_ download: WKDownload) {
        downloadsFinished += 1
        let key = ObjectIdentifier(download)
        if let path = downloadDestinations[key] {
            lastDownloadPath = path
            lastDownloadText = try? String(contentsOf: path, encoding: .utf8)
        }
        activeDownloads.removeValue(forKey: key)
    }

    func download(_ download: WKDownload,
                  didFailWithError error: Error,
                  resumeData: Data?) {
        downloadFailures += 1
        lastError = error.localizedDescription
        activeDownloads.removeValue(forKey: ObjectIdentifier(download))
    }

    func detach() { host?.unmount() }

    func releaseRuntime() {
        guard !isReleased else { return }
        isReleased = true
        detach()
        for popup in popupViews {
            popup.stopLoading()
            popup.navigationDelegate = nil
            popup.uiDelegate = nil
        }
        popupViews.removeAll()
        for download in activeDownloads.values { download.delegate = nil }
        activeDownloads.removeAll()
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
