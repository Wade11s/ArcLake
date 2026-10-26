import Foundation
import Testing

@testable import ArcLakeCore

enum PersistenceFixtures {
  static let now = Date(timeIntervalSince1970: 1_810_000_000)
  static let profileA = ProfileID(uuidString: "10000000-0000-0000-0000-000000000001")!
  static let profileB = ProfileID(uuidString: "10000000-0000-0000-0000-000000000002")!
  static let spaceA1 = SpaceID(uuidString: "20000000-0000-0000-0000-000000000001")!
  static let spaceA2 = SpaceID(uuidString: "20000000-0000-0000-0000-000000000002")!
  static let spaceB1 = SpaceID(uuidString: "20000000-0000-0000-0000-000000000003")!
  static let favoritesA = RootID(uuidString: "30000000-0000-0000-0000-000000000001")!
  static let favoritesB = RootID(uuidString: "30000000-0000-0000-0000-000000000002")!
  static let pinnedA1 = RootID(uuidString: "31000000-0000-0000-0000-000000000001")!
  static let todayA1 = RootID(uuidString: "31000000-0000-0000-0000-000000000002")!
  static let pinnedA2 = RootID(uuidString: "31000000-0000-0000-0000-000000000003")!
  static let todayA2 = RootID(uuidString: "31000000-0000-0000-0000-000000000004")!
  static let pinnedB1 = RootID(uuidString: "31000000-0000-0000-0000-000000000005")!
  static let todayB1 = RootID(uuidString: "31000000-0000-0000-0000-000000000006")!
  static let window = WindowID(uuidString: "40000000-0000-0000-0000-000000000001")!

  static let initialIDs = WorkspaceBootstrapIDs(
    profileID: profileA, spaceID: spaceA1,
    favoritesRootID: favoritesA, pinnedRootID: pinnedA1,
    todayRootID: todayA1, windowID: window,
    websiteStoreID: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!)

