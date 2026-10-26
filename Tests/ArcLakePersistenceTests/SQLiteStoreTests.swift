import Foundation
import SQLite3
import Testing

@testable import ArcLakeCore
@testable import ArcLakePersistence

@Suite("SQLite workspace")
struct SQLiteStoreTests {
  @Test("Schema v1 round-trips every workspace entity")
  func schemaV1RoundTripsEveryWorkspaceEntity() async throws {
    let (directory, path) = try temporaryDatabase()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try SQLiteWorkspaceStore(path: path)
    let rich = try PersistenceFixtures.richState()

    try await store.commit(rich, expectedRevision: 0)
    let loaded = try await store.load()
    let schema = try await store.schemaVersion()
    let journal = try await store.journalMode()

    #expect(schema == 1)
    #expect(journal.lowercased() == "wal")
    #expect(loaded == rich)

    let historyA = try await store.queryHistory(
      profileID: PersistenceFixtures.profileA, limit: 10)
    let historyB = try await store.queryHistory(
      profileID: PersistenceFixtures.profileB, limit: 10)
    #expect(historyA.map(\.title) == ["A Newer", "A History"])
    #expect(historyB.map(\.title) == ["B History"])

    let reopened = try SQLiteWorkspaceStore(path: path)
    let reopenedState = try await reopened.load()
    #expect(reopenedState == rich)
  }

