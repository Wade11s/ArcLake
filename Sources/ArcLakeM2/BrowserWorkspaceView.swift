import ArcLakeCore
import SwiftUI

struct M2BrowserWorkspaceView: View {
  @Bindable var model: M2Model

  var body: some View {
    VStack(spacing: 0) {
      browserToolbar
      if let progress = model.runtimeForSelectedTab?.estimatedProgress,
        progress > 0, progress < 1
      {
        ProgressView(value: progress)
          .progressViewStyle(.linear)
          .tint(Color(hex: model.selectedSpace?.theme.accentColorHex ?? "#1D4F7A"))
      }
      pageContent
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 18))
    .overlay {
      RoundedRectangle(cornerRadius: 18)
        .stroke(.white.opacity(0.45), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.1), radius: 24, y: 8)
    .padding(12)
  }

  private var browserToolbar: some View {
    HStack(spacing: 8) {
      if !model.sidebarVisible {
        Button {
          model.toggleSidebar()
        } label: {
          Image(systemName: "sidebar.left")
        }
        .buttonStyle(.plain)
        .help("Show Sidebar")
      }
      Button {
        model.goBack()
      } label: {
        Image(systemName: "chevron.left")
      }
      .disabled(!model.canGoBack)
      .buttonStyle(BrowserToolbarButtonStyle())
      .help("Back")
      Button {
        model.goForward()
      } label: {
        Image(systemName: "chevron.right")
      }
      .disabled(!model.canGoForward)
      .buttonStyle(BrowserToolbarButtonStyle())
      .help("Forward")
      Button {
        model.reload()
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .disabled(!model.canReload)
      .buttonStyle(BrowserToolbarButtonStyle())
      .help("Reload")

      Button {
        model.openCommandBar(.navigateCurrent)
      } label: {
        HStack(spacing: 7) {
          Image(systemName: model.selectedTab == nil ? "magnifyingglass" : "lock")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          Text(model.addressHost)
            .lineLimit(1)
            .foregroundStyle(.primary)
          Spacer(minLength: 2)
        }
        .font(.system(size: 12, design: .rounded))
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Color.primary.opacity(0.06), in: Capsule())
      }
      .buttonStyle(.plain)
      .help("Edit Address (⌘L)")

      Button {
        model.openCommandBar(.newTab)
      } label: {
        Image(systemName: "plus")
      }
      .buttonStyle(BrowserToolbarButtonStyle())
      .help("New Tab (⌘T)")

      Button {
        model.presentProfiles()
      } label: {
        Text(model.currentProfile?.name.prefix(1).uppercased() ?? "?")
          .font(.system(size: 11, weight: .bold, design: .rounded))
          .frame(width: 24, height: 24)
          .background(
            Color(hex: model.selectedSpace?.theme.accentColorHex ?? "#1D4F7A")
              .opacity(0.16),
            in: Circle())
      }
      .buttonStyle(.plain)
      .help("Profiles")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(.regularMaterial)
  }

  @ViewBuilder
  private var pageContent: some View {
    if let tabID = model.selectedTabID {
      ZStack {
        ProductBrowserHost(browser: model.browser, tabID: tabID)
          .id(tabID)
        if let runtime = model.runtimeForSelectedTab {
          switch runtime.loadState {
          case .failed(let message):
            BrowserFailureView(message: message) { model.reload() }
          case .loading where model.browser.session(for: tabID) == nil:
            ProgressView("Loading page…")
              .padding(22)
              .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
          default:
            EmptyView()
          }
        }
      }
    } else {
      BrowserEmptyView(model: model)
    }
  }
}

private struct BrowserToolbarButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .frame(width: 28, height: 28)
      .background(
        Color.primary.opacity(configuration.isPressed ? 0.12 : 0.05),
        in: Circle()
      )
      .opacity(configuration.isPressed ? 0.75 : 1)
  }
}

private struct BrowserFailureView: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: "wifi.exclamationmark")
        .font(.system(size: 34))
        .foregroundStyle(.orange)
      Text("Page could not load")
        .font(.system(.title2, design: .serif, weight: .bold))
      Text(message)
        .font(.system(.body, design: .monospaced))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      Button("Try Again", action: retry)
        .buttonStyle(.borderedProminent)
    }
    .padding(28)
    .frame(maxWidth: 520)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.12), radius: 18, y: 7)
  }
}

private struct BrowserEmptyView: View {
  let model: M2Model

  var body: some View {
    VStack(spacing: 18) {
      Spacer()
      ZStack {
        Circle()
          .fill(
            Color(hex: model.selectedSpace?.theme.accentColorHex ?? "#1D4F7A")
              .opacity(0.12)
          )
          .frame(width: 110, height: 110)
        Image(systemName: "water.waves")
          .font(.system(size: 38, weight: .light))
          .foregroundStyle(
            Color(hex: model.selectedSpace?.theme.accentColorHex ?? "#1D4F7A"))
      }
      Text(model.selectedSpace?.name ?? "ArcLake")
        .font(.system(size: 34, weight: .bold, design: .serif))
      Text("A quiet place for the pages you keep close.")
        .foregroundStyle(.secondary)
      Button {
        model.openCommandBar(.newTab)
      } label: {
        Label("Open a Page", systemImage: "command")
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent)
      .tint(Color(hex: model.selectedSpace?.theme.accentColorHex ?? "#1D4F7A"))
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      LinearGradient(
        colors: [
          Color(hex: model.selectedSpace?.theme.backgroundColorHex ?? "#E8EEF5"),
          .white.opacity(0.6),
        ],
        startPoint: .top, endPoint: .bottom))
  }
}
