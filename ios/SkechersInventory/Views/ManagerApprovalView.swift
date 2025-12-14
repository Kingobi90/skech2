import SwiftUI

struct ManagerApprovalView: View {
    @Environment(\.dismiss) var dismiss
    @State private var pendingItems: [PendingClassification] = []
    @State private var currentIndex = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    Text("Manager Approval")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1)/\(pendingItems.count)")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.trailing, 12)
                }
                .padding()
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Spacer()
                } else if pendingItems.isEmpty {
                    Spacer()
                    Text("No items pending approval")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                } else {
                    ZStack {
                        ForEach(Array(pendingItems.enumerated()), id: \.offset) { index, item in
                            if index == currentIndex {
                                ApprovalCard(item: item)
                                    .offset(dragOffset)
                                    .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                dragOffset = value.translation
                                            }
                                            .onEnded { value in
                                                handleSwipe(value.translation)
                                            }
                                    )
                            }
                        }
                    }
                    .padding()
                    
                    HStack(spacing: 60) {
                        Button(action: { rejectItem() }) {
                            VStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(width: 70, height: 70)
                                    .background(Circle().fill(Color.red.opacity(0.2)))
                                
                                Text("Drop")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: { approveItem() }) {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.green)
                                    .frame(width: 70, height: 70)
                                    .background(Circle().fill(Color.green.opacity(0.2)))
                                
                                Text("Keep")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            loadPendingItems()
        }
    }
    
    private func handleSwipe(_ translation: CGSize) {
        if translation.width > 100 {
            approveItem()
        } else if translation.width < -100 {
            rejectItem()
        } else {
            withAnimation(.spring()) {
                dragOffset = .zero
            }
        }
    }
    
    private func approveItem() {
        guard currentIndex < pendingItems.count else { return }
        
        let item = pendingItems[currentIndex]
        
        withAnimation(.spring()) {
            dragOffset = CGSize(width: 500, height: 0)
        }
        
        Task {
            try? await APIManager.shared.approveClassification(
                classificationId: item.classificationId,
                approved: true
            )
            
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    moveToNext()
                }
            }
        }
    }
    
    private func rejectItem() {
        guard currentIndex < pendingItems.count else { return }
        
        let item = pendingItems[currentIndex]
        
        withAnimation(.spring()) {
            dragOffset = CGSize(width: -500, height: 0)
        }
        
        Task {
            try? await APIManager.shared.approveClassification(
                classificationId: item.classificationId,
                approved: false
            )
            
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    moveToNext()
                }
            }
        }
    }
    
    private func moveToNext() {
        dragOffset = .zero
        if currentIndex < pendingItems.count - 1 {
            currentIndex += 1
        } else {
            dismiss()
        }
    }
    
    private func loadPendingItems() {
        Task {
            do {
                pendingItems = try await APIManager.shared.getPendingClassifications()
                isLoading = false
            } catch {
                print("Error loading pending items: \(error)")
                isLoading = false
            }
        }
    }
}

struct ApprovalCard: View {
    let item: PendingClassification
    
    var body: some View {
        OptimizedGlassCard(useBlur: true) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Style #\(item.styleNumber)")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(item.color)
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                HStack {
                    Text("Coordinator marked as:")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                    
                    StatusBadge(status: ItemStatus(rawValue: item.coordinatorAssignedStatus) ?? .wait)
                }
                
                if let styleInfo = item.completeStyleInfo {
                    Divider().background(Color.white.opacity(0.2))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if let division = styleInfo.division {
                            InfoRow(label: "Division", value: division)
                        }
                        
                        if let gender = styleInfo.gender {
                            InfoRow(label: "Gender", value: gender)
                        }
                        
                        if !styleInfo.colors.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Available Colors")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                
                                ForEach(styleInfo.colors, id: \.self) { color in
                                    Text("• \(color)")
                                        .font(.system(size: 15))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                }
                
                if let coordinator = item.coordinatorName {
                    Divider().background(Color.white.opacity(0.2))
                    
                    HStack {
                        Text("Submitted by:")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text(coordinator)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

struct PendingClassification: Codable {
    let classificationId: Int
    let styleNumber: String
    let color: String
    let coordinatorAssignedStatus: String
    let coordinatorName: String?
    let submissionTimestamp: String
    let completeStyleInfo: StyleInfo?
    let confidenceScore: Double?
    
    enum CodingKeys: String, CodingKey {
        case classificationId = "classification_id"
        case styleNumber = "style_number"
        case color
        case coordinatorAssignedStatus = "coordinator_assigned_status"
        case coordinatorName = "coordinator_name"
        case submissionTimestamp = "submission_timestamp"
        case completeStyleInfo = "complete_style_info"
        case confidenceScore = "confidence_score"
    }
}

struct StyleInfo: Codable {
    let styleNumber: String
    let division: String?
    let gender: String?
    let outsole: String?
    let colors: [String]
    
    enum CodingKeys: String, CodingKey {
        case styleNumber = "style_number"
        case division
        case gender
        case outsole
        case colors
    }
}
