import Foundation

public enum InvariantCode: String, Codable, Sendable {
  case i01 = "I01"
  case i02 = "I02"
  case i03 = "I03"
  case i04 = "I04"
  case i05 = "I05"
  case i06 = "I06"
  case i07 = "I07"
  case i08 = "I08"
  case i09 = "I09"
  case i10 = "I10"
  case i11 = "I11"
  case i12 = "I12"
}

public struct WorkspaceValidationError: Error, Equatable, Sendable,
  CustomStringConvertible
{
  public let code: InvariantCode
  public let message: String

  public init(_ code: InvariantCode, _ message: String) {
    self.code = code
    self.message = message
  }

  public var description: String { "\(code.rawValue): \(message)" }
}

public enum WorkspaceValidator {
  public static func validate(
    _ state: WorkspaceState,
    runtime: BrowserRuntimeSnapshot = .empty
  ) throws {
    try validateProfilesAndSpaces(state)
    try validateRootsAndItems(state)
    try validateProfilesAcrossTrees(state)
    try validateTabOwnership(state)
    try validateSplits(state)
    try validateSelections(state)
    try validateFavorites(state)
    try validateArchives(state)
    try validateHistory(state)
    try validateArchiveOwnership(state)
    try validateRuntime(state, runtime)
  }

  private static func validateProfilesAndSpaces(_ state: WorkspaceState) throws {
    guard !state.profiles.isEmpty, !state.spaces.isEmpty else {
      throw WorkspaceValidationError(.i01, "At least one Profile and one Space are required")
    }
    try requireUnique(state.profiles.map(\.id), code: .i01, label: "Profile")
    try requireUnique(state.spaces.map(\.id), code: .i02, label: "Space")

    let profileIDs = Set(state.profiles.map(\.id))
    let stores = state.profiles.map(\.websiteStoreID)
    guard !stores.contains(.domainZero) else {
      throw WorkspaceValidationError(.i02, "Profile website store UUID cannot be zero")
    }
    try requireUnique(stores, code: .i02, label: "Profile website store")
    for space in state.spaces where !profileIDs.contains(space.profileID) {
      throw WorkspaceValidationError(.i02, "Space \(space.id) references a missing Profile")
    }
    guard profileIDs.contains(state.settings.defaultProfileID) else {
      throw WorkspaceValidationError(.i02, "Default Profile is missing")
    }
  }

