import Foundation
import Testing
import WebKit

@testable import ArcLakeBrowsing
@testable import ArcLakeCore

@MainActor
@Suite("Product browsing")
struct ProductBrowserTests {
  @Test("Real WKWebView loads, navigates back and reports failure")
  func realWebViewNavigationAndFailure() async throws {
    let fixture = try await LocalFixtureProcess()
    defer { fixture.stop() }
    let log = BrowserEventLog()
    var openedURLs: [URL] = []
    let session = ProductBrowserSession(
      identity: identity(store: UUID()),
      onEvent: { log.events.append($0) },
      onNewWindow: { openedURLs.append($0) })
    defer { session.release() }

    session.navigate(to: fixture.url(path: "page", query: "one"))
    try await waitUntil("first page") {
      session.state == .ready && session.currentURL?.query == "case=one"
        && session.title == "ArcLake M0 local fixture"
    }
    #expect(session.title == "ArcLake M0 local fixture")
    #expect(
      log.events.contains { event in
        if case .navigationFinished = event.kind { return true }
        return false
      })
    _ = try await javaScriptString(
      "document.getElementById('blank').click(); return 'ok';",
      in: session.webView)
    try await waitUntil("target blank callback") { !openedURLs.isEmpty }
    #expect(openedURLs.first?.path == "/page")

    session.navigate(to: fixture.url(path: "page", query: "two"))
    try await waitUntil("second page") {
      session.state == .ready && session.currentURL?.query == "case=two"
    }
    #expect(session.canGoBack)
    session.goBack()
    try await waitUntil("back navigation") {
      session.state == .ready && session.currentURL?.query == "case=one"
    }

    session.navigate(to: URL(string: "http://127.0.0.1:1/")!)
    try await waitUntil("navigation failure", seconds: 15) {
      if case .failed = session.state { return true }
      return false
    }
    #expect(session.lastError != nil)
  }

  @Test("T03 stable coordinator reuses WebView without reloading")
  func coordinatorReusesWebView() async throws {
    let fixture = try await LocalFixtureProcess()
    defer { fixture.stop() }
    let coordinator = BrowserCoordinator()
    let identity = identity(store: UUID())
    await coordinator.apply(
      .loadTab(identity, fixture.url(path: "page", query: "stable")))
    try await waitUntil("coordinator ready") {
      coordinator.session(for: identity.tabID)?.state == .ready
    }
    let firstView = try #require(coordinator.webView(for: identity.tabID))
    _ = try await javaScriptString(
      "window.arcLakeStableCount = (window.arcLakeStableCount ?? 0) + 1; return 'ok';",
      in: firstView)

    await coordinator.apply(.spaceChanged(SpaceID()))
    await coordinator.apply(
      .loadTab(identity, fixture.url(path: "page", query: "stable")))
    let secondView = try #require(coordinator.webView(for: identity.tabID))
    let count = try await javaScriptString(
      "return String(window.arcLakeStableCount ?? -1);", in: firstView)
    #expect(ObjectIdentifier(firstView) == ObjectIdentifier(secondView))
    #expect(count == "1")
    coordinator.releaseAll()
  }

  @Test("T01 named product stores isolate cookie and localStorage")
  func productStoresAreIsolated() async throws {
    let fixture = try await LocalFixtureProcess()
    defer { fixture.stop() }
    let first = ProductBrowserSession(
      identity: identity(store: UUID()),
      onEvent: { _ in },
      onNewWindow: { _ in })
    let second = ProductBrowserSession(
      identity: identity(store: UUID()),
      onEvent: { _ in },
      onNewWindow: { _ in })
    defer {
      first.release()
      second.release()
    }

    first.navigate(to: fixture.originA)
    second.navigate(to: fixture.originA)
    try await waitUntil("first profile ready") { first.state == .ready }
    try await waitUntil("second profile ready") { second.state == .ready }

    _ = try await javaScriptString(
      """
      localStorage.setItem('arcLakeProfile', 'A');
      document.cookie = 'arcLakeProfile=A; Max-Age=86400; Path=/';
      return 'ok';
      """, in: first.webView)
    let firstMarker = try await readMarker(first.webView)
    let secondMarker = try await readMarker(second.webView)
    #expect(firstMarker.local == "A")
    #expect(firstMarker.cookie.contains("arcLakeProfile=A"))
    #expect(secondMarker.local == nil)
    #expect(!secondMarker.cookie.contains("arcLakeProfile=A"))
  }

  private func readMarker(_ webView: WKWebView) async throws
    -> (local: String?, cookie: String)
  {
    let value = try await javaScriptString(
      """
      return JSON.stringify({
        local: localStorage.getItem('arcLakeProfile'),
        cookie: document.cookie
      });
      """, in: webView)
    let object = try #require(
      JSONSerialization.jsonObject(with: Data(value.utf8)) as? [String: Any])
    return (object["local"] as? String, object["cookie"] as? String ?? "")
  }

  private func javaScriptString(
    _ body: String, in webView: WKWebView
  ) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      webView.callAsyncJavaScript(
        body, arguments: [:], in: nil, in: .page
      ) { result in
        switch result {
        case .success(let value):
          guard let string = value as? String else {
            continuation.resume(throwing: WaitError.timeout("non-string JS result"))
            return
          }
          continuation.resume(returning: string)
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }
    }
  }

  private func identity(store: UUID) -> BrowserIdentity {
    BrowserIdentity(
      tabID: TabID(), profileID: ProfileID(), websiteStoreID: store)
  }

  private func waitUntil(
    _ label: String, seconds: Double = 12,
    condition: @MainActor () -> Bool
  ) async throws {
    let start = ContinuousClock.now
    while !condition() {
      if start.duration(to: .now) > .seconds(seconds) {
        throw WaitError.timeout(label)
      }
      try await Task.sleep(for: .milliseconds(50))
    }
  }
}

@MainActor
private final class BrowserEventLog {
  var events: [BrowserEvent] = []
}

private enum WaitError: Error {
  case timeout(String)
}

@MainActor
private final class LocalFixtureProcess {
  let originA: URL
  let originB: URL
  private let process: Process
  private let directory: URL

  init() async throws {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ArcLakeM2Fixture-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    let config = directory.appendingPathComponent("origins.json")
    process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.currentDirectoryURL = root
    process.arguments = [
      "scripts/m0_fixture.py", "--config-output", config.path,
    ]
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()

    let start = ContinuousClock.now
    while !FileManager.default.fileExists(atPath: config.path) {
      if start.duration(to: .now) > .seconds(8) {
        process.terminate()
        throw WaitError.timeout("fixture startup")
      }
      try await Task.sleep(for: .milliseconds(50))
    }
    let object =
      try JSONSerialization.jsonObject(
        with: Data(contentsOf: config)) as? [String: [String]]
    let origins = try #require(object?["origins"])
    originA = try #require(URL(string: origins[0]))
    originB = try #require(URL(string: origins[1]))
  }

  func stop() {
    if process.isRunning {
      process.terminate()
      process.waitUntilExit()
    }
    try? FileManager.default.removeItem(at: directory)
  }

  func url(path: String, query: String? = nil) -> URL {
    var value = originA.appendingPathComponent(path)
    if let query {
      value.append(queryItems: [URLQueryItem(name: "case", value: query)])
    }
    return value
  }
}
