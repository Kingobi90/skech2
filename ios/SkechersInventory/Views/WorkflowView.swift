import SwiftUI

// Main workflow view now redirects to category selection
struct WorkflowView: View {
    var body: some View {
        WorkflowCategoryView()
    }
}

struct WorkflowCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var statusText: String?
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        OptimizedGlassCard(useBlur: false) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                if let status = statusText {
                    Text(status)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 120)
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
