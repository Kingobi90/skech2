import Foundation
import Combine

// Pending change types
enum PendingChangeType: String, Codable {
    case classification
    case placement
    case catalogItem
}

struct PendingChange: Codable, Identifiable {
    let id: UUID
    let type: PendingChangeType
    let data: Data
    let timestamp: Date
}

class SyncManager: ObservableObject {
    static let shared = SyncManager()

    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var pendingChangesCount: Int = 0

    private let databaseManager = DatabaseManager.shared
    private let apiManager = APIManager.shared
    private var syncTimer: Timer?
    private let deviceId: String
    private var pendingChanges: [PendingChange] = []
    private let pendingChangesKey = "pendingChanges"

    private init() {
        if let savedDeviceId = UserDefaults.standard.string(forKey: "deviceId") {
            deviceId = savedDeviceId
        } else {
            deviceId = UUID().uuidString
            UserDefaults.standard.set(deviceId, forKey: "deviceId")
        }

        loadLastSyncDate()
        loadPendingChanges()
    }

    // MARK: - Offline Queue Management

    func queueClassification(styleNumber: String, color: String, status: String, coordinatorName: String?, confidenceScore: Double?) {
        let data: [String: Any] = [
            "style_number": styleNumber,
            "color": color,
            "status": status,
            "coordinator_name": coordinatorName as Any,
            "confidence_score": confidenceScore as Any
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else { return }

        let change = PendingChange(
            id: UUID(),
            type: .classification,
            data: jsonData,
            timestamp: Date()
        )

        pendingChanges.append(change)
        savePendingChanges()
        print("✅ Queued classification for offline sync: \(styleNumber) - \(color)")
    }

    func queuePlacement(classificationId: Int, shelfLocation: String, coordinatorUserId: Int?) {
        let data: [String: Any] = [
            "classification_id": classificationId,
            "shelf_location": shelfLocation,
            "coordinator_user_id": coordinatorUserId as Any
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else { return }

        let change = PendingChange(
            id: UUID(),
            type: .placement,
            data: jsonData,
            timestamp: Date()
        )

        pendingChanges.append(change)
        savePendingChanges()
        print("✅ Queued placement for offline sync: \(shelfLocation)")
    }

    private func loadPendingChanges() {
        guard let data = UserDefaults.standard.data(forKey: pendingChangesKey),
              let changes = try? JSONDecoder().decode([PendingChange].self, from: data) else {
            pendingChanges = []
            pendingChangesCount = 0
            return
        }
        pendingChanges = changes
        pendingChangesCount = changes.count
        print("📦 Loaded \(changes.count) pending changes from disk")
    }

    private func savePendingChanges() {
        guard let data = try? JSONEncoder().encode(pendingChanges) else { return }
        UserDefaults.standard.set(data, forKey: pendingChangesKey)
        pendingChangesCount = pendingChanges.count
    }

    private func syncPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }

        print("📤 Syncing \(pendingChanges.count) pending changes...")

        var failedChanges: [PendingChange] = []

        for change in pendingChanges {
            do {
                switch change.type {
                case .classification:
                    if let dict = try JSONSerialization.jsonObject(with: change.data) as? [String: Any] {
                        _ = try await apiManager.createClassification(
                            styleNumber: dict["style_number"] as? String ?? "",
                            color: dict["color"] as? String ?? "",
                            status: dict["status"] as? String ?? "drop",
                            confidenceScore: dict["confidence_score"] as? Double
                        )
                        print("✅ Synced classification")
                    }

                case .placement:
                    if let dict = try JSONSerialization.jsonObject(with: change.data) as? [String: Any] {
                        // Note: This would need a corresponding API endpoint
                        print("⚠️ Placement sync not fully implemented")
                    }

                case .catalogItem:
                    print("⚠️ Catalog item sync not fully implemented")
                }
            } catch {
                print("❌ Failed to sync change: \(error)")
                failedChanges.append(change)
            }
        }

        // Keep only failed changes for retry
        pendingChanges = failedChanges
        savePendingChanges()

        if failedChanges.isEmpty {
            print("✅ All pending changes synced successfully")
        } else {
            print("⚠️ \(failedChanges.count) changes failed to sync, will retry later")
        }
    }
    
