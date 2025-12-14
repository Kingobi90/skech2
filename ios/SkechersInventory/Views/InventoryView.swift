import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var databaseManager: DatabaseManager
    @State private var searchText = ""
    @State private var selectedFilter: StatusFilter = .all
    @State private var inventoryItems: [InventoryItem] = []
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("Inventory")
                    .font(.system(size: 34, weight: .light))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 24)
                
                OptimizedGlassCard(useBlur: true) {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.5))
                        
                        TextField("Search styles, colors...", text: $searchText)
                            .foregroundColor(.white)
                            .font(.system(size: 15))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                HStack(spacing: 12) {
                    FilterChip(title: "All", filter: .all, selectedFilter: $selectedFilter)
                    FilterChip(title: "Keep", filter: .keep, selectedFilter: $selectedFilter)
                    FilterChip(title: "Wait", filter: .wait, selectedFilter: $selectedFilter)
                    FilterChip(title: "Drop", filter: .drop, selectedFilter: $selectedFilter)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredItems) { item in
                            InventoryItemRow(item: item)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            loadInventory()
        }
        .onChange(of: searchText) { _ in
            filterItems()
        }
        .onChange(of: selectedFilter) { _ in
            filterItems()
        }
    }
    
    private var filteredItems: [InventoryItem] {
        var items = inventoryItems
        
        if !searchText.isEmpty {
            items = items.filter { item in
                item.styleNumber.localizedCaseInsensitiveContains(searchText) ||
                item.color.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if selectedFilter != .all {
            items = items.filter { $0.status == selectedFilter.toItemStatus() }
        }
        
        return items
    }
    
    private func loadInventory() {
        Task {
            inventoryItems = await databaseManager.getAllInventoryItems()
        }
    }
    
    private func filterItems() {
        // Filtering is handled by computed property
    }
}

struct FilterChip: View {
    let title: String
    let filter: StatusFilter
    @Binding var selectedFilter: StatusFilter
    @Namespace private var animation
    
    var isSelected: Bool {
        selectedFilter == filter
    }
    
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        Rectangle()
                            .fill(Color.clear)
                            .overlay(
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundColor(.white),
                                alignment: .bottom
                            )
                            .matchedGeometryEffect(id: "underline", in: animation)
                    }
                }
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedFilter = filter
                }
            }
    }
}

struct InventoryItemRow: View {
    let item: InventoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(item.styleNumber)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if let location = item.shelfLocation {
                    Text(location)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
                
                StatusBadge(status: item.status)
            }
            
            Text(item.color)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
            
            if let division = item.division, let gender = item.gender {
                Text("\(division) • \(gender)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

enum StatusFilter: String {
    case all = "all"
    case keep = "keep"
    case wait = "wait"
    case drop = "drop"
    
    func toItemStatus() -> ItemStatus? {
        switch self {
        case .all:
            return nil
        case .keep:
            return .keep
        case .wait:
            return .wait
        case .drop:
            return .drop
        }
    }
}

