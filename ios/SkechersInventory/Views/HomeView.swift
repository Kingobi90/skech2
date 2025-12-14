import SwiftUI

struct HomeView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @EnvironmentObject var syncManager: SyncManager
    @State private var userName: String = "User"
    @State private var stats: SystemStats = SystemStats()
    @State private var recentItems: [InventoryItem] = []
    @State private var showingCamera = false
    @State private var showingManualEntry = false
    @State private var showingFileUpload = false
    @State private var showingWarehouseMode = false
    @State private var showingCatalog = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Welcome back, \(userName)")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                
                OptimizedGlassCard(useBlur: true) {
                    HStack(spacing: 40) {
                        StatItem(value: stats.totalStyles, label: "Total\nStyles")
                        StatItem(value: stats.showroomCount, label: "In\nShowroom")
                        StatItem(value: stats.pendingApprovals, label: "Pending\nApproval")
                    }
                }
                .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Access")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 24)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        QuickActionButton(icon: "camera.fill", title: "Scan Shoe", action: { showingCamera = true })
                        QuickActionButton(icon: "doc.text.fill", title: "Build Catalog", action: { showingCatalog = true })
                        QuickActionButton(icon: "shippingbox.fill", title: "Warehouse Mode", action: { showingWarehouseMode = true })
                        QuickActionButton(icon: "arrow.up.doc.fill", title: "Upload Files", action: { showingFileUpload = true })
                    }
                    .padding(.horizontal, 24)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Recent Activity")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        Spacer()

                        if syncManager.pendingChangesCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11))
                                Text("\(syncManager.pendingChangesCount) pending")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 24)

                    if recentItems.isEmpty {
                        Text("No recent activity")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(recentItems.prefix(5)) { item in
                                HStack(spacing: 8) {
                                    StatusBadge(status: item.status)
                                        .scaleEffect(0.8)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Style #\(item.styleNumber)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))

                                        Text(item.color)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                    }

                                    Spacer()

                                    if let shelf = item.shelfLocation {
                                        Text(shelf)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.black)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraScannerView(mode: .salesRep)
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .sheet(isPresented: $showingCatalog) {
            CatalogBuilderView()
        }
        .sheet(isPresented: $showingFileUpload) {
            FileUploadView()
        }
        .sheet(isPresented: $showingWarehouseMode) {
            WorkflowView()
        }
        .onAppear {
            loadUserData()
            loadStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            loadStats()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshStats"))) { _ in
            loadStats()
        }
    }
    
    private func loadUserData() {
        userName = UserDefaults.standard.string(forKey: "userName") ?? "User"
    }
    
    private func loadStats() {
        Task {
            if let loadedStats = await databaseManager.getStatistics() {
                stats = loadedStats
            }

            // Load recent inventory items
            let items = await databaseManager.getAllInventoryItems()
            recentItems = Array(items.prefix(5))
        }
    }
}

struct StatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        OptimizedGlassCard(useBlur: false) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }
    }
}

