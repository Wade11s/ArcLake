import AppKit
import ArcLakeBrowsing
import ArcLakeCore
import ArcLakePersistence
import Observation
import SwiftUI

enum M2Sheet: Identifiable, Equatable {
  case newProfile
  case newSpace
  case editSpace(SpaceID)
  case profiles
  case copyLink(ItemID)
  case changeSpaceProfile(SpaceID)
  case newFolder(SidebarParent)
  case renameItem(ItemID)

  var id: String {
    switch self {
    case .newProfile: "newProfile"
    case .newSpace: "newSpace"
    case .editSpace(let id): "editSpace:\(id)"
    case .profiles: "profiles"
    case .copyLink(let id): "copyLink:\(id)"
    case .changeSpaceProfile(let id): "changeSpaceProfile:\(id)"
    case .newFolder(let parent): "newFolder:\(parent)"
    case .renameItem(let id): "renameItem:\(id)"
    }
  }
}

enum M2ConfirmationAction: Equatable {
  case deleteProfile(ProfileID)
  case changeSpaceProfile(SpaceID, ProfileID)
}

struct M2Confirmation: Identifiable, Equatable {
  let id = UUID()
  var title: String
  var message: String
  var action: M2ConfirmationAction
}

@Observable
final class M2Model {
  let browser = BrowserCoordinator()
  let controller: AppController
  var startupFailure: String?
  var sidebarVisible = true
  var errorBanner: String?
  var isBusy = false

  var commandBarMode: CommandBarMode?
  var commandQuery = ""
  var commandCandidates: [CommandCandidate] = []
  var selectedCandidateID: String?
  private var commandGeneration = UUID()

  var sheet: M2Sheet?
  var confirmation: M2Confirmation?
  var draftName = ""
  var draftIcon = "circle"
  var draftProfileID: ProfileID?
  var draftBackgroundHex = "#E8EEF5"
  var draftAccentHex = "#1D4F7A"

  private var historyCache: [HistoryVisit] = []
  private var hasStarted = false

