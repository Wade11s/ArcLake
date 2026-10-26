import Foundation
import Testing

@testable import ArcLakeCore

@Suite("Workspace invariants")
struct InvariantTests {
  @Test("I01 requires Profile and Space")
  func i01RequiresProfileAndSpace() throws {
    var state = CoreFixtures.initial()
    state.profiles.removeAll()
    expectInvariant(.i01, state)
  }

  @Test("I02 rejects Space with missing Profile")
  func i02RejectsSpaceWithMissingProfile() throws {
    var state = CoreFixtures.initial()
    state.spaces[0].profileID = ProfileID()
    expectInvariant(.i02, state)
  }

  @Test("I03 rejects parent cycle")
  func i03RejectsParentCycle() throws {
    var state = try stateWithTab()
    let itemID = state.items[0].id
    state.items[0].parent = .item(itemID)
    expectInvariant(.i03, state)
  }

  @Test("I03 rejects mismatched root ownership")
  func i03RejectsMismatchedRootOwnership() throws {
    var state = CoreFixtures.initial()
    state.spaces[0].pinnedRootID = CoreFixtures.favoritesA
    expectInvariant(.i03, state)
  }

  @Test("I04 rejects Profile mismatch in tree")
  func i04RejectsProfileMismatchInTree() throws {
    var state = try stateWithTab()
    state.tabs[0].profileID = ProfileID()
    expectInvariant(.i04, state)
  }

  @Test("I05 rejects multiple item owners for one Tab")
  func i05RejectsMultipleItemOwnersForOneTab() throws {
    var state = try stateWithTab()
    state.items.append(
      SidebarItem(
        id: ItemID(), parent: .root(CoreFixtures.todayA1),
        orderKey: 1, kind: .tab, tabID: CoreFixtures.tabA1))
    expectInvariant(.i05, state)
  }

