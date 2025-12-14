import SwiftUI

struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss
    @State private var styleNumber = ""
    @State private var colorCode = ""
    @State private var isSearching = false
    @State private var searchResult: StyleLookupResult?
    @State private var showingResult = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        Text("Manual Entry")
                            .font(.system(size: 34, weight: .light))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                            .padding(.horizontal, 24)
                        
                        OptimizedGlassCard(useBlur: false) {
                            VStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Style Number")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    TextField("Enter 6-7 digits", text: $styleNumber)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.white)
                                        .keyboardType(.numberPad)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.1))
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Color Code")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    TextField("Enter 3-4 letters", text: $colorCode)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.white)
                                        .textInputAutocapitalization(.characters)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.1))
                                        )
                                }
                                
                                Button(action: lookupStyle) {
                                    HStack {
                                        if isSearching {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "magnifyingglass")
                                            Text("Look Up")
                                        }
                                    }
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.blue)
                                    )
                                }
                                .disabled(styleNumber.isEmpty || colorCode.isEmpty || isSearching)
                                .opacity((styleNumber.isEmpty || colorCode.isEmpty) ? 0.5 : 1.0)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        if let result = searchResult {
                            OptimizedGlassCard(useBlur: false) {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Style #\(result.styleNumber)")
                                                .font(.system(size: 20, weight: .semibold))
                                                .foregroundColor(.white)
                                            
                                            Text(result.colorName)
                                                .font(.system(size: 15))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        
                                        Spacer()
                                        
                                        StatusBadge(status: result.status)
                                    }
                                    
                                    if let imageUrl = result.imageUrl {
                                        AsyncImage(url: URL(string: "\(APIManager.shared.getBaseURL())\(imageUrl)")) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxHeight: 200)
                                                .cornerRadius(12)
                                        } placeholder: {
                                            ProgressView()
                                                .frame(height: 200)
                                        }
                                    }
                                    
                                    if let division = result.division {
                                        InfoRow(label: "Division", value: division)
                                    }
                                    
                                    if let gender = result.gender {
                                        InfoRow(label: "Gender", value: gender)
                                    }
                                    
                                    if let outsole = result.outsole {
                                        InfoRow(label: "Outsole", value: outsole)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func lookupStyle() {
        isSearching = true
        
        Task {
            do {
                let result = try await APIManager.shared.lookupStyle(styleNumber: styleNumber, color: colorCode)
                
                await MainActor.run {
                    searchResult = StyleLookupResult(
                        styleNumber: result.styleNumber,
                        colorCode: colorCode,
                        colorName: result.color ?? colorCode,
                        status: ItemStatus(rawValue: result.status) ?? .drop,
                        division: result.division,
                        gender: result.gender,
                        outsole: result.outsole,
                        imageUrl: result.imageUrl
                    )
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }
}

struct StyleLookupResult {
    let styleNumber: String
    let colorCode: String
    let colorName: String
    let status: ItemStatus
    let division: String?
    let gender: String?
    let outsole: String?
    let imageUrl: String?
}
