import AppKit
import SwiftUI
import WebKit
import M0Core

@MainActor
final class ProbeModel: ObservableObject {
    let configuration: ProbeConfiguration
    @Published var selectedSpace = "A1"
    @Published var sidebarVisible = true
    @Published var dark = false
    @Published var uiRevision = 0
    @Published var littleSpace: String?
    @Published var message = "M0 capability probe — not a daily browser"
    var sessions: [String: BrowserSession] = [:]
    var handoff: (() -> Void)?
    var reclaim: (() -> Void)?

    init(configuration: ProbeConfiguration, aliasStores: Bool = false) {
        self.configuration = configuration
        for space in configuration.spaces {
            let id = aliasStores && space.name == "B1" ? configuration.profileA.storeID : space.profile.storeID
            sessions[space.name] = BrowserSession(profileID: id)
        }
    }
    var selected: BrowserSession? { sessions[selectedSpace] }
    func toggleSidebar() { sidebarVisible.toggle(); uiRevision += 1 }
    func toggleTheme() { dark.toggle(); uiRevision += 1 }
    func releaseAll() {
        sessions.values.forEach { $0.releaseRuntime() }
        sessions.removeAll()
    }
}

struct BrowserHost: NSViewRepresentable {
    let session: BrowserSession
    let revision: Int
    func makeNSView(context: Context) -> BrowserHostView { BrowserHostView() }
    func updateNSView(_ view: BrowserHostView, context: Context) { view.mount(session) }
    static func dismantleNSView(_ view: BrowserHostView, coordinator: ()) { view.unmount() }
}

struct ProbeRoot: View {
    @ObservedObject var model: ProbeModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Sidebar") { model.toggleSidebar() }
                Button("Theme") { model.toggleTheme() }
                Button("Back") { model.selected?.webView.goBack() }
                Button("Reload") { model.selected?.webView.reload() }
                Button("Local fixture") { model.selected?.load(model.configuration.originA) }
                Button("Little window") { model.handoff?() }
                Spacer()
                Text("Profile " + (model.selectedSpace == "B1" ? "B" : "A"))
            }.padding(10)
            Divider()
            HStack(spacing: 0) {
                if model.sidebarVisible {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ArcLake M0").font(.headline)
                        ForEach(model.configuration.spaces, id: \.name) { space in
                            Button("\(space.name) · Profile \(space.profile.name)") {
                                model.selectedSpace = space.name
                            }
                        }
                        Text("A1 / A2 share a website store. B1 is isolated.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }.padding().frame(width: 180)
                }
                if let session = model.selected, model.littleSpace != model.selectedSpace {
                    BrowserHost(session: session, revision: model.uiRevision)
                } else {
                    VStack { Text("Page is in Little Window"); Button("Return page") { model.reclaim?() } }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Divider()
            Text(model.message).font(.caption).padding(6)
        }.preferredColorScheme(model.dark ? .dark : .light)
    }
}

@MainActor
final class ProbeWindows {
    let model: ProbeModel
    let main: NSWindow
    private(set) var little: NSWindow?
    private(set) var littleHost: BrowserHostView?
    let visible: Bool

    init(model: ProbeModel, visible: Bool) {
        self.model = model; self.visible = visible
        main = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 1080, height: 760),
                        styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        main.title = "ArcLake M0 — independent test application"
        main.isReleasedWhenClosed = false
        main.contentView = NSHostingView(rootView: ProbeRoot(model: model))
        main.contentView?.layoutSubtreeIfNeeded()
        model.handoff = { [weak self] in
            do { try self?.moveToLittle() } catch { self?.model.message = String(describing: error) }
        }
        model.reclaim = { [weak self] in self?.returnToMain() }
        if visible { main.makeKeyAndOrderFront(nil) }
    }

    func moveToLittle(targetProfile: UUID? = nil) throws {
        guard little == nil, let session = model.selected else { throw ProbeFailure("Little Window already exists or no selection") }
        try session.identity.validateMove(to: targetProfile ?? session.identity.profileID)
        let window = NSWindow(contentRect: NSRect(x: 200, y: 160, width: 780, height: 600),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.title = "ArcLake M0 Little Window — Return page in main window"
        window.isReleasedWhenClosed = false
        let host = BrowserHostView(frame: NSRect(x: 0, y: 0, width: 780, height: 600))
        host.role = .little
        window.contentView = host
        session.owner = .little
        // Change logical owner before SwiftUI dismantles the old host.
        model.littleSpace = model.selectedSpace
        host.mount(session)
        little = window; littleHost = host
        window.makeFirstResponder(session.webView)
        if visible { window.makeKeyAndOrderFront(nil) }
    }
    func returnToMain() {
        guard let space = model.littleSpace else { return }
        littleHost?.unmount()
        model.sessions[space]?.owner = .main
        model.selectedSpace = space; model.littleSpace = nil
        little?.close(); little = nil; littleHost = nil
        main.contentView?.layoutSubtreeIfNeeded()
    }
    func layout() { main.contentView?.layoutSubtreeIfNeeded(); little?.contentView?.layoutSubtreeIfNeeded() }
    func close() {
        littleHost?.unmount(); little?.close(); littleHost = nil; little = nil
        main.contentView = nil; main.close()
        model.releaseAll()
    }
}
