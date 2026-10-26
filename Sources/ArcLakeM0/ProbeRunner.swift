import AppKit
import WebKit
import M0Core

struct ProbeCheck: Codable {
    let id: String
    let status: String
    let detail: String
}
struct ProbeReport: Codable {
    let phase: String
    let os: String
    let bundleID: String
    let checks: [ProbeCheck]
    let facts: [String: String]
}

@MainActor
final class ProbeRunner {
    let configuration: ProbeConfiguration
    let phase: String
    var checks: [ProbeCheck] = []
    var facts: [String: String] = [:]
    init(configuration: ProbeConfiguration, phase: String) {
        self.configuration = configuration; self.phase = phase
    }
    func check(_ condition: Bool, _ id: String, _ detail: String) throws {
        checks.append(ProbeCheck(id: id, status: condition ? "pass" : "fail", detail: detail))
        guard condition else { throw ProbeFailure("\(id): \(detail)") }
    }
    func pending(_ id: String, _ detail: String) {
        checks.append(ProbeCheck(id: id, status: "pending", detail: detail))
    }
    func run() async -> Bool {
        do {
            if phase == "cleanup" {
                // On the current OS a cold static remove call crashes in WebKit's
                // WebsiteDataStoreIO run-loop dispatch. Bootstrap WebKit with an
                // unrelated nonpersistent view, release it, then remove owned stores.
                weak var bootstrap: WKWebView?
                autoreleasepool {
                    let config = WKWebViewConfiguration()
                    config.websiteDataStore = .nonPersistent()
                    let view = WKWebView(frame: .zero, configuration: config)
                    bootstrap = view
                }
                try await wait("bootstrap view release") { bootstrap == nil }
                for id in [configuration.profileA.storeID, configuration.profileB.storeID, configuration.disposableStoreID] {
                    try await removeStore(id)
                    try check(true, "delete-\(id.uuidString)", "Public store removal succeeded with no live probe WebViews")
                }
            } else {
                let model = ProbeModel(configuration: configuration, aliasStores: phase == "negative")
                let windows = ProbeWindows(model: model, visible: false)
                defer { windows.close() }
                if phase == "seed" { try await seed(model, windows) }
                else if phase == "verify" { try await verify(model) }
                else if phase == "verify-force-quit" { try await verify(model, forced: true) }
                else if phase == "force-quit-seed" { try await prepareForcedQuit(model) }
                else if phase == "negative" { try await negative(model) }
                else { throw ProbeFailure("Unknown test phase") }
            }
        } catch {
            checks.append(ProbeCheck(id: "phase-error", status: "fail", detail: String(describing: error)))
        }
        facts["profileAStore"] = configuration.profileA.storeID.uuidString
        facts["profileBStore"] = configuration.profileB.storeID.uuidString
        facts["originA"] = configuration.originA.absoluteString
        facts["originB"] = configuration.originB.absoluteString
        facts["windowMode"] = "non-activating hidden integration-test windows; no real keyboard events"
        let report = ProbeReport(phase: phase, os: ProcessInfo.processInfo.operatingSystemVersionString,
                                 bundleID: Bundle.main.bundleIdentifier ?? "missing", checks: checks, facts: facts)
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(report)
            FileHandle.standardOutput.write(Data("M0_REPORT ".utf8) + data + Data("\n".utf8))
        } catch { return false }
        return !checks.contains { $0.status == "fail" }
    }

    func wait(_ description: String, seconds: Double = 15, until predicate: () -> Bool) async throws {
        let start = ContinuousClock.now
        while !predicate() {
            if start.duration(to: .now) > .seconds(seconds) { throw ProbeFailure("Timed out: \(description)") }
            try await Task.sleep(for: .milliseconds(30))
        }
    }
    func load(_ session: BrowserSession, _ url: URL) async throws {
        let before = session.finishedNavigations
        session.load(url)
        try await wait("navigation to local fixture") { session.finishedNavigations > before || session.lastError != nil }
        if let error = session.lastError { throw ProbeFailure(error) }
    }
    func marker(_ session: BrowserSession) async throws -> [String: String?] {
        let value = try await session.javascript("return JSON.stringify(await fixture.readMarker());")
        return try JSONDecoder().decode([String: String?].self, from: Data(value.utf8))
    }
    func assertMarker(_ session: BrowserSession, expected: String?, id: String) async throws {
        let values = try await marker(session)
        let fields = ["local", "indexedDB", "cookie", "httpOnly"]
        try check(fields.allSatisfy { values.keys.contains($0) && (values[$0] ?? nil) == expected }, id,
                  "Expected \(expected ?? "empty") in localStorage, IndexedDB, JS Cookie and server-visible HttpOnly Cookie; got \(values)")
    }
    func setMarker(_ session: BrowserSession, _ token: String) async throws {
        _ = try await session.javascript("return JSON.stringify(await fixture.setMarker(token));", arguments: ["token": token])
    }
    func snapshot(_ session: BrowserSession) async throws -> String {
        try await session.javascript("return JSON.stringify(fixture.snapshot());")
    }
    func seed(_ model: ProbeModel, _ windows: ProbeWindows) async throws {
        guard let a1 = model.sessions["A1"], let a2 = model.sessions["A2"], let b1 = model.sessions["B1"] else { throw ProbeFailure("Missing fixture sessions") }
        try check(a1.webView.configuration.websiteDataStore.identifier == a2.webView.configuration.websiteDataStore.identifier
                  && a1.webView.configuration.websiteDataStore.identifier != b1.webView.configuration.websiteDataStore.identifier,
                  "store-identity", "A1/A2 share a named persistent store; B1 uses a different named store")
        for session in [a1, a2, b1] { try await load(session, configuration.originA) }
        try await assertMarker(a1, expected: nil, id: "fresh-A")
        try await assertMarker(b1, expected: nil, id: "fresh-B")
        try await setMarker(a1, configuration.runToken + "-A-one")
        try await assertMarker(a2, expected: configuration.runToken + "-A-one", id: "T01-shared-A1-A2")
        try await assertMarker(b1, expected: nil, id: "T01-no-leak-A-to-B")
        try await setMarker(b1, configuration.runToken + "-B-one")
        try await assertMarker(b1, expected: configuration.runToken + "-B-one", id: "T01-write-B")
        try await assertMarker(a1, expected: configuration.runToken + "-A-one", id: "T01-no-leak-B-to-A")
        try await secondOrigin(seed: true)
        try await identityAndHandoff(model, windows, a1)
        try await copyAcrossProfiles(model, windows, a1)
        try await navigationSmoke(a2)
        try await disposableDeletion()
        let stale = BrowserIdentity(tabID: a1.identity.tabID, profileID: a1.identity.profileID)
        let previous = a1.state
        a1.receiveTermination(for: stale)
        try check(a1.state == previous && a1.droppedEvents == 1, "T29-stale-generation", "Synthetic stale event cannot mutate the live session")
        a1.receiveTermination(for: a1.identity)
        try check(a1.state == "process-terminated", "T29-handler-injection", "Synthetic current-generation termination enters recoverable state (not a real WebKit crash)")
        try await load(a1, configuration.originA)
        try check(a1.state == "ready", "T29-reload", "Explicit URL load recovers session after injected termination state")
        pending("T29-real-process-termination", "No public process-kill API used; actual WebKit process termination still needs a controlled test")
        pending("minimum-macOS14", "This machine is not macOS 14; deployment target/build checks are not runtime compatibility tests")
        pending("real-keyboard-focus", "DOM focus/NSWindow responder wiring tested; physical typing, IME and foreground-window handoff not tested")
        facts["forceQuitTest"] = "Executed by separate force-quit-seed / verify-force-quit processes in the Python harness"
    }
    func secondOrigin(seed: Bool) async throws {
        let a = BrowserSession(profileID: configuration.profileA.storeID)
        let b = BrowserSession(profileID: configuration.profileB.storeID)
        defer { a.releaseRuntime(); b.releaseRuntime() }
        try await load(a, configuration.originB); try await load(b, configuration.originB)
        if seed {
            try await assertMarker(a, expected: nil, id: "origin2-fresh-A")
            try await assertMarker(b, expected: nil, id: "origin2-fresh-B")
            try await setMarker(a, configuration.runToken + "-A-two")
            try await setMarker(b, configuration.runToken + "-B-two")
        }
        try await assertMarker(a, expected: configuration.runToken + "-A-two", id: seed ? "origin2-A" : "T02-restart-origin2-A")
        try await assertMarker(b, expected: configuration.runToken + "-B-two", id: seed ? "origin2-B" : "T02-restart-origin2-B")
    }
    func identityAndHandoff(_ model: ProbeModel, _ windows: ProbeWindows, _ session: BrowserSession) async throws {
        windows.layout()
        try await wait("initial SwiftUI host") { session.host != nil }
        _ = try await session.javascript("document.getElementById('draft').value='unsubmitted-m0-draft'; window.memoryCounter=42; return 'ok';")
        let originalID = ObjectIdentifier(session.webView)
        let initial = try await snapshot(session)
        let loads = session.requestedLoads
        let navigations = session.finishedNavigations
        let firstUpdates = session.host!.updates
        for _ in 0..<50 {
            let before = session.host!.updates
            model.toggleSidebar(); windows.layout()
            try await wait("sidebar representable update", seconds: 3) { (session.host?.updates ?? 0) > before }
            let next = session.host!.updates
            model.toggleTheme(); windows.layout()
            try await wait("theme representable update", seconds: 3) { (session.host?.updates ?? 0) > next }
        }
        let after = try await snapshot(session)
        try check(originalID == ObjectIdentifier(session.webView) && initial == after
                  && loads == session.requestedLoads && navigations == session.finishedNavigations,
                  "T03-100-UI-updates", "50 sidebar + 50 theme toggles preserve WebView identity, document instance, load count, draft and JS memory")
        facts["representableUpdates"] = String(session.host!.updates - firstUpdates)
        facts["webViewIdentity"] = String(describing: originalID)
        // Scroll/focus are measured only after the layout stress test, to avoid resize clamping.
        _ = try await session.javascript("document.getElementById('draft').focus(); window.scrollTo(0,400); return 'ok';")
        try await Task.sleep(for: .milliseconds(150))
        let beforeMove = try await snapshot(session)
        let scroll = try await session.javascript("return JSON.stringify({y:scrollY,height:innerHeight,documentHeight:document.documentElement.scrollHeight});")
        facts["scrollProbe"] = scroll
        if let data = scroll.data(using: .utf8), let values = try JSONSerialization.jsonObject(with: data) as? [String: Double], (values["y"] ?? 0) <= 0 {
            pending("T04-nonzero-scroll", "Hidden-window scrollTo did not establish a nonzero offset; equality at zero is NOT a scroll preservation test")
        }
        let oldHost = session.host!
        try windows.moveToLittle()
        windows.layout()
        // Deterministic regression: a stale SwiftUI update/dismantle must never
        // steal or detach the WebView from its new logical owner.
        oldHost.mount(session)
        oldHost.unmount()
        try await Task.sleep(for: .milliseconds(150))
        let littleSnapshot = try await snapshot(session)
        try check(session.host === windows.littleHost && oldHost.session == nil
                  && session.webView.window === windows.little && originalID == ObjectIdentifier(session.webView),
                  "T04-single-owner", "ownerIsLittle=\(session.host === windows.littleHost); oldReleased=\(oldHost.session == nil); windowIsLittle=\(session.webView.window === windows.little); identityStable=\(originalID == ObjectIdentifier(session.webView)); superview=\(String(describing: session.webView.superview))")
        try check(beforeMove == littleSnapshot, "T04-page-state", "Handoff preserves document instance, memory=42, unsent form and DOM focus; scroll adequacy is reported separately; before=\(beforeMove), after=\(littleSnapshot)")
        facts["littleFirstResponder"] = String(describing: windows.little?.firstResponder)
        windows.returnToMain()
        try await wait("return to main host") { session.host != nil && session.webView.window === windows.main }
        let returned = try await snapshot(session)
        try check(beforeMove == returned && windows.little == nil, "T04-roundtrip", "Return to main preserves page state and closes Little Window; after=\(returned)")
    }
    func copyAcrossProfiles(_ model: ProbeModel, _ windows: ProbeWindows, _ original: BrowserSession) async throws {
        var rejected = false
        do { try windows.moveToLittle(targetProfile: configuration.profileB.storeID) }
        catch ProbeError.crossProfileMove { rejected = true }
        try check(rejected && windows.little == nil && original.webView.window === windows.main,
                  "T05-reject-cross-profile-move", "Ownership guard rejects cross-profile move before creating a window")
        let copy = BrowserSession(profileID: configuration.profileB.storeID)
        defer { copy.releaseRuntime() }
        try await load(copy, original.webView.url ?? configuration.originA)
        try await assertMarker(copy, expected: configuration.runToken + "-B-one", id: "T05-copy-uses-target-store")
        let draft = try await copy.javascript("return document.getElementById('draft').value;")
        try check(copy.identity.tabID != original.identity.tabID && draft.isEmpty,
                  "T05-copy-link-only", "Explicit URL copy uses new Tab identity and cannot copy the source form/JS state")
    }
    func navigationSmoke(_ session: BrowserSession) async throws {
        try await load(session, configuration.originA.appendingPathComponent("redirect"))
        try check(session.webView.url?.query == "redirected=1", "fixture-redirect", "Real WKWebView follows local HTTP 302")
        let post = try await session.javascript("const r=await fetch('/post',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:'text=local-test-only'}); return JSON.stringify(await r.json());")
        try check(post.contains("local-test-only") && post.contains("POST"), "fixture-post-fetch", "Local POST echo works through WKWebView fetch (not a native form-navigation test)")
        pending("fixture-popup-download", "Fixture links exist and HTTP contract is tested; native popup/download delegate handling is deferred")
    }
    func disposableDeletion() async throws {
        weak var releasedView: WKWebView?
        do {
            let session = BrowserSession(profileID: configuration.disposableStoreID)
            releasedView = session.webView
            try await load(session, configuration.originA)
            try await setMarker(session, configuration.runToken + "-disposable")
            session.releaseRuntime()
        }
        try await wait("release disposable WKWebView") { releasedView == nil }
        try await removeStore(configuration.disposableStoreID)
        try check(true, "store-delete-after-release", "Weak WKWebView reference is nil before public store removal completes")
        do {
            let fresh = BrowserSession(profileID: configuration.disposableStoreID)
            defer { fresh.releaseRuntime() }
            try await load(fresh, configuration.originA)
            try await assertMarker(fresh, expected: nil, id: "store-delete-content-empty")
        }
    }
    private func purgeWebsiteData(_ id: UUID) async {
        // Clearing the live data-store service before deleting its namespace also
        // invalidates cached cookies. Immediate UUID reuse exposed residual cookies
        // on the current OS when only remove(forIdentifier:) was used.
        let store = WKWebsiteDataStore(forIdentifier: id)
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
    }
    func removeStore(_ id: UUID) async throws {
        await purgeWebsiteData(id)
        for attempt in 1...10 {
            do {
                try await WKWebsiteDataStore.remove(forIdentifier: id)
                facts["deleteAttempts-" + id.uuidString] = String(attempt)
                return
            } catch {
                let nsError = error as NSError
                facts["deleteRetry-" + id.uuidString] = "\(nsError.domain)/\(nsError.code): \(nsError.localizedDescription)"
                if attempt == 10 { throw error }
                try await Task.sleep(for: .milliseconds(100 * attempt))
            }
        }
    }
    func prepareForcedQuit(_ model: ProbeModel) async throws {
        let session = model.sessions["A1"]!
        try await load(session, configuration.originA)
        try await setMarker(session, configuration.runToken + "-A-force")
        try await assertMarker(session, expected: configuration.runToken + "-A-force", id: "force-quit-write-acknowledged")
        // Harness kills ONLY this owned app PID after this acknowledged write.
        FileHandle.standardOutput.write(Data("M0_FORCE_QUIT_READY\n".utf8))
        while !Task.isCancelled { try await Task.sleep(for: .seconds(1)) }
    }
    func verify(_ model: ProbeModel, forced: Bool = false) async throws {
        for name in ["A1", "A2", "B1"] {
            let session = model.sessions[name]!
            try await load(session, configuration.originA)
            try await assertMarker(session, expected: configuration.runToken + (name == "B1" ? "-B-one" : (forced ? "-A-force" : "-A-one")), id: "T02-\(forced ? "force-quit" : "restart")-\(name)")
        }
        try await secondOrigin(seed: false)
    }
    func negative(_ model: ProbeModel) async throws {
        let session = model.sessions["B1"]!
        try await load(session, configuration.originA)
        // Deliberately aliases B's store to A in ProbeModel. This MUST fail, proving the
        // isolation assertion can detect real website data leakage rather than just IDs.
        try await assertMarker(session, expected: configuration.runToken + "-B-one", id: "negative-control-isolation")
    }
}
