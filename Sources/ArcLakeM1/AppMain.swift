import AppKit
import ArcLakeCore
import ArcLakePersistence
import Observation
import SwiftUI

@main
struct ArcLakeM1App: App {
  @State private var model = ArcLakeM1Model()

  var body: some Scene {
    WindowGroup {
      ArcLakeM1Root(model: model)
        .task { await model.startIfNeeded() }
    }
    .defaultSize(width: 820, height: 560)
  }
}

@MainActor
@Observable
final class ArcLakeM1Model {
  private(set) var controller: AppController?
  private(set) var startupFailure: String?
  private var hasStarted = false

  init() {
    openController()
  }

  private func openController() {
    do {
      let databaseURL: URL
      if let override = ProcessInfo.processInfo.environment["ARCLAKE_M1_DATABASE_PATH"],
        !override.isEmpty
      {
        databaseURL = URL(fileURLWithPath: override)
      } else {
        let support = try FileManager.default.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        databaseURL =
          support
          .appendingPathComponent("ArcLakeM1", isDirectory: true)
          .appendingPathComponent("ArcLake-M1.sqlite")
      }
      try FileManager.default.createDirectory(
        at: databaseURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
      let store = try SQLiteWorkspaceStore(path: databaseURL)
      controller = AppController(store: store)
      startupFailure = nil
    } catch {
      controller = nil
      startupFailure = String(describing: error)
    }
  }

  func startIfNeeded() async {
    guard !hasStarted else { return }
    hasStarted = true
    await controller?.start()
  }

  func retryStartup() async {
    if controller == nil {
      openController()
    }
    await controller?.retryStartup()
  }
}

struct ArcLakeM1Root: View {
  let model: ArcLakeM1Model

  var body: some View {
    Group {
      if let failure = model.startupFailure {
        recoveryView(title: "Database unavailable", message: failure)
      } else if let controller = model.controller {
        switch controller.phase {
        case .idle, .loading:
          loadingView
        case .recovery(let recovery):
          recoveryView(title: "Startup recovery", message: recovery.message)
        case .ready(let summary):
          readyView(controller: controller, summary: summary)
        }
      } else {
        recoveryView(title: "Startup failed", message: "No database controller")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      LinearGradient(
        colors: [Color(hex: 0xEAF2F7), Color(hex: 0xF8F2E8)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    )
  }

  private var loadingView: some View {
    VStack(spacing: 16) {
      ProgressView()
      Text("Opening workspace")
        .font(.headline)
      Text("SQLite migration, validation and lazy restore run before any page is loaded.")
        .foregroundStyle(.secondary)
    }
    .padding(32)
  }

  private func recoveryView(title: String, message: String) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 36))
        .foregroundStyle(.orange)
      Text(title).font(.largeTitle.bold())
      Text(message)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
      HStack {
        Button("Retry") {
          Task { await model.retryStartup() }
        }
        .keyboardShortcut(.defaultAction)
        Button("Quit") { NSApplication.shared.terminate(nil) }
      }
    }
    .padding(36)
    .frame(maxWidth: 640, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
  }

  private func readyView(
    controller: AppController,
    summary: BootSummary
  ) -> some View {
    let state = controller.workspace
    return HStack(alignment: .top, spacing: 28) {
      VStack(alignment: .leading, spacing: 10) {
        Text("ArcLake")
          .font(.system(size: 34, weight: .black, design: .rounded))
        Text("M1 workspace foundation")
          .foregroundStyle(.secondary)
        Divider().padding(.vertical, 8)
        Text(
          summary.createdNewWorkspace
            ? "Default Profile and Space created"
            : "Workspace restored"
        )
        .font(.headline)
        Text("Revision \(state?.revision ?? 0)")
          .font(.system(.body, design: .monospaced))
        if !summary.repairs.isEmpty {
          Text("\(summary.repairs.count) selection repair(s) committed")
            .foregroundStyle(.orange)
        }
      }
      .frame(width: 250, alignment: .leading)

      VStack(alignment: .leading, spacing: 14) {
        Text("Spaces")
          .font(.title2.bold())
        ForEach(state?.spaces ?? [], id: \.id) { space in
          let profileName = state?.profile(space.profileID)?.name ?? "Missing Profile"
          HStack {
            Circle()
              .fill(Color(hex: 0x1D4F7A))
              .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
              Text(space.name).font(.headline)
              Text("Profile \(profileName)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(space.selectedItemID == nil ? "Empty" : "Selected")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(14)
          .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 14))
        }
        if let plan = summary.restorationPlan {
          Text("Lazy restore: \(plan.tabIDs.count) visible Tab(s)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 8)
        }
        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(36)
  }
}

extension Color {
  fileprivate init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}
