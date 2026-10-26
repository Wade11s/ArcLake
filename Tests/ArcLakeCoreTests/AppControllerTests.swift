import Foundation
import Testing

@testable import ArcLakeCore

actor RecordingEffectHandler: AppEffectHandler {
  private let store: any WorkspaceStore
  private(set) var effects: [AppEffect] = []
  private(set) var revisions: [Int64] = []

  init(store: any WorkspaceStore) {
    self.store = store
  }

  func apply(_ effect: AppEffect) async {
    effects.append(effect)
    revisions.append((try? await store.currentRevision()) ?? -1)
  }

  func snapshot() -> (effects: [AppEffect], revisions: [Int64]) {
    (effects, revisions)
  }
}

@MainActor
@Suite("App controller")
struct AppControllerTests {
  @Test("T06 bootstrap commits Default workspace before ready effect")
  func bootstrapCommitsDefaultWorkspaceBeforeReadyEffect() async throws {
    let store = InMemoryWorkspaceStore()
    let recorder = RecordingEffectHandler(store: store)
    let controller = AppController(
      store: store,
      bootstrapIDs: CoreFixtures.bootstrapIds(),
      effectHandler: recorder,
      generationProvider: { GenerationID() })

    await controller.start()

    guard case .ready(let summary) = controller.phase else {
      Issue.record("Expected ready phase, got \(controller.phase)")
      return
    }
    #expect(summary.createdNewWorkspace)
    let persisted = await store.storedState()
    #expect(persisted?.profiles.count == 1)
    #expect(persisted?.spaces.count == 1)
    #expect(
      persisted?.profiles.first?.websiteStoreID
        == CoreFixtures.bootstrapIds().websiteStoreID)
    let recorded = await recorder.snapshot()
    #expect(recorded.effects == [.workspaceReady(createdNew: true)])
    #expect(recorded.revisions == [1])
  }

  @Test("Cold start lazily restores only selected visible Tabs")
  func coldStartLazilyRestoresOnlySelectedVisibleTabs() async throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0)
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA2,
      itemID: CoreFixtures.itemA2, order: 1)
    state = try Workspace.decide(
      state: state,
      command: .selectItem(
        CoreFixtures.window, CoreFixtures.itemA1,
        at: CoreFixtures.now)
    ).state
    let store = InMemoryWorkspaceStore(state: state)
    let recorder = RecordingEffectHandler(store: store)
    let controller = AppController(
      store: store, bootstrapIDs: CoreFixtures.bootstrapIds(),
      effectHandler: recorder,
      generationProvider: {
        GenerationID(
          uuidString: "00000000-0000-0000-0000-0000000009AA")!
      })

    await controller.start()

    guard case .ready(let summary) = controller.phase else {
      Issue.record("Expected ready phase")
      return
    }
    #expect(!summary.createdNewWorkspace)
    #expect(summary.restorationPlan?.tabIDs == [CoreFixtures.tabA1])
    let recorded = await recorder.snapshot()
    #expect(recorded.effects.first == .workspaceReady(createdNew: false))
    #expect(recorded.effects.count == 2)
    guard case .loadTab(let identity, let url) = recorded.effects[1] else {
      Issue.record("Expected one lazy load effect")
      return
    }
    #expect(identity.tabID == CoreFixtures.tabA1)
    #expect(url == URL(string: "https://example.com/a"))
  }

  @Test("Startup repairs stale selection before publishing ready")
  func startupRepairsStaleSelectionBeforePublishingReady() async throws {
    var broken = CoreFixtures.initial()
    broken.spaces[0].selectedItemID = ItemID()
    let store = InMemoryWorkspaceStore(state: broken)
    let recorder = RecordingEffectHandler(store: store)
    let controller = AppController(
      store: store, bootstrapIDs: CoreFixtures.bootstrapIds(),
      effectHandler: recorder)

    await controller.start()

    guard case .ready(let summary) = controller.phase else {
      Issue.record("Expected recovered ready phase")
      return
    }
    #expect(summary.repairs.count == 1)
    #expect(controller.workspace?.revision == 2)
    let recorded = await recorder.snapshot()
    #expect(recorded.revisions.first == 2)
  }

  @Test("Load failure shows recovery and retry can bootstrap")
  func loadFailureShowsRecoveryAndRetryCanBootstrap() async throws {
    let store = InMemoryWorkspaceStore()
    await store.setLoadFailure(.openFailed("locked"))
    let controller = AppController(
      store: store, bootstrapIDs: CoreFixtures.bootstrapIds())

    await controller.start()
    guard case .recovery(let recovery) = controller.phase else {
      Issue.record("Expected recovery phase")
      return
    }
    #expect(recovery.retryable)
    #expect(controller.workspace == nil)

    await store.setLoadFailure(nil)
    await controller.retryStartup()
    guard case .ready(let summary) = controller.phase else {
      Issue.record("Expected ready after retry")
      return
    }
    #expect(summary.createdNewWorkspace)
  }

  @Test("Commit failure does not publish state or effect")
  func commitFailureDoesNotPublishStateOrEffect() async throws {
    let store = InMemoryWorkspaceStore()
    let recorder = RecordingEffectHandler(store: store)
    let controller = AppController(
      store: store, bootstrapIDs: CoreFixtures.bootstrapIds(),
      effectHandler: recorder)
    await controller.start()
    let beforeEffects = await recorder.snapshot().effects
    let revision = controller.workspace?.revision

    await store.setCommitFailure(.diskFull)
    do {
      _ = try await controller.execute(
        .createSpace(
          CoreFixtures.spaceA2, profileID: CoreFixtures.profileA,
          pinnedRootID: CoreFixtures.pinnedA2,
          todayRootID: CoreFixtures.todayA2,
          name: "Second", icon: "circle", theme: SpaceTheme(),
          sortOrder: 1))
      Issue.record("Expected disk-full commit failure")
    } catch {
      #expect(error as? AppControllerError == .store(.diskFull))
    }
    #expect(controller.workspace?.revision == revision)
    #expect(controller.workspace?.spaces.count == 1)
    let afterEffects = await recorder.snapshot().effects
    let storedRevision = await store.storedState()?.revision
    #expect(afterEffects == beforeEffects)
    #expect(storedRevision == revision)
  }

  @Test("Browser events require current generation")
  func browserEventsRequireCurrentGeneration() async throws {
    var state = CoreFixtures.initial()
    state = try CoreFixtures.addTab(
      state, tabID: CoreFixtures.tabA1,
      itemID: CoreFixtures.itemA1, order: 0)
    state = try Workspace.decide(
      state: state,
      command: .selectItem(
        CoreFixtures.window, CoreFixtures.itemA1,
        at: CoreFixtures.now)
    ).state
    let store = InMemoryWorkspaceStore(state: state)
    let controller = AppController(
      store: store, bootstrapIDs: CoreFixtures.bootstrapIds(),
      generationProvider: {
        GenerationID(
          uuidString: "00000000-0000-0000-0000-0000000009BB")!
      })
    await controller.start()
    let current = try #require(
      controller.activeIdentities[CoreFixtures.tabA1])
    let currentEvent = BrowserEvent(
      identity: current,
      kind: .navigationFinished(
        url: URL(string: "https://example.com/a")!, title: "A"))
    #expect(controller.receive(currentEvent) == .accepted)

    var stale = current
    stale.generation = GenerationID()
    let staleEvent = BrowserEvent(
      identity: stale,
      kind: .processTerminated(message: "old"))
    #expect(controller.receive(staleEvent) == .droppedStale)
    #expect(controller.acceptedBrowserEvents == 1)
    #expect(controller.droppedBrowserEvents == 1)
  }

  @Test("T28 stale decision cannot overwrite committed revision")
  func staleDecisionCannotOverwriteCommittedRevision() async throws {
    let initial = CoreFixtures.initial()
    let store = InMemoryWorkspaceStore(state: initial)
    let controller = AppController(
      store: store, bootstrapIDs: CoreFixtures.bootstrapIds())
    await controller.start()

    let renamed = try await controller.execute(
      .rename(.space(CoreFixtures.spaceA1), value: "New Name"))
    #expect(renamed.state.revision == 2)

    let staleDecision = try Workspace.decide(
      state: initial,
      command: .createSpace(
        CoreFixtures.spaceA2, profileID: CoreFixtures.profileA,
        pinnedRootID: CoreFixtures.pinnedA2,
        todayRootID: CoreFixtures.todayA2,
        name: "Stale", icon: "circle", theme: SpaceTheme(),
        sortOrder: 1))
    do {
      try await store.commit(
        staleDecision.state,
        expectedRevision: initial.revision)
      Issue.record("Expected revision mismatch")
    } catch {
      #expect(
        error as? WorkspaceStoreError
          == .revisionMismatch(expected: 1, actual: 2))
    }
    let stored = await store.storedState()
    #expect(stored?.revision == 2)
    #expect(stored?.spaces.count == 1)
    #expect(stored?.spaces.first?.name == "New Name")
  }
}
