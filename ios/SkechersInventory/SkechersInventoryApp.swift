import SwiftUI

@main
struct SkechersInventoryApp: App {
    @StateObject private var databaseManager = DatabaseManager.shared
    @StateObject private var syncManager = SyncManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseManager)
                .environmentObject(syncManager)
                .onAppear {
                    initializeApp()
                }
        }
    }
    
    private func initializeApp() {
        databaseManager.initializeDatabase()
        
        if syncManager.needsSync() {
            Task {
                await syncManager.performFullSync()
            }
        }
    }
}
