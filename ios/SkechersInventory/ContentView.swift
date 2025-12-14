import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tag(0)
                    
                    InventoryView()
                        .tag(1)
                    
                    WorkflowView()
                        .tag(2)
                    
                    SettingsView()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                CustomTabBar(selectedTab: $selectedTab)
                    .padding(.bottom, 20)
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 12) {
            TabButton(icon: "house.fill", title: "Home", tag: 0, selectedTab: $selectedTab)
            TabButton(icon: "shippingbox.fill", title: "Inventory", tag: 1, selectedTab: $selectedTab)
            TabButton(icon: "arrow.triangle.branch", title: "Workflow", tag: 2, selectedTab: $selectedTab)
            TabButton(icon: "gearshape.fill", title: "Settings", tag: 3, selectedTab: $selectedTab)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 24)
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let tag: Int
    @Binding var selectedTab: Int
    
    private var isSelected: Bool {
        selectedTab == tag
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(isSelected ? 0.15 : 0))
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tag
            }
        }
    }
}
