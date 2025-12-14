import SwiftUI

struct StatusBadge: View {
    let status: ItemStatus
    
    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.3))
                    .overlay(
                        Capsule()
                            .stroke(statusColor, lineWidth: 1)
                    )
            )
    }
    
    private var statusColor: Color {
        switch status {
        case .keep:
            return .green
        case .wait:
            return .orange
        case .drop:
            return .red
        }
    }
}