  private static func validateRootsAndItems(_ state: WorkspaceState) throws {
    try requireUnique(state.roots.map(\.id), code: .i03, label: "Root")
    try requireUnique(state.items.map(\.id), code: .i03, label: "SidebarItem")

    let profiles = Dictionary(uniqueKeysWithValues: state.profiles.map { ($0.id, $0) })
    let spaces = Dictionary(uniqueKeysWithValues: state.spaces.map { ($0.id, $0) })
    let roots = Dictionary(uniqueKeysWithValues: state.roots.map { ($0.id, $0) })
    let items = Dictionary(uniqueKeysWithValues: state.items.map { ($0.id, $0) })

    for root in state.roots {
      switch (root.kind, root.owner) {
      case (.profileFavorites, .profile(let profileID)):
        guard profiles[profileID] != nil else {
          throw WorkspaceValidationError(.i03, "Favorites root owner Profile is missing")
        }
      case (.spacePinned, .space(let spaceID)), (.spaceToday, .space(let spaceID)):
        guard let space = spaces[spaceID] else {
          throw WorkspaceValidationError(.i03, "Space root owner Space is missing")
        }
        switch root.kind {
        case .spacePinned where space.pinnedRootID != root.id:
          throw WorkspaceValidationError(.i03, "Pinned root does not match Space pointer")
        case .spaceToday where space.todayRootID != root.id:
          throw WorkspaceValidationError(.i03, "Today root does not match Space pointer")
        default: break
        }
      default:
        throw WorkspaceValidationError(.i03, "Root kind and owner do not match")
      }
    }

    for space in state.spaces {
      guard let pinned = roots[space.pinnedRootID], pinned.kind == .spacePinned,
        pinned.owner == .space(space.id),
        let today = roots[space.todayRootID], today.kind == .spaceToday,
        today.owner == .space(space.id)
      else {
        throw WorkspaceValidationError(.i03, "Space is missing a typed root")
      }
    }
    for profile in state.profiles {
      let favorites = state.roots.filter {
        $0.kind == .profileFavorites && $0.owner == .profile(profile.id)
      }
      guard favorites.count == 1 else {
        throw WorkspaceValidationError(.i03, "Each Profile must own exactly one Favorites root")
      }
    }

    for item in state.items {
      switch item.parent {
      case .root(let rootID):
        guard let root = roots[rootID] else {
          throw WorkspaceValidationError(.i03, "Item references a missing root")
        }
        if item.kind == .folder && root.kind != .spacePinned {
          throw WorkspaceValidationError(.i03, "Folders may only appear under the Pinned root")
        }
      case .item(let parentID):
        guard let parent = items[parentID] else {
          throw WorkspaceValidationError(.i03, "Item references a missing parent item")
        }
        guard parent.kind == .folder || parent.kind == .split else {
          throw WorkspaceValidationError(.i03, "Only folders and split groups may contain items")
        }
        if parent.kind == .split && item.kind != .tab {
          throw WorkspaceValidationError(.i03, "Split groups may only contain tab items")
        }
        if parent.kind == .folder,
          state.parentRootID(of: parentID).flatMap({ roots[$0] })?.kind != .spacePinned
        {
          throw WorkspaceValidationError(.i03, "Folder descendants must remain under Pinned")
        }
      }

      switch item.kind {
      case .tab:
        guard item.tabID != nil else {
          throw WorkspaceValidationError(.i03, "Tab item is missing its Tab reference")
        }
      case .folder, .split:
        guard item.tabID == nil else {
          throw WorkspaceValidationError(.i03, "Folder or split item cannot reference a Tab")
        }
      }
      if item.kind == .folder, folderDepth(item.id, items: items) > 8 {
        throw WorkspaceValidationError(.i03, "Folder depth exceeds 8")
      }
    }

    for item in state.items {
      guard parentChainHasNoCycle(item.id, items: items) else {
        throw WorkspaceValidationError(.i03, "Sidebar tree contains a cycle")
      }
    }
    for parent in parentKeys(in: state) {
      let siblings = state.children(of: parent)
      let orders = siblings.map(\.orderKey)
      guard Set(orders).count == orders.count else {
        throw WorkspaceValidationError(.i03, "Sibling order keys must be unique")
      }
    }
  }

  private static func validateProfilesAcrossTrees(_ state: WorkspaceState) throws {
    let profileIDs = Set(state.profiles.map(\.id))
    for tab in state.tabs where !profileIDs.contains(tab.profileID) {
      throw WorkspaceValidationError(.i04, "Tab references a missing Profile")
    }
    for item in state.items where item.kind == .tab {
      guard let tabID = item.tabID, let tab = state.tab(tabID),
        let itemProfile = state.profile(forItemID: item.id)
      else {
        throw WorkspaceValidationError(.i04, "Tab item cannot resolve its Profile")
      }
      guard tab.profileID == itemProfile.id else {
        throw WorkspaceValidationError(.i04, "Tab item and Tab Profiles differ")
      }
    }
    for split in state.splitConfigurations {
      guard let profile = state.profile(forItemID: split.itemID) else {
        throw WorkspaceValidationError(.i04, "Split cannot resolve its Profile")
      }
      for child in state.children(of: split.itemID) {
        guard let tabID = child.tabID, let tab = state.tab(tabID),
          tab.profileID == profile.id
        else {
          throw WorkspaceValidationError(.i04, "Split child is outside its Profile")
        }
      }
    }
  }

  private static func validateTabOwnership(_ state: WorkspaceState) throws {
    try requireUnique(state.tabs.map(\.id), code: .i05, label: "Tab")
    let items = Dictionary(uniqueKeysWithValues: state.items.map { ($0.id, $0) })
    let windows = Dictionary(uniqueKeysWithValues: state.windows.map { ($0.id, $0) })
    var referencedTabs = Set<TabID>()

    for item in state.items where item.kind == .tab {
      guard let tabID = item.tabID, referencedTabs.insert(tabID).inserted,
        let tab = state.tab(tabID)
      else {
        throw WorkspaceValidationError(.i05, "A Tab is referenced more than once")
      }
      guard tab.owner == .sidebarItem(item.id) else {
        throw WorkspaceValidationError(.i05, "Tab owner token does not match its item")
      }
    }
    for tab in state.tabs {
      switch tab.owner {
      case .sidebarItem(let itemID):
        guard let item = items[itemID], item.kind == .tab, item.tabID == tab.id else {
          throw WorkspaceValidationError(.i05, "Tab owner item is missing or inconsistent")
        }
      case .littleWindow(let windowID):
        guard let window = windows[windowID], window.kind == .little,
          !referencedTabs.contains(tab.id)
        else {
          throw WorkspaceValidationError(
            .i05, "Little-window Tab has an invalid or duplicate owner")
        }
      }
    }
  }

