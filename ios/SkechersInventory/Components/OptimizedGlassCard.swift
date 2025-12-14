import SwiftUI

struct OptimizedGlassCard<Content: View>: View {
    let useBlur: Bool
    let content: Content
    
    init(useBlur: Bool = false, @ViewBuilder content: () -> Content) {
        self.useBlur = useBlur
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if useBlur {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            }
            
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
            
            content
                .padding(20)
        }
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}
