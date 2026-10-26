import ArcLakeCore
import Foundation
import SQLite3

public actor SQLiteWorkspaceStore: WorkspaceStore {
  private let connection: SQLiteConnection
  public nonisolated let databaseURL: URL
  private let supportedVersion: Int32
  private var forceDiskFullOnNextCommit = false

  public init(path: URL) throws {
    try self.init(path: path, migrations: SQLiteMigrations.production())
  }

  init(path: URL, migrations: [SQLiteMigration]) throws {
    precondition(!migrations.isEmpty)
    precondition(migrations.map(\.version) == migrations.map(\.version).sorted())
    guard let lastMigration = migrations.last else {
      throw WorkspaceStoreError.migrationFailed("Migration plan is empty")
    }
    databaseURL = path
    supportedVersion = lastMigration.version

    do {
      try FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(),
        withIntermediateDirectories: true)
      guard FileManager.default.isWritableFile(atPath: path.deletingLastPathComponent().path),
        !FileManager.default.fileExists(atPath: path.path)
          || FileManager.default.isWritableFile(atPath: path.path)
      else {
        throw WorkspaceStoreError.readOnly(
          "Database file or containing directory is not writable")
      }
      let connection = try SQLiteConnection(path: path.path)
      let foundVersion = Int32(try connection.queryInt("PRAGMA user_version"))
      guard foundVersion <= supportedVersion else {
        throw WorkspaceStoreError.futureSchema(
          found: foundVersion, supported: supportedVersion)
      }

      if foundVersion < supportedVersion {
        if Self.databaseHasContent(path) {
          let backupURL = Self.backupURL(for: path, version: foundVersion)
          try connection.backup(to: backupURL)
        }
        for migration in migrations where migration.version > foundVersion {
          do {
            try connection.transaction {
              try migration.apply(connection)
              try connection.execute("PRAGMA user_version = \(migration.version)")
            }
          } catch {
            throw WorkspaceStoreError.migrationFailed(
              "\(migration.name): \(error)")
          }
        }
      }
      try connection.execute("PRAGMA foreign_keys = ON")
      try connection.execute("PRAGMA journal_mode = WAL")
      try connection.execute("PRAGMA synchronous = FULL")
      try connection.execute("BEGIN IMMEDIATE")
      try connection.execute("ROLLBACK")
      self.connection = connection
    } catch let error as WorkspaceStoreError {
      throw error
    } catch let error as SQLiteFailure {
      throw Self.map(error)
    } catch {
      throw WorkspaceStoreError.openFailed(String(describing: error))
    }
  }

  public func load() async throws -> WorkspaceState? {
    do {
      let revision = try connection.queryInt(
        "SELECT CAST(value AS INTEGER) FROM meta WHERE key = 'revision'")
      let profiles = try loadProfiles()
      if profiles.isEmpty {
        guard revision == 0 else {
          throw WorkspaceStoreError.invalidState(
            "Non-zero revision without Profiles")
        }
        return nil
      }
      return WorkspaceState(
        revision: revision,
        profiles: profiles,
        spaces: try loadSpaces(),
        roots: try loadRoots(),
        items: try loadItems(),
        tabs: try loadTabs(),
        splitConfigurations: try loadSplits(),
        windows: try loadWindows(),
        archiveEntries: try loadArchives(),
        history: try loadHistory(),
        routeRules: try loadRouteRules(),
        pendingOperations: try loadPendingOperations(),
        settings: try loadSettings()
      )
    } catch let error as WorkspaceStoreError {
      throw error
    } catch let error as SQLiteFailure {
      throw Self.map(error)
    } catch {
      throw WorkspaceStoreError.database(String(describing: error))
    }
  }

  public func commit(_ state: WorkspaceState, expectedRevision: Int64) async throws {
    do {
      try WorkspaceValidator.validate(state)
    } catch {
      throw WorkspaceStoreError.invalidState(String(describing: error))
    }
    guard state.revision == expectedRevision + 1 else {
      throw WorkspaceStoreError.invalidState(
        "Revision must advance exactly one from \(expectedRevision)")
    }

    do {
      try connection.transaction {
        let actual = try connection.queryInt(
          "SELECT CAST(value AS INTEGER) FROM meta WHERE key = 'revision'")
        guard actual == expectedRevision else {
          throw WorkspaceStoreError.revisionMismatch(
            expected: expectedRevision, actual: actual)
        }
        try clearWorkspaceTables()
        try insert(state)
        if forceDiskFullOnNextCommit {
          forceDiskFullOnNextCommit = false
          throw SQLiteFailure(
            code: SQLITE_FULL,
            message: "Injected disk-full failure")
        }
        let statement = try connection.prepare(
          "UPDATE meta SET value = ? WHERE key = 'revision'")
        try statement.bind(String(state.revision), at: 1)
        _ = try statement.step()
      }
    } catch let error as WorkspaceStoreError {
      throw error
    } catch let error as SQLiteFailure {
      throw Self.map(error)
    } catch {
      throw WorkspaceStoreError.database(String(describing: error))
    }
  }

  public func queryHistory(
    profileID: ProfileID,
    limit: Int
  ) async throws -> [HistoryVisit] {
    guard limit > 0 else { return [] }
    do {
      let statement = try connection.prepare(
        """
        SELECT id, profile_id, url, title, visited_at
        FROM history_visits
        WHERE profile_id = ?
        ORDER BY visited_at DESC, id ASC
        LIMIT ?
        """)
      try statement.bind(profileID.rawValue, at: 1)
      try statement.bind(Int64(limit), at: 2)
      var result: [HistoryVisit] = []
      while try statement.step() {
        result.append(try historyVisit(from: statement))
      }
      return result
    } catch let error as SQLiteFailure {
      throw Self.map(error)
    } catch {
      throw WorkspaceStoreError.database(String(describing: error))
    }
  }

  public func currentRevision() async throws -> Int64 {
    try connection.queryInt(
      "SELECT CAST(value AS INTEGER) FROM meta WHERE key = 'revision'")
  }

  public func schemaVersion() async throws -> Int32 {
    Int32(try connection.queryInt("PRAGMA user_version"))
  }

  public func journalMode() async throws -> String {
    try connection.queryText("PRAGMA journal_mode") ?? "unknown"
  }

  func setMaxPageCountForTesting(_ count: Int64) throws {
    try connection.execute("PRAGMA max_page_count = \(count)")
  }

  func simulateDiskFullOnNextCommit() {
    forceDiskFullOnNextCommit = true
  }

  private func clearWorkspaceTables() throws {
    try connection.execute(
      """
      DELETE FROM application_settings;
      DELETE FROM history_visits;
      DELETE FROM archive_entries;
      DELETE FROM split_configurations;
      DELETE FROM items;
      DELETE FROM tabs;
      DELETE FROM window_sessions;
      DELETE FROM roots;
      DELETE FROM spaces;
      DELETE FROM profiles;
      DELETE FROM route_rules;
      DELETE FROM pending_operations;
      """)
  }

  private func insert(_ state: WorkspaceState) throws {
    for profile in state.profiles { try insert(profile) }
    for space in state.spaces { try insert(space) }
    for root in state.roots { try insert(root) }
    for item in state.items { try insert(item) }
    for tab in state.tabs { try insert(tab) }
    for split in state.splitConfigurations { try insert(split) }
    for window in state.windows { try insert(window) }
    for archive in state.archiveEntries { try insert(archive) }
    for visit in state.history { try insert(visit) }
    for rule in state.routeRules { try insert(rule) }
    try insert(state.settings)
    for operation in state.pendingOperations { try insert(operation) }
  }

  private func insert(_ profile: Profile) throws {
    let statement = try connection.prepare(
      """
      INSERT INTO profiles VALUES (?, ?, ?, ?, ?, ?, ?)
      """)
    try statement.bind(profile.id.rawValue, at: 1)
    try statement.bind(profile.name, at: 2)
    try statement.bind(profile.websiteStoreID, at: 3)
    try statement.bind(profile.archiveIntervalSeconds, at: 4)
    try statement.bind(profile.searchEngineTemplate, at: 5)
    try statement.bind(profile.lifecycle.rawValue, at: 6)
    try statement.bind(profile.createdAt.timeIntervalSinceReferenceDate, at: 7)
    _ = try statement.step()
  }

  private func insert(_ space: Space) throws {
    let statement = try connection.prepare(
      """
      INSERT INTO spaces VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      """)
    try statement.bind(space.id.rawValue, at: 1)
    try statement.bind(space.profileID.rawValue, at: 2)
    try statement.bind(space.name, at: 3)
    try statement.bind(space.icon, at: 4)
    try statement.bind(space.theme.backgroundColorHex, at: 5)
    try statement.bind(space.theme.accentColorHex, at: 6)
    try statement.bind(space.sortOrder, at: 7)
    try statement.bind(space.pinnedRootID.rawValue, at: 8)
    try statement.bind(space.todayRootID.rawValue, at: 9)
    try statement.bind(space.selectedItemID?.rawValue, at: 10)
    _ = try statement.step()
  }

  private func insert(_ root: RootContainer) throws {
    let statement = try connection.prepare(
      "INSERT INTO roots VALUES (?, ?, ?, ?)")
    try statement.bind(root.id.rawValue, at: 1)
    try statement.bind(root.kind.rawValue, at: 2)
    switch root.owner {
    case .profile(let id):
      try statement.bind("profile", at: 3)
      try statement.bind(id.rawValue, at: 4)
    case .space(let id):
      try statement.bind("space", at: 3)
      try statement.bind(id.rawValue, at: 4)
    }
    _ = try statement.step()
  }

  private func insert(_ item: SidebarItem) throws {
    let statement = try connection.prepare(
      "INSERT INTO items VALUES (?, ?, ?, ?, ?, ?, ?)")
    try statement.bind(item.id.rawValue, at: 1)
    switch item.parent {
    case .root(let id):
      try statement.bind("root", at: 2)
      try statement.bind(id.rawValue, at: 3)
    case .item(let id):
      try statement.bind("item", at: 2)
      try statement.bind(id.rawValue, at: 3)
    }
    try statement.bind(item.orderKey, at: 4)
    try statement.bind(item.kind.rawValue, at: 5)
    try statement.bind(item.tabID?.rawValue, at: 6)
    try statement.bind(item.customTitle, at: 7)
    _ = try statement.step()
  }

  private func insert(_ tab: Tab) throws {
    let statement = try connection.prepare(
      "INSERT INTO tabs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
    try statement.bind(tab.id.rawValue, at: 1)
    try statement.bind(tab.profileID.rawValue, at: 2)
    try statement.bind(tab.currentURL?.absoluteString, at: 3)
    try statement.bind(tab.savedURL?.absoluteString, at: 4)
    try statement.bind(tab.pageTitle, at: 5)
    try statement.bind(tab.lastActiveAt.timeIntervalSinceReferenceDate, at: 6)
    try statement.bind(tab.createdAt.timeIntervalSinceReferenceDate, at: 7)
    switch tab.owner {
    case .sidebarItem(let id):
      try statement.bind("sidebarItem", at: 8)
      try statement.bind(id.rawValue, at: 9)
    case .littleWindow(let id):
      try statement.bind("littleWindow", at: 8)
      try statement.bind(id.rawValue, at: 9)
    }
    _ = try statement.step()
  }

  private func insert(_ split: SplitConfiguration) throws {
    let statement = try connection.prepare(
      "INSERT INTO split_configurations VALUES (?, ?, ?, ?)")
    try statement.bind(split.itemID.rawValue, at: 1)
    try statement.bind(split.orientation.rawValue, at: 2)
    try statement.bind(try Self.encode(split.weights), at: 3)
    try statement.bind(split.focusedChildItemID.rawValue, at: 4)
    _ = try statement.step()
  }

  private func insert(_ window: WindowSession) throws {
    let statement = try connection.prepare(
      "INSERT INTO window_sessions VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
    try statement.bind(window.id.rawValue, at: 1)
    try statement.bind(window.kind.rawValue, at: 2)
    try statement.bind(window.selectedSpaceID?.rawValue, at: 3)
    try statement.bind(window.selectedItemID?.rawValue, at: 4)
    try statement.bind(window.selectedPaneID?.rawValue, at: 5)
    try statement.bind(Int64(window.sidebarVisible ? 1 : 0), at: 6)
    try statement.bind(window.sidebarWidth, at: 7)
    try statement.bind(window.frame.map { try Self.encode($0) }, at: 8)
    try statement.bind(try Self.encode(window.lastSelections), at: 9)
    _ = try statement.step()
  }

  private func insert(_ archive: ArchiveEntry) throws {
    let statement = try connection.prepare(
      "INSERT INTO archive_entries VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
    try statement.bind(archive.id.rawValue, at: 1)
    try statement.bind(archive.profileID.rawValue, at: 2)
    try statement.bind(archive.originSpaceID?.rawValue, at: 3)
    try statement.bind(archive.originParentHintID?.rawValue, at: 4)
    try statement.bind(archive.originalRegion.rawValue, at: 5)
    try statement.bind(Int64(archive.payloadVersion), at: 6)
    try statement.bind(try Self.encode(archive.snapshot), at: 7)
    try statement.bind(archive.reason.rawValue, at: 8)
    try statement.bind(archive.archivedAt.timeIntervalSinceReferenceDate, at: 9)
    try statement.bind(archive.restoredAt?.timeIntervalSinceReferenceDate, at: 10)
    _ = try statement.step()
  }

  private func insert(_ visit: HistoryVisit) throws {
    let statement = try connection.prepare(
      "INSERT INTO history_visits VALUES (?, ?, ?, ?, ?)")
    try statement.bind(visit.id.rawValue, at: 1)
    try statement.bind(visit.profileID.rawValue, at: 2)
    try statement.bind(visit.url.absoluteString, at: 3)
    try statement.bind(visit.title, at: 4)
    try statement.bind(visit.visitedAt.timeIntervalSinceReferenceDate, at: 5)
    _ = try statement.step()
  }

  private func insert(_ rule: RouteRule) throws {
    let statement = try connection.prepare(
      "INSERT INTO route_rules VALUES (?, ?, ?, ?, ?, ?, ?)")
    try statement.bind(rule.id.rawValue, at: 1)
    try statement.bind(rule.order, at: 2)
    try statement.bind(Int64(rule.enabled ? 1 : 0), at: 3)
    try statement.bind(rule.matchingStyle.rawValue, at: 4)
    try statement.bind(rule.pattern, at: 5)
    switch rule.destination {
    case .space(let id):
      try statement.bind("space", at: 6)
      try statement.bind(id.rawValue, at: 7)
    case .littleWindow(let id):
      try statement.bind("littleWindow", at: 6)
      try statement.bind(id.rawValue, at: 7)
    }
    _ = try statement.step()
  }

  private func insert(_ settings: ApplicationSettings) throws {
    let statement = try connection.prepare(
      "INSERT INTO application_settings VALUES (1, ?, ?, ?, ?, ?, ?)")
    try statement.bind(settings.defaultProfileID.rawValue, at: 1)
    switch settings.externalDefaultDestination {
    case .space(let id):
      try statement.bind("space", at: 2)
      try statement.bind(id.rawValue, at: 3)
    case .littleWindow(let id):
      try statement.bind("littleWindow", at: 2)
      try statement.bind(id.rawValue, at: 3)
    }
    try statement.bind(settings.appearance.rawValue, at: 4)
    try statement.bind(settings.archiveRetentionSeconds, at: 5)
    try statement.bind(settings.historyRetentionSeconds, at: 6)
    _ = try statement.step()
  }

  private func insert(_ operation: PendingOperation) throws {
    let statement = try connection.prepare(
      "INSERT INTO pending_operations VALUES (?, ?, ?, ?, ?, ?, ?)")
    try statement.bind(operation.id.rawValue, at: 1)
    try statement.bind(operation.kind.rawValue, at: 2)
    try statement.bind(operation.targetID, at: 3)
    try statement.bind(operation.storeID, at: 4)
    try statement.bind(operation.phase.rawValue, at: 5)
    try statement.bind(operation.lastError, at: 6)
    try statement.bind(operation.attemptAt.timeIntervalSinceReferenceDate, at: 7)
    _ = try statement.step()
  }

  private func loadProfiles() throws -> [Profile] {
    let statement = try connection.prepare(
      "SELECT id, name, website_store_id, archive_interval_seconds, search_engine_template, lifecycle, created_at FROM profiles ORDER BY created_at, id"
    )
    var result: [Profile] = []
    while try statement.step() {
      result.append(
        Profile(
          id: try profileID(statement.text(at: 0)),
          name: statement.text(at: 1),
          websiteStoreID: try requiredUUID(statement.uuid(at: 2)),
          archiveIntervalSeconds: statement.double(at: 3),
          searchEngineTemplate: statement.text(at: 4),
          lifecycle: try enumValue(ProfileLifecycle.self, statement.text(at: 5)),
          createdAt: Date(timeIntervalSinceReferenceDate: statement.double(at: 6))
        ))
    }
    return result
  }

  private func loadSpaces() throws -> [Space] {
    let statement = try connection.prepare(
      "SELECT id, profile_id, name, icon, background_color_hex, accent_color_hex, sort_order, pinned_root_id, today_root_id, selected_item_id FROM spaces ORDER BY sort_order, id"
    )
    var result: [Space] = []
    while try statement.step() {
      result.append(
        Space(
          id: try spaceID(statement.text(at: 0)),
          profileID: try profileID(statement.text(at: 1)),
          name: statement.text(at: 2),
          icon: statement.text(at: 3),
          theme: SpaceTheme(
            backgroundColorHex: statement.text(at: 4),
            accentColorHex: statement.text(at: 5)),
          sortOrder: statement.int64(at: 6),
          pinnedRootID: try rootID(statement.text(at: 7)),
          todayRootID: try rootID(statement.text(at: 8)),
          selectedItemID: try statement.optionalText(at: 9).map(itemID)
        ))
    }
    return result
  }

  private func loadRoots() throws -> [RootContainer] {
    let statement = try connection.prepare(
      "SELECT id, kind, owner_kind, owner_id FROM roots ORDER BY id")
    var result: [RootContainer] = []
    while try statement.step() {
      let owner: RootOwner
      switch statement.text(at: 2) {
      case "profile": owner = .profile(try profileID(statement.text(at: 3)))
      case "space": owner = .space(try spaceID(statement.text(at: 3)))
      default: throw WorkspaceStoreError.invalidState("Invalid Root owner kind")
      }
      result.append(
        RootContainer(
          id: try rootID(statement.text(at: 0)),
          kind: try enumValue(RootKind.self, statement.text(at: 1)),
          owner: owner
        ))
    }
    return result
  }

  private func loadItems() throws -> [SidebarItem] {
    let statement = try connection.prepare(
      "SELECT id, parent_kind, parent_id, order_key, kind, tab_id, custom_title FROM items ORDER BY order_key, id"
    )
    var result: [SidebarItem] = []
    while try statement.step() {
      let parent: SidebarParent
      switch statement.text(at: 1) {
      case "root": parent = .root(try rootID(statement.text(at: 2)))
      case "item": parent = .item(try itemID(statement.text(at: 2)))
      default: throw WorkspaceStoreError.invalidState("Invalid item parent kind")
      }
      result.append(
        SidebarItem(
          id: try itemID(statement.text(at: 0)),
          parent: parent,
          orderKey: statement.int64(at: 3),
          kind: try enumValue(SidebarItemKind.self, statement.text(at: 4)),
          tabID: try statement.optionalText(at: 5).map(tabID),
          customTitle: statement.optionalText(at: 6)
        ))
    }
    return result
  }

  private func loadTabs() throws -> [Tab] {
    let statement = try connection.prepare(
      "SELECT id, profile_id, current_url, saved_url, page_title, last_active_at, created_at, owner_kind, owner_id FROM tabs ORDER BY created_at, id"
    )
    var result: [Tab] = []
    while try statement.step() {
      let owner: TabOwner
      switch statement.text(at: 7) {
      case "sidebarItem": owner = .sidebarItem(try itemID(statement.text(at: 8)))
      case "littleWindow": owner = .littleWindow(try windowID(statement.text(at: 8)))
      default: throw WorkspaceStoreError.invalidState("Invalid Tab owner kind")
      }
      result.append(
        Tab(
          id: try tabID(statement.text(at: 0)),
          profileID: try profileID(statement.text(at: 1)),
          currentURL: try url(from: statement.optionalText(at: 2)),
          savedURL: try url(from: statement.optionalText(at: 3)),
          pageTitle: statement.optionalText(at: 4),
          lastActiveAt: Date(timeIntervalSinceReferenceDate: statement.double(at: 5)),
          createdAt: Date(timeIntervalSinceReferenceDate: statement.double(at: 6)),
          owner: owner
        ))
    }
    return result
  }

  private func loadSplits() throws -> [SplitConfiguration] {
    let statement = try connection.prepare(
      "SELECT item_id, orientation, weights_json, focused_child_item_id FROM split_configurations ORDER BY item_id"
    )
    var result: [SplitConfiguration] = []
    while try statement.step() {
      result.append(
        SplitConfiguration(
          itemID: try itemID(statement.text(at: 0)),
          orientation: try enumValue(SplitOrientation.self, statement.text(at: 1)),
          weights: try Self.decode([Double].self, statement.text(at: 2)),
          focusedChildItemID: try itemID(statement.text(at: 3))
        ))
    }
    return result
  }

  private func loadWindows() throws -> [WindowSession] {
    let statement = try connection.prepare(
      "SELECT id, kind, selected_space_id, selected_item_id, selected_pane_id, sidebar_visible, sidebar_width, frame_json, last_selections_json FROM window_sessions ORDER BY id"
    )
    var result: [WindowSession] = []
    while try statement.step() {
      let frame: WindowFrame? = try statement.optionalText(at: 7).map {
        try Self.decode(WindowFrame.self, $0)
      }
      result.append(
        WindowSession(
          id: try windowID(statement.text(at: 0)),
          kind: try enumValue(WindowKind.self, statement.text(at: 1)),
          selectedSpaceID: try statement.optionalText(at: 2).map(spaceID),
          selectedItemID: try statement.optionalText(at: 3).map(itemID),
          selectedPaneID: try statement.optionalText(at: 4).map(itemID),
          sidebarVisible: statement.bool(at: 5),
          sidebarWidth: statement.double(at: 6),
          frame: frame,
          lastSelections: try Self.decode(
            [SpaceSelection].self,
            statement.text(at: 8))
        ))
    }
    return result
  }

  private func loadArchives() throws -> [ArchiveEntry] {
    let statement = try connection.prepare(
      "SELECT id, profile_id, origin_space_id, origin_parent_hint_id, original_region, payload_version, snapshot_json, reason, archived_at, restored_at FROM archive_entries ORDER BY archived_at DESC, id"
    )
    var result: [ArchiveEntry] = []
    while try statement.step() {
      result.append(
        ArchiveEntry(
          id: try archiveID(statement.text(at: 0)),
          profileID: try profileID(statement.text(at: 1)),
          originSpaceID: try statement.optionalText(at: 2).map(spaceID),
          originParentHintID: try statement.optionalText(at: 3).map(itemID),
          originalRegion: try enumValue(SpaceRegion.self, statement.text(at: 4)),
          payloadVersion: statement.int(at: 5),
          snapshot: try Self.decode(ArchiveSnapshot.self, statement.text(at: 6)),
          reason: try enumValue(ArchiveReason.self, statement.text(at: 7)),
          archivedAt: Date(timeIntervalSinceReferenceDate: statement.double(at: 8)),
          restoredAt: statement.optionalDouble(at: 9).map(
            Date.init(timeIntervalSinceReferenceDate:))
        ))
    }
    return result
  }

  private func loadHistory() throws -> [HistoryVisit] {
    let statement = try connection.prepare(
      "SELECT id, profile_id, url, title, visited_at FROM history_visits ORDER BY visited_at DESC, id"
    )
    var result: [HistoryVisit] = []
    while try statement.step() {
      result.append(try historyVisit(from: statement))
    }
    return result
  }

  private func historyVisit(from statement: SQLiteStatement) throws -> HistoryVisit {
    HistoryVisit(
      id: try historyID(statement.text(at: 0)),
      profileID: try profileID(statement.text(at: 1)),
      url: try requiredWebURL(statement.text(at: 2)),
      title: statement.optionalText(at: 3),
      visitedAt: Date(timeIntervalSinceReferenceDate: statement.double(at: 4))
    )
  }

  private func loadRouteRules() throws -> [RouteRule] {
    let statement = try connection.prepare(
      "SELECT id, sort_order, enabled, matching_style, pattern, destination_kind, destination_id FROM route_rules ORDER BY sort_order, id"
    )
    var result: [RouteRule] = []
    while try statement.step() {
      let destination: RouteDestination
      switch statement.text(at: 5) {
      case "space": destination = .space(try spaceID(statement.text(at: 6)))
      case "littleWindow": destination = .littleWindow(try profileID(statement.text(at: 6)))
      default: throw WorkspaceStoreError.invalidState("Invalid route destination")
      }
      result.append(
        RouteRule(
          id: try routeID(statement.text(at: 0)),
          order: statement.int64(at: 1),
          enabled: statement.bool(at: 2),
          matchingStyle: try enumValue(
            RouteMatchingStyle.self,
            statement.text(at: 3)),
          pattern: statement.text(at: 4),
          destination: destination
        ))
    }
    return result
  }

  private func loadPendingOperations() throws -> [PendingOperation] {
    let statement = try connection.prepare(
      "SELECT id, kind, target_id, store_id, phase, last_error, attempt_at FROM pending_operations ORDER BY attempt_at, id"
    )
    var result: [PendingOperation] = []
    while try statement.step() {
      result.append(
        PendingOperation(
          id: try pendingID(statement.text(at: 0)),
          kind: try enumValue(PendingOperationKind.self, statement.text(at: 1)),
          targetID: try requiredUUID(statement.uuid(at: 2)),
          storeID: statement.uuid(at: 3),
          phase: try enumValue(PendingOperationPhase.self, statement.text(at: 4)),
          lastError: statement.optionalText(at: 5),
          attemptAt: Date(timeIntervalSinceReferenceDate: statement.double(at: 6))
        ))
    }
    return result
  }

  private func loadSettings() throws -> ApplicationSettings {
    let statement = try connection.prepare(
      "SELECT default_profile_id, external_destination_kind, external_destination_id, appearance, archive_retention_seconds, history_retention_seconds FROM application_settings WHERE singleton = 1"
    )
    guard try statement.step() else {
      throw WorkspaceStoreError.invalidState("Application settings are missing")
    }
    let destination: RouteDestination
    switch statement.text(at: 1) {
    case "space": destination = .space(try spaceID(statement.text(at: 2)))
    case "littleWindow": destination = .littleWindow(try profileID(statement.text(at: 2)))
    default: throw WorkspaceStoreError.invalidState("Invalid external destination")
    }
    return ApplicationSettings(
      defaultProfileID: try profileID(statement.text(at: 0)),
      externalDefaultDestination: destination,
      appearance: try enumValue(AppAppearance.self, statement.text(at: 3)),
      archiveRetentionSeconds: statement.double(at: 4),
      historyRetentionSeconds: statement.double(at: 5)
    )
  }

  private func profileID(_ value: String) throws -> ProfileID {
    try identifier(value, ProfileID.self)
  }
  private func spaceID(_ value: String) throws -> SpaceID {
    try identifier(value, SpaceID.self)
  }
  private func rootID(_ value: String) throws -> RootID {
    try identifier(value, RootID.self)
  }
  private func itemID(_ value: String) throws -> ItemID {
    try identifier(value, ItemID.self)
  }
  private func tabID(_ value: String) throws -> TabID {
    try identifier(value, TabID.self)
  }
  private func windowID(_ value: String) throws -> WindowID {
    try identifier(value, WindowID.self)
  }
  private func archiveID(_ value: String) throws -> ArchiveID {
    try identifier(value, ArchiveID.self)
  }
  private func historyID(_ value: String) throws -> HistoryID {
    try identifier(value, HistoryID.self)
  }
  private func routeID(_ value: String) throws -> RouteRuleID {
    try identifier(value, RouteRuleID.self)
  }
  private func pendingID(_ value: String) throws -> PendingOperationID {
    try identifier(value, PendingOperationID.self)
  }

  private func identifier<Tag: DomainIdentifierTag>(
    _ value: String, _ type: DomainIdentifier<Tag>.Type
  ) throws -> DomainIdentifier<Tag> {
    guard let id = DomainIdentifier<Tag>(uuidString: value) else {
      throw WorkspaceStoreError.invalidState("Invalid identifier: \(value)")
    }
    return id
  }

  private func requiredUUID(_ value: UUID?) throws -> UUID {
    guard let value else {
      throw WorkspaceStoreError.invalidState("Required UUID is missing")
    }
    return value
  }

  private func url(from value: String?) throws -> URL? {
    guard let value else { return nil }
    guard let url = URL(string: value) else {
      throw WorkspaceStoreError.invalidState("Invalid URL: \(value)")
    }
    return url
  }

  private func requiredWebURL(_ value: String) throws -> URL {
    guard let url = URL(string: value),
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https"
    else {
      throw WorkspaceStoreError.invalidState("Invalid history URL")
    }
    return url
  }

  private func enumValue<T: RawRepresentable>(
    _ type: T.Type, _ value: String
  ) throws -> T where T.RawValue == String {
    guard let result = T(rawValue: value) else {
      throw WorkspaceStoreError.invalidState("Invalid enum value: \(value)")
    }
    return result
  }

  private static func encode<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  private static func decode<T: Decodable>(_ type: T.Type, _ value: String) throws -> T {
    try JSONDecoder().decode(type, from: Data(value.utf8))
  }

  private static func databaseHasContent(_ url: URL) -> Bool {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? NSNumber
    else { return false }
    return size.int64Value > 0
  }

  private static func backupURL(for url: URL, version: Int32) -> URL {
    url.deletingLastPathComponent().appendingPathComponent(
      "\(url.lastPathComponent).backup-v\(version)-\(UUID().uuidString).sqlite")
  }

  private static func map(_ failure: SQLiteFailure) -> WorkspaceStoreError {
    let primary = failure.code & 0xFF
    if primary == SQLITE_FULL {
      return .diskFull
    }
    if primary == SQLITE_READONLY {
      return .readOnly(failure.message)
    }
    return .database(failure.message)
  }
}
