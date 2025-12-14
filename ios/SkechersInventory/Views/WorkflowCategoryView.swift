import SwiftUI

struct WorkflowCategoryView: View {
    @State private var selectedCategory: WorkflowCategory?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Text("Workflow")
                        .font(.system(size: 34, weight: .light))
                        .foregroundColor(.white)
                        .padding(.top, 60)
                    
                    VStack(spacing: 24) {
                        CategoryButton(
                            icon: "person.fill",
                            title: "Sales Rep",
                            subtitle: "Scan shoes and build catalogs",
                            color: .blue
                        ) {
                            selectedCategory = .salesRep
                        }
                        
                        CategoryButton(
                            icon: "shippingbox.fill",
                            title: "Warehouse",
                            subtitle: "Coordinate, manage, and place inventory",
                            color: .orange
                        ) {
                            selectedCategory = .warehouse
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedCategory) { category in
            WorkflowListView(category: category)
        }
    }
}

struct CategoryButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
                    .background(
                        Circle()
                            .fill(color.opacity(0.3))
                    )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
}

enum WorkflowCategory: String, Identifiable {
    case salesRep = "Sales Rep"
    case warehouse = "Warehouse"
    
    var id: String { rawValue }
}
