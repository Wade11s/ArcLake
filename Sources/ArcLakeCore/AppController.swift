import Foundation
import Observation

public struct BootSummary: Equatable, Sendable {
  public var createdNewWorkspace: Bool
  public var repairs: [WorkspaceRepair]
  public var restorationPlan: RestorationPlan?

  public init(
    createdNewWorkspace: Bool, repairs: [WorkspaceRepair],
    restorationPlan: RestorationPlan?
  ) {
    self.createdNewWorkspace = createdNewWorkspace
    self.repairs = repairs
    self.restorationPlan = restorationPlan
  }
}

public struct RecoveryState: Equatable, Sendable {
  public var message: String
  public var retryable: Bool

  public init(message: String, retryable: Bool = true) {
    self.message = message
    self.retryable = retryable
  }
}

public enum AppControllerPhase: Equatable, Sendable {
  case idle
  case loading
  case ready(BootSummary)
  case recovery(RecoveryState)
}

public enum AppEffect: Equatable, Sendable {
  case workspaceReady(createdNew: Bool)
  case loadTab(BrowserIdentity, URL)
  case releaseTab(TabID)
  case spaceChanged(SpaceID)
  case showEmptySpace(SpaceID)
  case itemActivated(ItemID)
}

@MainActor
public protocol AppEffectHandler {
  func apply(_ effect: AppEffect) async
}

@MainActor
public struct NoopAppEffectHandler: AppEffectHandler {
  public init() {}
  public func apply(_ effect: AppEffect) async {}
}

@MainActor
public protocol ProfileDataStoreDeleting {
  func deleteWebsiteData(profileID: ProfileID, storeID: UUID) async throws
}

public enum BrowserEventDisposition: Equatable, Sendable {
  case accepted
  case droppedStale
}

public enum AppControllerError: Error, Equatable, Sendable,
  CustomStringConvertible
{
  case notReady
  case commandInProgress
  case store(WorkspaceStoreError)

  public var description: String {
    switch self {
    case .notReady: "AppController is not in the ready phase"
    case .commandInProgress: "Another structural command is still committing"
    case .store(let error): error.description
    }
  }
}

@MainActor
@Observable
public final class AppController {
  @ObservationIgnored public let bootstrapIDs: WorkspaceBootstrapIDs
  @ObservationIgnored private let store: any WorkspaceStore
  @ObservationIgnored private let effectHandler: any AppEffectHandler
  @ObservationIgnored private let generationProvider: @Sendable () -> GenerationID
  @ObservationIgnored private let historyIDProvider: @Sendable () -> HistoryID
  @ObservationIgnored private let profileDataStore: (any ProfileDataStoreDeleting)?

  public private(set) var phase: AppControllerPhase = .idle
  public private(set) var workspace: WorkspaceState?
  public private(set) var lastError: String?
  public private(set) var droppedBrowserEvents = 0
  public private(set) var acceptedBrowserEvents = 0
  public private(set) var activeIdentities: [TabID: BrowserIdentity] = [:]
  public private(set) var browserRuntime: [TabID: BrowserTabRuntime] = [:]
  public private(set) var isExecutingCommand = false
  public private(set) var isStarting = false

  public init(
    store: any WorkspaceStore,
    bootstrapIDs: WorkspaceBootstrapIDs = WorkspaceBootstrapIDs(),
    effectHandler: any AppEffectHandler = NoopAppEffectHandler(),
    generationProvider: @escaping @Sendable () -> GenerationID = { GenerationID() },
    historyIDProvider: @escaping @Sendable () -> HistoryID = { HistoryID() },
    profileDataStore: (any ProfileDataStoreDeleting)? = nil
  ) {
    self.store = store
    self.bootstrapIDs = bootstrapIDs
    self.effectHandler = effectHandler
    self.generationProvider = generationProvider
    self.historyIDProvider = historyIDProvider
    self.profileDataStore = profileDataStore
  }