  @Test("T26 revision mismatch does not publish new state")
  func revisionMismatchDoesNotPublishNewState() async throws {
    let (directory, path) = try temporaryDatabase()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try SQLiteWorkspaceStore(path: path)
    let first = try PersistenceFixtures.richState()
    try await store.commit(first, expectedRevision: 0)

    var stale = first
    stale.spaces[0].name = "Stale"
    do {
      try await store.commit(stale, expectedRevision: 0)
      Issue.record("Expected revision mismatch")
    } catch {
      #expect(
        error as? WorkspaceStoreError
          == .revisionMismatch(expected: 0, actual: 1))
    }
    let loaded = try await store.load()
    let revision = try await store.currentRevision()
    #expect(loaded == first)
    #expect(revision == 1)
  }

  @Test("T26 disk full rolls back all rows")
  func diskFullRollsBackAllRows() async throws {
    let (directory, path) = try temporaryDatabase()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try SQLiteWorkspaceStore(path: path)
    let first = try PersistenceFixtures.richState()
    try await store.commit(first, expectedRevision: 0)

    await store.simulateDiskFullOnNextCommit()
    do {
      try await store.commit(
        PersistenceFixtures.renamed(first),
        expectedRevision: 1)
      Issue.record("Expected disk-full failure")
    } catch {
      #expect(error as? WorkspaceStoreError == .diskFull)
    }
    let loaded = try await store.load()
    let revision = try await store.currentRevision()
    #expect(loaded == first)
    #expect(revision == 1)
  }

  @Test("T25 uncommitted transaction is invisible after reopen")
  func uncommittedTransactionIsInvisibleAfterReopen() async throws {
    let (directory, path) = try temporaryDatabase()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try SQLiteWorkspaceStore(path: path)
    let first = try PersistenceFixtures.richState()
    try await store.commit(first, expectedRevision: 0)

    do {
      let connection = try SQLiteConnection(path: path.path)
      try connection.execute("BEGIN IMMEDIATE")
      try connection.execute(
        "UPDATE meta SET value = '99' WHERE key = 'revision'")
      try connection.execute("DELETE FROM profiles")
      // Deinit closes without COMMIT, matching process death before commit.
    }

    let reopened = try SQLiteWorkspaceStore(path: path)
    let reopenedState = try await reopened.load()
    let revision = try await reopened.currentRevision()
    #expect(reopenedState == first)
    #expect(revision == 1)
  }

  @Test("T26 read-only database fails explicitly")
  func readOnlyDatabaseFailsExplicitly() async throws {
    let (directory, path) = try temporaryDatabase()
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: directory.path)
      try? FileManager.default.removeItem(at: directory)
    }
    let store = try SQLiteWorkspaceStore(path: path)
    try await store.commit(
      try PersistenceFixtures.richState(),
      expectedRevision: 0)
    for file in try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil)
    {
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o444], ofItemAtPath: file.path)
    }
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o555], ofItemAtPath: directory.path)

    do {
      _ = try SQLiteWorkspaceStore(path: path)
      Issue.record("Expected read-only failure")
    } catch {
      guard let value = error as? WorkspaceStoreError else {
        Issue.record("Expected WorkspaceStoreError, got \(error)")
        return
      }
      switch value {
      case .readOnly, .openFailed: break
      default: Issue.record("Expected read-only/open failure, got \(value)")
      }
    }
  }

  @Test("T27 interrupted migration rolls back and preserves backup")
  func interruptedMigrationRollsBackAndPreservesBackup() async throws {
    let (directory, path) = try temporaryDatabase()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try SQLiteWorkspaceStore(path: path)
    let rich = try PersistenceFixtures.richState()
    try await store.commit(rich, expectedRevision: 0)

    let v2 = SQLiteMigration(version: 2, name: "migration-probe") {
      connection in
      try connection.execute(
        "CREATE TABLE migration_probe (id TEXT PRIMARY KEY)")
      throw SQLiteFailure(
        code: SQLITE_ERROR, message: "Injected migration failure")
    }
    do {
      _ = try SQLiteWorkspaceStore(
        path: path,
        migrations: SQLiteMigrations.production() + [v2])
      Issue.record("Expected migration failure")
    } catch {
      guard case .migrationFailed = error as? WorkspaceStoreError else {
        Issue.record("Expected migration failure, got \(error)")
        return
      }
    }

    let connection = try SQLiteConnection(path: path.path)
    #expect(try connection.queryInt("PRAGMA user_version") == 1)
    #expect(
      try connection.queryInt(
        "SELECT COUNT(*) FROM sqlite_master WHERE name = 'migration_probe'")
        == 0)

    let backups = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    ).filter { $0.lastPathComponent.contains(".backup-v1-") }
    let backup = try #require(backups.first)
    let backupConnection = try SQLiteConnection(path: backup.path)
    #expect(try backupConnection.queryInt("PRAGMA user_version") == 1)
    #expect(try backupConnection.queryInt("SELECT COUNT(*) FROM profiles") == 2)
  }

  @Test("T27 future schema is rejected without overwrite")
  func futureSchemaIsRejectedWithoutOverwrite() async throws {
    let (directory, path) = try temporaryDatabase()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try SQLiteWorkspaceStore(path: path)
    let rich = try PersistenceFixtures.richState()
    try await store.commit(rich, expectedRevision: 0)

    do {
      let connection = try SQLiteConnection(path: path.path)
      try connection.execute("PRAGMA user_version = 99")
    }
    do {
      _ = try SQLiteWorkspaceStore(path: path)
      Issue.record("Expected future-schema rejection")
    } catch {
      #expect(
        error as? WorkspaceStoreError
          == .futureSchema(found: 99, supported: 1))
    }
    let connection = try SQLiteConnection(path: path.path)
    #expect(try connection.queryInt("PRAGMA user_version") == 99)
    #expect(try connection.queryInt("SELECT COUNT(*) FROM profiles") == 2)
  }

  @MainActor
  @Test("Invalid tree move does not write or advance revision")
  func invalidTreeMoveDoesNotWriteOrAdvanceRevision() async throws {
    let (directory, path) = try temporaryDatabase()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try SQLiteWorkspaceStore(path: path)
    let rich = try PersistenceFixtures.richState()
    try await store.commit(rich, expectedRevision: 0)

    let controller = AppController(
      store: store,
      bootstrapIDs: PersistenceFixtures.initialIDs)
    await controller.start()
    let baseline = try #require(controller.workspace)
    let folder = try #require(
      controller.workspace?.items.first { $0.kind == .folder })

    do {
      _ = try await controller.execute(
        .moveItem(folder.id, destination: .item(folder.id), orderKey: 0))
      Issue.record("Expected invalid self-move")
    } catch {
      #expect(error as? WorkspaceCommandError == .cannotMoveIntoSelf)
    }

    let persisted = try await store.load()
    let revision = try await store.currentRevision()
    #expect(persisted == baseline)
    #expect(revision == baseline.revision)
  }

  private func temporaryDatabase() throws -> (URL, URL) {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "ArcLakeM1-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    return (directory, directory.appendingPathComponent("workspace.sqlite"))
  }
}
