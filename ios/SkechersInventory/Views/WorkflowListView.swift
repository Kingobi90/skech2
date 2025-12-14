import SwiftUI

struct WorkflowListView: View {
    let category: WorkflowCategory
    @Environment(\.dismiss) var dismiss
    @State private var showingSalesRepScanner = false
    @State private var showingWarehouseCoordinator = false
    @State private var showingWarehouseManager = false
    @State private var showingManualEntry = false
    @State private var catalogItemCount = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        Text(category.rawValue)
                            .font(.system(size: 34, weight: .light))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                            .padding(.horizontal, 24)
                        
                        VStack(spacing: 16) {
                            if category == .salesRep {
                                salesRepWorkflows
                            } else {
                                warehouseWorkflows
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showingSalesRepScanner) {
            CameraScannerView(mode: .salesRep)
        }
        .sheet(isPresented: $showingWarehouseCoordinator) {
            CameraScannerView(mode: .coordinator)
        }
        .sheet(isPresented: $showingWarehouseManager) {
            ManagerApprovalView()
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
    }
    
    private var salesRepWorkflows: some View {
        Group {
            WorkflowCard(
                icon: "camera.fill",
                title: "Scan Shoe",
                subtitle: "Scan shoe tags to look up product info"
            ) {
                showingSalesRepScanner = true
            }
            
            WorkflowCard(
                icon: "magnifyingglass",
                title: "Manual Search",
                subtitle: "Enter style and color manually for lookup"
            ) {
                showingManualEntry = true
            }
            
            WorkflowCard(
                icon: "doc.text.fill",
                title: "Build Catalog",
                subtitle: "Scan multiple shoes and export CSV catalog",
                statusText: catalogItemCount > 0 ? "Scanned: \(catalogItemCount) items" : nil
            ) {
                // Navigate to catalog builder
            }
        }
    }
    
    private var warehouseWorkflows: some View {
        Group {
            WorkflowCard(
                icon: "person.fill",
                title: "Coordinator",
                subtitle: "Scan and auto-classify shoes for showroom"
            ) {
                showingWarehouseCoordinator = true
            }
            
            WorkflowCard(
                icon: "checkmark.circle.fill",
                title: "Manager",
                subtitle: "Review and approve or reject classified items"
            ) {
                showingWarehouseManager = true
            }
            
            WorkflowCard(
                icon: "location.fill",
                title: "Placement",
                subtitle: "Assign approved items to shelf locations"
            ) {
                // Navigate to placement
            }
        }
    }
}
