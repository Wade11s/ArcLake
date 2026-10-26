import Foundation
import Testing

@testable import ArcLakeCore
@testable import ArcLakePersistence

@Suite("SQLite workspace smoke")
struct SQLiteStoreSmokeTests {
  @Test("Fresh database creates schema and round-trips bootstrap")
  func freshDatabaseCreatesSchemaAndRoundTripsBootstrap() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "ArcLakeM1Smoke-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let store = try SQLiteWorkspaceStore(
      path: directory.appendingPathComponent("workspace.sqlite"))
    let empty = try await store.load()
    let schemaVersion = try await store.schemaVersion()
    let journalMode = try await store.journalMode()
    #expect(empty == nil)
    #expect(schemaVersion == 1)
    #expect(journalMode.lowercased() == "wal")

    let initial = WorkspaceBootstrap.initialState(
      ids: WorkspaceBootstrapIDs(
        websiteStoreID: UUID())
    )
    try await store.commit(initial, expectedRevision: 0)
    let loaded = try await store.load()
    #expect(loaded == initial)
  }
}
