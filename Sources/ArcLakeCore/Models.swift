import Foundation

public enum ProfileLifecycle: String, Codable, Sendable {
  case active
  case deleting
}

public struct Profile: Codable, Equatable, Sendable {
  public var id: ProfileID
  public var name: String
  public var websiteStoreID: UUID
  public var archiveIntervalSeconds: TimeInterval
  public var searchEngineTemplate: String
  public var lifecycle: ProfileLifecycle
  public var createdAt: Date

  public init(
    id: ProfileID, name: String, websiteStoreID: UUID,
    archiveIntervalSeconds: TimeInterval = 12 * 60 * 60,
    searchEngineTemplate: String = "https://duckduckgo.com/?q={query}",
    lifecycle: ProfileLifecycle = .active,
    createdAt: Date
  ) {
    self.id = id
    self.name = name
    self.websiteStoreID = websiteStoreID
    self.archiveIntervalSeconds = archiveIntervalSeconds
    self.searchEngineTemplate = searchEngineTemplate
    self.lifecycle = lifecycle
    self.createdAt = createdAt
  }
}

public struct SpaceTheme: Codable, Equatable, Sendable {
  public var backgroundColorHex: String
  public var accentColorHex: String

  public init(backgroundColorHex: String = "#E8EEF5", accentColorHex: String = "#1D4F7A") {
    self.backgroundColorHex = backgroundColorHex
    self.accentColorHex = accentColorHex
  }
}

public struct Space: Codable, Equatable, Sendable {
  public var id: SpaceID
  public var profileID: ProfileID
  public var name: String
  public var icon: String
  public var theme: SpaceTheme
  public var sortOrder: Int64
  public var pinnedRootID: RootID
  public var todayRootID: RootID
  public var selectedItemID: ItemID?

  public init(
    id: SpaceID, profileID: ProfileID, name: String, icon: String,
    theme: SpaceTheme, sortOrder: Int64,
    pinnedRootID: RootID, todayRootID: RootID,
    selectedItemID: ItemID? = nil
  ) {
    self.id = id
    self.profileID = profileID
    self.name = name
    self.icon = icon
    self.theme = theme
    self.sortOrder = sortOrder
    self.pinnedRootID = pinnedRootID
    self.todayRootID = todayRootID
    self.selectedItemID = selectedItemID
  }
}

public enum RootKind: String, Codable, Sendable {
  case profileFavorites
  case spacePinned
  case spaceToday
}

public enum RootOwner: Codable, Equatable, Sendable {
  case profile(ProfileID)
  case space(SpaceID)

  private enum CodingKeys: String, CodingKey { case kind, id }
  private enum Kind: String, Codable { case profile, space }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .profile: self = .profile(try container.decode(ProfileID.self, forKey: .id))
    case .space: self = .space(try container.decode(SpaceID.self, forKey: .id))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .profile(let id):
      try container.encode(Kind.profile, forKey: .kind)
      try container.encode(id, forKey: .id)
    case .space(let id):
      try container.encode(Kind.space, forKey: .kind)
      try container.encode(id, forKey: .id)
    }
  }
}

public struct RootContainer: Codable, Equatable, Sendable {
  public var id: RootID
  public var kind: RootKind
  public var owner: RootOwner

  public init(id: RootID, kind: RootKind, owner: RootOwner) {
    self.id = id
    self.kind = kind
    self.owner = owner
  }
}

public enum SidebarParent: Codable, Equatable, Sendable {
  case root(RootID)
  case item(ItemID)

  private enum CodingKeys: String, CodingKey { case kind, id }
  private enum Kind: String, Codable { case root, item }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .root: self = .root(try container.decode(RootID.self, forKey: .id))
    case .item: self = .item(try container.decode(ItemID.self, forKey: .id))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .root(let id):
      try container.encode(Kind.root, forKey: .kind)
      try container.encode(id, forKey: .id)
    case .item(let id):
      try container.encode(Kind.item, forKey: .kind)
      try container.encode(id, forKey: .id)
    }
  }
}

public enum SidebarItemKind: String, Codable, Sendable {
  case tab
  case folder
  case split
}

public struct SidebarItem: Codable, Equatable, Sendable {
  public var id: ItemID
  public var parent: SidebarParent
  public var orderKey: Int64
  public var kind: SidebarItemKind
  public var tabID: TabID?
  public var customTitle: String?

  public init(
    id: ItemID, parent: SidebarParent, orderKey: Int64,
    kind: SidebarItemKind, tabID: TabID? = nil,
    customTitle: String? = nil
  ) {
    self.id = id
    self.parent = parent
    self.orderKey = orderKey
    self.kind = kind
    self.tabID = tabID
    self.customTitle = customTitle
  }
}

public enum TabOwner: Codable, Equatable, Sendable {
  case sidebarItem(ItemID)
  case littleWindow(WindowID)

