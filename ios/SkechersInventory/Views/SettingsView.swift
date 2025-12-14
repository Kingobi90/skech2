import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var syncManager: SyncManager
    @State private var userName = ""
    @State private var userRole = "Sales Rep"
    @State private var apiEndpoint = ""
    @State private var autoSyncEnabled = true
    @State private var syncInterval = 60
    @State private var lastSyncDate: Date?
    @State private var showingSyncAlert = false
    @State private var showingRolePicker = false
    @State private var isConnected = false
    @State private var isTestingConnection = false
    @State private var connectionMessage = ""
    
    let availableRoles = ["Sales Rep", "Manager", "Warehouse Staff", "Admin"]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Settings")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                    .padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("User Profile")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                    
                    OptimizedGlassCard(useBlur: false) {
                        VStack(spacing: 16) {
                            SettingsTextField(title: "Name", text: $userName, placeholder: "Enter your name")
                                .onChange(of: userName) { newValue in
                                    saveUserName(newValue)
                                }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            Button(action: { showingRolePicker = true }) {
                                HStack {
                                    Text("Role")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Spacer()
                                    
                                    Text(userRole)
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Synchronization")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                    
                    OptimizedGlassCard(useBlur: false) {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Auto Sync")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Toggle("", isOn: $autoSyncEnabled)
                                    .labelsHidden()
                                    .onChange(of: autoSyncEnabled) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: "autoSyncEnabled")
                                    }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            HStack {
                                Text("Sync Interval")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("\(syncInterval)s")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            HStack {
                                Text("Last Sync")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text(lastSyncText)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            Button(action: {
                                performManualSync()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Sync Now")
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Connection")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                    
                    OptimizedGlassCard(useBlur: false) {
                        VStack(spacing: 16) {
                            SettingsTextField(
                                title: "API Endpoint",
                                text: $apiEndpoint,
                                placeholder: "http://192.168.1.100:8000"
                            )

                            Divider()
                                .background(Color.white.opacity(0.2))

                            Button(action: testConnection) {
                                HStack {
                                    if isTestingConnection {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Testing...")
                                    } else {
                                        Image(systemName: "network")
                                        Text("Test Connection")
                                    }
                                }
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15))
                                )
                            }
                            .disabled(isTestingConnection || apiEndpoint.isEmpty)

                            Divider()
                                .background(Color.white.opacity(0.2))

                            HStack {
                                Text("Connection Status")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)

                                Spacer()

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(isConnected ? Color.green : Color.red)
                                        .frame(width: 8, height: 8)

                                    Text(isConnected ? "Connected" : "Disconnected")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }

                            if !connectionMessage.isEmpty {
                                Text(connectionMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(isConnected ? .green : .red)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Data Management")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                    
                    OptimizedGlassCard(useBlur: false) {
                        VStack(spacing: 16) {
                            Button(action: {
                                // Clear cache
                            }) {
                                HStack {
                                    Text("Clear Cache")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            
                            Divider()
                                .background(Color.white.opacity(0.2))
                            
                            Button(action: {
                                // Export data
                            }) {
                                HStack {
                                    Text("Export Data")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.black)
        .alert("Sync Complete", isPresented: $showingSyncAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Data synchronized successfully")
        }
        .sheet(isPresented: $showingRolePicker) {
            RolePickerView(selectedRole: $userRole)
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private var lastSyncText: String {
        guard let date = lastSyncDate else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func loadSettings() {
        userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        userRole = UserDefaults.standard.string(forKey: "userRole") ?? "Sales Rep"
        apiEndpoint = UserDefaults.standard.string(forKey: "backend_url") ?? ""
        autoSyncEnabled = UserDefaults.standard.bool(forKey: "autoSyncEnabled")
        syncInterval = UserDefaults.standard.integer(forKey: "syncInterval")

        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            lastSyncDate = timestamp
        }

        // Test connection on load
        if !apiEndpoint.isEmpty {
            Task {
                await testConnectionAsync()
            }
        }
    }

    private func saveUserName(_ name: String) {
        UserDefaults.standard.set(name, forKey: "userName")
    }

    private func testConnection() {
        Task {
            await testConnectionAsync()
        }
    }

    private func testConnectionAsync() async {
        isTestingConnection = true
        connectionMessage = ""

        let result = await APIManager.shared.testAndSaveURL(apiEndpoint)

        await MainActor.run {
            isConnected = result
            isTestingConnection = false
            if result {
                connectionMessage = "Successfully connected to server"
            } else {
                connectionMessage = "Failed to connect. Check URL and try again"
            }
        }
    }

    private func performManualSync() {
        Task {
            await syncManager.performFullSync()
            lastSyncDate = Date()
            showingSyncAlert = true
        }
    }
}

struct SettingsTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            
            TextField(placeholder, text: $text)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.vertical, 8)
        }
    }
}
