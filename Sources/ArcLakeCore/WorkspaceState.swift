import Foundation

public struct WorkspaceState: Codable, Equatable, Sendable {
  public var revision: Int64
  public var profiles: [Profile]
  public var spaces: [Space]
  public var roots: [RootContainer]
  public var items: [SidebarItem]
  public var tabs: [Tab]
  public var splitConfigurations: [SplitConfiguration]
  public var windows: [WindowSession]
  public var archiveEntries: [ArchiveEntry]
  public var history: [HistoryVisit]
  public var routeRules: [RouteRule]
  public var pendingOperations: [PendingOperation]
  public var settings: ApplicationSettings

  public init(
    revision: Int64, profiles: [Profile], spaces: [Space],
    roots: [RootContainer], items: [SidebarItem], tabs: [Tab],
    splitConfigurations: [SplitConfiguration],
    windows: [WindowSession], archiveEntries: [ArchiveEntry] = [],
    history: [HistoryVisit] = [], routeRules: [RouteRule] = [],
    pendingOperations: [PendingOperation] = [],
    settings: ApplicationSettings
  ) {
    self.revision = revision
    self.profiles = profiles
    self.spaces = spaces
    self.roots = roots
    self.items = items
    self.tabs = tabs
    self.splitConfigurations = splitConfigurations
    self.windows = windows
    self.archiveEntries = archiveEntries
    self.history = history
    self.routeRules = routeRules
    self.pendingOperations = pendingOperations
    self.settings = settings
  }

  public static func == (lhs: WorkspaceState, rhs: WorkspaceState) -> Bool {
    lhs.revision == rhs.revision
      && lhs.profiles.sorted(by: { $0.id < $1.id })
        == rhs.profiles.sorted(by: { $0.id < $1.id })
      && lhs.spaces.sorted(by: { $0.id < $1.id })
        == rhs.spaces.sorted(by: { $0.id < $1.id })
      && lhs.roots.sorted(by: { $0.id < $1.id })
        == rhs.roots.sorted(by: { $0.id < $1.id })
      && lhs.items.sorted(by: { $0.id < $1.id })
        == rhs.items.sorted(by: { $0.id < $1.id })
      && lhs.tabs.sorted(by: { $0.id < $1.id })
        == rhs.tabs.sorted(by: { $0.id < $1.id })
      && lhs.splitConfigurations.sorted(by: { $0.itemID < $1.itemID })
        == rhs.splitConfigurations.sorted(by: { $0.itemID < $1.itemID })
      && lhs.windows.sorted(by: { $0.id < $1.id })
        == rhs.windows.sorted(by: { $0.id < $1.id })
      && lhs.archiveEntries.sorted(by: { $0.id < $1.id })
        == rhs.archiveEntries.sorted(by: { $0.id < $1.id })
      && lhs.history.sorted(by: { $0.id < $1.id })
        == rhs.history.sorted(by: { $0.id < $1.id })
      && lhs.routeRules.sorted(by: { $0.id < $1.id })
        == rhs.routeRules.sorted(by: { $0.id < $1.id })
      && lhs.pendingOperations.sorted(by: { $0.id < $1.id })
        == rhs.pendingOperations.sorted(by: { $0.id < $1.id })
      && lhs.settings == rhs.settings
  }

  public func profile(_ id: ProfileID) -> Profile? {
    profiles.first { $0.id == id }
  }

  public func space(_ id: SpaceID) -> Space? {
    spaces.first { $0.id == id }
  }

  public func root(_ id: RootID) -> RootContainer? {
    roots.first { $0.id == id }
  }

  public func item(_ id: ItemID) -> SidebarItem? {
    items.first { $0.id == id }
  }

  public func tab(_ id: TabID) -> Tab? {
    tabs.first { $0.id == id }
  }

  public func window(_ id: WindowID) -> WindowSession? {
    windows.first { $0.id == id }
  }

  public func split(_ itemID: ItemID) -> SplitConfiguration? {
    splitConfigurations.first { $0.itemID == itemID }
  }

  public func children(of parent: SidebarParent) -> [SidebarItem] {
    items.filter { $0.parent == parent }.sorted(by: SidebarItem.order)
  }

  public func children(of itemID: ItemID) -> [SidebarItem] {
    children(of: .item(itemID))
  }

  public func parentRootID(of itemID: ItemID) -> RootID? {
    var current = item(itemID)
    var visited = Set<ItemID>()
    while let value = current {
      guard visited.insert(value.id).inserted else { return nil }
      switch value.parent {
      case .root(let rootID): return rootID
      case .item(let parentID): current = item(parentID)
      }
    }
    return nil
  }

  public func region(of itemID: ItemID) -> SpaceRegion? {
    guard let rootID = parentRootID(of: itemID), let root = root(rootID) else { return nil }
    return root.region
  }

  public func space(containing itemID: ItemID) -> Space? {
    guard let rootID = parentRootID(of: itemID), let root = root(rootID) else { return nil }
    switch root.owner {
    case .space(let spaceID): return space(spaceID)
    case .profile: return nil
    }
  }