  public func start() async {
    guard !isStarting, !isExecutingCommand else { return }
    isStarting = true
    defer { isStarting = false }
    phase = .loading
    lastError = nil
    activeIdentities.removeAll()
    browserRuntime.removeAll()
    do {
      if var loaded = try await store.load() {
        let repairs = WorkspaceSelectionRepair.normalize(&loaded)
        try WorkspaceValidator.validate(loaded)
        if !repairs.isEmpty {
          let expected = loaded.revision
          loaded.revision += 1
          try await store.commit(loaded, expectedRevision: expected)
        }
        workspace = loaded
        let restorationPlan = restorationPlan(for: loaded)
        phase = .ready(
          BootSummary(
            createdNewWorkspace: false,
            repairs: repairs,
            restorationPlan: restorationPlan
          ))
        await effectHandler.apply(.workspaceReady(createdNew: false))
        await restore(restorationPlan, from: loaded)
      } else {
        let initial = WorkspaceBootstrap.initialState(ids: bootstrapIDs)
        try WorkspaceValidator.validate(initial)
        try await store.commit(initial, expectedRevision: 0)
        workspace = initial
        phase = .ready(
          BootSummary(
            createdNewWorkspace: true,
            repairs: [],
            restorationPlan: restorationPlan(for: initial)
          ))
        await effectHandler.apply(.workspaceReady(createdNew: true))
      }
    } catch {
      workspace = nil
      lastError = String(describing: error)
      phase = .recovery(RecoveryState(message: lastError ?? "Unknown startup error"))
    }
  }

  public func retryStartup() async {
    await start()
  }

  @discardableResult
  public func execute(_ command: WorkspaceCommand) async throws -> WorkspaceDecision {
    guard !isExecutingCommand else {
      throw AppControllerError.commandInProgress
    }
    isExecutingCommand = true
    defer { isExecutingCommand = false }
    return try await performCommand(command)
  }

  private func performCommand(_ command: WorkspaceCommand) async throws
    -> WorkspaceDecision
  {
    guard case .ready = phase, let current = workspace else {
      throw AppControllerError.notReady
    }
    do {
      let decision = try Workspace.decide(state: current, command: command)
      try WorkspaceValidator.validate(
        decision.state,
        runtime: runtimeSnapshot(for: decision.state))
      try await store.commit(decision.state, expectedRevision: current.revision)
      workspace = decision.state
      lastError = nil
      for effect in decision.effects {
        await apply(effect)
      }
      return decision
    } catch let error as WorkspaceStoreError {
      lastError = error.description
      throw AppControllerError.store(error)
    } catch {
      lastError = String(describing: error)
      throw error
    }
  }

  public func receive(_ event: BrowserEvent) -> BrowserEventDisposition {
    guard accepts(event.identity) else {
      droppedBrowserEvents += 1
      return .droppedStale
    }
    acceptedBrowserEvents += 1
    return .accepted
  }

  @discardableResult
  public func handleBrowserEvent(_ event: BrowserEvent) async
    -> BrowserEventDisposition
  {
    guard accepts(event.identity) else {
      droppedBrowserEvents += 1
      return .droppedStale
    }
    acceptedBrowserEvents += 1
    if var runtime = browserRuntime[event.identity.tabID] {
      switch event.kind {
      case .navigationStarted(let url):
        runtime.url = url
        runtime.loadState = .loading
        runtime.estimatedProgress = 0
      case .navigationCommitted(let url, let title):
        runtime.url = url
        runtime.title = title
      case .navigationFinished(let url, let title):
        runtime.url = url
        runtime.title = title
        runtime.loadState = .ready
        runtime.estimatedProgress = 1
      case .navigationFailed(_, let message):
        runtime.loadState = .failed(message)
      case .loadingProgress(let progress):
        runtime.estimatedProgress = min(max(progress, 0), 1)
      case .historyStateChanged(let canGoBack, let canGoForward):
        runtime.canGoBack = canGoBack
        runtime.canGoForward = canGoForward
      case .titleChanged(let title):
        runtime.title = title
      case .processTerminated(let message):
        runtime.loadState = .failed(message)
      case .downloadStarted(_), .downloadFinished(_):
        break
      }
      browserRuntime[event.identity.tabID] = runtime
    }

    if case .navigationFinished(let url, let title) = event.kind {
      guard !isExecutingCommand else {
        lastError =
          "Navigation finished during a structural command; visit metadata was not committed"
        return .accepted
      }
      do {
        _ = try await execute(
          .recordNavigation(
            event.identity.tabID,
            historyID: historyIDProvider(),
            url: url,
            title: title,
            at: Date()))
      } catch {
        lastError = "Navigation committed, but history metadata was not saved: \(error)"
      }
    }
    return .accepted
  }

