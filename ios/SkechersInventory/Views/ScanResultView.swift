import SwiftUI

struct ScanResultView: View {
    let result: ScanResult
    let mode: ScanMode
    @Environment(\.dismiss) var dismiss
    @State private var showingConfirmation = false
    @State private var showingPlacement = false
    @State private var showingManualEntry = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        if let styleNumber = result.styleNumber {
                            Text("Style #\(styleNumber)")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        if let color = result.color {
                            Text(color)
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        
                        StatusBadge(status: result.status)
                            .scaleEffect(1.5)
                            .padding(.top, 8)
                    }
                    .padding(.top, 60)
                    
                    if result.styleNumber != nil {
                        OptimizedGlassCard(useBlur: false) {
                            VStack(alignment: .leading, spacing: 16) {
                                if let division = result.division {
                                    InfoRow(label: "Division", value: division)
                                    Divider().background(Color.white.opacity(0.2))
                                }
                                
                                if let gender = result.gender {
                                    InfoRow(label: "Gender", value: gender)
                                    Divider().background(Color.white.opacity(0.2))
                                }
                                
                                if let colors = result.availableColors, !colors.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Other Colors Available")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                        
                                        ForEach(colors, id: \.self) { color in
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(Color.white.opacity(0.8))
                                                    .frame(width: 4, height: 4)
                                                
                                                Text(color)
                                                    .font(.system(size: 15))
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    VStack(spacing: 16) {
                        Button(action: confirmResult) {
                            Text("Confirm")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                        )
                                )
                        }
                        
                        Button(action: { showingPlacement = true }) {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Set Placement")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue)
                            )
                        }
                        
                        Button(action: { showingManualEntry = true }) {
                            HStack {
                                Image(systemName: "keyboard")
                                Text("Manual Entry")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                        }
                        
                        Button(action: { dismiss() }) {
                            Text("Re-scan")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showingPlacement) {
            PlacementView(
                styleNumber: result.styleNumber ?? "",
                colorCode: result.color ?? ""
            )
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualEntryView()
        }
        .alert("Success", isPresented: $showingConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    private func confirmResult() {
        if mode == .coordinator {
            Task {
                await submitClassification()
            }
        } else if mode == .catalogBuilder {
            addToCatalog()
        }
        showingConfirmation = true
    }
    
    private func addToCatalog() {
        guard let styleNumber = result.styleNumber, let color = result.color else { return }
        
        let catalogItem = CatalogItem(
            styleNumber: styleNumber,
            colorCode: color,
            colorName: color,
            status: result.status,
            division: result.division,
            gender: result.gender,
            outsole: nil
        )
        
        // Save to UserDefaults
        let catalogKey = "salesRepCatalog"
        var catalogItems: [CatalogItem] = []
        
        if let data = UserDefaults.standard.data(forKey: catalogKey),
           let decoded = try? JSONDecoder().decode([CatalogItem].self, from: data) {
            catalogItems = decoded
        }
        
        // Check if item already exists
        if !catalogItems.contains(where: { $0.styleNumber == styleNumber && $0.colorCode == color }) {
            catalogItems.insert(catalogItem, at: 0)
            
            if let encoded = try? JSONEncoder().encode(catalogItems) {
                UserDefaults.standard.set(encoded, forKey: catalogKey)
            }
        }
    }
    
    private func submitClassification() async {
        guard let styleNumber = result.styleNumber, let color = result.color else { return }
        
        do {
            _ = try await APIManager.shared.createClassification(
                styleNumber: styleNumber,
                color: color,
                status: result.status.rawValue,
                confidenceScore: result.confidence
            )
        } catch {
            print("Error submitting classification: \(error)")
        }
    }
    
    private var confirmationMessage: String {
        switch mode {
        case .salesRep:
            return "Item information confirmed"
        case .coordinator:
            return "Item classified as \(result.status.rawValue.uppercased())"
        case .catalogBuilder:
            if let styleNumber = result.styleNumber, let color = result.color {
                return "\(styleNumber) - \(color) added to catalog"
            }
            return "Item added to catalog"
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
    }
}
