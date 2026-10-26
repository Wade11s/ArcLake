import Foundation
import Testing

@testable import ArcLakeCore

@Suite("Random workspace properties")
struct RandomWorkspaceTests {
  @Test("100 random legal tree moves preserve all invariants")
  func oneHundredRandomLegalTreeMovesPreserveAllInvariants() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addSpace(state)
    let tabs: [(TabID, ItemID)] = [
      (CoreFixtures.tabA1, CoreFixtures.itemA1),
      (CoreFixtures.tabA2, CoreFixtures.itemA2),
      (TabID(), ItemID()),
      (TabID(), ItemID()),
    ]
    for (index, pair) in tabs.enumerated() {
      state = try CoreFixtures.addTab(
        state, tabID: pair.0, itemID: pair.1,
        spaceID: index.isMultiple(of: 2)
          ? CoreFixtures.spaceA1 : CoreFixtures.spaceA2,
        order: Int64(index / 2))
    }
    try WorkspaceValidator.validate(state)

    let roots: [RootID] = [
      CoreFixtures.todayA1, CoreFixtures.pinnedA1,
      CoreFixtures.todayA2, CoreFixtures.pinnedA2,
    ]
    var generator = LCG(seed: 0xA11CE)
    let startingRevision = state.revision
    let leafTabs = Set(state.items.compactMap(\.tabID))
    let itemCount = state.items.count

    for iteration in 0..<100 {
      let pair = tabs[Int(generator.next() % UInt64(tabs.count))]
      let destination = roots[Int(generator.next() % UInt64(roots.count))]
      let order = Int64(generator.next() % 8)
      let decision = try Workspace.decide(
        state: state,
        command: .moveItem(
          pair.1, destination: .root(destination), orderKey: order))
      state = decision.state
      try WorkspaceValidator.validate(state)
      #expect(
        Set(state.items.compactMap(\.tabID)) == leafTabs,
        "iteration \(iteration)")
      #expect(state.items.count == itemCount, "iteration \(iteration)")
      #expect(
        state.items.allSatisfy {
          state.profile(forItemID: $0.id)?.id == CoreFixtures.profileA
        },
        "iteration \(iteration)")
    }
    #expect(state.revision == startingRevision + 100)
  }

  private struct LCG {
    private var value: UInt64

    init(seed: UInt64) {
      value = seed
    }

    mutating func next() -> UInt64 {
      value = value &* 6_364_136_223_846_793_005 &+ 1
      return value
    }
  }
}
