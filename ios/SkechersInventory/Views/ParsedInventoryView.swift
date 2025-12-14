import SwiftUI

struct ParsedInventoryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var inventoryItems: [ParsedInventoryItem] = []
    @State private var searchText = ""
    @State private var selectedFilter: FilterOption = .all
    @State private var isLoading = true
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case keep = "Keep"
        case wait = "Wait"
        case drop = "Drop"
    }
    
    var filteredItems: [ParsedInventoryItem] {
        var items = inventoryItems
        
        // Filter by status
        if selectedFilter != .all {
            items = items.filter { $0.status.rawValue == selectedFilter.rawValue }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            items = items.filter {
                $0.styleNumber.contains(searchText) ||
                $0.colorCode.contains(searchText) ||
                ($0.division?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return items
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("Search styles or colors...", text: $searchText)
                            .foregroundColor(.white)
                            .textInputAutocapitalization(.characters)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(FilterOption.allCases, id: \.self) { filter in
                                CatalogFilterChip(
                                    title: filter.rawValue,
                                    isSelected: selectedFilter == filter,
                                    count: countForFilter(filter)
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 16)
                    
                    // Stats bar
                    HStack(spacing: 20) {
                        StatBadge(label: "Total", value: inventoryItems.count, color: .white)
                        StatBadge(label: "Keep", value: countForFilter(.keep), color: .green)
                        StatBadge(label: "Wait", value: countForFilter(.wait), color: .orange)
                        StatBadge(label: "Drop", value: countForFilter(.drop), color: .red)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    // Items list
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading inventory...")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)
                        Spacer()
                    } else if filteredItems.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.3))
                            
                            Text(searchText.isEmpty ? "No items found" : "No results for '\(searchText)'")
                                .font(.system(size: 17))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredItems) { item in
                                    InventoryItemCard(item: item)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                    }
                }
            }
            .navigationTitle("Parsed Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: exportCatalog) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                loadInventory()
            }
        }
    }
    
    private func countForFilter(_ filter: FilterOption) -> Int {
        if filter == .all {
            return inventoryItems.count
        }
        return inventoryItems.filter { $0.status.rawValue == filter.rawValue }.count
    }
    
    private func loadInventory() {
        Task {
            do {
                let syncData = try await APIManager.shared.fullSync(deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown")
                
                // Get base URL from APIManager
                let baseURL = APIManager.shared.getBaseURL()
                
                var items: [ParsedInventoryItem] = []
                
                for style in syncData.styles {
                    for colorName in style.colors {
                        // Construct image URL using the configured base URL
                        let imageUrl = "\(baseURL)/uploads/shoe_images/\(style.styleNumber)_\(colorName).png"
                        
                        let item = ParsedInventoryItem(
                            styleNumber: style.styleNumber,
                            colorCode: colorName,
                            colorName: colorName,
                            status: .keep,
                            division: style.division,
                            gender: style.gender,
                            outsole: style.outsole,
                            imageURL: imageUrl,
                            lastUpdated: ISO8601DateFormatter().date(from: style.updatedAt) ?? Date(),
                            sourceFiles: style.sourceFileIds.compactMap { fileId in
                                syncData.files.first(where: { $0.id == fileId }).map {
                                    SourceFileInfo(id: $0.id, filename: $0.filename)
                                }
                            }
                        )
                        items.append(item)
                    }
                }
                
                await MainActor.run {
                    inventoryItems = items
                    isLoading = false
                }
            } catch {
                print("❌ Failed to load inventory: \(error)")
                await MainActor.run {
                    inventoryItems = []
                    isLoading = false
                }
            }
        }
    }
    
    
    private func exportCatalog() {
        // Export functionality
    }
}

struct CatalogFilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                    )
            }
            .foregroundColor(isSelected ? .white : .white.opacity(0.6))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
            )
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

struct InventoryItemCard: View {
    let item: ParsedInventoryItem
    @State private var isExpanded = false
    
    var body: some View {
        OptimizedGlassCard(useBlur: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Product Image
                    AsyncImage(url: item.imageURL.flatMap { URL(string: $0) }) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 80, height: 80)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .cornerRadius(8)
                                .clipped()
                        case .failure:
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                VStack(spacing: 4) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white.opacity(0.3))
                                    
                                    Text(item.styleNumber)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Style #\(item.styleNumber)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(item.colorName)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Spacer()
                        
                        StatusBadge(status: item.status)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    Label(item.colorCode, systemImage: "paintpalette.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.8))
                    
                    if let division = item.division {
                        Label(division, systemImage: "tag.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if let gender = item.gender {
                        Label(gender, systemImage: "person.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                if isExpanded {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if let outsole = item.outsole {
                            DetailRow(label: "Outsole", value: outsole)
                        }
                        
                        if let sourceFiles = item.sourceFiles, !sourceFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Source Files")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                ForEach(sourceFiles) { file in
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.blue)
                                        Text(file.filename)
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                        }
                        
                        DetailRow(label: "Last Updated", value: item.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
    }
}

struct ParsedInventoryItem: Identifiable, Codable {
    let id: UUID
    let styleNumber: String
    let colorCode: String
    let colorName: String
    let status: ItemStatus
    let division: String?
    let gender: String?
    let outsole: String?
    let imageURL: String?
    let lastUpdated: Date
    let sourceFiles: [SourceFileInfo]?
    
    init(id: UUID = UUID(), styleNumber: String, colorCode: String, colorName: String, status: ItemStatus, division: String?, gender: String?, outsole: String?, imageURL: String? = nil, lastUpdated: Date = Date(), sourceFiles: [SourceFileInfo]? = nil) {
        self.id = id
        self.styleNumber = styleNumber
        self.colorCode = colorCode
        self.colorName = colorName
        self.status = status
        self.division = division
        self.gender = gender
        self.outsole = outsole
        self.imageURL = imageURL
        self.lastUpdated = lastUpdated
        self.sourceFiles = sourceFiles
    }
}

struct SourceFileInfo: Identifiable, Codable {
    let id: Int
    let filename: String
}
