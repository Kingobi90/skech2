import SwiftUI

struct PlacementView: View {
    @Environment(\.dismiss) var dismiss
    let styleNumber: String
    let colorCode: String
    
    @State private var selectedLocation = ""
    @State private var shelfNumber = ""
    @State private var notes = ""
    @State private var showingConfirmation = false
    
    let locations = ["Showroom A", "Showroom B", "Warehouse", "Storage"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        Text("Placement")
                            .font(.system(size: 34, weight: .light))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                            .padding(.horizontal, 24)
                        
                        OptimizedGlassCard(useBlur: false) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Style #\(styleNumber)")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Color: \(colorCode)")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Location")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 24)
                            
                            OptimizedGlassCard(useBlur: false) {
                                VStack(spacing: 12) {
                                    ForEach(locations, id: \.self) { location in
                                        Button(action: {
                                            selectedLocation = location
                                        }) {
                                            HStack {
                                                Text(location)
                                                    .font(.system(size: 15))
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                if selectedLocation == location {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.blue)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundColor(.white.opacity(0.3))
                                                }
                                            }
                                            .padding(.vertical, 8)
                                        }
                                        
                                        if location != locations.last {
                                            Divider()
                                                .background(Color.white.opacity(0.2))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Details")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 24)
                            
                            OptimizedGlassCard(useBlur: false) {
                                VStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Shelf Number")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        TextField("e.g., A-12", text: $shelfNumber)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                            .padding()
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.1))
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Notes (Optional)")
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        TextEditor(text: $notes)
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                            .frame(height: 100)
                                            .padding(8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.white.opacity(0.1))
                                            )
                                            .scrollContentBackground(.hidden)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Button(action: savePlacement) {
                            Text("Save Placement")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.blue)
                                )
                        }
                        .disabled(selectedLocation.isEmpty)
                        .opacity(selectedLocation.isEmpty ? 0.5 : 1.0)
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Placement Saved", isPresented: $showingConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Style #\(styleNumber) has been placed in \(selectedLocation)")
            }
        }
    }
    
    private func savePlacement() {
        // Save placement logic here
        showingConfirmation = true
    }
}
