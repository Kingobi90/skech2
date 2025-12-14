import SwiftUI
import UniformTypeIdentifiers

struct CatalogBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var catalogItems: [CatalogItem] = []
    @State private var showingScanner = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    
    private let catalogKey = "salesRepCatalog"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header stats
                    HStack(spacing: 20) {
                        StatBadge(label: "Items", value: catalogItems.count, color: .white)
                        StatBadge(label: "Styles", value: uniqueStyleCount, color: .blue)
                        StatBadge(label: "Colors", value: catalogItems.count, color: .green)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Catalog items list
                    if catalogItems.isEmpty {
                        Spacer()
                        VStack(spacing: 24) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 64, weight: .thin))
                                .foregroundColor(.white.opacity(0.3))
                            
                            VStack(spacing: 8) {
                                Text("No Items in Catalog")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Scan shoe tags to build your catalog")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Button(action: { showingScanner = true }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Start Scanning")
                                }
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue)
                                )
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(catalogItems) { item in
                                    CatalogItemRow(item: item, onDelete: {
                                        deleteItem(item)
                                    })
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
            .navigationTitle("My Catalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !catalogItems.isEmpty {
                            Button(action: exportCatalog) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                            }
                            
                            Button(action: clearCatalog) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        
                        Button(action: { showingScanner = true }) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                CameraScannerView(mode: .catalogBuilder)
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .onAppear {
                loadCatalog()
            }
        }
    }
    
    private var uniqueStyleCount: Int {
        Set(catalogItems.map { $0.styleNumber }).count
    }
    
    private func loadCatalog() {
        if let data = UserDefaults.standard.data(forKey: catalogKey),
           let decoded = try? JSONDecoder().decode([CatalogItem].self, from: data) {
            catalogItems = decoded
        }
    }
    
    private func saveCatalog() {
        if let encoded = try? JSONEncoder().encode(catalogItems) {
            UserDefaults.standard.set(encoded, forKey: catalogKey)
        }
    }
    
    func addItem(_ item: CatalogItem) {
        // Check if item already exists
        if !catalogItems.contains(where: { $0.styleNumber == item.styleNumber && $0.colorCode == item.colorCode }) {
            catalogItems.insert(item, at: 0)
            saveCatalog()
        }
    }
    
    private func deleteItem(_ item: CatalogItem) {
        catalogItems.removeAll { $0.id == item.id }
        saveCatalog()
    }
    
    private func clearCatalog() {
        catalogItems.removeAll()
        saveCatalog()
    }
    
    private func exportCatalog() {
        let csvContent = generateCSV()
        
        let fileName = "catalog_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            exportURL = tempURL
            showingExportSheet = true
        } catch {
            print("Error exporting CSV: \(error)")
        }
    }
    
    private func generateCSV() -> String {
        var csv = "Style Number,Color Code,Color Name,Division,Gender,Outsole,Status,Added Date\n"
        
        for item in catalogItems {
            let row = [
                item.styleNumber,
                item.colorCode,
                item.colorName,
                item.division ?? "",
                item.gender ?? "",
                item.outsole ?? "",
                item.status.rawValue,
                item.addedDate.formatted(date: .numeric, time: .shortened)
            ].map { "\"\($0)\"" }.joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
}

struct CatalogItemRow: View {
    let item: CatalogItem
    let onDelete: () -> Void
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        OptimizedGlassCard(useBlur: false) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Style #\(item.styleNumber)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(item.colorCode) - \(item.colorName)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    if let division = item.division {
                        Text(division)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: item.status)
                    
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red.opacity(0.6))
                            .padding(8)
                    }
                }
            }
        }
        .alert("Remove Item?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Remove \(item.styleNumber) - \(item.colorCode) from catalog?")
        }
    }
}

struct CatalogItem: Identifiable, Codable {
    let id: UUID
    let styleNumber: String
    let colorCode: String
    let colorName: String
    let status: ItemStatus
    let division: String?
    let gender: String?
    let outsole: String?
    let addedDate: Date
    
    init(id: UUID = UUID(), styleNumber: String, colorCode: String, colorName: String, status: ItemStatus, division: String? = nil, gender: String? = nil, outsole: String? = nil, addedDate: Date = Date()) {
        self.id = id
        self.styleNumber = styleNumber
        self.colorCode = colorCode
        self.colorName = colorName
        self.status = status
        self.division = division
        self.gender = gender
        self.outsole = outsole
        self.addedDate = addedDate
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