  @Test("I06 rejects malformed Split")
  func i06RejectsMalformedSplit() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1, itemID: CoreFixtures.itemA1, order: 0)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA2, itemID: CoreFixtures.itemA2, order: 1)
    let splitID = ItemID()
    state.items.append(
      SidebarItem(
        id: splitID, parent: .root(CoreFixtures.todayA1),
        orderKey: 2, kind: .split))
    for index in state.items.indices
    where state.items[index].id == CoreFixtures.itemA1
      || state.items[index].id == CoreFixtures.itemA2
    {
      state.items[index].parent = .item(splitID)
      state.items[index].orderKey = Int64(index)
    }
    state.splitConfigurations.append(
      SplitConfiguration(
        itemID: splitID, orientation: .horizontal,
        weights: [0.6, 0.6], focusedChildItemID: CoreFixtures.itemA1))
    expectInvariant(.i06, state)
  }

  @Test("I07 rejects stale Space selection")
  func i07RejectsStaleSpaceSelection() throws {
    var state = CoreFixtures.initial()
    state.spaces[0].selectedItemID = ItemID()
    expectInvariant(.i07, state)
  }

  @Test("I08 rejects composite Favorites roots")
  func i08RejectsCompositeFavoritesRoots() throws {
    var state = try stateWithTab()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA2, itemID: CoreFixtures.itemA2, order: 1)
    let splitID = ItemID()
    state.items.append(
      SidebarItem(
        id: splitID, parent: .root(CoreFixtures.favoritesA),
        orderKey: 0, kind: .split))
    for (index, itemID) in [CoreFixtures.itemA1, CoreFixtures.itemA2].enumerated() {
      let position = try #require(state.items.firstIndex { $0.id == itemID })
      state.items[position].parent = .item(splitID)
      state.items[position].orderKey = Int64(index)
    }
    state.splitConfigurations.append(
      SplitConfiguration(
        itemID: splitID, orientation: .horizontal,
        weights: [0.5, 0.5], focusedChildItemID: CoreFixtures.itemA1))
    expectInvariant(.i08, state)
  }

  @Test("I09 rejects executable archive URL")
  func i09RejectsExecutableArchiveURL() throws {
    var state = CoreFixtures.initial()
    state.archiveEntries.append(
      ArchiveEntry(
        id: ArchiveID(), profileID: CoreFixtures.profileA,
        originSpaceID: CoreFixtures.spaceA1, originParentHintID: nil,
        originalRegion: .today,
        snapshot: ArchiveSnapshot(nodes: [
          .tab(
            itemID: ItemID(), tabID: TabID(), title: "Bad",
            currentURL: URL(string: "javascript:alert(1)"),
            savedURL: nil)
        ]),
        reason: .manualClose, archivedAt: CoreFixtures.now))
    expectInvariant(.i09, state)
  }

  @Test("I10 rejects History outside known Profile")
  func i10RejectsHistoryOutsideKnownProfile() throws {
    var state = CoreFixtures.initial()
    state.history.append(
      HistoryVisit(
        id: HistoryID(), profileID: ProfileID(),
        url: URL(string: "https://example.com")!,
        title: "Foreign", visitedAt: CoreFixtures.now))
    expectInvariant(.i10, state)
  }

  @Test("I11 rejects archive and active ownership overlap")
  func i11RejectsArchiveAndActiveOwnershipOverlap() throws {
    var state = try stateWithTab()
    state.archiveEntries.append(
      ArchiveEntry(
        id: ArchiveID(), profileID: CoreFixtures.profileA,
        originSpaceID: CoreFixtures.spaceA1, originParentHintID: nil,
        originalRegion: .today,
        snapshot: ArchiveSnapshot(nodes: [
          .tab(
            itemID: CoreFixtures.itemA1, tabID: CoreFixtures.tabA1,
            title: "Duplicate",
            currentURL: URL(string: "https://example.com/a"),
            savedURL: nil)
        ]),
        reason: .manualClose, archivedAt: CoreFixtures.now))
    expectInvariant(.i11, state)
  }

  @Test("I12 rejects store mismatch and duplicate host")
  func i12RejectsStoreMismatchAndDuplicateHost() throws {
    var state = try stateWithTab()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA2,
      itemID: CoreFixtures.itemA2, order: 1)
    let wrong = BrowserRuntimeBinding(
      identity: BrowserIdentity(
        tabID: CoreFixtures.tabA1,
        profileID: CoreFixtures.profileA,
        websiteStoreID: UUID(),
        hostID: BrowserHostID()))
    expectInvariant(
      .i12, state,
      runtime: BrowserRuntimeSnapshot(bindings: [wrong]))

    let storeID = try #require(
      state.profile(CoreFixtures.profileA)?.websiteStoreID)
    let host = BrowserHostID()
    let duplicateHost = BrowserRuntimeSnapshot(bindings: [
      BrowserRuntimeBinding(
        identity: BrowserIdentity(
          tabID: CoreFixtures.tabA1, profileID: CoreFixtures.profileA,
          websiteStoreID: storeID, hostID: host)),
      BrowserRuntimeBinding(
        identity: BrowserIdentity(
          tabID: CoreFixtures.tabA2, profileID: CoreFixtures.profileA,
          websiteStoreID: storeID, hostID: host)),
    ])
    expectInvariant(.i12, state, runtime: duplicateHost)
  }

  private func stateWithTab() throws -> WorkspaceState {
    try CoreFixtures.addTab(
      CoreFixtures.initial(), tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0)
  }

  private func expectInvariant(
    _ code: InvariantCode,
    _ state: WorkspaceState,
    runtime: BrowserRuntimeSnapshot = .empty
  ) {
    do {
      try WorkspaceValidator.validate(state, runtime: runtime)
      Issue.record("Expected \(code.rawValue) violation")
    } catch let error as WorkspaceValidationError {
      #expect(error.code == code)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }
}
