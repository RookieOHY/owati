import Foundation
import SQLite3

// 系统自带SQLite 零依赖 思路参考HealthTick的Database
// 只负责开库 业务表后续加
final class Database {
    static let shared = Database()
    private var db: OpaquePointer?

    private let dbPath: String = {
        let dir = NSHomeDirectory() + "/Library/Application Support/owati"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/data.db"
    }()

    private init() {
        // 读写不存在则创建
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else {
            db = nil
            return
        }
        // WAL 写入并发更稳
        execute("PRAGMA journal_mode=WAL")
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // 执行无结果SQL 建表等后续都会走这
    @discardableResult
    func execute(_ sql: String) -> Bool {
        guard let db else { return false }
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }
}
