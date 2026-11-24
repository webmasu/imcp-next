import Foundation
import SQLite3

/// Short read-only queries for app identifiers absent from the high-level store models.
struct ReadOnlyIndex {
    let url: URL

    func rows(_ sql: String, parameters: [String]) throws -> [[String]] {
        var db: OpaquePointer?
        let status = sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        defer { sqlite3_close(db) }
        func failure() -> ToolInputError {
            ToolInputError("Cannot read \(url.lastPathComponent): \(String(cString: sqlite3_errmsg(db)))")
        }
        guard status == SQLITE_OK else { throw failure() }
        var deadline = DispatchTime.now().uptimeNanoseconds + 1_000_000_000
        return try withUnsafeMutablePointer(to: &deadline) { pointer in
            sqlite3_progress_handler(
                db,
                1000,
                { context in
                    guard let context else { return 1 }
                    let end = context.assumingMemoryBound(to: UInt64.self).pointee
                    return Task.isCancelled || DispatchTime.now().uptimeNanoseconds >= end ? 1 : 0
                },
                pointer
            )
            defer { sqlite3_progress_handler(db, 0, nil, nil) }
            return try Self.query(db, sql, parameters: parameters)
        }
    }

    static func query(_ db: OpaquePointer?, _ sql: String, parameters: [String] = []) throws -> [[String]] {
        func failure() -> ToolInputError { ToolInputError(String(cString: sqlite3_errmsg(db))) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { throw failure() }
        defer { sqlite3_finalize(statement) }
        for (index, parameter) in parameters.enumerated() {
            guard
                sqlite3_bind_text(
                    statement,
                    Int32(index + 1),
                    parameter,
                    -1,
                    unsafeBitCast(-1, to: sqlite3_destructor_type.self)
                ) == SQLITE_OK
            else { throw failure() }
        }
        var result: [[String]] = []
        while true {
            switch sqlite3_step(statement) {
            case SQLITE_DONE: return result
            case SQLITE_ROW:
                result.append(
                    (0 ..< sqlite3_column_count(statement)).map {
                        sqlite3_column_text(statement, $0).map { String(cString: $0) } ?? ""
                    }
                )
            default: throw failure()
            }
        }
    }
}