    func needsSync() -> Bool {
        guard let lastSync = lastSyncDate else {
            return true
        }
        
        let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
        return hoursSinceSync > 24
    }
    
    func performFullSync() async {
        guard !isSyncing else { return }
        
        await MainActor.run {
            isSyncing = true
        }
        
        do {
            let syncData = try await apiManager.fullSync(deviceId: deviceId)
            
            await databaseManager.saveStyles(syncData.styles)
            await databaseManager.savePlacements(syncData.placements)
            
            let now = Date()
            await databaseManager.updateSyncLog(deviceId: deviceId, status: "success")
            
            await MainActor.run {
                lastSyncDate = now
                UserDefaults.standard.set(now, forKey: "lastSyncDate")
                isSyncing = false
            }
            
            print("Full sync completed successfully")
        } catch {
            print("Sync error: \(error)")
            await databaseManager.updateSyncLog(deviceId: deviceId, status: "failed")
            
            await MainActor.run {
                isSyncing = false
            }
        }
    }
    
    func performIncrementalSync() async {
        guard !isSyncing else { return }
        guard let lastSync = lastSyncDate else {
            await performFullSync()
            return
        }

        await MainActor.run {
            isSyncing = true
        }

        do {
            // First, upload any pending offline changes
            await syncPendingChanges()

            // Then, download server changes
            let changes = try await apiManager.incrementalSync(since: lastSync, deviceId: deviceId)

            if !changes.styles.isEmpty {
                await databaseManager.saveStyles(changes.styles)
            }

            if !changes.placements.isEmpty {
                await databaseManager.savePlacements(changes.placements)
            }

            let now = Date()
            await databaseManager.updateSyncLog(deviceId: deviceId, status: "success")

            await MainActor.run {
                lastSyncDate = now
                UserDefaults.standard.set(now, forKey: "lastSyncDate")
                isSyncing = false
            }

            print("✅ Incremental sync completed: \(changes.styles.count) styles, \(changes.placements.count) placements")
        } catch {
            print("❌ Incremental sync error: \(error)")
            await MainActor.run {
                isSyncing = false
            }
        }
    }
    
    func startAutoSync(interval: TimeInterval = 60) {
        stopAutoSync()
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.performIncrementalSync()
            }
        }
    }
    
    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    private func loadLastSyncDate() {
        Task {
            if let date = await databaseManager.getLastSyncTimestamp() {
                await MainActor.run {
                    lastSyncDate = date
                }
            } else if let savedDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
                await MainActor.run {
                    lastSyncDate = savedDate
                }
            }
        }
    }
}

struct SyncResponse: Codable {
    let files: [SyncFile]
    let styles: [SyncStyle]
    let placements: [SyncPlacement]
    let syncMetadata: SyncMetadata
    
    enum CodingKeys: String, CodingKey {
        case files
        case styles
        case placements
        case syncMetadata = "sync_metadata"
    }
}

struct SyncFile: Codable {
    let id: Int
    let filename: String
    let fileType: String
    let category: String
    let uploadDate: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case filename
        case fileType = "file_type"
        case category
        case uploadDate = "upload_date"
    }
}

struct SyncMetadata: Codable {
    let currentTimestamp: String
    let totalStyles: Int?
    let totalPlacements: Int?
    
    enum CodingKeys: String, CodingKey {
        case currentTimestamp = "current_timestamp"
        case totalStyles = "total_styles"
        case totalPlacements = "total_placements"
    }
}

struct IncrementalSyncResponse: Codable {
    let styles: [SyncStyle]
    let placements: [SyncPlacement]
    let syncMetadata: SyncMetadata
    
    enum CodingKeys: String, CodingKey {
        case styles
        case placements
        case syncMetadata = "sync_metadata"
    }
}