  private static func validateSplits(_ state: WorkspaceState) throws {
    try requireUnique(state.splitConfigurations.map(\.itemID), code: .i06, label: "Split")
    for split in state.splitConfigurations {
      guard let item = state.item(split.itemID), item.kind == .split else {
        throw WorkspaceValidationError(.i06, "Split configuration has no split item")
      }
      let children = state.children(of: split.itemID)
      guard (2...4).contains(children.count),
        split.weights.count == children.count,
        split.weights.allSatisfy({ $0.isFinite && $0 > 0 }),
        abs(split.weights.reduce(0, +) - 1) < 0.000_001,
        children.contains(where: { $0.id == split.focusedChildItemID })
      else {
        throw WorkspaceValidationError(.i06, "Split must contain 2–4 positive normalized panes")
      }
    }
    for item in state.items where item.kind == .split {
      guard state.split(item.id) != nil else {
        throw WorkspaceValidationError(.i06, "Split item has no configuration")
      }
    }
  }

  private static func validateSelections(_ state: WorkspaceState) throws {
    try requireUnique(state.windows.map(\.id), code: .i07, label: "Window")
    guard !state.windows.isEmpty else {
      throw WorkspaceValidationError(.i07, "At least one WindowSession is required")
    }
    for space in state.spaces {
      if let selected = space.selectedItemID, !state.validSelection(selected, in: space) {
        throw WorkspaceValidationError(.i07, "Space selection points outside its tree")
      }
    }
    let spaces = Dictionary(uniqueKeysWithValues: state.spaces.map { ($0.id, $0) })
    for window in state.windows {
      guard let selectedSpaceID = window.selectedSpaceID,
        let space = spaces[selectedSpaceID]
      else {
        throw WorkspaceValidationError(.i07, "Window selection points to a missing Space")
      }
      if let selected = window.selectedItemID, !state.validSelection(selected, in: space) {
        throw WorkspaceValidationError(.i07, "Window item is outside its selected Space")
      }
      if let pane = window.selectedPaneID {
        guard let split = state.split(space.selectedItemID ?? window.selectedItemID ?? pane),
          state.children(of: split.itemID).contains(where: { $0.id == pane })
        else {
          throw WorkspaceValidationError(.i07, "Selected split pane is invalid")
        }
      }
      for selection in window.lastSelections {
        guard let selectedSpace = spaces[selection.spaceID],
          state.validSelection(selection.itemID, in: selectedSpace)
        else {
          throw WorkspaceValidationError(.i07, "Remembered Space selection is invalid")
        }
      }
    }
  }

  private static func validateFavorites(_ state: WorkspaceState) throws {
    for root in state.roots where root.kind == .profileFavorites {
      let children = state.children(of: .root(root.id))
      guard children.allSatisfy({ $0.kind == .tab }) else {
        throw WorkspaceValidationError(
          .i08, "Favorites root may only contain single-Tab items")
      }
    }
  }

  private static func validateArchives(_ state: WorkspaceState) throws {
    try requireUnique(state.archiveEntries.map(\.id), code: .i09, label: "Archive")
    let profileIDs = Set(state.profiles.map(\.id))
    let spaceIDs = Set(state.spaces.map(\.id))
    for entry in state.archiveEntries {
      guard profileIDs.contains(entry.profileID),
        entry.originSpaceID.map(spaceIDs.contains) ?? true,
        entry.payloadVersion == 1
      else {
        throw WorkspaceValidationError(.i09, "Archive metadata is invalid")
      }
      for node in entry.snapshot.nodes {
        try validateArchivedNode(node)
      }
    }
  }

  private static func validateHistory(_ state: WorkspaceState) throws {
    try requireUnique(state.history.map(\.id), code: .i10, label: "History")
    let profileIDs = Set(state.profiles.map(\.id))
    for visit in state.history {
      guard profileIDs.contains(visit.profileID), isSafeWebURL(visit.url) else {
        throw WorkspaceValidationError(.i10, "History must be Profile-scoped and HTTP(S) only")
      }
    }
  }