  public func profile(forRootID rootID: RootID) -> Profile? {
    guard let root = root(rootID) else { return nil }
    switch root.owner {
    case .profile(let profileID): return profile(profileID)
    case .space(let spaceID):
      guard let space = space(spaceID) else { return nil }
      return profile(space.profileID)
    }
  }

  public func profile(forItemID itemID: ItemID) -> Profile? {
    guard let rootID = parentRootID(of: itemID) else { return nil }
    return profile(forRootID: rootID)
  }

  public func favoritesRoot(for profileID: ProfileID) -> RootContainer? {
    roots.first {
      $0.kind == .profileFavorites && $0.owner == .profile(profileID)
    }
  }

  public func fallbackSelection(in spaceID: SpaceID) -> ItemID? {
    guard let space = space(spaceID) else { return nil }
    if let selected = space.selectedItemID, validSelection(selected, in: space) {
      return selected
    }
    if let today = children(of: .root(space.todayRootID)).first { return today.id }
    return children(of: .root(space.pinnedRootID)).first?.id
  }

  public func validSelection(_ itemID: ItemID, in space: Space) -> Bool {
    guard item(itemID) != nil else { return false }
    return self.space(containing: itemID)?.id == space.id
  }

  public mutating func removeItemSubtree(_ itemID: ItemID) {
    let descendants = descendantItemIDs(of: itemID)
    let ids = descendants.union([itemID])
    let tabIDs = Set(items.filter { ids.contains($0.id) }.compactMap(\.tabID))
    items.removeAll { ids.contains($0.id) }
    tabs.removeAll { tabIDs.contains($0.id) }
    splitConfigurations.removeAll { ids.contains($0.itemID) }
  }

  public func descendantItemIDs(of itemID: ItemID) -> Set<ItemID> {
    var result = Set<ItemID>()
    var stack = children(of: itemID).map(\.id)
    while let next = stack.popLast() {
      guard result.insert(next).inserted else { continue }
      stack.append(contentsOf: children(of: next).map(\.id))
    }
    return result
  }
}

extension RootContainer {
  public var region: SpaceRegion {
    switch kind {
    case .profileFavorites: .favorites
    case .spacePinned: .pinned
    case .spaceToday: .today
    }
  }
}

extension SidebarItem {
  public static func order(_ lhs: SidebarItem, _ rhs: SidebarItem) -> Bool {
    if lhs.orderKey != rhs.orderKey { return lhs.orderKey < rhs.orderKey }
    return lhs.id < rhs.id
  }
}

public struct WorkspaceBootstrapIDs: Equatable, Sendable {
  public var profileID: ProfileID
  public var spaceID: SpaceID
  public var favoritesRootID: RootID
  public var pinnedRootID: RootID
  public var todayRootID: RootID
  public var windowID: WindowID
  public var websiteStoreID: UUID

  public init(
    profileID: ProfileID = ProfileID(), spaceID: SpaceID = SpaceID(),
    favoritesRootID: RootID = RootID(), pinnedRootID: RootID = RootID(),
    todayRootID: RootID = RootID(), windowID: WindowID = WindowID(),
    websiteStoreID: UUID = UUID()
  ) {
    self.profileID = profileID
    self.spaceID = spaceID
    self.favoritesRootID = favoritesRootID
    self.pinnedRootID = pinnedRootID
    self.todayRootID = todayRootID
    self.windowID = windowID
    self.websiteStoreID = websiteStoreID
  }
}

public enum WorkspaceBootstrap {
  public static func initialState(
    ids: WorkspaceBootstrapIDs,
    now: Date = Date()
  ) -> WorkspaceState {
    let profile = Profile(
      id: ids.profileID, name: "Default",
      websiteStoreID: ids.websiteStoreID, createdAt: now)
    let space = Space(
      id: ids.spaceID, profileID: ids.profileID,
      name: "Default", icon: "circle",
      theme: SpaceTheme(), sortOrder: 0,
      pinnedRootID: ids.pinnedRootID,
      todayRootID: ids.todayRootID)
    let roots = [
      RootContainer(
        id: ids.favoritesRootID, kind: .profileFavorites,
        owner: .profile(ids.profileID)),
      RootContainer(
        id: ids.pinnedRootID, kind: .spacePinned,
        owner: .space(ids.spaceID)),
      RootContainer(
        id: ids.todayRootID, kind: .spaceToday,
        owner: .space(ids.spaceID)),
    ]
    let window = WindowSession(
      id: ids.windowID, kind: .main,
      selectedSpaceID: ids.spaceID)
    let settings = ApplicationSettings(
      defaultProfileID: ids.profileID,
      externalDefaultDestination: .littleWindow(ids.profileID))
    return WorkspaceState(
      revision: 1,
      profiles: [profile],
      spaces: [space],
      roots: roots,
      items: [],
      tabs: [],
      splitConfigurations: [],
      windows: [window],
      settings: settings
    )
  }
}
