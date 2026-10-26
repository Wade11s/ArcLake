import Foundation
import SQLite3

struct SQLiteFailure: Error, CustomStringConvertible {
  let code: Int32
  let message: String

  var description: String { "SQLite \(code): \(message)" }
}

final class SQLiteConnection {
  private let handle: OpaquePointer

  init(
    path: String, flags: Int32 = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
  ) throws {
    var pointer: OpaquePointer?
    let result = sqlite3_open_v2(path, &pointer, flags, nil)
    guard result == SQLITE_OK, let pointer else {
      let message =
        pointer.flatMap { String(cString: sqlite3_errmsg($0)) }
        ?? "Unable to allocate SQLite handle"
      if let pointer { sqlite3_close(pointer) }
      throw SQLiteFailure(code: result, message: message)
    }
    handle = pointer
    sqlite3_extended_result_codes(pointer, 1)
    sqlite3_busy_timeout(pointer, 5_000)
  }

  deinit {
    sqlite3_close(handle)
  }

  func execute(_ sql: String) throws {
    var errorPointer: UnsafeMutablePointer<CChar>?
    let result = sqlite3_exec(handle, sql, nil, nil, &errorPointer)
    guard result == SQLITE_OK else {
      let message =
        errorPointer.map { String(cString: $0) }
        ?? String(cString: sqlite3_errmsg(handle))
      sqlite3_free(errorPointer)
      throw SQLiteFailure(code: result, message: message)
    }
  }

  func prepare(_ sql: String) throws -> SQLiteStatement {
    try SQLiteStatement(connection: handle, sql: sql)
  }

  func queryInt(_ sql: String) throws -> Int64 {
    let statement = try prepare(sql)
    guard try statement.step() else { return 0 }
    return statement.int64(at: 0)
  }

  func queryText(_ sql: String) throws -> String? {
    let statement = try prepare(sql)
    guard try statement.step(), !statement.isNull(at: 0) else { return nil }
    return statement.text(at: 0)
  }

  func transaction<T>(_ body: () throws -> T) throws -> T {
    try execute("BEGIN IMMEDIATE")
    do {
      let value = try body()
      try execute("COMMIT")
      return value
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  func backup(to url: URL) throws {
    let destination = try SQLiteConnection(path: url.path)
    guard let backup = sqlite3_backup_init(destination.handle, "main", handle, "main") else {
      throw SQLiteFailure(
        code: sqlite3_errcode(handle),
        message: String(cString: sqlite3_errmsg(handle)))
    }
    defer {
      sqlite3_backup_finish(backup)
    }
    let result = sqlite3_backup_step(backup, -1)
    guard result == SQLITE_DONE else {
      throw SQLiteFailure(
        code: result,
        message: String(cString: sqlite3_errmsg(destination.handle)))
    }
  }
}

final class SQLiteStatement {
  private let database: OpaquePointer
  private var statement: OpaquePointer?
  private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

  init(connection: OpaquePointer, sql: String) throws {
    database = connection
    let result = sqlite3_prepare_v2(connection, sql, -1, &statement, nil)
    guard result == SQLITE_OK, statement != nil else {
      throw SQLiteFailure(
        code: result,
        message: String(cString: sqlite3_errmsg(connection)))
    }
  }

  deinit {
    sqlite3_finalize(statement)
  }

  func bind(_ value: String, at index: Int32) throws {
    let result = value.withCString {
      sqlite3_bind_text(statement, index, $0, -1, transient)
    }
    try check(result)
  }

  func bind(_ value: Int64, at index: Int32) throws {
    try check(sqlite3_bind_int64(statement, index, value))
  }

  func bind(_ value: Double, at index: Int32) throws {
    try check(sqlite3_bind_double(statement, index, value))
  }

  func bind(_ value: Double?, at index: Int32) throws {
    if let value { try bind(value, at: index) } else { try bindNull(at: index) }
  }

  func bindNull(at index: Int32) throws {
    try check(sqlite3_bind_null(statement, index))
  }

  func bind(_ value: String?, at index: Int32) throws {
    if let value { try bind(value, at: index) } else { try bindNull(at: index) }
  }

  func bind(_ value: UUID, at index: Int32) throws {
    try bind(value.uuidString.lowercased(), at: index)
  }

  func bind(_ value: UUID?, at index: Int32) throws {
    if let value { try bind(value, at: index) } else { try bindNull(at: index) }
  }

  func step() throws -> Bool {
    let result = sqlite3_step(statement)
    switch result {
    case SQLITE_ROW: return true
    case SQLITE_DONE: return false
    default:
      throw SQLiteFailure(
        code: result,
        message: String(cString: sqlite3_errmsg(database)))
    }
  }

  func text(at index: Int32) -> String {
    guard let value = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: value)
  }

  func optionalText(at index: Int32) -> String? {
    isNull(at: index) ? nil : text(at: index)
  }

  func int64(at index: Int32) -> Int64 {
    sqlite3_column_int64(statement, index)
  }

  func int(at index: Int32) -> Int {
    Int(int64(at: index))
  }

  func double(at index: Int32) -> Double {
    sqlite3_column_double(statement, index)
  }

  func bool(at index: Int32) -> Bool {
    int64(at: index) != 0
  }

  func optionalDouble(at index: Int32) -> Double? {
    isNull(at: index) ? nil : double(at: index)
  }

  func uuid(at index: Int32) -> UUID? {
    optionalText(at: index).flatMap(UUID.init(uuidString:))
  }

  func isNull(at index: Int32) -> Bool {
    sqlite3_column_type(statement, index) == SQLITE_NULL
  }

  private func check(_ result: Int32) throws {
    guard result == SQLITE_OK else {
      throw SQLiteFailure(
        code: result,
        message: String(cString: sqlite3_errmsg(database)))
    }
  }
}