  private enum CodingKeys: String, CodingKey { case kind, id }
  private enum Kind: String, Codable { case sidebarItem, littleWindow }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .sidebarItem: self = .sidebarItem(try container.decode(ItemID.self, forKey: .id))
    case .littleWindow: self = .littleWindow(try container.decode(WindowID.self, forKey: .id))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .sidebarItem(let id):
      try container.encode(Kind.sidebarItem, forKey: .kind)
      try container.encode(id, forKey: .id)
    case .littleWindow(let id):
      try container.encode(Kind.littleWindow, forKey: .kind)
      try container.encode(id, forKey: .id)
    }
  }
}

public struct Tab: Codable, Equatable, Sendable {
  public var id: TabID
  public var profileID: ProfileID
  public var currentURL: URL?
  public var savedURL: URL?
  public var pageTitle: String?
  public var lastActiveAt: Date
  public var createdAt: Date
  public var owner: TabOwner

  public init(
    id: TabID, profileID: ProfileID, currentURL: URL? = nil,
    savedURL: URL? = nil, pageTitle: String? = nil,
    lastActiveAt: Date, createdAt: Date, owner: TabOwner
  ) {
    self.id = id
    self.profileID = profileID
    self.currentURL = currentURL
    self.savedURL = savedURL
    self.pageTitle = pageTitle
    self.lastActiveAt = lastActiveAt
    self.createdAt = createdAt
    self.owner = owner
  }
}

public enum SplitOrientation: String, Codable, Sendable {
  case horizontal
  case vertical
}

public struct SplitConfiguration: Codable, Equatable, Sendable {
  public var itemID: ItemID
  public var orientation: SplitOrientation
  public var weights: [Double]
  public var focusedChildItemID: ItemID

  public init(
    itemID: ItemID, orientation: SplitOrientation,
    weights: [Double], focusedChildItemID: ItemID
  ) {
    self.itemID = itemID
    self.orientation = orientation
    self.weights = weights
    self.focusedChildItemID = focusedChildItemID
  }
}

public enum WindowKind: String, Codable, Sendable {
  case main
  case little
}

public struct WindowFrame: Codable, Equatable, Sendable {
  public var x: Double
  public var y: Double
  public var width: Double
  public var height: Double

  public init(x: Double, y: Double, width: Double, height: Double) {
    self.x = x
    self.y = y
    self.width = width
    self.height = height
  }
}

public struct SpaceSelection: Codable, Equatable, Sendable {
  public var spaceID: SpaceID
  public var itemID: ItemID

  public init(spaceID: SpaceID, itemID: ItemID) {
    self.spaceID = spaceID
    self.itemID = itemID
  }
}

public struct WindowSession: Codable, Equatable, Sendable {
  public var id: WindowID
  public var kind: WindowKind
  public var selectedSpaceID: SpaceID?
  public var selectedItemID: ItemID?
  public var selectedPaneID: ItemID?
  public var sidebarVisible: Bool
  public var sidebarWidth: Double
  public var frame: WindowFrame?
  public var lastSelections: [SpaceSelection]

  public init(
    id: WindowID, kind: WindowKind, selectedSpaceID: SpaceID? = nil,
    selectedItemID: ItemID? = nil, selectedPaneID: ItemID? = nil,
    sidebarVisible: Bool = true, sidebarWidth: Double = 260,
    frame: WindowFrame? = nil, lastSelections: [SpaceSelection] = []
  ) {
    self.id = id
    self.kind = kind
    self.selectedSpaceID = selectedSpaceID
    self.selectedItemID = selectedItemID
    self.selectedPaneID = selectedPaneID
    self.sidebarVisible = sidebarVisible
    self.sidebarWidth = sidebarWidth
    self.frame = frame
    self.lastSelections = lastSelections
  }
}

public enum SpaceRegion: String, Codable, Sendable {
  case favorites
  case pinned
  case today
}

public indirect enum ArchivedNode: Codable, Equatable, Sendable {
  case tab(
    itemID: ItemID, tabID: TabID, title: String?,
    currentURL: URL?, savedURL: URL?)
  case folder(itemID: ItemID, title: String?, children: [ArchivedNode])
  case split(
    itemID: ItemID, title: String?, orientation: SplitOrientation,
    weights: [Double], children: [ArchivedNode])
}

public struct ArchiveSnapshot: Codable, Equatable, Sendable {
  public var nodes: [ArchivedNode]

  public init(nodes: [ArchivedNode]) {
    self.nodes = nodes
  }
}

public enum ArchiveReason: String, Codable, Sendable {
  case manualClose
  case autoArchive
  case folderDeleted
  case spaceDeleted
  case littleClosed
  case unknown
}

