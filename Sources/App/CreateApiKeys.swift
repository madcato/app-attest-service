import Fluent
import FluentSQL

struct CreateApiKeys: AsyncMigration {
  func prepare(on database: Database) async throws {
    guard let database = database as? SQLDatabase else { fatalError("Erro accessing db") }
    // Create api_keys table with raw SQL (includes CHECK constraint)
    try await database.raw("""
            CREATE TABLE \(unsafeRaw: ApiKey.schema) (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                grok_key TEXT NOT NULL,
                status TEXT NOT NULL,
                daily_spend_limit_usd REAL NOT NULL,
                daily_request_limit INTEGER NOT NULL,
                created_at DATETIME NOT NULL,
                assigned_at DATETIME,
                last_used_at DATETIME,
                revoked_at DATETIME,
                total_spent_usd REAL NOT NULL,
                total_requests INTEGER NOT NULL,
                UNIQUE(grok_key),
                CHECK(status IN ('available','assigned','revoked','burned'))
            )
        """).run()
    
    // Create device_assignments table with raw SQL (includes CHECK and FOREIGN KEY)
    try await database.raw("""
            CREATE TABLE \(unsafeRaw: DeviceAssignment.schema) (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT NOT NULL,
                api_key_id INTEGER NOT NULL,
                plan TEXT NOT NULL,
                assigned_at DATETIME NOT NULL,
                last_active_at DATETIME NOT NULL,
                revenuecat_user_id TEXT,
                subscription_expires_at DATETIME,
                UNIQUE(device_id),
                UNIQUE(api_key_id),
                CHECK(plan IN ('free','paid','trial','grandfathered')),
                FOREIGN KEY(api_key_id) REFERENCES \(unsafeRaw: ApiKey.schema)(id) ON DELETE RESTRICT
            )
        """).run()
    
    // Indexes (using raw SQL)
    try await database.raw("""
            CREATE INDEX idx_keys_available ON \(unsafeRaw: ApiKey.schema) (status) WHERE status = 'available'
        """).run()
    try await database.raw("""
            CREATE INDEX idx_keys_last_used ON \(unsafeRaw: ApiKey.schema) (last_used_at)
        """).run()
    try await database.raw("""
            CREATE INDEX idx_device_active ON \(unsafeRaw: DeviceAssignment.schema) (last_active_at)
        """).run()
    try await database.raw("""
            CREATE INDEX idx_device_plan ON \(unsafeRaw: DeviceAssignment.schema) (plan)
        """).run()
    
    // View (raw SQL)
    try await database.raw("""
            CREATE VIEW next_available_key AS
            SELECT id, grok_key
            FROM \(unsafeRaw: ApiKey.schema)
            WHERE status = 'available'
            ORDER BY id ASC
            LIMIT 1
        """).run()
    
    // PRAGMAs (raw SQL)
    try await database.raw("PRAGMA journal_mode = WAL").run()
    try await database.raw("PRAGMA foreign_keys = ON").run()
    try await database.raw("PRAGMA busy_timeout = 5000").run()
  }
  
  func revert(on database: Database) async throws {
    guard let database = database as? SQLDatabase else { fatalError("Erro accessing db") }
    
    try await database.raw("DROP TABLE IF EXISTS \(DeviceAssignment.schema)").run()
    try await database.raw("DROP TABLE IF EXISTS \(ApiKey.schema)").run()
    try await database.raw("DROP VIEW IF EXISTS next_available_key").run()
  }
}
