import SwiftUI
import UniformTypeIdentifiers

struct FileUploadView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showingFilePicker = false
    @State private var uploadedFiles: [UploadedFile] = []
    @State private var isUploading = false
    @State private var showingLoading = false
    @State private var loadingMessage = "Uploading file..."
    @State private var uploadProgress: Double? = nil
    @State private var showingParsedInventory = false
    
    private let filesKey = "uploadedFiles"
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        Text("Upload Files")
                            .font(.system(size: 34, weight: .light))
                            .foregroundColor(.white)
                            .padding(.top, 20)
                            .padding(.horizontal, 24)
                        
                        OptimizedGlassCard(useBlur: false) {
                            VStack(spacing: 20) {
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("Upload Excel or PDF Files")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.white)
                                
                                Text("Supported formats: .xlsx, .xls, .pdf")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                
                                Button(action: { showingFilePicker = true }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Choose Files")
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
                            }
                            .padding(.vertical, 20)
                        }
                        .padding(.horizontal, 24)
                        
                        if !uploadedFiles.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent Uploads")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .padding(.horizontal, 24)
                                
                                ForEach(uploadedFiles) { file in
                                    FileRow(file: file, onDelete: {
                                        deleteFile(file)
                                    })
                                    .padding(.horizontal, 24)
                                }
                            }
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !uploadedFiles.isEmpty {
                        Button(action: { showingParsedInventory = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet.rectangle")
                                Text("View Parsed")
                                    .font(.system(size: 15))
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(uploadedFiles: $uploadedFiles, onFilesAdded: { uploadAndParse() })
            }
            .sheet(isPresented: $showingParsedInventory) {
                ParsedInventoryView()
            }
            .overlay {
                if showingLoading {
                    LoadingView(message: loadingMessage, progress: uploadProgress)
                }
            }
            .onAppear {
                loadFiles()
            }
        }
    }
    
    private func loadFiles() {
        if let data = UserDefaults.standard.data(forKey: filesKey),
           let decoded = try? JSONDecoder().decode([UploadedFile].self, from: data) {
            uploadedFiles = decoded
        }
    }
    
    private func saveFiles() {
        if let encoded = try? JSONEncoder().encode(uploadedFiles) {
            UserDefaults.standard.set(encoded, forKey: filesKey)
        }
    }
    
    private func deleteFile(_ file: UploadedFile) {
        guard let fileId = file.fileId else {
            // Just remove from local list if no fileId
            uploadedFiles.removeAll { $0.id == file.id }
            saveFiles()
            clearLocalCache()
            return
        }
        
        Task {
            do {
                let response = try await APIManager.shared.deleteFile(fileId: fileId)
                
                await MainActor.run {
                    // Remove from list
                    uploadedFiles.removeAll { $0.id == file.id }
                    saveFiles()
                    
                    // Clear local cache
                    clearLocalCache()
                    
                    // Post notification to refresh stats
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshStats"), object: nil)
                    
                    print("File deleted: \(response.message)")
                    if response.removalTasksCreated > 0 {
                        print("Created \(response.removalTasksCreated) removal tasks")
                    }
                }
            } catch {
                await MainActor.run {
                    print("Error deleting file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func clearLocalCache() {
        // Clear parsed inventory from UserDefaults
        UserDefaults.standard.removeObject(forKey: "parsedInventory")
    }
    
    private func uploadAndParse() {
        saveFiles()

        guard let latestFile = uploadedFiles.first else { return }

        showingLoading = true
        loadingMessage = "Uploading \(latestFile.name)..."
        uploadProgress = 0.2

        Task {
            defer {
                // Always hide loading after completion or error
                Task { @MainActor in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.showingLoading = false
                        self.uploadProgress = nil
                    }
                }
            }

            do {
                // Get file URL from document picker (stored temporarily)
                guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    throw NSError(domain: "FileUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not access documents directory"])
                }

                let fileURL = documentsURL.appendingPathComponent(latestFile.name)

                await MainActor.run {
                    loadingMessage = "Parsing file data..."
                    uploadProgress = 0.5
                }

                // Determine file type
                let fileType = latestFile.type == .excel ? "xlsx" : "pdf"

                // Upload to backend
                let response = try await APIManager.shared.uploadFile(
                    fileURL: fileURL,
                    fileType: fileType,
                    category: "all_bought"
                )

                await MainActor.run {
                    loadingMessage = "Extracting inventory items..."
                    uploadProgress = 0.8
                }

                // Mark file as processed and save fileId
                await MainActor.run {
                    if let index = uploadedFiles.firstIndex(where: { $0.id == latestFile.id }) {
                        uploadedFiles[index] = UploadedFile(
                            id: latestFile.id,
                            name: latestFile.name,
                            type: latestFile.type,
                            uploadDate: latestFile.uploadDate,
                            isProcessing: false,
                            fileId: response.fileId
                        )
                        saveFiles()
                    }

                    loadingMessage = "Complete! Parsed successfully"
                    uploadProgress = 1.0
                }

                print("✅ Upload completed successfully: \(response.filename)")
            } catch {
                print("❌ Upload error: \(error.localizedDescription)")

                // Mark file as failed (not processing) and remove the fileId
                await MainActor.run {
                    if let index = uploadedFiles.firstIndex(where: { $0.id == latestFile.id }) {
                        uploadedFiles[index] = UploadedFile(
                            id: latestFile.id,
                            name: latestFile.name,
                            type: latestFile.type,
                            uploadDate: latestFile.uploadDate,
                            isProcessing: false,
                            fileId: nil
                        )
                        saveFiles()
                    }

                    loadingMessage = "Error: \(error.localizedDescription)"
                    uploadProgress = nil
                }
            }
        }
    }
}

struct FileRow: View {
    let file: UploadedFile
    let onDelete: () -> Void
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        OptimizedGlassCard(useBlur: false) {
            HStack(spacing: 12) {
                Image(systemName: file.type == .excel ? "doc.text.fill" : "doc.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(file.uploadDate, style: .date)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if file.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Button(action: {
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(8)
                    }
                }
            }
        }
        .alert("Delete File?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("This will remove the file and clear cached data. Items in the showroom may be flagged for removal.")
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var uploadedFiles: [UploadedFile]
    let onFilesAdded: () -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.spreadsheet,
            UTType.pdf,
            UTType(filenameExtension: "xlsx")!,
            UTType(filenameExtension: "xls")!
        ])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                // Copy file to documents directory
                if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)
                    
                    do {
                        // Remove existing file if present
                        try? FileManager.default.removeItem(at: destinationURL)
                        
                        // Copy file
                        try FileManager.default.copyItem(at: url, to: destinationURL)
                        
                        let file = UploadedFile(
                            name: url.lastPathComponent,
                            type: url.pathExtension.lowercased() == "pdf" ? .pdf : .excel,
                            uploadDate: Date(),
                            isProcessing: true
                        )
                        parent.uploadedFiles.insert(file, at: 0)
                    } catch {
                        print("Error copying file: \(error)")
                    }
                }
            }
            parent.onFilesAdded()
            parent.dismiss()
        }
    }
}

struct UploadedFile: Identifiable, Codable {
    let id: UUID
    let name: String
    let type: FileType
    let uploadDate: Date
    let isProcessing: Bool
    let fileId: Int?
    
    init(id: UUID = UUID(), name: String, type: FileType, uploadDate: Date, isProcessing: Bool, fileId: Int? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.uploadDate = uploadDate
        self.isProcessing = isProcessing
        self.fileId = fileId
    }
    
    enum FileType: String, Codable {
        case excel, pdf
    }
}
