import Foundation
import GRDB

class DatabaseManager: ObservableObject {
    static let shared = DatabaseManager()
    
    private var dbQueue: DatabaseQueue?
    
    private init() {}
    
    func initializeDatabase() {
        do {
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dbPath = documentsPath.appendingPathComponent("skechers_inventory.db")
            
            dbQueue = try DatabaseQueue(path: dbPath.path)
            
            try dbQueue?.write { db in
                try db.create(table: "styles", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("style_number", .text).notNull().unique()
                    t.column("division", .text)
                    t.column("outsole", .text)
                    t.column("gender", .text)
                    t.column("source_file_ids", .text)
                    t.column("created_at", .datetime).notNull()
                    t.column("updated_at", .datetime).notNull()
                }
                
                try db.create(table: "colors", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("style_id", .integer).notNull()
                        .references("styles", onDelete: .cascade)
                    t.column("color_name", .text).notNull()
                    t.column("source_file_id", .integer)
                    t.column("created_at", .datetime).notNull()
                }
                
                try db.create(table: "showroom_inventory", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("style_number", .text).notNull()
                    t.column("color", .text).notNull()
                    t.column("shelf_location", .text)
                    t.column("status", .text).notNull()
                    t.column("coordinator_id", .integer)
                    t.column("manager_approved", .boolean).notNull().defaults(to: false)
                    t.column("date_placed", .datetime)
                    t.column("final_status", .text)
                }
                
                try db.create(table: "catalog_items", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("style_number", .text).notNull()
                    t.column("color", .text).notNull()
                    t.column("scanned_at", .datetime).notNull()
                }
                
                try db.create(table: "sync_log", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("last_sync_timestamp", .datetime).notNull()
                    t.column("device_id", .text).notNull()
                    t.column("sync_status", .text).notNull()
                }
                
                try db.create(index: "idx_styles_number", on: "styles", columns: ["style_number"], ifNotExists: true)
                try db.create(index: "idx_colors_style_id", on: "colors", columns: ["style_id"], ifNotExists: true)
                try db.create(index: "idx_inventory_style", on: "showroom_inventory", columns: ["style_number"], ifNotExists: true)
            }
            
            print("Database initialized successfully")
        } catch {
            print("Database initialization error: \(error)")
        }
    }
    
    func getStyle(byNumber styleNumber: String) async -> StyleRecord? {
        return try? await dbQueue?.read { db in
            try StyleRecord.fetchOne(db, sql: "SELECT * FROM styles WHERE LOWER(style_number) = LOWER(?)", arguments: [styleNumber])
        }
    }
    
    func getColors(forStyleId styleId: Int) async -> [ColorRecord] {
        return (try? await dbQueue?.read { db in
            try ColorRecord.fetchAll(db, sql: "SELECT * FROM colors WHERE style_id = ?", arguments: [styleId])
        }) ?? []
    }
    
