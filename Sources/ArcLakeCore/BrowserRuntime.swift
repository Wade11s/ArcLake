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

public enum BrowserEventKind: Equatable, Sendable {
  case navigationFinished(url: URL, title: String?)
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
