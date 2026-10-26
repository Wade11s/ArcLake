import Foundation

@testable import ArcLakeCore

enum CoreFixtures {
  static let now = Date(timeIntervalSince1970: 1_800_000_000)
  static let profileA = ProfileID(uuidString: "00000000-0000-0000-0000-000000000101")!
  static let profileB = ProfileID(uuidString: "00000000-0000-0000-0000-000000000102")!
  static let spaceA1 = SpaceID(uuidString: "00000000-0000-0000-0000-000000000201")!
  static let spaceA2 = SpaceID(uuidString: "00000000-0000-0000-0000-000000000202")!
  static let spaceB1 = SpaceID(uuidString: "00000000-0000-0000-0000-000000000203")!
  static let favoritesA = RootID(uuidString: "00000000-0000-0000-0000-000000000301")!
  static let favoritesB = RootID(uuidString: "00000000-0000-0000-0000-000000000302")!
  static let pinnedA1 = RootID(uuidString: "00000000-0000-0000-0000-000000000311")!
  static let todayA1 = RootID(uuidString: "00000000-0000-0000-0000-000000000312")!
  static let pinnedA2 = RootID(uuidString: "00000000-0000-0000-0000-000000000321")!
  static let todayA2 = RootID(uuidString: "00000000-0000-0000-0000-000000000322")!
  static let pinnedB1 = RootID(uuidString: "00000000-0000-0000-0000-000000000331")!
  static let todayB1 = RootID(uuidString: "00000000-0000-0000-0000-000000000332")!
  static let window = WindowID(uuidString: "00000000-0000-0000-0000-000000000401")!
  static let tabA1 = TabID(uuidString: "00000000-0000-0000-0000-000000000601")!
  static let tabA2 = TabID(uuidString: "00000000-0000-0000-0000-000000000602")!
  static let tabB1 = TabID(uuidString: "00000000-0000-0000-0000-000000000603")!
  static let itemA1 = ItemID(uuidString: "00000000-0000-0000-0000-000000000701")!
  static let itemA2 = ItemID(uuidString: "00000000-0000-0000-0000-000000000702")!
  static let itemB1 = ItemID(uuidString: "00000000-0000-0000-0000-000000000703")!
  static let folder1 = ItemID(uuidString: "00000000-0000-0000-0000-000000000711")!
  static let folder2 = ItemID(uuidString: "00000000-0000-0000-0000-000000000712")!
  static let folder3 = ItemID(uuidString: "00000000-0000-0000-0000-000000000713")!

  static func bootstrapIds() -> WorkspaceBootstrapIDs {
    WorkspaceBootstrapIDs(
      profileID: profileA,
      spaceID: spaceA1,
      favoritesRootID: favoritesA,
      pinnedRootID: pinnedA1,
      todayRootID: todayA1,
      windowID: window,
      websiteStoreID: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
    )
  }

  static func initial() -> WorkspaceState {
    WorkspaceBootstrap.initialState(ids: bootstrapIds(), now: now)
  }

  static func addSpace(
    _ state: WorkspaceState,
    id: SpaceID = spaceA2,
    profileID: ProfileID = profileA,
    pinned: RootID = pinnedA2,
    today: RootID = todayA2,
    name: String = "Second",
    order: Int64 = 1
  ) throws -> WorkspaceState {
    try Workspace.decide(
      state: state,
      command: .createSpace(
        id, profileID: profileID, pinnedRootID: pinned, todayRootID: today,
        name: name, icon: "circle", theme: SpaceTheme(), sortOrder: order)
    ).state
  }

  static func addProfileB(_ state: WorkspaceState) throws -> WorkspaceState {
    let withProfile = try Workspace.decide(
      state: state,
      command: .createProfile(
        profileB, favoritesRootID: favoritesB, name: "Work",
        websiteStoreID: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!,
        createdAt: now)
    ).state
    return try Workspace.decide(
      state: withProfile,
      command: .createSpace(
        spaceB1, profileID: profileB, pinnedRootID: pinnedB1,
        todayRootID: todayB1, name: "Work", icon: "briefcase",
        theme: SpaceTheme(), sortOrder: 2)
    ).state
  }

  static func apply(
    _ commands: [WorkspaceCommand],
    to state: WorkspaceState
  ) throws -> WorkspaceState {
    try commands.reduce(state) { partial, command in
      try Workspace.decide(state: partial, command: command).state
    }
  }

  static func addTab(
    _ state: WorkspaceState,
    tabID: TabID = TabID(),
    itemID: ItemID = ItemID(),
    spaceID: SpaceID = spaceA1,
    parent: SidebarParent? = nil,
    order: Int64 = 0,
    url: URL? = URL(string: "https://example.com/a"),
    title: String? = "A"
  ) throws -> WorkspaceState {
    let root = spaceID == spaceA1 ? todayA1 : (spaceID == spaceA2 ? todayA2 : todayB1)
    return try Workspace.decide(
      state: state,
      command: .createTab(
        tabID, itemID: itemID, spaceID: spaceID,
        parent: parent ?? .root(root), url: url, title: title,
        orderKey: order, createdAt: now)
    ).state
  }

  static func addFolder(
    _ state: WorkspaceState,
    itemID: ItemID = ItemID(),
    parent: SidebarParent = .root(pinnedA1),
    name: String = "Folder",
    order: Int64 = 0
  ) throws -> WorkspaceState {
    try Workspace.decide(
      state: state,
      command: .createFolder(
        itemID, spaceID: spaceA1,
        parent: parent, name: name, orderKey: order)
    ).state
  }
}
