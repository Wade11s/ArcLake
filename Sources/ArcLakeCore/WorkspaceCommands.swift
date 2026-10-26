import Foundation

public enum RenameTarget: Equatable, Sendable {
  case profile(ProfileID)
  case space(SpaceID)
  case item(ItemID)
}

public enum WorkspaceCommand: Equatable, Sendable {
  case createProfile(
    ProfileID, favoritesRootID: RootID, name: String,
    websiteStoreID: UUID, createdAt: Date)
  case createSpace(
    SpaceID, profileID: ProfileID, pinnedRootID: RootID,
    todayRootID: RootID, name: String, icon: String,
    theme: SpaceTheme, sortOrder: Int64)
  case createTab(
    TabID, itemID: ItemID, spaceID: SpaceID,
    parent: SidebarParent, url: URL?, title: String?,
    orderKey: Int64, createdAt: Date)
  case createFolder(
    ItemID, spaceID: SpaceID, parent: SidebarParent,
    name: String, orderKey: Int64)
  case moveItem(ItemID, destination: SidebarParent, orderKey: Int64)
  case pinItem(ItemID, spaceID: SpaceID, at: Date)
  case unpinItem(ItemID, at: Date)
  case favoriteItem(ItemID, currentSpaceID: SpaceID)
  case unfavoriteItem(ItemID, currentSpaceID: SpaceID, at: Date)
  case rename(RenameTarget, value: String)
  case switchSpace(WindowID, SpaceID)
  case selectItem(WindowID, ItemID, at: Date)
  case activateItem(ItemID, windowID: WindowID, at: Date)
  case navigateTab(TabID, url: URL, title: String?, at: Date)
  case releasePinnedTab(TabID)
  case resetPinnedItem(ItemID, at: Date)
}

public enum WorkspaceEffect: Equatable, Sendable {
  case loadTab(TabID, URL)
  case releaseTab(TabID)
  case showEmptySpace(SpaceID)
  case spaceChanged(SpaceID)
  case itemActivated(ItemID)
}

public struct WorkspaceDecision: Equatable, Sendable {
  public var state: WorkspaceState
  public var effects: [WorkspaceEffect]

  public init(state: WorkspaceState, effects: [WorkspaceEffect]) {
    self.state = state
    self.effects = effects
  }
}

public enum WorkspaceCommandError: Error, Equatable, Sendable,
  CustomStringConvertible
{
  case duplicateIdentifier(String)
  case unknownProfile(ProfileID)
  case profileDeleting(ProfileID)
  case unknownSpace(SpaceID)
  case unknownRoot(RootID)
  case unknownItem(ItemID)
  case unknownTab(TabID)
  case unknownWindow(WindowID)
  case invalidName
  case invalidStoreID
  case invalidURL
  case crossProfileMove
  case invalidDestination
  case cannotMoveIntoSelf
  case cannotMoveIntoDescendant
  case folderDestinationRestricted
  case splitPaneMoveUnsupported
  case favoritesOccupied
  case itemNotInExpectedRegion
  case folderUnpinUnsupported
  case lastSpaceRequired

  public var description: String {
    switch self {
    case .duplicateIdentifier(let value): "Identifier already exists: \(value)"
    case .unknownProfile(let id): "Unknown Profile: \(id)"
    case .profileDeleting(let id): "Profile is deleting: \(id)"
    case .unknownSpace(let id): "Unknown Space: \(id)"
    case .unknownRoot(let id): "Unknown root: \(id)"
    case .unknownItem(let id): "Unknown item: \(id)"
    case .unknownTab(let id): "Unknown Tab: \(id)"
    case .unknownWindow(let id): "Unknown Window: \(id)"
    case .invalidName: "Name must be non-empty and at most 200 characters"
    case .invalidStoreID: "Website store UUID must be non-zero and unique"
    case .invalidURL: "Only HTTP(S) URLs are accepted"
    case .crossProfileMove: "Items may only move within the same Profile"
    case .invalidDestination: "The destination cannot contain this item"
    case .cannotMoveIntoSelf: "An item cannot move into itself"
    case .cannotMoveIntoDescendant: "An item cannot move into its descendant"
    case .folderDestinationRestricted: "Folders may only live under Pinned"
    case .splitPaneMoveUnsupported: "Split pane restructuring is not part of M1"
    case .favoritesOccupied: "Favorites already contains its single M1 tab"
    case .itemNotInExpectedRegion: "Item is not in the expected region"
    case .folderUnpinUnsupported: "A Folder cannot be moved directly to Today"
    case .lastSpaceRequired: "The last Space cannot be removed"
    }
  }
}

