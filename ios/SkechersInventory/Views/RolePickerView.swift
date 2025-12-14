import SwiftUI

struct RolePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedRole: String
    
    let roles = ["Sales Rep", "Manager", "Warehouse Staff", "Admin"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ForEach(roles, id: \.self) { role in
                        Button(action: {
                            selectedRole = role
                            UserDefaults.standard.set(role, forKey: "userRole")
                            dismiss()
                        }) {
                            HStack {
                                Text(role)
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if selectedRole == role {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                        }
                        
                        if role != roles.last {
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.horizontal, 24)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("Select Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
