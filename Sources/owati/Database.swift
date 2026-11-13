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
            CREATE TABLE IF NOT EXISTS goal_overrides (
                date TEXT PRIMARY KEY,
                goal_ml INTEGER NOT NULL
            );
        """)
        migrate()
    }

    // 旧库补列 drink_type 老数据默认水
    private func migrate() {
        guard !columnExists("drink_records", "drink_type") else { return }
        execute("ALTER TABLE drink_records ADD COLUMN drink_type TEXT NOT NULL DEFAULT 'water'")
    }

    // 查列是否存在
    private func columnExists(_ table: String, _ col: String) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\(table))", -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if String(cString: sqlite3_column_text(stmt, 1)) == col { return true }
        }
        return false
    }

    // 水合系数CASE 与 DrinkType.ratio 同源 聚合时按类型加权
    private static let ratioCase: String = {
        let whens = DrinkType.allCases
            .map { "WHEN '\($0.rawValue)' THEN \($0.ratio)" }
            .joined(separator: " ")
        return "CASE drink_type \(whens) ELSE 1.0 END"
    }()

    // 记一笔
    func addDrink(_ ml: Int, type: DrinkType = .water) -> Int64 {
        let now = Self.tsFormat.string(from: Date())
        let today = Self.dayFormat.string(from: Date())
        let sql = "INSERT INTO drink_records (amount_ml, ts, date, drink_type) VALUES (?, ?, ?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(ml))
        sqlite3_bind_text(stmt, 2, now, -1, transient)
        sqlite3_bind_text(stmt, 3, today, -1, transient)
        sqlite3_bind_text(stmt, 4, type.rawValue, -1, transient)
        // step必须成功 否则last_insert_rowid会返回上一次的旧id 假成功
        guard sqlite3_step(stmt) == SQLITE_DONE else { return 0 }
        return sqlite3_last_insert_rowid(db)
    }

    // 某天水合总量 按类型加权取整
    func totalML(on date: String) -> Int {
        queryInt("SELECT CAST(ROUND(COALESCE(SUM(amount_ml * \(Self.ratioCase)), 0)) AS INTEGER) FROM drink_records WHERE date = ?", [date])
    }

    // 今日总量
    func todayTotalML() -> Int {
        totalML(on: Self.dayFormat.string(from: Date()))
    }

    // 当日目标覆盖 只影响这一天 没设过返回nil
    func todayGoalOverride() -> Int? {
        goalOverride(on: Self.dayFormat.string(from: Date()))
    }

    // 某天目标覆盖 分享卡回看历史用
    func goalOverride(on date: String) -> Int? {
        var stmt: OpaquePointer?
        let sql = "SELECT goal_ml FROM goal_overrides WHERE date = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, date, -1, transient)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    // 设置当日目标 只写今天这个日期 明天起仍用默认值
    func setGoalOverride(date: String, ml: Int) {
        var stmt: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO goal_overrides (date, goal_ml) VALUES (?, ?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, date, -1, transient)
        sqlite3_bind_int(stmt, 2, Int32(ml))
        sqlite3_step(stmt)
    }

    // 今日杯数
    func todayCups() -> Int {
        queryInt("SELECT COUNT(*) FROM drink_records WHERE date = ?",
                 [Self.dayFormat.string(from: Date())])
    }

    // 连续达标天数 今天没达标不算断 从昨天继续数
    func streakDays(goalML: Int) -> Int {
        streakDays(on: Self.dayFormat.string(from: Date()), goalML: goalML)
    }

    // 连续达标天数(截至某天) 向前回溯 该天没达标不算断
    func streakDays(on target: String, goalML: Int) -> Int {
        var stmt: OpaquePointer?
        let sql = """
            SELECT date, CAST(ROUND(COALESCE(SUM(amount_ml * \(Self.ratioCase)), 0)) AS INTEGER)
            FROM drink_records GROUP BY date ORDER BY date DESC LIMIT 90
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        let cal = Calendar.current
        var streak = 0
        var prevDate: Date?
        while sqlite3_step(stmt) == SQLITE_ROW {
            let dateStr = String(cString: sqlite3_column_text(stmt, 0))
            let total = Int(sqlite3_column_int64(stmt, 1))
            // 目标日期之前的记录不看
            if dateStr > target { continue }
            guard let day = Self.dayFormat.date(from: dateStr) else { break }
            // 日期断档 连不上就断
            if let prev = prevDate, cal.dateComponents([.day], from: day, to: prev).day != 1 { break }
            prevDate = day
            if total >= goalML {
                streak += 1
            } else if dateStr == target {
                continue // 截至日当天没达标不算断
            } else {
                break
            }
            if dateStr == target { break } // 数到目标日为止
        }
        return streak
    }

    // 全库累计水合总量 分享卡用
    func totalAllML() -> Int {
        queryInt("SELECT CAST(ROUND(COALESCE(SUM(amount_ml * \(Self.ratioCase)), 0)) AS INTEGER) FROM drink_records", [])
    }

    // 某天杯数
    func cups(on date: String) -> Int {
        queryInt("SELECT COUNT(*) FROM drink_records WHERE date = ?", [date])
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

    // 一周每天水合总量 key=yyyy-MM-dd
    func mlByDate(dates: [String]) -> [String: Int] {
        guard !dates.isEmpty else { return [:] }
        let qs = dates.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT date, CAST(ROUND(COALESCE(SUM(amount_ml * \(Self.ratioCase)), 0)) AS INTEGER) FROM drink_records WHERE date IN (\(qs)) GROUP BY date"
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

    // 今日喝水明细 时间正序
    func todayRecords() -> [(id: Int64, date: Date, ml: Int, type: DrinkType)] {
        var stmt: OpaquePointer?
        let sql = "SELECT id, ts, amount_ml, drink_type FROM drink_records WHERE date = ? ORDER BY ts ASC"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, Self.dayFormat.string(from: Date()), -1, transient)
        var out: [(id: Int64, date: Date, ml: Int, type: DrinkType)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let c = sqlite3_column_text(stmt, 1),
                  let d = Self.tsFormat.date(from: String(cString: c)) else { continue }
            let t = String(cString: sqlite3_column_text(stmt, 3))
            out.append((sqlite3_column_int64(stmt, 0), d, Int(sqlite3_column_int64(stmt, 2)),
                        DrinkType(rawValue: t) ?? .water))
        }
        return out
    }

    // 改一条记录的量
    func updateDrink(id: Int64, ml: Int) {
        var stmt: OpaquePointer?
        let sql = "UPDATE drink_records SET amount_ml = ? WHERE id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(ml))
        sqlite3_bind_int64(stmt, 2, id)
        sqlite3_step(stmt)
    }

    // 删一条记录
    func deleteDrink(id: Int64) {
        var stmt: OpaquePointer?
        let sql = "DELETE FROM drink_records WHERE id = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        sqlite3_step(stmt)
    }

    // 撤销删除 按原时间插回
    func restoreDrink(ts: Date, ml: Int, type: DrinkType = .water) -> Int64 {
        var stmt: OpaquePointer?
        let sql = "INSERT INTO drink_records (amount_ml, ts, date, drink_type) VALUES (?, ?, ?, ?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        let t = Self.tsFormat.string(from: ts)
        sqlite3_bind_int(stmt, 1, Int32(ml))
        sqlite3_bind_text(stmt, 2, t, -1, transient)
        sqlite3_bind_text(stmt, 3, Self.dayFormat.string(from: ts), -1, transient)
        sqlite3_bind_text(stmt, 4, type.rawValue, -1, transient)
        sqlite3_step(stmt)
        return sqlite3_last_insert_rowid(db)
    }

    // MARK: 统计页

    // 全历史每天水合总量 升序 最佳连续/最佳日用
    func dayTotals() -> [(date: String, ml: Int)] {
        var stmt: OpaquePointer?
        let sql = """
            SELECT date, CAST(ROUND(COALESCE(SUM(amount_ml * \(Self.ratioCase)), 0)) AS INTEGER)
            FROM drink_records GROUP BY date ORDER BY date ASC
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [(date: String, ml: Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            out.append((String(cString: sqlite3_column_text(stmt, 0)), Int(sqlite3_column_int64(stmt, 1))))
        }
        return out
    }

    // 批量取目标覆盖 key=date SQLite变量上限999 分片500稳妥
    func goalOverrides(dates: [String]) -> [String: Int] {
        var out: [String: Int] = [:]
        for start in stride(from: 0, to: dates.count, by: 500) {
            let chunk = Array(dates[start..<min(start + 500, dates.count)])
            guard !chunk.isEmpty else { continue }
            let qs = chunk.map { _ in "?" }.joined(separator: ",")
            let sql = "SELECT date, goal_ml FROM goal_overrides WHERE date IN (\(qs))"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
            defer { sqlite3_finalize(stmt) }
            for (i, d) in chunk.enumerated() {
                sqlite3_bind_text(stmt, Int32(i + 1), d, -1, transient)
            }
            while sqlite3_step(stmt) == SQLITE_ROW {
                out[String(cString: sqlite3_column_text(stmt, 0))] = Int(sqlite3_column_int64(stmt, 1))
            }
        }
        return out
    }

    // 区间内各类型 原始ml与杯数 量降序
    func typeTotals(dates: [String]) -> [(type: DrinkType, ml: Int, cups: Int)] {
        guard !dates.isEmpty else { return [] }
        let qs = dates.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT drink_type, SUM(amount_ml), COUNT(*) FROM drink_records WHERE date IN (\(qs)) GROUP BY drink_type ORDER BY 2 DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, d) in dates.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), d, -1, transient)
        }
        var out: [(type: DrinkType, ml: Int, cups: Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let t = String(cString: sqlite3_column_text(stmt, 0))
            out.append((DrinkType(rawValue: t) ?? .water,
                        Int(sqlite3_column_int64(stmt, 1)),
                        Int(sqlite3_column_int64(stmt, 2))))
        }
        return out
    }

    // 区间内每小时加权水合量 key=hour(0-23)
    func mlByHour(dates: [String]) -> [Int: Int] {
        guard !dates.isEmpty else { return [:] }
        let qs = dates.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT CAST(strftime('%H', ts) AS INTEGER) AS h,
                   CAST(ROUND(COALESCE(SUM(amount_ml * \(Self.ratioCase)), 0)) AS INTEGER)
            FROM drink_records WHERE date IN (\(qs)) GROUP BY h
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(stmt) }
        for (i, d) in dates.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), d, -1, transient)
        }
        var out: [Int: Int] = [:]
        while sqlite3_step(stmt) == SQLITE_ROW {
            out[Int(sqlite3_column_int64(stmt, 0))] = Int(sqlite3_column_int64(stmt, 1))
        }
        return out
    }

    // 区间内全部记录 时间正序 方格卡用
    func recordsIn(dates: [String]) -> [(id: Int64, ts: Date, ml: Int, type: DrinkType)] {
        guard !dates.isEmpty else { return [] }
        let qs = dates.map { _ in "?" }.joined(separator: ",")
        let sql = "SELECT id, ts, amount_ml, drink_type FROM drink_records WHERE date IN (\(qs)) ORDER BY ts ASC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        for (i, d) in dates.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), d, -1, transient)
        }
        var out: [(id: Int64, ts: Date, ml: Int, type: DrinkType)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let c = sqlite3_column_text(stmt, 1),
                  let t = Self.tsFormat.date(from: String(cString: c)) else { continue }
            out.append((sqlite3_column_int64(stmt, 0), t,
                        Int(sqlite3_column_int64(stmt, 2)),
                        DrinkType(rawValue: String(cString: sqlite3_column_text(stmt, 3))) ?? .water))
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