  static func richState() throws -> WorkspaceState {
    var state = WorkspaceBootstrap.initialState(ids: initialIDs, now: now)
    state = try Workspace.decide(
      state: state,
      command: .createSpace(
        spaceA2, profileID: profileA, pinnedRootID: pinnedA2,
        todayRootID: todayA2, name: "Research", icon: "book",
        theme: SpaceTheme(
          backgroundColorHex: "#EEF3E4",
          accentColorHex: "#496B2F"),
        sortOrder: 1)
    ).state
    state = try Workspace.decide(
      state: state,
      command: .createProfile(
        profileB, favoritesRootID: favoritesB, name: "Work",
        websiteStoreID: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
        createdAt: now)
    ).state
    state = try Workspace.decide(
      state: state,
      command: .createSpace(
        spaceB1, profileID: profileB, pinnedRootID: pinnedB1,
        todayRootID: todayB1, name: "Work", icon: "briefcase",
        theme: SpaceTheme(), sortOrder: 2)
    ).state

    let folder1 = ItemID()
    let folder2 = ItemID()
    state = try Workspace.decide(
      state: state,
      command: .createFolder(
        folder1, spaceID: spaceA1,
        parent: .root(pinnedA1), name: "Projects",
        orderKey: 0)
    ).state
    state = try Workspace.decide(
      state: state,
      command: .createFolder(
        folder2, spaceID: spaceA1,
        parent: .item(folder1), name: "Nested",
        orderKey: 0)
    ).state
    let tabA1 = TabID()
    let itemA1 = ItemID()
    state = try Workspace.decide(
      state: state,
      command: .createTab(
        tabA1, itemID: itemA1, spaceID: spaceA1,
        parent: .item(folder2), url: URL(string: "https://example.com/projects"),
        title: "Projects", orderKey: 0, createdAt: now)
    ).state

    let tabA3 = TabID()
    let itemA3 = ItemID()
    state = try Workspace.decide(
      state: state,
      command: .createTab(
        tabA3, itemID: itemA3, spaceID: spaceA2,
        parent: .root(todayA2), url: URL(string: "https://example.com/research"),
        title: "Research", orderKey: 0, createdAt: now)
    ).state

    let tabB1 = TabID()
    let itemB1 = ItemID()
    state = try Workspace.decide(
      state: state,
      command: .createTab(
        tabB1, itemID: itemB1, spaceID: spaceB1,
        parent: .root(todayB1), url: URL(string: "https://example.com/work"),
        title: "Work", orderKey: 0, createdAt: now)
    ).state

    let tabA4 = TabID()
    let itemA4 = ItemID()
    let tabA5 = TabID()
    let itemA5 = ItemID()
    for (index, value) in [(tabA4, itemA4), (tabA5, itemA5)].enumerated() {
      state = try Workspace.decide(
        state: state,
        command: .createTab(
          value.0, itemID: value.1, spaceID: spaceA1,
          parent: .root(todayA1),
          url: URL(string: "https://example.com/split-\(index)"),
          title: "Split \(index)", orderKey: Int64(index),
          createdAt: now)
      ).state
    }
    let splitID = ItemID()
    state.items.append(
      SidebarItem(
        id: splitID, parent: .root(todayA1), orderKey: 10, kind: .split,
        customTitle: "Pair"))
    for (index, itemID) in [itemA4, itemA5].enumerated() {
      let position = try #require(state.items.firstIndex { $0.id == itemID })
      state.items[position].parent = .item(splitID)
      state.items[position].orderKey = Int64(index)
    }
    state.splitConfigurations.append(
      SplitConfiguration(
        itemID: splitID, orientation: .horizontal,
        weights: [0.42, 0.58], focusedChildItemID: itemA4))
    state = try Workspace.decide(
      state: state,
      command: .selectItem(window, itemA1, at: now)
    ).state

    let windowIndex = try #require(state.windows.firstIndex { $0.id == window })
    state.windows[windowIndex].frame = WindowFrame(x: 80, y: 60, width: 1280, height: 820)
    state.windows[windowIndex].sidebarWidth = 280
    state.windows[windowIndex].lastSelections = [
      SpaceSelection(spaceID: spaceA1, itemID: itemA1),
      SpaceSelection(spaceID: spaceA2, itemID: itemA3),
    ]

    state.history = [
      HistoryVisit(
        id: HistoryID(), profileID: profileA,
        url: URL(string: "https://example.com/a-history")!,
        title: "A History", visitedAt: now),
      HistoryVisit(
        id: HistoryID(), profileID: profileA,
        url: URL(string: "https://example.com/a-newer")!,
        title: "A Newer", visitedAt: now.addingTimeInterval(10)),
      HistoryVisit(
        id: HistoryID(), profileID: profileB,
        url: URL(string: "https://example.com/b-history")!,
        title: "B History", visitedAt: now.addingTimeInterval(20)),
    ]
    state.routeRules = [
      RouteRule(
        id: RouteRuleID(), order: 0, enabled: true,
        matchingStyle: .contains, pattern: "example.com/research",
        destination: .space(spaceA2))
    ]
    state.pendingOperations = [
      PendingOperation(
        id: PendingOperationID(), kind: .profileDataDeletion,
        targetID: profileB.rawValue,
        storeID: state.profile(profileB)?.websiteStoreID,
        phase: .retry, lastError: "network process busy", attemptAt: now)
    ]
    state.archiveEntries = [
      ArchiveEntry(
        id: ArchiveID(), profileID: profileB,
        originSpaceID: spaceB1, originParentHintID: nil,
        originalRegion: .today,
        snapshot: ArchiveSnapshot(nodes: [
          .tab(
            itemID: ItemID(), tabID: TabID(), title: "Archived",
            currentURL: URL(string: "https://example.com/archived"),
            savedURL: URL(string: "https://example.com/archived"))
        ]),
        reason: .manualClose, archivedAt: now)
    ]
    state.revision = 1
    try WorkspaceValidator.validate(state)
    return state
  }

  static func renamed(_ state: WorkspaceState) -> WorkspaceState {
    var next = state
    next.revision = 2
    next.spaces[0].name = "Renamed"
    return next
  }
}
