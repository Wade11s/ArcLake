import Foundation
import Testing

@testable import ArcLakeCore

@Suite("Workspace commands")
struct WorkspaceCommandTests {
  @Test("T07 Spaces have independent roots and switch restores selection")
  func spacesHaveIndependentRootsAndSwitchRestoresSelection() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addSpace(state)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1, itemID: CoreFixtures.itemA1,
      spaceID: CoreFixtures.spaceA1, order: 0)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA2, itemID: CoreFixtures.itemA2,
      spaceID: CoreFixtures.spaceA2, order: 0)

    let switched = try Workspace.decide(
      state: state,
      command: .switchSpace(CoreFixtures.window, CoreFixtures.spaceA2))
    let window = try #require(switched.state.window(CoreFixtures.window))
    #expect(window.selectedSpaceID == CoreFixtures.spaceA2)
    #expect(window.selectedItemID == CoreFixtures.itemA2)
    #expect(switched.effects.contains(.spaceChanged(CoreFixtures.spaceA2)))
    #expect(
      switched.state.favoritesRoot(for: CoreFixtures.profileA)?.id
        == CoreFixtures.favoritesA)

    let switchedBack = try Workspace.decide(
      state: switched.state,
      command: .switchSpace(CoreFixtures.window, CoreFixtures.spaceA1))
    #expect(
      switchedBack.state.window(CoreFixtures.window)?.selectedItemID
        == CoreFixtures.itemA1)
    try WorkspaceValidator.validate(switchedBack.state)
  }

  @Test("T08 Favorites are Profile scoped and unfavorite returns to current Space")
  func favoritesAreProfileScopedAndUnfavoriteReturnsToCurrentSpace() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addSpace(state)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1, itemID: CoreFixtures.itemA1,
      spaceID: CoreFixtures.spaceA1, order: 0)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA2, itemID: CoreFixtures.itemA2,
      spaceID: CoreFixtures.spaceA2, order: 0)

    let favorited = try Workspace.decide(
      state: state,
      command: .favoriteItem(
        CoreFixtures.itemA1, currentSpaceID: CoreFixtures.spaceA1)
    ).state
    let twoFavorites = try Workspace.decide(
      state: favorited,
      command: .favoriteItem(
        CoreFixtures.itemA2, currentSpaceID: CoreFixtures.spaceA2)
    ).state
    #expect(
      twoFavorites.item(CoreFixtures.itemA1)?.parent
        == .root(CoreFixtures.favoritesA))
    #expect(
      twoFavorites.children(of: .root(CoreFixtures.favoritesA)).map(\.id)
        == [CoreFixtures.itemA1, CoreFixtures.itemA2])

    let withProfileB = try CoreFixtures.addProfileB(twoFavorites)
    #expect(
      withProfileB.children(of: .root(CoreFixtures.favoritesB)).isEmpty,
      "A Profile must not see another Profile's Favorites")

    let reordered = try Workspace.decide(
      state: withProfileB,
      command: .moveItem(
        CoreFixtures.itemA2, destination: .root(CoreFixtures.favoritesA),
        orderKey: 0)
    ).state
    #expect(
      reordered.children(of: .root(CoreFixtures.favoritesA)).map(\.id)
        == [CoreFixtures.itemA2, CoreFixtures.itemA1])

    let unfavorited = try Workspace.decide(
      state: reordered,
      command: .unfavoriteItem(
        CoreFixtures.itemA1, currentSpaceID: CoreFixtures.spaceA2,
        at: CoreFixtures.now)
    ).state
    #expect(
      unfavorited.item(CoreFixtures.itemA1)?.parent
        == .root(CoreFixtures.todayA2))
    #expect(
      unfavorited.children(of: .root(CoreFixtures.favoritesA)).map(\.id)
        == [CoreFixtures.itemA2])
    #expect(
      Set(unfavorited.items.compactMap(\.tabID))
        == Set([CoreFixtures.tabA1, CoreFixtures.tabA2]))
    try WorkspaceValidator.validate(unfavorited)
  }

  @Test("T09 Pinned saved URL and custom title survive close and reset")
  func pinnedSavedURLAndCustomTitleSurviveCloseAndReset() throws {
    var state = CoreFixtures.initial()
    let originalURL = URL(string: "https://example.com/original")!
    let navigatedURL = URL(string: "https://example.com/navigated")!
    let resetURL = URL(string: "https://example.com/after-reset")!
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1, itemID: CoreFixtures.itemA1,
      url: originalURL, title: "Original")

    let pinned = try Workspace.decide(
      state: state,
      command: .pinItem(
        CoreFixtures.itemA1, spaceID: CoreFixtures.spaceA1,
        at: CoreFixtures.now)
    ).state
    #expect(pinned.region(of: CoreFixtures.itemA1) == .pinned)
    #expect(pinned.tab(CoreFixtures.tabA1)?.savedURL == originalURL)

    let navigated = try Workspace.decide(
      state: pinned,
      command: .navigateTab(
        CoreFixtures.tabA1, url: navigatedURL, title: "Navigated",
        at: CoreFixtures.now.addingTimeInterval(1))
    ).state
    #expect(navigated.tab(CoreFixtures.tabA1)?.currentURL == navigatedURL)
    #expect(navigated.tab(CoreFixtures.tabA1)?.savedURL == originalURL)

    let renamed = try Workspace.decide(
      state: navigated,
      command: .rename(.item(CoreFixtures.itemA1), value: "Custom Pin")
    ).state
    #expect(
      renamed.item(CoreFixtures.itemA1)?.customTitle == "Custom Pin")

    let released = try Workspace.decide(
      state: renamed,
      command: .releasePinnedTab(CoreFixtures.tabA1))
    #expect(released.state.tab(CoreFixtures.tabA1)?.currentURL == nil)
    #expect(
      released.state.item(CoreFixtures.itemA1)?.customTitle == "Custom Pin")
    #expect(released.effects.contains(.releaseTab(CoreFixtures.tabA1)))

    let activated = try Workspace.decide(
      state: released.state,
      command: .activateItem(
        CoreFixtures.itemA1, windowID: CoreFixtures.window,
        at: CoreFixtures.now.addingTimeInterval(2)))
    #expect(
      activated.effects.contains(.loadTab(CoreFixtures.tabA1, originalURL)))
    #expect(
      activated.state.item(CoreFixtures.itemA1)?.customTitle == "Custom Pin")

    let navigatedAgain = try Workspace.decide(
      state: activated.state,
      command: .navigateTab(
        CoreFixtures.tabA1, url: resetURL, title: "Reset Me",
        at: CoreFixtures.now.addingTimeInterval(3))
    ).state
    let reset = try Workspace.decide(
      state: navigatedAgain,
      command: .resetPinnedItem(
        CoreFixtures.itemA1, at: CoreFixtures.now.addingTimeInterval(4)))
    #expect(reset.state.tab(CoreFixtures.tabA1)?.currentURL == originalURL)
    #expect(reset.effects.contains(.loadTab(CoreFixtures.tabA1, originalURL)))
  }

  @Test("T10 Folder moves are atomic and respect tree rules")
  func folderMovesAreAtomicAndRespectTreeRules() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addFolder(
      state, itemID: CoreFixtures.folder1,
      parent: .root(CoreFixtures.pinnedA1), name: "One", order: 0)
    state = try CoreFixtures.addFolder(
      state, itemID: CoreFixtures.folder2,
      parent: .item(CoreFixtures.folder1), name: "Two", order: 0)
    state = try CoreFixtures.addFolder(
      state, itemID: CoreFixtures.folder3,
      parent: .item(CoreFixtures.folder2), name: "Three", order: 0)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1, itemID: CoreFixtures.itemA1,
      parent: .item(CoreFixtures.folder3), order: 0)

    #expect(throws: WorkspaceCommandError.cannotMoveIntoSelf) {
      try Workspace.decide(
        state: state,
        command: .moveItem(
          CoreFixtures.folder1,
          destination: .item(CoreFixtures.folder1), orderKey: 0))
    }
    #expect(throws: WorkspaceCommandError.cannotMoveIntoDescendant) {
      try Workspace.decide(
        state: state,
        command: .moveItem(
          CoreFixtures.folder1,
          destination: .item(CoreFixtures.folder3), orderKey: 0))
    }
    #expect(throws: WorkspaceCommandError.folderDestinationRestricted) {
      try Workspace.decide(
        state: state,
        command: .moveItem(
          CoreFixtures.folder1,
          destination: .root(CoreFixtures.todayA1), orderKey: 0))
    }

    let withB = try CoreFixtures.addProfileB(state)
    #expect(throws: WorkspaceCommandError.crossProfileMove) {
      try Workspace.decide(
        state: withB,
        command: .moveItem(
          CoreFixtures.itemA1,
          destination: .root(CoreFixtures.pinnedB1), orderKey: 0))
    }

    let leavesBefore = Set(state.items.compactMap(\.tabID))
    let moved = try Workspace.decide(
      state: state,
      command: .moveItem(
        CoreFixtures.itemA1, destination: .root(CoreFixtures.pinnedA1),
        orderKey: 0)
    ).state
    #expect(Set(moved.items.compactMap(\.tabID)) == leavesBefore)
    #expect(
      moved.profile(forItemID: CoreFixtures.itemA1)?.id
        == CoreFixtures.profileA)
    try WorkspaceValidator.validate(moved)

    var deep = CoreFixtures.initial()
    var parent = SidebarParent.root(CoreFixtures.pinnedA1)
    for index in 0..<8 {
      let id = ItemID()
      deep = try CoreFixtures.addFolder(
        deep, itemID: id, parent: parent, name: "Depth \(index)", order: 0)
      parent = .item(id)
    }
    let ninthID = ItemID()
    #expect(throws: WorkspaceCommandError.invalidDestination) {
      try CoreFixtures.addFolder(
        deep, itemID: ninthID, parent: parent, name: "Too Deep", order: 0)
    }
  }
}