public enum Workspace {
  public static func decide(
    state: WorkspaceState,
    command: WorkspaceCommand
  ) throws -> WorkspaceDecision {
    var next = state
    var effects: [WorkspaceEffect] = []

    switch command {
    case .createProfile(let id, let favoritesRootID, let name, let storeID, let createdAt):
      try createProfile(
        &next, id: id, favoritesRootID: favoritesRootID,
        name: name, storeID: storeID, createdAt: createdAt)

    case .createSpace(
      let id, let profileID, let pinnedRootID, let todayRootID,
      let
        name, let icon, let theme, let sortOrder):
      try createSpace(
        &next, id: id, profileID: profileID,
        pinnedRootID: pinnedRootID, todayRootID: todayRootID,
        name: name, icon: icon, theme: theme, sortOrder: sortOrder)

    case .createTab(
      let tabID, let itemID, let spaceID, let parent, let url, let title, let orderKey,
      let createdAt):
      try createTab(
        &next, tabID: tabID, itemID: itemID, spaceID: spaceID,
        parent: parent, url: url, title: title,
        orderKey: orderKey, createdAt: createdAt)

    case .createFolder(let itemID, let spaceID, let parent, let name, let orderKey):
      try createFolder(
        &next, itemID: itemID, spaceID: spaceID,
        parent: parent, name: name, orderKey: orderKey)

    case .moveItem(let itemID, let destination, let orderKey):
      try moveItem(&next, itemID: itemID, destination: destination, orderKey: orderKey)

    case .pinItem(let itemID, let spaceID, let date):
      effects = try pinItem(&next, itemID: itemID, spaceID: spaceID, at: date)

    case .unpinItem(let itemID, let date):
      effects = try unpinItem(&next, itemID: itemID, at: date)

    case .favoriteItem(let itemID, let currentSpaceID):
      try favoriteItem(&next, itemID: itemID, currentSpaceID: currentSpaceID)

    case .unfavoriteItem(let itemID, let currentSpaceID, let date):
      try unfavoriteItem(
        &next, itemID: itemID,
        currentSpaceID: currentSpaceID, at: date)

    case .rename(let target, let value):
      try rename(&next, target: target, value: value)

    case .switchSpace(let windowID, let spaceID):
      effects = try switchSpace(&next, windowID: windowID, spaceID: spaceID)

    case .selectItem(let windowID, let itemID, let date):
      try selectItem(&next, windowID: windowID, itemID: itemID, at: date)

    case .activateItem(let itemID, let windowID, let date):
      effects = try activateItem(
        &next, itemID: itemID,
        windowID: windowID, at: date)

    case .navigateTab(let tabID, let url, let title, let date):
      try navigateTab(&next, tabID: tabID, url: url, title: title, at: date)

    case .releasePinnedTab(let tabID):
      effects = try releasePinnedTab(&next, tabID: tabID)

    case .resetPinnedItem(let itemID, let date):
      effects = try resetPinnedItem(&next, itemID: itemID, at: date)
    }

    next.revision = state.revision + 1
    try WorkspaceValidator.validate(next)
    return WorkspaceDecision(state: next, effects: effects)
  }

  private static func createProfile(
    _ state: inout WorkspaceState,
    id: ProfileID, favoritesRootID: RootID,
    name: String, storeID: UUID,
    createdAt: Date
  ) throws {
    try validateName(name)
    guard storeID != .domainZero,
      !state.profiles.contains(where: { $0.websiteStoreID == storeID })
    else {
      throw WorkspaceCommandError.invalidStoreID
    }
    guard !state.profiles.contains(where: { $0.id == id }),
      !state.roots.contains(where: { $0.id == favoritesRootID })
    else {
      throw WorkspaceCommandError.duplicateIdentifier("Profile or favorites root")
    }
    state.profiles.append(
      Profile(
        id: id, name: name,
        websiteStoreID: storeID, createdAt: createdAt))
    state.roots.append(
      RootContainer(
        id: favoritesRootID,
        kind: .profileFavorites,
        owner: .profile(id)))
  }