  init() {
    do {
      let path: URL
      if let override = ProcessInfo.processInfo.environment["ARCLAKE_M2_DATABASE_PATH"],
        !override.isEmpty
      {
        path = URL(fileURLWithPath: override)
      } else {
        let support = try FileManager.default.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true)
        path =
          support
          .appendingPathComponent("ArcLakeM2", isDirectory: true)
          .appendingPathComponent("ArcLake.sqlite")
      }
      try FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(),
        withIntermediateDirectories: true)
      let store = try SQLiteWorkspaceStore(path: path)
      controller = AppController(
        store: store,
        effectHandler: browser,
        profileDataStore: browser)
    } catch {
      startupFailure = String(describing: error)
      let store = InMemoryWorkspaceStore()
      controller = AppController(
        store: store,
        effectHandler: browser,
        profileDataStore: browser)
    }
  }

  var workspace: WorkspaceState? { controller.workspace }
  var phase: AppControllerPhase { controller.phase }
  var mainWindow: WindowSession? {
    workspace?.windows.first { $0.kind == .main } ?? workspace?.windows.first
  }
  var selectedSpaceID: SpaceID? { mainWindow?.selectedSpaceID }
  var selectedSpace: Space? {
    selectedSpaceID.flatMap { workspace?.space($0) }
  }
  var selectedItemID: ItemID? { mainWindow?.selectedItemID }
  var selectedItem: SidebarItem? {
    selectedItemID.flatMap { workspace?.item($0) }
  }
  var selectedTabID: TabID? {
    if let tabID = selectedItem?.tabID { return tabID }
    if let itemID = selectedItemID,
      let split = workspace?.split(itemID)
    {
      return workspace?.item(split.focusedChildItemID)?.tabID
    }
    return nil
  }
  var selectedTab: ArcLakeCore.Tab? { selectedTabID.flatMap { workspace?.tab($0) } }
  var currentProfile: Profile? {
    selectedSpace.flatMap { workspace?.profile($0.profileID) }
  }
  var activeProfiles: [Profile] {
    workspace?.profiles.filter { $0.lifecycle == .active } ?? []
  }
  var currentSpaces: [Space] {
    guard let profileID = currentProfile?.id else { return [] }
    return workspace?.spaces
      .filter { $0.profileID == profileID }
      .sorted {
        if $0.sortOrder != $1.sortOrder {
          return $0.sortOrder < $1.sortOrder
        }
        return $0.id < $1.id
      } ?? []
  }
  var favoritesRoot: RootContainer? {
    currentProfile.flatMap { workspace?.favoritesRoot(for: $0.id) }
  }
  var runtimeForSelectedTab: BrowserTabRuntime? {
    selectedTabID.flatMap { controller.browserRuntime[$0] }
  }
  var canGoBack: Bool {
    selectedTabID.flatMap { browser.session(for: $0)?.canGoBack } ?? false
  }
  var canGoForward: Bool {
    selectedTabID.flatMap { browser.session(for: $0)?.canGoForward } ?? false
  }
  var canReload: Bool { selectedTabID != nil }
  var addressHost: String {
    guard let url = selectedTab?.currentURL ?? runtimeForSelectedTab?.url else {
      return "Search or enter address"
    }
    return url.host ?? url.absoluteString
  }

  func startIfNeeded() async {
    guard !hasStarted else { return }
    hasStarted = true
    browser.eventHandler = { [weak self] event in
      guard let self else { return }
      _ = await self.controller.handleBrowserEvent(event)
      await self.refreshHistory()
    }
    browser.newWindowHandler = { [weak self] url in
      await self?.createTab(url: url)
    }
    await controller.start()
    if case .recovery(let recovery) = controller.phase {
      startupFailure = recovery.message
    }
    await refreshHistory()
    await openSmokeURLIfNeeded()
  }

  func retryStartup() async {
    startupFailure = nil
    await controller.retryStartup()
    await refreshHistory()
  }

  func toggleSidebar() {
    sidebarVisible.toggle()
  }

  func openCommandBar(_ mode: CommandBarMode) {
    commandBarMode = mode
    commandQuery =
      mode == .navigateCurrent
      ? (selectedTab?.currentURL?.absoluteString ?? "") : ""
    selectedCandidateID = nil
    Task { await refreshCommandCandidates() }
  }

  func closeCommandBar() {
    commandBarMode = nil
    commandQuery = ""
    commandCandidates = []
    selectedCandidateID = nil
  }

  func updateCommandQuery() async {
    await refreshCommandCandidates(debounce: true)
  }

  func submitCommandBar() async {
    let candidate =
      commandCandidates.first { $0.id == selectedCandidateID }
      ?? commandCandidates.first
    guard let candidate else { return }
    closeCommandBar()
    await execute(candidate: candidate)
  }

  func execute(candidate: CommandCandidate) async {
    switch candidate.action {
    case .openURLNewTab(let url):
      await createTab(url: url)
    case .navigateCurrent(let url):
      await navigateCurrent(to: url)
    case .selectSpace(let spaceID):
      await switchSpace(spaceID)
    case .selectItem(let itemID):
      await activateItem(itemID)
    case .application(let command):
      await perform(command)
    }
  }

  func switchSpace(_ spaceID: SpaceID) async {
    guard let windowID = mainWindow?.id else { return }
    await run {
      _ = try await self.controller.execute(.switchSpace(windowID, spaceID))
    }
  }

  func switchToProfile(_ profileID: ProfileID) async {
    guard
      let space =
        (workspace?.spaces
          .filter { $0.profileID == profileID }
          .sorted(by: { $0.sortOrder < $1.sortOrder })
          .first)
    else {
      errorBanner = "This Profile has no Space yet"
      return
    }
    await switchSpace(space.id)
  }

  func activateItem(_ itemID: ItemID) async {
    guard let windowID = mainWindow?.id else { return }
    await run {
      _ = try await self.controller.execute(
        .activateItem(itemID, windowID: windowID, at: Date()))
    }
  }

  func createTab(url: URL) async {
    guard let space = selectedSpace, let workspace else {
      errorBanner = "Select a Space before creating a Tab"
      return
    }
    let parent = SidebarParent.root(space.todayRootID)
    let order = (workspace.children(of: parent).map(\.orderKey).max() ?? -1) + 1
    let tabID = TabID()
    let itemID = ItemID()
    await run {
      _ = try await self.controller.execute(
        .createTab(
          tabID, itemID: itemID, spaceID: space.id, parent: parent,
          url: url, title: nil, orderKey: order, createdAt: Date()))
      guard let windowID = self.mainWindow?.id else { return }
      _ = try await self.controller.execute(
        .activateItem(itemID, windowID: windowID, at: Date()))
    }
  }

  func navigateCurrent(to url: URL) async {
    guard let tabID = selectedTabID else {
      await createTab(url: url)
      return
    }
    await run {
      _ = try await self.controller.execute(
        .navigateTab(tabID, url: url, title: nil, at: Date()))
    }
  }

  func closeSelectedTab() async {
    guard let tabID = selectedTabID else { return }
    await closeTab(tabID)
  }

  func closeTab(_ tabID: TabID) async {
    await run {
      _ = try await self.controller.execute(.closeTab(tabID, at: Date()))
      await self.activateSelectedFallbackIfNeeded()
    }
  }

  func reload() {
    guard let tabID = selectedTabID else { return }
    browser.reload(tabID)
  }

  func goBack() {
    guard let tabID = selectedTabID else { return }
    browser.goBack(tabID)
  }

  func goForward() {
    guard let tabID = selectedTabID else { return }
    browser.goForward(tabID)
  }

  func togglePinSelected() async {
    guard let item = selectedItem, let workspace else { return }
    switch workspace.region(of: item.id) {
    case .pinned:
      await run {
        _ = try await self.controller.execute(
          .unpinItem(item.id, at: Date()))
      }
    case .today:
      guard let spaceID = selectedSpace?.id else { return }
      await run {
        _ = try await self.controller.execute(
          .pinItem(item.id, spaceID: spaceID, at: Date()))
      }
    case .favorites, .none:
      errorBanner = "Only Today or Pinned items can be pinned"
    }
  }

  func toggleFavoriteSelected() async {
    guard let item = selectedItem, let workspace,
      let spaceID = selectedSpace?.id
    else { return }
    if workspace.region(of: item.id) == .favorites {
      await run {
        _ = try await self.controller.execute(
          .unfavoriteItem(item.id, currentSpaceID: spaceID, at: Date()))
      }
    } else {
      await run {
        _ = try await self.controller.execute(
          .favoriteItem(item.id, currentSpaceID: spaceID))
      }
    }
  }

  func resetPinnedItem(_ itemID: ItemID) async {
    await run {
      _ = try await self.controller.execute(
        .resetPinnedItem(itemID, at: Date()))
    }
  }

  func moveDraggedItem(_ value: String, to destination: SidebarParent) async {
    guard let itemID = ItemID(uuidString: value),
      let workspace
    else { return }
    let order = (workspace.children(of: destination).map(\.orderKey).max() ?? -1) + 1
    await run {
      _ = try await self.controller.execute(
        .moveItem(itemID, destination: destination, orderKey: order))
    }
  }

  func presentNewFolder(parent: SidebarParent? = nil) {
    let target: SidebarParent
    if let parent {
      target = parent
    } else if let item = selectedItem, item.kind == .folder {
      target = .item(item.id)
    } else if let selectedSpace {
      target = .root(selectedSpace.pinnedRootID)
    } else {
      return
    }
    draftName = "New Folder"
    sheet = .newFolder(target)
  }

  func createFolder(parent: SidebarParent) async {
    guard let spaceID = selectedSpace?.id, let workspace else { return }
    let order = (workspace.children(of: parent).map(\.orderKey).max() ?? -1) + 1
    let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      errorBanner = "Folder name cannot be empty"
      return
    }
    sheet = nil
    await run {
      _ = try await self.controller.execute(
        .createFolder(
          ItemID(), spaceID: spaceID, parent: parent,
          name: name, orderKey: order))
    }
  }

  func presentRename(itemID: ItemID) {
    draftName = workspace?.item(itemID)?.customTitle ?? ""
    sheet = .renameItem(itemID)
  }

  func rename(itemID: ItemID) async {
    let value = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      errorBanner = "Name cannot be empty"
      return
    }
    sheet = nil
    await run {
      _ = try await self.controller.execute(
        .rename(.item(itemID), value: value))
    }
  }

  func presentNewProfile() {
    draftName = "New Profile"
    sheet = .newProfile
  }

  func createProfile() async {
    let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      errorBanner = "Profile name cannot be empty"
      return
    }
    sheet = nil
    await run {
      _ = try await self.controller.execute(
        .createProfile(
          ProfileID(), favoritesRootID: RootID(), name: name,
          websiteStoreID: UUID(), createdAt: Date()))
    }
  }

  func presentNewSpace() {
    draftName = "New Space"
    draftIcon = "circle"
    draftBackgroundHex = "#E8EEF5"
    draftAccentHex = "#1D4F7A"
    draftProfileID = currentProfile?.id ?? activeProfiles.first?.id
    sheet = .newSpace
  }

  func createSpace() async {
    guard let profileID = draftProfileID else { return }
    let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      errorBanner = "Space name cannot be empty"
      return
    }
    let sortOrder = Int64(
      (workspace?.spaces.filter { $0.profileID == profileID }
        .map(\.sortOrder).max() ?? -1) + 1)
    let newSpaceID = SpaceID()
    sheet = nil
    await run {
      _ = try await self.controller.execute(
        .createSpace(
          newSpaceID, profileID: profileID,
          pinnedRootID: RootID(), todayRootID: RootID(),
          name: name, icon: self.draftIcon,
          theme: SpaceTheme(
            backgroundColorHex: self.draftBackgroundHex,
            accentColorHex: self.draftAccentHex),
          sortOrder: sortOrder))
    }
    if errorBanner == nil {
      await switchSpace(newSpaceID)
    }
  }

  func presentEditSpace(_ spaceID: SpaceID) {
    guard let space = workspace?.space(spaceID) else { return }
    draftName = space.name
    draftIcon = space.icon
    draftBackgroundHex = space.theme.backgroundColorHex
    draftAccentHex = space.theme.accentColorHex
    sheet = .editSpace(spaceID)
  }

  func updateSpace(_ spaceID: SpaceID) async {
    let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      errorBanner = "Space name cannot be empty"
      return
    }
    sheet = nil
    await run {
      _ = try await self.controller.execute(
        .updateSpace(
          spaceID, name: name, icon: self.draftIcon,
          theme: SpaceTheme(
            backgroundColorHex: self.draftBackgroundHex,
            accentColorHex: self.draftAccentHex),
          sortOrder: nil))
    }
  }

  func moveSpace(_ spaceID: SpaceID, direction: SpaceMoveDirection) async {
    await run {
      _ = try await self.controller.execute(
        .moveSpace(spaceID, direction: direction))
    }
  }

  func presentProfiles() {
    sheet = .profiles
  }

  func requestDeleteProfile(_ profileID: ProfileID) {
    guard let profile = workspace?.profile(profileID),
      profile.lifecycle == .deleting
        || !(workspace?.spaces.contains { $0.profileID == profileID } ?? false)
    else {
      errorBanner = "Remove this Profile's Spaces before deleting it"
      return
    }
    confirmation = M2Confirmation(
      title: "Delete “\(profile.name)”?",
      message:
        "This removes Favorites, history, archives and the WebKit data store for this Profile.",
      action: .deleteProfile(profileID))
  }

  func retryProfileDeletion(_ profileID: ProfileID) async {
    guard
      let operation = workspace?.pendingOperations.first(where: {
        $0.targetID == profileID.rawValue
      })
    else { return }
    await run {
      _ = try await self.controller.execute(
        .retryProfileDeletion(
          profileID, operationID: operation.id, at: Date()))
    }
  }

  func presentCopyLink(_ itemID: ItemID) {
    draftProfileID = activeProfiles.first { $0.id != currentProfile?.id }?.id
    sheet = .copyLink(itemID)
  }

  func copyLink(_ itemID: ItemID) async {
    guard let targetProfileID = draftProfileID,
      let targetSpace =
        (workspace?.spaces
          .filter { $0.profileID == targetProfileID }
          .sorted(by: { $0.sortOrder < $1.sortOrder })
          .first)
    else {
      errorBanner = "Target Profile needs a Space"
      return
    }
    sheet = nil
    await run {
      _ = try await self.controller.execute(
        .copyLink(
          itemID, targetProfileID: targetProfileID,
          targetSpaceID: targetSpace.id,
          newItemID: ItemID(), newTabID: TabID(), at: Date()))
    }
  }

  func presentChangeSpaceProfile(_ spaceID: SpaceID) {
    draftProfileID =
      activeProfiles.first {
        $0.id != workspace?.space(spaceID)?.profileID
      }?.id
    sheet = .changeSpaceProfile(spaceID)
  }

  func confirmChangeSpaceProfile(_ spaceID: SpaceID) {
    guard let targetProfileID = draftProfileID else { return }
    sheet = nil
    confirmation = M2Confirmation(
      title: "Change Space Profile?",
      message:
        "Open pages will be released and recreated in the target Profile. You may need to sign in again.",
      action: .changeSpaceProfile(spaceID, targetProfileID))
  }

  func confirm(_ confirmation: M2Confirmation) async {
    self.confirmation = nil
    switch confirmation.action {
    case .deleteProfile(let profileID):
      await run {
        _ = try await self.controller.execute(
          .requestProfileDeletion(
            profileID, operationID: PendingOperationID(), at: Date()))
      }
    case .changeSpaceProfile(let spaceID, let targetProfileID):
      await run {
        _ = try await self.controller.execute(
          .changeSpaceProfile(
            spaceID, targetProfileID: targetProfileID, at: Date()))
      }
    }
  }

  func perform(_ command: AppCommand) async {
    switch command {
    case .toggleSidebar:
      toggleSidebar()
    case .newTab:
      openCommandBar(.newTab)
    case .navigateCurrent:
      openCommandBar(.navigateCurrent)
    case .closeTab:
      await closeSelectedTab()
    case .pinOrUnpinSelected:
      await togglePinSelected()
    case .favoriteOrUnfavoriteSelected:
      await toggleFavoriteSelected()
    case .newFolder:
      presentNewFolder()
    case .newProfile:
      presentNewProfile()
    case .newSpace:
      presentNewSpace()
    }
  }

  func switchSpaceByIndex(_ index: Int) async {
    guard currentSpaces.indices.contains(index) else { return }
    await switchSpace(currentSpaces[index].id)
  }

  func refreshHistory() async {
    guard let profileID = currentProfile?.id else {
      historyCache = []
      return
    }
    do {
      let visits = try await controller.history(profileID: profileID, limit: 100)
      guard currentProfile?.id == profileID else { return }
      historyCache = visits
      if commandBarMode != nil {
        await refreshCommandCandidates()
      }
    } catch {
      historyCache = []
    }
  }

  private func refreshCommandCandidates(debounce: Bool = false) async {
    guard let mode = commandBarMode, let workspace,
      let windowID = mainWindow?.id, let spaceID = selectedSpaceID
    else {
      commandCandidates = []
      return
    }
    let generation = UUID()
    commandGeneration = generation
    if debounce {
      try? await Task.sleep(for: .milliseconds(100))
    }
    guard commandGeneration == generation else { return }
    let context = CommandContext(
      windowID: windowID,
      selectedItemID: selectedItemID,
      selectedSpaceID: spaceID)
    let candidates = CommandBarEngine.candidates(
      query: commandQuery, mode: mode, state: workspace,
      context: context, history: historyCache)
    guard commandGeneration == generation else { return }
    commandCandidates = candidates
    if !candidates.contains(where: { $0.id == selectedCandidateID }) {
      selectedCandidateID = candidates.first?.id
    }
  }

  private func activateSelectedFallbackIfNeeded() async {
    guard let itemID = mainWindow?.selectedItemID,
      let windowID = mainWindow?.id
    else { return }
    _ = try? await controller.execute(
      .activateItem(itemID, windowID: windowID, at: Date()))
  }

  private func run(_ operation: @escaping @MainActor () async throws -> Void) async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    do {
      try await operation()
      errorBanner = nil
      await refreshHistory()
    } catch {
      errorBanner = String(describing: error)
    }
  }

  private func openSmokeURLIfNeeded() async {
    guard let value = ProcessInfo.processInfo.environment["ARCLAKE_M2_START_URL"],
      let url = URL(string: value),
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https",
      workspace?.items.isEmpty == true
    else { return }
    await createTab(url: url)
  }
}