  private func accepts(_ identity: BrowserIdentity) -> Bool {
    activeIdentities[identity.tabID] == identity
  }

  public func history(
    profileID: ProfileID,
    limit: Int = 100
  ) async throws -> [HistoryVisit] {
    try await store.queryHistory(profileID: profileID, limit: limit)
  }

  private func restorationPlan(for state: WorkspaceState) -> RestorationPlan? {
    let mainWindow = state.windows.first { $0.kind == .main } ?? state.windows.first
    return mainWindow.flatMap { RestorationPlanner.plan(for: $0.id, in: state) }
  }

  private func restore(_ plan: RestorationPlan?, from state: WorkspaceState) async {
    guard let plan else { return }
    for tabID in plan.tabIDs {
      guard let tab = state.tab(tabID),
        let profile = state.profile(tab.profileID),
        let url = tab.currentURL ?? tab.savedURL
      else { continue }
      let identity = BrowserIdentity(
        tabID: tab.id,
        profileID: tab.profileID,
        websiteStoreID: profile.websiteStoreID,
        generation: generationProvider()
      )
      activeIdentities[tab.id] = identity
      browserRuntime[tab.id] = BrowserTabRuntime(
        identity: identity,
        url: url,
        title: tab.pageTitle,
        loadState: .loading,
        estimatedProgress: 0)
      await effectHandler.apply(.loadTab(identity, url))
    }
  }

  private func apply(_ effect: WorkspaceEffect) async {
    guard let state = workspace else { return }
    switch effect {
    case .loadTab(let tabID, let url):
      guard let tab = state.tab(tabID),
        let profile = state.profile(tab.profileID)
      else { return }
      let identity = BrowserIdentity(
        tabID: tabID,
        profileID: tab.profileID,
        websiteStoreID: profile.websiteStoreID,
        generation: generationProvider()
      )
      activeIdentities[tabID] = identity
      browserRuntime[tabID] = BrowserTabRuntime(
        identity: identity,
        url: url,
        title: tab.pageTitle,
        loadState: .loading,
        estimatedProgress: 0)
      await effectHandler.apply(.loadTab(identity, url))
    case .releaseTab(let tabID):
      activeIdentities.removeValue(forKey: tabID)
      browserRuntime.removeValue(forKey: tabID)
      await effectHandler.apply(.releaseTab(tabID))
    case .showEmptySpace(let spaceID):
      await effectHandler.apply(.showEmptySpace(spaceID))
    case .spaceChanged(let spaceID):
      await effectHandler.apply(.spaceChanged(spaceID))
    case .itemActivated(let itemID):
      await effectHandler.apply(.itemActivated(itemID))
    case .beginProfileDeletion(let profileID, let storeID, let operationID):
      let releaseIDs =
        activeIdentities
        .filter { $0.value.profileID == profileID }
        .map(\.key)
      for tabID in releaseIDs {
        activeIdentities.removeValue(forKey: tabID)
        browserRuntime.removeValue(forKey: tabID)
        await effectHandler.apply(.releaseTab(tabID))
      }
      guard let profileDataStore else {
        let message = "No WebKit profile data-store deletion service is configured"
        _ = try? await performCommand(
          .markProfileDeletionFailed(
            profileID, operationID: operationID,
            error: message, at: Date()))
        lastError = message
        return
      }
      do {
        try await profileDataStore.deleteWebsiteData(
          profileID: profileID, storeID: storeID)
        _ = try await performCommand(
          .completeProfileDeletion(profileID, operationID: operationID))
      } catch {
        let message = String(describing: error)
        _ = try? await performCommand(
          .markProfileDeletionFailed(
            profileID, operationID: operationID,
            error: message, at: Date()))
        lastError = message
      }
    case .profileDeleted:
      break
    }
  }

  private func runtimeSnapshot(for state: WorkspaceState) -> BrowserRuntimeSnapshot {
    BrowserRuntimeSnapshot(
      bindings: activeIdentities.values.compactMap { identity in
        guard let tab = state.tab(identity.tabID),
          let profile = state.profile(tab.profileID),
          tab.profileID == identity.profileID,
          profile.websiteStoreID == identity.websiteStoreID
        else { return nil }
        return BrowserRuntimeBinding(identity: identity)
      })
  }
}