  private static func createSpace(
    _ state: inout WorkspaceState,
    id: SpaceID, profileID: ProfileID,
    pinnedRootID: RootID, todayRootID: RootID,
    name: String, icon: String,
    theme: SpaceTheme, sortOrder: Int64
  ) throws {
    try validateName(name)
    try requireActiveProfile(profileID, in: state)
    guard !state.spaces.contains(where: { $0.id == id }),
      !state.roots.contains(where: { $0.id == pinnedRootID || $0.id == todayRootID }),
      pinnedRootID != todayRootID
    else {
      throw WorkspaceCommandError.duplicateIdentifier("Space or Space root")
    }
    state.spaces.append(
      Space(
        id: id, profileID: profileID, name: name, icon: icon,
        theme: theme, sortOrder: sortOrder,
        pinnedRootID: pinnedRootID, todayRootID: todayRootID
      ))
    state.roots.append(
      RootContainer(
        id: pinnedRootID, kind: .spacePinned,
        owner: .space(id)))
    state.roots.append(
      RootContainer(
        id: todayRootID, kind: .spaceToday,
        owner: .space(id)))
  }

  private static func createTab(
    _ state: inout WorkspaceState,
    tabID: TabID, itemID: ItemID, spaceID: SpaceID,
    parent: SidebarParent, url: URL?, title: String?,
    orderKey: Int64, createdAt: Date
  ) throws {
    guard let space = state.space(spaceID) else {
      throw WorkspaceCommandError.unknownSpace(spaceID)
    }
    try requireActiveProfile(space.profileID, in: state)
    guard state.item(itemID) == nil,
      state.tab(tabID) == nil
    else {
      throw WorkspaceCommandError.duplicateIdentifier("Tab or item")
    }
    try validateWebURL(url)
    try validateDestination(
      parent, space: space, in: state,
      adding: .tab)
    insertOrder(&state, parent: parent, orderKey: orderKey)
    state.items.append(
      SidebarItem(
        id: itemID, parent: parent, orderKey: orderKey, kind: .tab,
        tabID: tabID))
    state.tabs.append(
      Tab(
        id: tabID, profileID: space.profileID, currentURL: url,
        pageTitle: title, lastActiveAt: createdAt,
        createdAt: createdAt, owner: .sidebarItem(itemID)))
  }

  private static func createFolder(
    _ state: inout WorkspaceState,
    itemID: ItemID, spaceID: SpaceID,
    parent: SidebarParent, name: String,
    orderKey: Int64
  ) throws {
    guard let space = state.space(spaceID) else {
      throw WorkspaceCommandError.unknownSpace(spaceID)
    }
    try requireActiveProfile(space.profileID, in: state)
    guard state.item(itemID) == nil else {
      throw WorkspaceCommandError.duplicateIdentifier("Item")
    }
    try validateName(name)
    try validateDestination(parent, space: space, in: state, adding: .folder)
    insertOrder(&state, parent: parent, orderKey: orderKey)
    state.items.append(
      SidebarItem(
        id: itemID, parent: parent, orderKey: orderKey,
        kind: .folder, customTitle: name))
  }

