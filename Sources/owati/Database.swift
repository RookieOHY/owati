import Foundation
import SQLite3

// 系统自带SQLite 零依赖
final class Database {
    static let shared = Database()
    private var db: OpaquePointer?

    // sqlite3_bind_text 需要这个 拷贝传入的字符串
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static let dayFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static let tsFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private let dbPath: String = {
        let dir = NSHomeDirectory() + "/Library/Application Support/owati"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/data.db"
    }()

    private init() {
        // 读写 不存在则创建
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(dbPath, &db, flags, nil) == SQLITE_OK else {
            db = nil
            return
        }
        // WAL 写入并发更稳
        execute("PRAGMA journal_mode=WAL")
        createTables()
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // 建表
    private func createTables() {
        execute("""
            CREATE TABLE IF NOT EXISTS drink_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                amount_ml INTEGER NOT NULL,
                ts TEXT NOT NULL,
                date TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_drink_date ON drink_records(date);
        """)
    }

    // 记一笔
    func addDrink(_ ml: Int) {
        let now = Self.tsFormat.string(from: Date())
        let today = Self.dayFormat.string(from: Date())
        let sql = "INSERT INTO drink_records (amount_ml, ts, date) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(ml))
        sqlite3_bind_text(stmt, 2, now, -1, transient)
        sqlite3_bind_text(stmt, 3, today, -1, transient)
        sqlite3_step(stmt)
    }

    // 某天总量
    func totalML(on date: String) -> Int {
        queryInt("SELECT COALESCE(SUM(amount_ml), 0) FROM drink_records WHERE date = ?", [date])
    }

    // 今日总量
    func todayTotalML() -> Int {
        totalML(on: Self.dayFormat.string(from: Date()))
    }

    // 今日杯数
    func todayCups() -> Int {
        queryInt("SELECT COUNT(*) FROM drink_records WHERE date = ?",
                 [Self.dayFormat.string(from: Date())])
    }

    // 连续达标天数 今天没达标不算断 从昨天继续数
    func streakDays(goalML: Int) -> Int {
        var stmt: OpaquePointer?
        let sql = """
            SELECT date, SUM(amount_ml) FROM drink_records
            GROUP BY date ORDER BY date DESC LIMIT 90
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        let cal = Calendar.current
        let today = Self.dayFormat.string(from: Date())
        var streak = 0
        var prevDate: Date?
        while sqlite3_step(stmt) == SQLITE_ROW {
            let dateStr = String(cString: sqlite3_column_text(stmt, 0))
            let total = Int(sqlite3_column_int64(stmt, 1))
            guard let day = Self.dayFormat.date(from: dateStr) else { break }
            // 日期断档 连不上就断
            if let prev = prevDate, cal.dateComponents([.day], from: day, to: prev).day != 1 { break }
            prevDate = day
            if total >= goalML {
                streak += 1
            } else if dateStr == today {
                continue
            } else {
                break
            }
        }
        return streak
    }

    // 距最近一次喝水 文案化 没记录返回nil 超过一天也算没喝
    func lastDrinkText() -> String? {
        var stmt: OpaquePointer?
        let sql = "SELECT ts FROM drink_records ORDER BY ts DESC LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let c = sqlite3_column_text(stmt, 0) else { return nil }
        let ts = String(cString: c)
        guard let date = Self.tsFormat.date(from: ts) else { return nil }
        let m = max(0, Int(Date().timeIntervalSince(date) / 60))
        if m < 1 { return "刚刚" }
        if m < 60 { return "\(m) 分" }
        let h = m / 60
        if h < 24 { return "\(h) 小时" }
        return nil
    }

    // 一周每天杯数 key=yyyy-MM-dd
    func cupsByDate(dates: [String]) -> [String: Int] {
        guard !dates.isEmpty else { return [:] }
        let qs = dates.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT date, COUNT(*) FROM drink_records WHERE date IN (\(qs)) GROUP BY date"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        for (i, d) in dates.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), d, -1, transient)
        }
        var out: [String: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            out[String(cString: sqlite3_column_text(stmt, 0))] = Int(sqlite3_column_int64(stmt, 1))
        }
        return out
    }

    // 取单个整数 带参数绑定
    private func queryInt(_ sql: String, _ params: [String]) -> Int {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), p, -1, transient)
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // 执行无结果SQL
    @discardableResult
    func execute(_ sql: String) -> Bool {
        guard let db else { return false }
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }
}
