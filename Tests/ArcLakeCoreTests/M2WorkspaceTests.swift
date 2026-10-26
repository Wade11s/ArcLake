import Foundation
import Testing

@testable import ArcLakeCore

@MainActor
@Suite("M2 workspace flows")
struct M2WorkspaceTests {
  @Test("Space edit and ordering update one coherent workspace revision")
  func spaceEditAndOrdering() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addSpace(state)
    let updated = try Workspace.decide(
      state: state,
      command: .updateSpace(
        CoreFixtures.spaceA2,
        name: "Docs",
        icon: "doc.text",
        theme: SpaceTheme(
          backgroundColorHex: "#F7F0DD",
          accentColorHex: "#6A4F2A"),
        sortOrder: 2)
    ).state
    #expect(updated.space(CoreFixtures.spaceA2)?.name == "Docs")
    #expect(updated.space(CoreFixtures.spaceA2)?.icon == "doc.text")
    #expect(updated.space(CoreFixtures.spaceA2)?.theme.accentColorHex == "#6A4F2A")

    let moved = try Workspace.decide(
      state: updated,
      command: .moveSpace(CoreFixtures.spaceA2, direction: .up)
    ).state
    let ordered = moved.spaces
      .filter { $0.profileID == CoreFixtures.profileA }
      .sorted { $0.sortOrder < $1.sortOrder }
    #expect(ordered.map(\.id) == [CoreFixtures.spaceA2, CoreFixtures.spaceA1])
    try WorkspaceValidator.validate(moved)
  }

  @Test("T05 explicit cross-Profile copy creates new identity and leaves source")
  func crossProfileCopyCreatesNewIdentity() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addProfileB(state)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0,
      url: URL(string: "https://example.com/source")!,
      title: "Source")
    let newItem = ItemID()
    let newTab = TabID()
    let copied = try Workspace.decide(
      state: state,
      command: .copyLink(
        CoreFixtures.itemA1,
        targetProfileID: CoreFixtures.profileB,
        targetSpaceID: CoreFixtures.spaceB1,
        newItemID: newItem,
        newTabID: newTab,
        at: CoreFixtures.now)
    )
    #expect(copied.state.item(newItem)?.parent == .root(CoreFixtures.todayB1))
    #expect(copied.state.tab(newTab)?.profileID == CoreFixtures.profileB)
    #expect(
      copied.state.tab(newTab)?.currentURL
        == URL(string: "https://example.com/source"))
    #expect(copied.state.tab(newTab)?.id != CoreFixtures.tabA1)
    #expect(copied.state.tab(CoreFixtures.tabA1) != nil)
    #expect(copied.effects == [.loadTab(newTab, URL(string: "https://example.com/source")!)])
    try WorkspaceValidator.validate(copied.state)
  }

  @Test("T11 Space Profile change releases old identities and keeps A history")
  func changeSpaceProfileReleasesOldIdentity() async throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addProfileB(state)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0)
    state = try Workspace.decide(
      state: state,
      command: .selectItem(
        CoreFixtures.window, CoreFixtures.itemA1, at: CoreFixtures.now)
    ).state
    state.history.append(
      HistoryVisit(
        id: HistoryID(), profileID: CoreFixtures.profileA,
        url: URL(string: "https://example.com/a")!,
        title: "A", visitedAt: CoreFixtures.now))
    let store = InMemoryWorkspaceStore(state: state)
    let controller = AppController(
      store: store,
      bootstrapIDs: CoreFixtures.bootstrapIds(),
      generationProvider: {
        GenerationID(
          uuidString: "00000000-0000-0000-0000-000000000A11")!
      })
    await controller.start()
    let oldIdentity = try #require(
      controller.activeIdentities[CoreFixtures.tabA1])

    _ = try await controller.execute(
      .changeSpaceProfile(
        CoreFixtures.spaceA1, targetProfileID: CoreFixtures.profileB,
        at: CoreFixtures.now.addingTimeInterval(1)))
    #expect(controller.activeIdentities[CoreFixtures.tabA1] == nil)
    #expect(
      controller.workspace?.tab(CoreFixtures.tabA1)?.profileID
        == CoreFixtures.profileB)
    #expect(
      controller.workspace?.history.contains {
        $0.profileID == CoreFixtures.profileA
      } == true)

    let stale = BrowserEvent(
      identity: oldIdentity,
      kind: .navigationFinished(
        url: URL(string: "https://example.com/stale")!,
        title: "Stale"))
    #expect(await controller.handleBrowserEvent(stale) == .droppedStale)

    _ = try await controller.execute(
      .activateItem(
        CoreFixtures.itemA1, windowID: CoreFixtures.window,
        at: CoreFixtures.now.addingTimeInterval(2)))
    let newIdentity = try #require(
      controller.activeIdentities[CoreFixtures.tabA1])
    #expect(newIdentity.profileID == CoreFixtures.profileB)
    #expect(
      newIdentity.websiteStoreID
        == controller.workspace?.profile(CoreFixtures.profileB)?.websiteStoreID)
  }

  @Test("T12 Profile deletion failure is retryable and then removes all data")
  func profileDeletionFailureAndRetry() async throws {
    var state = CoreFixtures.initial()
    let profileC = ProfileID()
    let favoritesC = RootID()
    let tabC = TabID()
    let itemC = ItemID()
    let operation = PendingOperationID()
    state = try Workspace.decide(
      state: state,
      command: .createProfile(
        profileC, favoritesRootID: favoritesC, name: "Temp",
        websiteStoreID: UUID(),
        createdAt: CoreFixtures.now)
    ).state
    state.items.append(
      SidebarItem(
        id: itemC, parent: .root(favoritesC), orderKey: 0,
        kind: .tab, tabID: tabC))
    state.tabs.append(
      Tab(
        id: tabC, profileID: profileC,
        currentURL: URL(string: "https://example.com/temp"),
        pageTitle: "Temp", lastActiveAt: CoreFixtures.now,
        createdAt: CoreFixtures.now, owner: .sidebarItem(itemC)))
    state.history.append(
      HistoryVisit(
        id: HistoryID(), profileID: profileC,
        url: URL(string: "https://example.com/temp")!,
        title: "Temp", visitedAt: CoreFixtures.now))
    try WorkspaceValidator.validate(state)

    let store = InMemoryWorkspaceStore(state: state)
    let deleter = MockProfileDataStoreDeleter(failuresRemaining: 1)
    let controller = AppController(
      store: store, bootstrapIDs: CoreFixtures.bootstrapIds(),
      profileDataStore: deleter)
    await controller.start()

    _ = try await controller.execute(
      .requestProfileDeletion(
        profileC, operationID: operation, at: CoreFixtures.now))
    #expect(
      controller.workspace?.profile(profileC)?.lifecycle == .deleting)
    #expect(
      controller.workspace?.pendingOperations.first?.phase == .retry)
    #expect(controller.workspace?.pendingOperations.first?.lastError != nil)
    #expect(deleter.callCount == 1)

    _ = try await controller.execute(
      .retryProfileDeletion(
        profileC, operationID: operation,
        at: CoreFixtures.now.addingTimeInterval(1)))
    #expect(controller.workspace?.profile(profileC) == nil)
    #expect(controller.workspace?.favoritesRoot(for: profileC) == nil)
    #expect(controller.workspace?.history.contains { $0.profileID == profileC } == false)
    #expect(controller.workspace?.pendingOperations.isEmpty == true)
    #expect(deleter.callCount == 2)
  }

  @Test("Navigation records Profile-scoped history and pinned close keeps saved URL")
  func navigationHistoryAndTabClose() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0,
      url: URL(string: "https://example.com/original")!,
      title: "Original")
    state = try Workspace.decide(
      state: state,
      command: .pinItem(
        CoreFixtures.itemA1, spaceID: CoreFixtures.spaceA1,
        at: CoreFixtures.now)
    ).state
    let historyID = HistoryID()
    let url = URL(string: "https://example.com/navigated")!
    let navigated = try Workspace.decide(
      state: state,
      command: .recordNavigation(
        CoreFixtures.tabA1, historyID: historyID,
        url: url, title: "Navigated", at: CoreFixtures.now)
    ).state
    #expect(
      navigated.history.first { $0.id == historyID }?.profileID
        == CoreFixtures.profileA)
    let closed = try Workspace.decide(
      state: navigated,
      command: .closeTab(
        CoreFixtures.tabA1, at: CoreFixtures.now.addingTimeInterval(1)))
    #expect(closed.state.item(CoreFixtures.itemA1) != nil)
    #expect(closed.state.tab(CoreFixtures.tabA1)?.currentURL == nil)
    #expect(
      closed.state.tab(CoreFixtures.tabA1)?.savedURL
        == URL(string: "https://example.com/original"))
    #expect(closed.effects.contains(.releaseTab(CoreFixtures.tabA1)))
  }

  @Test("Accepted browser finish commits history and metadata atomically")
  func acceptedBrowserFinishCommitsHistory() async throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0,
      url: URL(string: "https://example.com/start")!,
      title: "Start")
    state = try Workspace.decide(
      state: state,
      command: .selectItem(
        CoreFixtures.window, CoreFixtures.itemA1, at: CoreFixtures.now)
    ).state
    let store = InMemoryWorkspaceStore(state: state)
    let fixedHistoryID = HistoryID()
    let controller = AppController(
      store: store,
      bootstrapIDs: CoreFixtures.bootstrapIds(),
      historyIDProvider: { fixedHistoryID })
    await controller.start()
    let identity = try #require(
      controller.activeIdentities[CoreFixtures.tabA1])
    let startingRevision = try #require(controller.workspace?.revision)
    let finalURL = URL(string: "https://example.com/final")!
    let event = BrowserEvent(
      identity: identity,
      kind: .navigationFinished(url: finalURL, title: "Final"))
    #expect(await controller.handleBrowserEvent(event) == .accepted)
    #expect(
      controller.workspace?.tab(CoreFixtures.tabA1)?.currentURL == finalURL)
    #expect(
      controller.workspace?.history.first { $0.id == fixedHistoryID }?.title
        == "Final")
    let storedRevision = try await store.currentRevision()
    #expect(storedRevision == startingRevision + 1)
  }
}

@MainActor
final class MockProfileDataStoreDeleter: ProfileDataStoreDeleting {
  var failuresRemaining: Int
  private(set) var callCount = 0

  init(failuresRemaining: Int) {
    self.failuresRemaining = failuresRemaining
  }

  func deleteWebsiteData(profileID: ProfileID, storeID: UUID) async throws {
    callCount += 1
    if failuresRemaining > 0 {
      failuresRemaining -= 1
      throw WorkspaceStoreError.database("simulated WebKit deletion failure")
    }
  }
}