  private static func moveItem(
    _ state: inout WorkspaceState,
    itemID: ItemID,
    destination: SidebarParent,
    orderKey: Int64
  ) throws {
    guard let item = state.item(itemID) else {
      throw WorkspaceCommandError.unknownItem(itemID)
    }
    if case .item(let parentID) = item.parent,
      state.item(parentID)?.kind == .split
    {
      throw WorkspaceCommandError.splitPaneMoveUnsupported
    }
    if destination == .item(itemID) {
      throw WorkspaceCommandError.cannotMoveIntoSelf
    }
    if case .item(let destinationID) = destination {
      guard state.item(destinationID) != nil else {
        throw WorkspaceCommandError.unknownItem(destinationID)
      }
      if state.item(destinationID)?.kind == .split {
        throw WorkspaceCommandError.splitPaneMoveUnsupported
      }
      if state.descendantItemIDs(of: itemID).contains(destinationID) {
        throw WorkspaceCommandError.cannotMoveIntoDescendant
      }
    }
    guard let sourceProfile = state.profile(forItemID: itemID),
      let destinationProfile = profile(for: destination, in: state)
    else {
      throw WorkspaceCommandError.invalidDestination
    }
    guard sourceProfile.id == destinationProfile.id else {
      throw WorkspaceCommandError.crossProfileMove
    }
    try requireActiveProfile(destinationProfile.id, in: state)
    if item.kind == .folder {
      guard destinationRegion(destination, in: state) == .pinned else {
        throw WorkspaceCommandError.folderDestinationRestricted
      }
    }
    insertOrder(&state, parent: destination, orderKey: orderKey, excluding: itemID)
    guard let index = state.items.firstIndex(where: { $0.id == itemID }) else {
      throw WorkspaceCommandError.unknownItem(itemID)
    }
    state.items[index].parent = destination
    state.items[index].orderKey = orderKey
    updateSelectionsAfterRemoval(&state, removedItemID: itemID)
  }

  private static func pinItem(
    _ state: inout WorkspaceState,
    itemID: ItemID, spaceID: SpaceID,
    at date: Date
  ) throws -> [WorkspaceEffect] {
    guard let space = state.space(spaceID) else {
      throw WorkspaceCommandError.unknownSpace(spaceID)
    }
    guard let item = state.item(itemID) else {
      throw WorkspaceCommandError.unknownItem(itemID)
    }
    guard item.parent == .root(space.todayRootID) else {
      throw WorkspaceCommandError.itemNotInExpectedRegion
    }
    if item.kind == .folder {
      throw WorkspaceCommandError.folderDestinationRestricted
    }
    let order = (state.children(of: .root(space.pinnedRootID)).map(\.orderKey).max() ?? -1) + 1
    try moveItem(
      &state, itemID: itemID,
      destination: .root(space.pinnedRootID), orderKey: order)
    let leafTabs = tabIDs(in: itemID, state: state)
    for tabID in leafTabs {
      if let index = state.tabs.firstIndex(where: { $0.id == tabID }) {
        state.tabs[index].savedURL =
          state.tabs[index].currentURL
          ?? state.tabs[index].savedURL
        state.tabs[index].lastActiveAt = date
      }
    }
    return []
  }

  private static func unpinItem(
    _ state: inout WorkspaceState,
    itemID: ItemID, at date: Date
  ) throws -> [WorkspaceEffect] {
    guard let item = state.item(itemID),
      let space = state.space(containing: itemID)
    else {
      throw WorkspaceCommandError.unknownItem(itemID)
    }
    guard state.region(of: itemID) == .pinned else {
      throw WorkspaceCommandError.itemNotInExpectedRegion
    }
    if item.kind == .folder {
      throw WorkspaceCommandError.folderUnpinUnsupported
    }
    let order = (state.children(of: .root(space.todayRootID)).map(\.orderKey).max() ?? -1) + 1
    try moveItem(
      &state, itemID: itemID,
      destination: .root(space.todayRootID), orderKey: order)
    for tabID in tabIDs(in: itemID, state: state) {
      if let index = state.tabs.firstIndex(where: { $0.id == tabID }) {
        state.tabs[index].lastActiveAt = date
      }
    }
    return []
  }

  private static func favoriteItem(
    _ state: inout WorkspaceState,
    itemID: ItemID,
    currentSpaceID: SpaceID
  ) throws {
    guard let item = state.item(itemID),
      let profile = state.profile(forItemID: itemID),
      let currentSpace = state.space(currentSpaceID),
      currentSpace.profileID == profile.id,
      item.kind == .tab
    else {
      throw WorkspaceCommandError.itemNotInExpectedRegion
    }
    guard let favoritesRoot = state.favoritesRoot(for: profile.id) else {
      throw WorkspaceCommandError.invalidDestination
    }
    if !state.children(of: .root(favoritesRoot.id)).isEmpty {
      throw WorkspaceCommandError.favoritesOccupied
    }
    let order = (state.children(of: .root(favoritesRoot.id)).map(\.orderKey).max() ?? -1) + 1
    try moveItem(
      &state, itemID: itemID,
      destination: .root(favoritesRoot.id), orderKey: order)
  }

