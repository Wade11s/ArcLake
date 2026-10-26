import AppKit
import ArcLakeCore
import SwiftUI

@main
struct ArcLakeM2App: App {
  @State private var model = M2Model()

  var body: some Scene {
    WindowGroup {
      M2RootView(model: model)
        .task { await model.startIfNeeded() }
    }
    .defaultSize(width: 1280, height: 820)
    .commands { M2Commands(model: model) }
  }
}

struct M2Commands: Commands {
  let model: M2Model

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button("New Tab") {
        Task { await model.perform(.newTab) }
      }
      .keyboardShortcut("t", modifiers: .command)

      Button("Edit Address") {
        Task { await model.perform(.navigateCurrent) }
      }
      .keyboardShortcut("l", modifiers: .command)

      Button("Close Current Tab") {
        Task { await model.perform(.closeTab) }
      }
      .keyboardShortcut("w", modifiers: .command)
    }

    CommandMenu("View") {
      Button("Toggle Sidebar") {
        model.toggleSidebar()
      }
      .keyboardShortcut("s", modifiers: .command)

      Button("Pin or Unpin") {
        Task { await model.perform(.pinOrUnpinSelected) }
      }
      .keyboardShortcut("d", modifiers: .command)
    }

    CommandMenu("Spaces") {
      ForEach(1...9, id: \.self) { index in
        Button("Space \(index)") {
          Task { await model.switchSpaceByIndex(index - 1) }
        }
        .keyboardShortcut(
          KeyEquivalent(Character(String(index))),
          modifiers: .control)
      }
    }
  }
}

struct M2RootView: View {
  @Bindable var model: M2Model

  var body: some View {
    Group {
      if let failure = model.startupFailure {
        M2RecoveryView(title: "ArcLake could not open", message: failure) {
          await model.retryStartup()
        }
      } else {
        switch model.phase {
        case .idle, .loading:
          M2LoadingView()
        case .recovery(let recovery):
          M2RecoveryView(title: "Workspace recovery", message: recovery.message) {
            await model.retryStartup()
          }
        case .ready:
          workspaceView
        }
      }
    }
    .frame(minWidth: 900, minHeight: 620)
    .background(background)
    .overlay(alignment: .top) {
      if model.commandBarMode != nil {
        M2CommandBarView(model: model)
          .padding(.top, 54)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .overlay(alignment: .bottom) {
      if let error = model.errorBanner {
        M2ErrorBanner(message: error) {
          model.errorBanner = nil
        }
        .padding(18)
      }
    }
    .sheet(item: $model.sheet) { sheet in
      M2SheetView(model: model, sheet: sheet)
    }
    .alert(item: $model.confirmation) { confirmation in
      Alert(
        title: Text(confirmation.title),
        message: Text(confirmation.message),
        primaryButton: .destructive(Text("Continue")) {
          Task { await model.confirm(confirmation) }
        },
        secondaryButton: .cancel())
    }
    .onChange(of: model.commandQuery) {
      Task { await model.updateCommandQuery() }
    }
  }

  private var workspaceView: some View {
    HSplitView {
      if model.sidebarVisible {
        M2SidebarView(model: model)
          .frame(minWidth: 220, idealWidth: 280, maxWidth: 430)
      }
      M2BrowserWorkspaceView(model: model)
        .frame(minWidth: 620)
    }
  }

  private var background: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(hex: model.selectedSpace?.theme.backgroundColorHex ?? "#E8EEF5"),
          Color(hex: "#F7F1E7"),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)
      Circle()
        .fill(
          Color(hex: model.selectedSpace?.theme.accentColorHex ?? "#1D4F7A")
            .opacity(0.12)
        )
        .frame(width: 420, height: 420)
        .blur(radius: 70)
        .offset(x: 380, y: -280)
    }
    .ignoresSafeArea()
  }
}

private struct M2LoadingView: View {
  var body: some View {
    VStack(spacing: 14) {
      ProgressView()
      Text("Opening ArcLake workspace")
        .font(.system(.title3, design: .serif, weight: .semibold))
      Text("Validating SQLite state before loading any page.")
        .foregroundStyle(.secondary)
    }
  }
}

private struct M2RecoveryView: View {
  let title: String
  let message: String
  let retry: () async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 34))
        .foregroundStyle(.orange)
      Text(title)
        .font(.system(size: 30, weight: .bold, design: .serif))
      Text(message)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
      HStack {
        Button("Retry") { Task { await retry() } }
          .keyboardShortcut(.defaultAction)
        Button("Quit") { NSApplication.shared.terminate(nil) }
      }
    }
    .padding(32)
    .frame(maxWidth: 680, alignment: .leading)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
  }
}

private struct M2ErrorBanner: View {
  let message: String
  let dismiss: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "exclamationmark.circle.fill")
        .foregroundStyle(.orange)
      Text(message)
        .lineLimit(3)
      Spacer()
      Button("Dismiss", action: dismiss)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.regularMaterial, in: Capsule())
    .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
  }
}

extension Color {
  init(hex: String) {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&value)
    let red: Double
    let green: Double
    let blue: Double
    if cleaned.count == 6 {
      red = Double((value >> 16) & 0xFF) / 255
      green = Double((value >> 8) & 0xFF) / 255
      blue = Double(value & 0xFF) / 255
    } else {
      red = 0.35
      green = 0.45
      blue = 0.55
    }
    self.init(red: red, green: green, blue: blue)
  }
}
