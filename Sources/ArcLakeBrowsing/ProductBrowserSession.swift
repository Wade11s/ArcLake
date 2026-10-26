import AppKit
import ArcLakeCore
import WebKit

@MainActor
public final class ProductBrowserSession: NSObject, WKNavigationDelegate, WKUIDelegate {
  public let identity: BrowserIdentity
  public let webView: WKWebView
  public private(set) var state: BrowserLoadState = .idle
  public private(set) var lastError: String?
  public private(set) var title: String?
  public private(set) var currentURL: URL?
  public private(set) var isReleased = false

  private let onEvent: @MainActor (BrowserEvent) -> Void
  private let onNewWindow: @MainActor (URL) -> Void
  private var titleObservation: NSKeyValueObservation?

  public init(
    identity: BrowserIdentity,
    onEvent: @escaping @MainActor (BrowserEvent) -> Void,
    onNewWindow: @escaping @MainActor (URL) -> Void
  ) {
    self.identity = identity
    self.onEvent = onEvent
    self.onNewWindow = onNewWindow

    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = WKWebsiteDataStore(
      forIdentifier: identity.websiteStoreID)
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    webView = WKWebView(
      frame: NSRect(x: 0, y: 0, width: 960, height: 700),
      configuration: configuration)
    super.init()
    webView.navigationDelegate = self
    webView.uiDelegate = self
    webView.allowsBackForwardNavigationGestures = true
    webView.autoresizingMask = [.width, .height]
    titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, change in
      Task { @MainActor in
        self?.updateTitle(change.newValue ?? nil)
      }
    }
  }

  public var canGoBack: Bool { webView.canGoBack }
  public var canGoForward: Bool { webView.canGoForward }
  public var estimatedProgress: Double { webView.estimatedProgress }

  public func navigate(to url: URL) {
    guard !isReleased, Self.isSafeWebURL(url) else { return }
    if state == .ready, webView.url?.absoluteString == url.absoluteString {
      return
    }
    lastError = nil
    state = .loading
    webView.load(URLRequest(url: url))
  }

  public func reload() {
    guard !isReleased else { return }
    lastError = nil
    state = .loading
    webView.reload()
  }

  public func goBack() {
    guard !isReleased, webView.canGoBack else { return }
    webView.goBack()
  }

  public func goForward() {
    guard !isReleased, webView.canGoForward else { return }
    webView.goForward()
  }

  public func stop() {
    webView.stopLoading()
  }

  public func release() {
    guard !isReleased else { return }
    isReleased = true
    webView.stopLoading()
    webView.navigationDelegate = nil
    webView.uiDelegate = nil
    webView.removeFromSuperview()
    titleObservation?.invalidate()
    titleObservation = nil
    state = .idle
  }

  public func webView(
    _ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!
  ) {
    guard !isReleased else { return }
    state = .loading
    emit(.navigationStarted(url: webView.url))
    emitHistoryState()
  }

  public func webView(
    _ webView: WKWebView, didCommit navigation: WKNavigation!
  ) {
    guard !isReleased else { return }
    currentURL = webView.url
    updateTitle(webView.title)
    emit(.navigationCommitted(url: webView.url, title: webView.title))
  }

  public func webView(
    _ webView: WKWebView, didFinish navigation: WKNavigation!
  ) {
    guard !isReleased else { return }
    state = .ready
    lastError = nil
    currentURL = webView.url
    updateTitle(webView.title)
    guard let url = webView.url else { return }
    emit(.navigationFinished(url: url, title: webView.title))
    emitHistoryState()
  }

  public func webView(
    _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
  ) {
    fail(error)
  }

  public func webView(
    _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    fail(error)
  }

  public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
    guard !isReleased else { return }
    state = .failed("Web content process ended")
    lastError = "Web content process ended"
    emit(.processTerminated(message: lastError ?? "Web content process ended"))
  }

  public func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction
  ) async -> WKNavigationActionPolicy {
    guard !isReleased else { return .cancel }
    guard let url = navigationAction.request.url else { return .cancel }
    guard Self.isSafeWebURL(url) else {
      failMessage("Blocked non-HTTP(S) navigation")
      return .cancel
    }
    return .allow
  }

  public func webView(
    _ webView: WKWebView,
    didReceive challenge: URLAuthenticationChallenge
  ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    (.performDefaultHandling, nil)
  }

  public func webView(
    _ webView: WKWebView,
    createWebViewWith configuration: WKWebViewConfiguration,
    for navigationAction: WKNavigationAction,
    windowFeatures: WKWindowFeatures
  ) -> WKWebView? {
    guard !isReleased, let url = navigationAction.request.url,
      Self.isSafeWebURL(url)
    else { return nil }
    onNewWindow(url)
    return nil
  }

  public func webView(
    _ webView: WKWebView,
    runJavaScriptAlertPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo
  ) async {
    let alert = NSAlert()
    alert.messageText = webView.url?.host ?? "Website"
    alert.informativeText = message
    alert.runModal()
  }

  public func webView(
    _ webView: WKWebView,
    runJavaScriptConfirmPanelWithMessage message: String,
    initiatedByFrame frame: WKFrameInfo
  ) async -> Bool {
    let alert = NSAlert()
    alert.messageText = webView.url?.host ?? "Website"
    alert.informativeText = message
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
  }

  public func webView(
    _ webView: WKWebView,
    runJavaScriptTextInputPanelWithPrompt prompt: String,
    defaultText: String?,
    initiatedByFrame frame: WKFrameInfo
  ) async -> String? {
    let alert = NSAlert()
    alert.messageText = webView.url?.host ?? "Website"
    alert.informativeText = prompt
    let field = NSTextField(string: defaultText ?? "")
    field.frame = NSRect(x: 0, y: 0, width: 320, height: 24)
    alert.accessoryView = field
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    guard alert.runModal() == .alertFirstButtonReturn else { return nil }
    return field.stringValue
  }

  private func fail(_ error: Error) {
    guard !isReleased else { return }
    let nsError = error as NSError
    if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
      return
    }
    failMessage(error.localizedDescription)
  }

  private func failMessage(_ message: String) {
    state = .failed(message)
    lastError = message
    emit(.navigationFailed(url: webView.url, message: message))
  }

  private func emit(_ kind: BrowserEventKind) {
    onEvent(BrowserEvent(identity: identity, kind: kind))
  }

  private func emitHistoryState() {
    emit(
      .historyStateChanged(
        canGoBack: webView.canGoBack,
        canGoForward: webView.canGoForward))
  }

  private func updateTitle(_ next: String?) {
    guard !isReleased else { return }
    guard title != next else { return }
    title = next
    emit(.titleChanged(next))
  }

  private static func isSafeWebURL(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
  }
}