  private static func unfavoriteItem(
    _ state: inout WorkspaceState,
    itemID: ItemID, currentSpaceID: SpaceID,
    at date: Date
  ) throws {
    guard state.item(itemID) != nil,
      let currentSpace = state.space(currentSpaceID),
      let profile = state.profile(forItemID: itemID),
      profile.id == currentSpace.profileID,
      state.region(of: itemID) == .favorites
    else {
      throw WorkspaceCommandError.itemNotInExpectedRegion
    }
    let order =
      (state.children(of: .root(currentSpace.todayRootID)).map(\.orderKey).max() ?? -1) + 1
    try moveItem(
      &state, itemID: itemID,
      destination: .root(currentSpace.todayRootID), orderKey: order)
    if let tabID = state.item(itemID)?.tabID,
      let index = state.tabs.firstIndex(where: { $0.id == tabID })
    {
      state.tabs[index].lastActiveAt = date
    }
  }

  private static func rename(
    _ state: inout WorkspaceState,
    target: RenameTarget, value: String
  ) throws {
    try validateName(value)
    switch target {
    case .profile(let profileID):
      guard let index = state.profiles.firstIndex(where: { $0.id == profileID }) else {
        throw WorkspaceCommandError.unknownProfile(profileID)
      }
      state.profiles[index].name = value
    case .space(let spaceID):
      guard let index = state.spaces.firstIndex(where: { $0.id == spaceID }) else {
        throw WorkspaceCommandError.unknownSpace(spaceID)
      }
      state.spaces[index].name = value
    case .item(let itemID):
      guard let index = state.items.firstIndex(where: { $0.id == itemID }) else {
        throw WorkspaceCommandError.unknownItem(itemID)
      }
      state.items[index].customTitle = value
    }
  }

  private static func switchSpace(
    _ state: inout WorkspaceState,
    windowID: WindowID,
    spaceID: SpaceID
  ) throws -> [WorkspaceEffect] {
    guard let windowIndex = state.windows.firstIndex(where: { $0.id == windowID }) else {
      throw WorkspaceCommandError.unknownWindow(windowID)
    }
    guard let space = state.space(spaceID) else {
      throw WorkspaceCommandError.unknownSpace(spaceID)
    }
    guard let spaceIndex = state.spaces.firstIndex(where: { $0.id == spaceID }) else {
      throw WorkspaceCommandError.unknownSpace(spaceID)
    }
    try requireActiveProfile(space.profileID, in: state)
    if let oldSpaceID = state.windows[windowIndex].selectedSpaceID,
      let oldItemID = state.windows[windowIndex].selectedItemID,
      let oldSpace = state.space(oldSpaceID)
    {
      let remembered = SpaceSelection(spaceID: oldSpaceID, itemID: oldItemID)
      state.windows[windowIndex].lastSelections.removeAll {
        $0.spaceID == oldSpaceID
      }
      if state.validSelection(oldItemID, in: oldSpace) {
        state.windows[windowIndex].lastSelections.append(remembered)
      }
    }
    let remembered = state.windows[windowIndex].lastSelections.first {
      $0.spaceID == spaceID
    }?.itemID
    let selected =
      remembered.flatMap { itemID in
        state.validSelection(itemID, in: space) ? itemID : nil
      } ?? space.selectedItemID ?? state.fallbackSelection(in: spaceID)
    state.spaces[spaceIndex].selectedItemID = selected
    state.windows[windowIndex].selectedSpaceID = spaceID
    state.windows[windowIndex].selectedItemID = selected
    state.windows[windowIndex].selectedPaneID = selected.flatMap {
      state.split($0)?.focusedChildItemID
    }
    var effects: [WorkspaceEffect] = [.spaceChanged(spaceID)]
    if let selected {
      effects.append(.itemActivated(selected))
    } else {
      effects.append(.showEmptySpace(spaceID))
    }
    return effects
  }