  private static func validateArchiveOwnership(_ state: WorkspaceState) throws {
    let activeItems = Set(state.items.map(\.id))
    let activeTabs = Set(state.tabs.map(\.id))
    for entry in state.archiveEntries {
      for node in entry.snapshot.nodes {
        let ids = archivedIdentifiers(node)
        guard ids.items.isDisjoint(with: activeItems),
          ids.tabs.isDisjoint(with: activeTabs)
        else {
          throw WorkspaceValidationError(.i11, "Archived and active ownership overlap")
        }
      }
    }
  }

  private static func validateRuntime(
    _ state: WorkspaceState,
    _ runtime: BrowserRuntimeSnapshot
  ) throws {
    var tabs = Set<TabID>()
    var hosts = Set<BrowserHostID>()
    let profiles = Dictionary(uniqueKeysWithValues: state.profiles.map { ($0.id, $0) })
    for binding in runtime.bindings {
      let identity = binding.identity
      guard tabs.insert(identity.tabID).inserted,
        let tab = state.tab(identity.tabID),
        let profile = profiles[tab.profileID],
        tab.profileID == identity.profileID,
        profile.websiteStoreID == identity.websiteStoreID
      else {
        throw WorkspaceValidationError(.i12, "Runtime binding does not match its Tab/Profile/store")
      }
      if let host = identity.hostID, !hosts.insert(host).inserted {
        throw WorkspaceValidationError(.i12, "A WebView host is bound more than once")
      }
    }
  }

  private static func validateArchivedNode(_ node: ArchivedNode) throws {
    switch node {
    case .tab(_, _, _, let currentURL, let savedURL):
      guard currentURL.map(isSafeWebURL) ?? true,
        savedURL.map(isSafeWebURL) ?? true
      else {
        throw WorkspaceValidationError(.i09, "Archive contains an executable or local URL")
      }
    case .folder(_, _, let children):
      for child in children { try validateArchivedNode(child) }
    case .split(_, _, _, let weights, let children):
      guard (2...4).contains(children.count),
        weights.count == children.count,
        weights.allSatisfy({ $0.isFinite && $0 > 0 }),
        abs(weights.reduce(0, +) - 1) < 0.000_001
      else {
        throw WorkspaceValidationError(.i09, "Archived split is malformed")
      }
      for child in children { try validateArchivedNode(child) }
    }
  }

  private static func archivedIdentifiers(_ node: ArchivedNode)
    -> (items: Set<ItemID>, tabs: Set<TabID>)
  {
    switch node {
    case .tab(let itemID, let tabID, _, _, _):
      return (Set([itemID]), Set([tabID]))
    case .folder(let itemID, _, let children), .split(let itemID, _, _, _, let children):
      var items: Set<ItemID> = [itemID]
      var tabs = Set<TabID>()
      for child in children {
        let nested = archivedIdentifiers(child)
        items.formUnion(nested.items)
        tabs.formUnion(nested.tabs)
      }
      return (items, tabs)
    }
  }

  private static func folderDepth(
    _ itemID: ItemID,
    items: [ItemID: SidebarItem]
  ) -> Int {
    var depth = 0
    var current = items[itemID]
    var visited = Set<ItemID>()
    while let value = current {
      guard visited.insert(value.id).inserted else { return .max }
      if value.kind == .folder { depth += 1 }
      switch value.parent {
      case .root: return depth
      case .item(let parentID): current = items[parentID]
      }
    }
    return depth
  }

  private static func parentChainHasNoCycle(
    _ itemID: ItemID,
    items: [ItemID: SidebarItem]
  ) -> Bool {
    var visited = Set<ItemID>()
    var current: ItemID? = itemID
    while let value = current {
      guard visited.insert(value).inserted else { return false }
      switch items[value]?.parent {
      case .item(let parentID): current = parentID
      default: return true
      }
    }
    return true
  }

  private static func parentKeys(in state: WorkspaceState) -> [SidebarParent] {
    let roots = state.roots.map { SidebarParent.root($0.id) }
    let items = state.items.map { SidebarParent.item($0.id) }
    return roots + items
  }

  private static func requireUnique<T: Hashable>(
    _ values: [T], code: InvariantCode,
    label: String
  ) throws {
    guard Set(values).count == values.count else {
      throw WorkspaceValidationError(code, "\(label) identifiers must be unique")
    }
  }

  private static func isSafeWebURL(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
  }
}
