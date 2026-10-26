import Foundation
import Testing

@testable import ArcLakeCore

@Suite("M2 command bar")
struct M2CommandBarTests {
  @Test("T21 URL submission respects new-tab and navigate-current modes")
  func urlSubmissionRespectsModes() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0)
    state = try Workspace.decide(
      state: state,
      command: .selectItem(
        CoreFixtures.window, CoreFixtures.itemA1, at: CoreFixtures.now)
    ).state
    let context = CommandContext(
      windowID: CoreFixtures.window,
      selectedItemID: CoreFixtures.itemA1,
      selectedSpaceID: CoreFixtures.spaceA1)
    let url = "https://example.com/research"

    let newTab = CommandBarEngine.candidates(
      query: url, mode: .newTab, state: state,
      context: context, history: [])
    #expect(newTab.first?.kind == .url)
    #expect(
      newTab.contains {
        $0.action == .openURLNewTab(URL(string: url)!)
      })

    let navigate = CommandBarEngine.candidates(
      query: url, mode: .navigateCurrent, state: state,
      context: context, history: [])
    #expect(
      navigate.contains {
        $0.action == .navigateCurrent(URL(string: url)!)
      })
  }

  @Test("T21 descriptor and command bar share enabled command rules")
  func registryAndCommandBarShareRules() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0)
    state = try Workspace.decide(
      state: state,
      command: .selectItem(
        CoreFixtures.window, CoreFixtures.itemA1, at: CoreFixtures.now)
    ).state
    let context = CommandContext(
      windowID: CoreFixtures.window,
      selectedItemID: CoreFixtures.itemA1,
      selectedSpaceID: CoreFixtures.spaceA1)
    let descriptors = CommandRegistry.descriptors(state: state, context: context)
    #expect(descriptors.first { $0.command == .closeTab }?.enabled == true)
    #expect(descriptors.first { $0.command == .pinOrUnpinSelected }?.enabled == true)

    let candidates = CommandBarEngine.candidates(
      query: "Pin", mode: .newTab, state: state,
      context: context, history: [])
    #expect(
      candidates.contains {
        $0.action == .application(.pinOrUnpinSelected) && $0.enabled
      })
  }

  @Test("History candidates never leak another Profile")
  func historyCandidatesAreProfileScoped() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0)
    state = try Workspace.decide(
      state: state,
      command: .selectItem(
        CoreFixtures.window, CoreFixtures.itemA1, at: CoreFixtures.now)
    ).state
    let context = CommandContext(
      windowID: CoreFixtures.window,
      selectedItemID: CoreFixtures.itemA1,
      selectedSpaceID: CoreFixtures.spaceA1)
    let history = [
      HistoryVisit(
        id: HistoryID(), profileID: CoreFixtures.profileA,
        url: URL(string: "https://a.example.com/news")!,
        title: "A News", visitedAt: CoreFixtures.now),
      HistoryVisit(
        id: HistoryID(), profileID: CoreFixtures.profileB,
        url: URL(string: "https://b.example.com/private")!,
        title: "B Private", visitedAt: CoreFixtures.now),
    ]
    let candidates = CommandBarEngine.candidates(
      query: "news", mode: .newTab, state: state,
      context: context, history: history)
    #expect(
      candidates.contains {
        $0.kind == .history && $0.title == "A News"
      })
    #expect(
      !candidates.contains {
        $0.kind == .history && $0.title == "B Private"
      })
  }

  @Test("Command bar never executes javascript or data schemes")
  func commandBarRejectsExecutableSchemes() throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0)
    let context = CommandContext(
      windowID: CoreFixtures.window,
      selectedItemID: CoreFixtures.itemA1,
      selectedSpaceID: CoreFixtures.spaceA1)
    for query in ["javascript:alert(1)", "data:text/html,hello", "file:///etc/hosts"] {
      let candidates = CommandBarEngine.candidates(
        query: query, mode: .newTab, state: state,
        context: context, history: [])
      #expect(
        !candidates.contains {
          switch $0.action {
          case .openURLNewTab, .navigateCurrent: true
          default: false
          }
        })
    }
  }
}