  private static func selectItem(
    _ state: inout WorkspaceState,
    windowID: WindowID, itemID: ItemID,
    at date: Date
  ) throws {
    guard let windowIndex = state.windows.firstIndex(where: { $0.id == windowID }) else {
      throw WorkspaceCommandError.unknownWindow(windowID)
    }
    guard let space = state.space(containing: itemID),
      let spaceIndex = state.spaces.firstIndex(where: { $0.id == space.id })
    else {
      throw WorkspaceCommandError.unknownItem(itemID)
    }
    state.spaces[spaceIndex].selectedItemID = itemID
    state.windows[windowIndex].selectedSpaceID = space.id
    state.windows[windowIndex].selectedItemID = itemID
    state.windows[windowIndex].selectedPaneID = state.split(itemID)?.focusedChildItemID
    let leaves = tabIDs(in: itemID, state: state)
    for tabID in leaves {
      if let index = state.tabs.firstIndex(where: { $0.id == tabID }) {
        state.tabs[index].lastActiveAt = date
      }
    }
  }

  private static func activateItem(
    _ state: inout WorkspaceState,
    itemID: ItemID, windowID: WindowID,
    at date: Date
  ) throws -> [WorkspaceEffect] {
    try selectItem(&state, windowID: windowID, itemID: itemID, at: date)
    let tabIDs = tabIDs(in: itemID, state: state)
    var effects: [WorkspaceEffect] = [.itemActivated(itemID)]
    if tabIDs.isEmpty {
      if let space = state.space(containing: itemID) {
        effects.append(.showEmptySpace(space.id))
      }
      return effects
    }
    for tabID in tabIDs {
      guard let tab = state.tab(tabID),
        let url = state.region(of: itemID) == .pinned
          ? (tab.savedURL ?? tab.currentURL)
          : (tab.currentURL ?? tab.savedURL)
      else { continue }
      effects.append(.loadTab(tabID, url))
    }
    return effects
  }

  private static func navigateTab(
    _ state: inout WorkspaceState,
    tabID: TabID, url: URL, title: String?,
    at date: Date
  ) throws {
    guard isSafeWebURL(url) else {
      throw WorkspaceCommandError.invalidURL
    }
    guard let index = state.tabs.firstIndex(where: { $0.id == tabID }) else {
      throw WorkspaceCommandError.unknownTab(tabID)
    }
    state.tabs[index].currentURL = url
    if let title { state.tabs[index].pageTitle = title }
    state.tabs[index].lastActiveAt = date
  }

  private static func releasePinnedTab(
    _ state: inout WorkspaceState,
    tabID: TabID
  ) throws -> [WorkspaceEffect] {
    guard let tab = state.tab(tabID) else {
      throw WorkspaceCommandError.unknownTab(tabID)
    }
    guard case .sidebarItem(let itemID) = tab.owner,
      state.region(of: itemID) == .pinned
    else {
      throw WorkspaceCommandError.itemNotInExpectedRegion
    }
    if let index = state.tabs.firstIndex(where: { $0.id == tabID }) {
      state.tabs[index].currentURL = nil
    }
    return [.releaseTab(tabID)]
  }

  private static func resetPinnedItem(
    _ state: inout WorkspaceState,
    itemID: ItemID,
    at date: Date
  ) throws -> [WorkspaceEffect] {
    guard state.item(itemID) != nil,
      state.region(of: itemID) == .pinned
    else {
      throw WorkspaceCommandError.itemNotInExpectedRegion
    }
    var effects: [WorkspaceEffect] = [.itemActivated(itemID)]
    for tabID in tabIDs(in: itemID, state: state) {
      guard let index = state.tabs.firstIndex(where: { $0.id == tabID }),
        let savedURL = state.tabs[index].savedURL
      else { continue }
      state.tabs[index].currentURL = savedURL
      state.tabs[index].lastActiveAt = date
      effects.append(.loadTab(tabID, savedURL))
    }
    return effects
  }

