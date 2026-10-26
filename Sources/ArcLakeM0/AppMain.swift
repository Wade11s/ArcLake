import AppKit
import SwiftUI
import M0Core

@main
struct ArcLakeM0Main {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = ProbeAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(CommandLine.arguments.contains("demo") ? .regular : .accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class ProbeAppDelegate: NSObject, NSApplicationDelegate {
    var windows: ProbeWindows?
    var testTask: Task<Void, Never>?
    var demo = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let args = try options()
            let phase = args["phase"] ?? "demo"
            demo = phase == "demo"
            let config = try configuration(args)
            if demo {
                let menu = NSMenu()
                let item = NSMenuItem(); menu.addItem(item)
                let appMenu = NSMenu(); item.submenu = appMenu
                appMenu.addItem(withTitle: "Quit ArcLake M0", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
                NSApp.mainMenu = menu
                let model = ProbeModel(configuration: config)
                windows = ProbeWindows(model: model, visible: true)
                for session in model.sessions.values { session.load(config.originA) }
            } else {
                testTask = Task { @MainActor in
                    let success = await ProbeRunner(configuration: config, phase: phase).run()
                    if success { NSApp.terminate(nil) }
                    else { exit(1) }
                }
            }
        } catch {
            let text = "ArcLake M0 configuration error: \(error)\nRun python3 scripts/run_m0.py --demo (or --test) from the project.\n"
            FileHandle.standardError.write(Data(text.utf8))
            exit(2)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { demo }
    func applicationWillTerminate(_ notification: Notification) { windows?.close() }

    private func options() throws -> [String: String] {
        let values = Array(CommandLine.arguments.dropFirst())
        guard values.count.isMultiple(of: 2) else { throw ProbeFailure("Arguments must be --key value pairs") }
        var result: [String: String] = [:]
        for index in stride(from: 0, to: values.count, by: 2) {
            guard values[index].hasPrefix("--") else { throw ProbeFailure("Invalid argument") }
            result[String(values[index].dropFirst(2))] = values[index + 1]
        }
        return result
    }
    private func configuration(_ options: [String: String]) throws -> ProbeConfiguration {
        func required(_ key: String) throws -> String {
            guard let value = options[key] else { throw ProbeFailure("Missing --\(key)") }
            return value
        }
        func id(_ key: String) throws -> UUID {
            guard let id = UUID(uuidString: try required(key)) else { throw ProbeFailure("Invalid UUID for \(key)") }
            return id
        }
        guard let originA = URL(string: try required("origin-a")),
              let originB = URL(string: try required("origin-b")) else { throw ProbeFailure("Invalid fixture URL") }
        return try ProbeConfiguration(originA: originA, originB: originB,
                                      storeA: id("store-a"), storeB: id("store-b"),
                                      disposableStoreID: id("disposable-store"), runToken: required("run-token"))
    }
}