    func getAllInventoryItems() async -> [InventoryItem] {
        return (try? await dbQueue?.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT si.id, si.style_number, si.color, si.status, si.shelf_location,
                       s.division, s.gender
                FROM showroom_inventory si
                LEFT JOIN styles s ON si.style_number = s.style_number
                ORDER BY si.date_placed DESC
            """)
            
            return rows.map { row in
                InventoryItem(
                    id: row["id"],
                    styleNumber: row["style_number"],
                    color: row["color"],
                    status: ItemStatus(rawValue: row["status"]) ?? .drop,
                    division: row["division"],
                    gender: row["gender"],
                    shelfLocation: row["shelf_location"]
                )
            }
        }) ?? []
    }
    
    func getStatistics() async -> SystemStats? {
        return try? await dbQueue?.read { db in
            let totalStyles = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM styles") ?? 0
            let showroomCount = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM showroom_inventory WHERE status = 'keep'") ?? 0
            let pendingApprovals = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM showroom_inventory WHERE manager_approved = 0") ?? 0
            
            return SystemStats(
                totalStyles: totalStyles,
                showroomCount: showroomCount,
                pendingApprovals: pendingApprovals
            )
        }
    }
    
    func saveStyles(_ styles: [SyncStyle]) async {
        try? await dbQueue?.write { db in
            for style in styles {
                let existingStyle = try StyleRecord.fetchOne(db, sql: "SELECT * FROM styles WHERE LOWER(style_number) = LOWER(?)", arguments: [style.styleNumber])
                
                if let existing = existingStyle {
                    try db.execute(sql: """
                        UPDATE styles SET division = ?, gender = ?, outsole = ?, updated_at = ?
                        WHERE id = ?
                    """, arguments: [style.division, style.gender, style.outsole, Date(), existing.id])
                    
                    try db.execute(sql: "DELETE FROM colors WHERE style_id = ?", arguments: [existing.id])
                    
                    for color in style.colors {
                        try db.execute(sql: """
                            INSERT INTO colors (style_id, color_name, created_at)
                            VALUES (?, ?, ?)
                        """, arguments: [existing.id, color, Date()])
                    }
                } else {
                    try db.execute(sql: """
                        INSERT INTO styles (style_number, division, gender, outsole, source_file_ids, created_at, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, arguments: [style.styleNumber, style.division, style.gender, style.outsole, "[]", Date(), Date()])
                    
                    let styleId = db.lastInsertedRowID
                    
                    for color in style.colors {
                        try db.execute(sql: """
                            INSERT INTO colors (style_id, color_name, created_at)
                            VALUES (?, ?, ?)
                        """, arguments: [styleId, color, Date()])
                    }
                }
            }
        }
    }
    
    func savePlacements(_ placements: [SyncPlacement]) async {
        try? await dbQueue?.write { db in
            for placement in placements {
                try db.execute(sql: """
                    INSERT OR REPLACE INTO showroom_inventory 
                    (style_number, color, shelf_location, status, manager_approved, date_placed, final_status)
                    VALUES (?, ?, ?, 'keep', 1, ?, 'keep')
                """, arguments: [placement.styleNumber, placement.color, placement.shelfLocation, Date()])
            }
        }
    }
    
    func updateSyncLog(deviceId: String, status: String) async {
        try? await dbQueue?.write { db in
            try db.execute(sql: """
                INSERT INTO sync_log (last_sync_timestamp, device_id, sync_status)
                VALUES (?, ?, ?)
            """, arguments: [Date(), deviceId, status])
        }
    }
    
    func getLastSyncTimestamp() async -> Date? {
        return try? await dbQueue?.read { db in
            try Date.fetchOne(db, sql: "SELECT last_sync_timestamp FROM sync_log ORDER BY id DESC LIMIT 1")
        }
    }
}

struct StyleRecord: Codable, FetchableRecord {
    let id: Int
    let styleNumber: String
    let division: String?
    let outsole: String?
    let gender: String?
    let sourceFileIds: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case styleNumber = "style_number"
        case division
        case outsole
        case gender
        case sourceFileIds = "source_file_ids"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ColorRecord: Codable, FetchableRecord {
    let id: Int
    let styleId: Int
    let colorName: String
    let sourceFileId: Int?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case styleId = "style_id"
        case colorName = "color_name"
        case sourceFileId = "source_file_id"
        case createdAt = "created_at"
    }
}

struct SyncStyle: Codable {
    let id: Int
    let styleNumber: String
    let division: String?
    let gender: String?
    let outsole: String?
    let colors: [String]
    let sourceFileIds: [Int]
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case styleNumber = "style_number"
        case division
        case gender
        case outsole
        case colors
        case sourceFileIds = "source_file_ids"
        case updatedAt = "updated_at"
    }
}

struct SyncPlacement: Codable {
    let id: Int
    let styleNumber: String
    let color: String
    let shelfLocation: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case styleNumber = "style_number"
        case color
        case shelfLocation = "shelf_location"
    }
}
