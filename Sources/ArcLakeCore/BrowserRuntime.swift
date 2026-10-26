import Foundation

public struct BrowserIdentity: Codable, Equatable, Sendable {
  public var tabID: TabID
  public var profileID: ProfileID
  public var websiteStoreID: UUID
  public var generation: GenerationID
  public var hostID: BrowserHostID?

  public init(
    tabID: TabID, profileID: ProfileID, websiteStoreID: UUID,
    generation: GenerationID = GenerationID(),
    hostID: BrowserHostID? = nil
  ) {
    self.tabID = tabID
    self.profileID = profileID
    self.websiteStoreID = websiteStoreID
    self.generation = generation
    self.hostID = hostID
  }

  public func accepts(_ other: BrowserIdentity) -> Bool {
    self == other
  }
}

public struct BrowserRuntimeBinding: Equatable, Sendable {
  public var identity: BrowserIdentity

  public init(identity: BrowserIdentity) {
    self.identity = identity
  }
}

public struct BrowserRuntimeSnapshot: Equatable, Sendable {
  public var bindings: [BrowserRuntimeBinding]

  public init(bindings: [BrowserRuntimeBinding] = []) {
    self.bindings = bindings
  }

  public static let empty = BrowserRuntimeSnapshot()
}

public enum BrowserLoadState: Equatable, Sendable {
  case idle
  case loading
  case ready
  case failed(String)
}

public struct BrowserTabRuntime: Equatable, Sendable {
  public var identity: BrowserIdentity
  public var url: URL?
  public var title: String?
  public var loadState: BrowserLoadState
  public var canGoBack: Bool
  public var canGoForward: Bool
  public var estimatedProgress: Double

  public init(
    identity: BrowserIdentity, url: URL?, title: String?,
    loadState: BrowserLoadState, canGoBack: Bool = false,
    canGoForward: Bool = false, estimatedProgress: Double = 0
  ) {
    self.identity = identity
    self.url = url
    self.title = title
    self.loadState = loadState
    self.canGoBack = canGoBack
    self.canGoForward = canGoForward
    self.estimatedProgress = estimatedProgress
  }
}

public enum BrowserEventKind: Equatable, Sendable {
  case navigationStarted(url: URL?)
  case navigationCommitted(url: URL?, title: String?)
  case navigationFinished(url: URL, title: String?)
  case navigationFailed(url: URL?, message: String)
  case loadingProgress(Double)
  case titleChanged(String?)
  case historyStateChanged(canGoBack: Bool, canGoForward: Bool)
  case processTerminated(message: String)
  case downloadStarted(id: UUID)
  case downloadFinished(id: UUID)
}

public struct BrowserEvent: Equatable, Sendable {
  public var identity: BrowserIdentity
  public var kind: BrowserEventKind

  public init(identity: BrowserIdentity, kind: BrowserEventKind) {
    self.identity = identity
    self.kind = kind
  }
}
