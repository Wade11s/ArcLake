import ArcLakeCore
import Observation
import WebKit

public enum BrowserRuntimeError: Error, Equatable, Sendable,
  CustomStringConvertible
{
  case dataStoreRemovalFailed(String)

  public var description: String {
    switch self {
    case .dataStoreRemovalFailed(let message):
      "Website data store removal failed: \(message)"
    }
  }
}

@MainActor
@Observable
public final class BrowserCoordinator: AppEffectHandler, ProfileDataStoreDeleting {
  @ObservationIgnored private var sessions: [TabID: ProductBrowserSession] = [:]
  @ObservationIgnored public var eventHandler: (@MainActor (BrowserEvent) async -> Void)?
  @ObservationIgnored public var newWindowHandler: (@MainActor (URL) async -> Void)?
  public private(set) var revision: Int = 0

  public init() {}

  public func apply(_ effect: AppEffect) async {
    switch effect {
    case .workspaceReady, .spaceChanged, .showEmptySpace, .itemActivated:
      break
    case .loadTab(let identity, let url):
      load(identity: identity, url: url)
    case .releaseTab(let tabID):
      release(tabID: tabID)
    }
  }

  public func webView(for tabID: TabID) -> WKWebView? {
    sessions[tabID]?.webView
  }

  public func session(for tabID: TabID) -> ProductBrowserSession? {
    sessions[tabID]
  }

  public func reload(_ tabID: TabID) {
    sessions[tabID]?.reload()
  }

  public func goBack(_ tabID: TabID) {
    sessions[tabID]?.goBack()
  }

  public func goForward(_ tabID: TabID) {
    sessions[tabID]?.goForward()
  }

  public func releaseAll() {
    for session in sessions.values {
      session.release()
    }
    sessions.removeAll()
    revision += 1
  }

  public func deleteWebsiteData(profileID: ProfileID, storeID: UUID) async throws {
    let ownedTabIDs = sessions.compactMap { tabID, session in
      session.identity.profileID == profileID ? tabID : nil
    }
    for tabID in ownedTabIDs {
      release(tabID: tabID)
    }

    let store = WKWebsiteDataStore(forIdentifier: storeID)
    await store.removeData(
      ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
      modifiedSince: .distantPast)
    for attempt in 1...10 {
      do {
        try await WKWebsiteDataStore.remove(forIdentifier: storeID)
        revision += 1
        return
      } catch {
        if attempt == 10 {
          throw BrowserRuntimeError.dataStoreRemovalFailed(
            error.localizedDescription)
        }
        try? await Task.sleep(for: .milliseconds(100 * attempt))
      }
    }
  }

  private func load(identity: BrowserIdentity, url: URL) {
    if let existing = sessions[identity.tabID] {
      if existing.identity == identity {
        existing.navigate(to: url)
        return
      }
      existing.release()
      sessions.removeValue(forKey: identity.tabID)
    }

    let session = ProductBrowserSession(
      identity: identity,
      onEvent: { [weak self] event in
        guard let self else { return }
        Task { @MainActor in
          await self.eventHandler?(event)
        }
      },
      onNewWindow: { [weak self] url in
        guard let self else { return }
        Task { @MainActor in
          await self.newWindowHandler?(url)
        }
      })
    sessions[identity.tabID] = session
    revision += 1
    session.navigate(to: url)
  }

  private func release(tabID: TabID) {
    guard let session = sessions.removeValue(forKey: tabID) else { return }
    session.release()
    revision += 1
  }
}