  private static func validateDestination(
    _ parent: SidebarParent,
    space: Space,
    in state: WorkspaceState,
    adding kind: SidebarItemKind
  ) throws {
    switch parent {
    case .root(let rootID):
      guard let root = state.root(rootID) else {
        throw WorkspaceCommandError.unknownRoot(rootID)
      }
      guard root.owner == .space(space.id) || root.owner == .profile(space.profileID) else {
        throw WorkspaceCommandError.invalidDestination
      }
      if root.kind == .spaceToday && kind == .folder {
        throw WorkspaceCommandError.folderDestinationRestricted
      }
      if root.kind == .profileFavorites {
        guard kind == .tab,
          state.children(of: parent).isEmpty
        else {
          throw WorkspaceCommandError.favoritesOccupied
        }
      }
    case .item(let parentID):
      guard let parentItem = state.item(parentID),
        let spaceID = state.space(containing: parentID)?.id,
        spaceID == space.id
      else {
        throw WorkspaceCommandError.unknownItem(parentID)
      }
      guard parentItem.kind == .folder else {
        throw WorkspaceCommandError.invalidDestination
      }
      if kind == .folder {
        let depth = folderDepth(parentID, state: state) + 1
        guard depth <= 8 else {
          throw WorkspaceCommandError.invalidDestination
        }
      }
    }
  }

  private static func insertOrder(
    _ state: inout WorkspaceState,
    parent: SidebarParent, orderKey: Int64,
    excluding excludedItem: ItemID? = nil
  ) {
    for index in state.items.indices
    where
      state.items[index].parent == parent
      && state.items[index].id != excludedItem
      && state.items[index].orderKey >= orderKey
    {
      state.items[index].orderKey += 1
    }
  }

  private static func updateSelectionsAfterRemoval(
    _ state: inout WorkspaceState,
    removedItemID: ItemID
  ) {
    for index in state.spaces.indices {
      if state.spaces[index].selectedItemID == removedItemID {
        state.spaces[index].selectedItemID = state.fallbackSelection(
          in: state.spaces[index].id)
      }
    }
    for index in state.windows.indices
    where
      state.windows[index].selectedItemID == removedItemID
    {
      state.windows[index].selectedItemID = state.windows[index].selectedSpaceID
        .flatMap { state.space($0)?.selectedItemID }
    }
  }

  private static func tabIDs(
    in itemID: ItemID,
    state: WorkspaceState
  ) -> [TabID] {
    guard let item = state.item(itemID) else { return [] }
    switch item.kind {
    case .tab:
      return item.tabID.map { [$0] } ?? []
    case .folder, .split:
      return state.children(of: itemID).flatMap {
        tabIDs(in: $0.id, state: state)
      }
    }
  }

  private static func profile(
    for parent: SidebarParent,
    in state: WorkspaceState
  ) -> Profile? {
    switch parent {
    case .root(let rootID): return state.profile(forRootID: rootID)
    case .item(let itemID): return state.profile(forItemID: itemID)
    }
  }

  private static func destinationRegion(
    _ parent: SidebarParent,
    in state: WorkspaceState
  ) -> SpaceRegion? {
    switch parent {
    case .root(let rootID): return state.root(rootID)?.region
    case .item(let itemID): return state.region(of: itemID)
    }
  }

  private static func folderDepth(
    _ itemID: ItemID,
    state: WorkspaceState
  ) -> Int {
    var depth = 1
    var current = state.item(itemID)
    var visited = Set<ItemID>()
    while let value = current {
      guard visited.insert(value.id).inserted else { return .max }
      if case .item(let parentID) = value.parent {
        depth += 1
        current = state.item(parentID)
      } else {
        break
      }
    }
    return depth
  }

  private static func requireActiveProfile(
    _ profileID: ProfileID,
    in state: WorkspaceState
  ) throws {
    guard let profile = state.profile(profileID) else {
      throw WorkspaceCommandError.unknownProfile(profileID)
    }
    guard profile.lifecycle == .active else {
      throw WorkspaceCommandError.profileDeleting(profileID)
    }
  }

  private static func validateName(_ value: String) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 200 else {
      throw WorkspaceCommandError.invalidName
    }
  }

  private static func validateWebURL(_ url: URL?) throws {
    if let url, !isSafeWebURL(url) {
      throw WorkspaceCommandError.invalidURL
    }
  }

  private static func isSafeWebURL(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
  }
}
