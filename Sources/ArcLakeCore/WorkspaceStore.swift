import Foundation

public enum WorkspaceStoreError: Error, Equatable, Sendable,
  CustomStringConvertible
{
  case openFailed(String)
  case readOnly(String)
  case migrationFailed(String)
  case futureSchema(found: Int32, supported: Int32)
  case revisionMismatch(expected: Int64, actual: Int64)
  case diskFull
  case invalidState(String)
  case database(String)

  public var description: String {
    switch self {
    case .openFailed(let message): "Database open failed: \(message)"
    case .readOnly(let message): "Database is read-only: \(message)"
    case .migrationFailed(let message): "Database migration failed: \(message)"
    case .futureSchema(let found, let supported):
      "Database schema \(found) is newer than supported schema \(supported)"
    case .revisionMismatch(let expected, let actual):
      "Revision mismatch: expected \(expected), actual \(actual)"
    case .diskFull: "SQLite reports that the database or disk is full"
    case .invalidState(let message): "Workspace state is invalid: \(message)"
    case .database(let message): "Database error: \(message)"
    }
  }
}

public protocol WorkspaceStore: Sendable {
  func load() async throws -> WorkspaceState?
  func commit(_ state: WorkspaceState, expectedRevision: Int64) async throws
  func queryHistory(profileID: ProfileID, limit: Int) async throws -> [HistoryVisit]
  func currentRevision() async throws -> Int64
}

public actor InMemoryWorkspaceStore: WorkspaceStore {
  private var state: WorkspaceState?
  public var loadFailure: WorkspaceStoreError?
  public var commitFailure: WorkspaceStoreError?
  public var commitCount = 0

  public init(state: WorkspaceState? = nil) {
    self.state = state
  }

  public func load() async throws -> WorkspaceState? {
    if let loadFailure { throw loadFailure }
    return state
  }

  public func commit(_ next: WorkspaceState, expectedRevision: Int64) async throws {
    commitCount += 1
    if let commitFailure { throw commitFailure }
    let actual = state?.revision ?? 0
    guard actual == expectedRevision else {
      throw WorkspaceStoreError.revisionMismatch(
        expected: expectedRevision,
        actual: actual)
    }
    guard next.revision == expectedRevision + 1 else {
      throw WorkspaceStoreError.invalidState(
        "Committed revision must advance exactly one")
    }
    try WorkspaceValidator.validate(next)
    state = next
  }

  public func queryHistory(
    profileID: ProfileID,
    limit: Int
  ) async throws -> [HistoryVisit] {
    guard limit > 0 else { return [] }
    return Array(
      (state?.history ?? [])
        .filter { $0.profileID == profileID }
        .sorted { $0.visitedAt > $1.visitedAt }
        .prefix(limit))
  }

  public func currentRevision() async throws -> Int64 {
    state?.revision ?? 0
  }

  public func storedState() -> WorkspaceState? {
    state
  }

  public func replaceForTesting(_ next: WorkspaceState?) {
    state = next
  }

  public func setLoadFailure(_ failure: WorkspaceStoreError?) {
    loadFailure = failure
  }

  public func setCommitFailure(_ failure: WorkspaceStoreError?) {
    commitFailure = failure
  }
}