public struct ArchiveEntry: Codable, Equatable, Sendable {
  public var id: ArchiveID
  public var profileID: ProfileID
  public var originSpaceID: SpaceID?
  public var originParentHintID: ItemID?
  public var originalRegion: SpaceRegion
  public var payloadVersion: Int
  public var snapshot: ArchiveSnapshot
  public var reason: ArchiveReason
  public var archivedAt: Date
  public var restoredAt: Date?

  public init(
    id: ArchiveID, profileID: ProfileID, originSpaceID: SpaceID?,
    originParentHintID: ItemID?, originalRegion: SpaceRegion,
    payloadVersion: Int = 1, snapshot: ArchiveSnapshot,
    reason: ArchiveReason, archivedAt: Date,
    restoredAt: Date? = nil
  ) {
    self.id = id
    self.profileID = profileID
    self.originSpaceID = originSpaceID
    self.originParentHintID = originParentHintID
    self.originalRegion = originalRegion
    self.payloadVersion = payloadVersion
    self.snapshot = snapshot
    self.reason = reason
    self.archivedAt = archivedAt
    self.restoredAt = restoredAt
  }
}

public struct HistoryVisit: Codable, Equatable, Sendable {
  public var id: HistoryID
  public var profileID: ProfileID
  public var url: URL
  public var title: String?
  public var visitedAt: Date

  public init(
    id: HistoryID, profileID: ProfileID, url: URL,
    title: String?, visitedAt: Date
  ) {
    self.id = id
    self.profileID = profileID
    self.url = url
    self.title = title
    self.visitedAt = visitedAt
  }
}

public enum RouteMatchingStyle: String, Codable, Sendable {
  case contains
  case exact
}

public enum RouteDestination: Codable, Equatable, Sendable {
  case space(SpaceID)
  case littleWindow(ProfileID)

  private enum CodingKeys: String, CodingKey { case kind, id }
  private enum Kind: String, Codable { case space, littleWindow }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .space: self = .space(try container.decode(SpaceID.self, forKey: .id))
    case .littleWindow: self = .littleWindow(try container.decode(ProfileID.self, forKey: .id))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .space(let id):
      try container.encode(Kind.space, forKey: .kind)
      try container.encode(id, forKey: .id)
    case .littleWindow(let id):
      try container.encode(Kind.littleWindow, forKey: .kind)
      try container.encode(id, forKey: .id)
    }
  }
}

public struct RouteRule: Codable, Equatable, Sendable {
  public var id: RouteRuleID
  public var order: Int64
  public var enabled: Bool
  public var matchingStyle: RouteMatchingStyle
  public var pattern: String
  public var destination: RouteDestination

  public init(
    id: RouteRuleID, order: Int64, enabled: Bool,
    matchingStyle: RouteMatchingStyle, pattern: String,
    destination: RouteDestination
  ) {
    self.id = id
    self.order = order
    self.enabled = enabled
    self.matchingStyle = matchingStyle
    self.pattern = pattern
    self.destination = destination
  }
}

public enum PendingOperationKind: String, Codable, Sendable {
  case profileDataDeletion
}

public enum PendingOperationPhase: String, Codable, Sendable {
  case pending
  case releasing
  case deleting
  case retry
}

public struct PendingOperation: Codable, Equatable, Sendable {
  public var id: PendingOperationID
  public var kind: PendingOperationKind
  public var targetID: UUID
  public var storeID: UUID?
  public var phase: PendingOperationPhase
  public var lastError: String?
  public var attemptAt: Date

  public init(
    id: PendingOperationID, kind: PendingOperationKind,
    targetID: UUID, storeID: UUID?, phase: PendingOperationPhase,
    lastError: String?, attemptAt: Date
  ) {
    self.id = id
    self.kind = kind
    self.targetID = targetID
    self.storeID = storeID
    self.phase = phase
    self.lastError = lastError
    self.attemptAt = attemptAt
  }
}

public enum AppAppearance: String, Codable, Sendable {
  case system
  case light
  case dark
}

public struct ApplicationSettings: Codable, Equatable, Sendable {
  public var defaultProfileID: ProfileID
  public var externalDefaultDestination: RouteDestination
  public var appearance: AppAppearance
  public var archiveRetentionSeconds: TimeInterval
  public var historyRetentionSeconds: TimeInterval

  public init(
    defaultProfileID: ProfileID,
    externalDefaultDestination: RouteDestination,
    appearance: AppAppearance = .system,
    archiveRetentionSeconds: TimeInterval = 30 * 24 * 60 * 60,
    historyRetentionSeconds: TimeInterval = 90 * 24 * 60 * 60
  ) {
    self.defaultProfileID = defaultProfileID
    self.externalDefaultDestination = externalDefaultDestination
    self.appearance = appearance
    self.archiveRetentionSeconds = archiveRetentionSeconds
    self.historyRetentionSeconds = historyRetentionSeconds
  }
}
