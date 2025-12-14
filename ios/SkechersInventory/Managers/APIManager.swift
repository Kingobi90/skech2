import Foundation

class APIManager {
    static let shared = APIManager()

    private var baseURL: String
    private let session: URLSession

    private init() {
        // Check UserDefaults for custom backend URL first
        if let customURL = UserDefaults.standard.string(forKey: "backend_url"), !customURL.isEmpty {
            baseURL = customURL
        } else if let savedURL = UserDefaults.standard.string(forKey: "last_working_url") {
            baseURL = savedURL
        } else {
            // Default to production server
            baseURL = "http://api.obinnachukwu.org"
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)

        print("📡 API Base URL: \(baseURL)")
    }

    // Update base URL dynamically
    func updateBaseURL(_ url: String) {
        baseURL = url
        UserDefaults.standard.set(url, forKey: "backend_url")
        print("📡 API Base URL updated to: \(baseURL)")
    }

    // Test and save working URL
    func testAndSaveURL(_ url: String) async -> Bool {
        guard let testURL = URL(string: "\(url)/health") else { return false }
        do {
            let (_, response) = try await session.data(from: testURL)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                UserDefaults.standard.set(url, forKey: "last_working_url")
                UserDefaults.standard.set(url, forKey: "backend_url")
                baseURL = url
                return true
            }
        } catch {
            print("❌ URL test failed: \(error.localizedDescription)")
        }
        return false
    }
    
    // Get current base URL
    func getBaseURL() -> String {
        return baseURL
    }
    
    func uploadFile(fileURL: URL, fileType: String, category: String) async throws -> FileUploadResponse {
        let url = URL(string: "\(baseURL)/api/files/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file type
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file_type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(fileType)\r\n".data(using: .utf8)!)
        
        // Add category
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"category\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(category)\r\n".data(using: .utf8)!)
        
        // Add file data
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let uploadResponse = try JSONDecoder().decode(FileUploadResponse.self, from: data)
        return uploadResponse
    }
    
    func detectShoeTag(imageData: String) async throws -> CVDetectionResponse {
        let url = URL(string: "\(baseURL)/api/cv/detect")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["image_data": imageData]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        return try JSONDecoder().decode(CVDetectionResponse.self, from: data)
    }
    
    func lookupStyle(styleNumber: String, color: String) async throws -> LookupResponse {
        var components = URLComponents(string: "\(baseURL)/api/lookup")!
        components.queryItems = [
            URLQueryItem(name: "style", value: styleNumber),
            URLQueryItem(name: "color", value: color)
        ]
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        return try JSONDecoder().decode(LookupResponse.self, from: data)
    }
    
    func createClassification(styleNumber: String, color: String, status: String, confidenceScore: Double?) async throws -> ClassificationResponse {
        let url = URL(string: "\(baseURL)/api/warehouse/classify")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "style_number": styleNumber,
            "color": color,
            "status": status,
            "confidence_score": confidenceScore as Any
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        return try JSONDecoder().decode(ClassificationResponse.self, from: data)
    }
    
    func getPendingClassifications() async throws -> [PendingClassification] {
        let url = URL(string: "\(baseURL)/api/warehouse/pending")!
        let (data, _) = try await session.data(from: url)
        
        let response = try JSONDecoder().decode(PendingClassificationsResponse.self, from: data)
        return response.pendingClassifications
    }
    
    func approveClassification(classificationId: Int, approved: Bool) async throws -> ApprovalResponse {
        let url = URL(string: "\(baseURL)/api/warehouse/approve")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "classification_id": classificationId,
            "approved": approved
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        return try JSONDecoder().decode(ApprovalResponse.self, from: data)
    }
    
    func fullSync(deviceId: String) async throws -> SyncResponse {
        var components = URLComponents(string: "\(baseURL)/api/sync")!
        components.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        return try JSONDecoder().decode(SyncResponse.self, from: data)
    }
    
    func incrementalSync(since: Date, deviceId: String) async throws -> IncrementalSyncResponse {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: since)
        
        var components = URLComponents(string: "\(baseURL)/api/sync/changes")!
        components.queryItems = [
            URLQueryItem(name: "since", value: timestamp),
            URLQueryItem(name: "device_id", value: deviceId)
        ]
        
        let (data, response) = try await session.data(from: components.url!)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        return try JSONDecoder().decode(IncrementalSyncResponse.self, from: data)
    }
    
    func getStatistics() async throws -> StatsResponse {
        let url = URL(string: "\(baseURL)/api/admin/stats")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(StatsResponse.self, from: data)
    }
    
    func deleteFile(fileId: Int) async throws -> DeleteFileResponse {
        let url = URL(string: "\(baseURL)/api/files/\(fileId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError
        }
        
        return try JSONDecoder().decode(DeleteFileResponse.self, from: data)
    }
}

enum APIError: Error {
    case invalidURL
    case serverError
    case decodingError
    case networkError
}

struct CVDetectionResponse: Codable {
    let detectedStyleNumber: String?
    let detectedColor: String?
    let confidenceScore: Double
    let success: Bool
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case detectedStyleNumber = "detected_style_number"
        case detectedColor = "detected_color"
        case confidenceScore = "confidence_score"
        case success
        case message
    }
    
    var styleNumber: String? { detectedStyleNumber }
    var color: String? { detectedColor }
    var confidence: Double { confidenceScore }
}

struct LookupResponse: Codable {
    let status: String
    let styleNumber: String
    let color: String?
    let division: String?
    let gender: String?
    let outsole: String?
    let imageUrl: String?
    let colors: [String]
    let message: String
    let sourceFiles: [SourceFile]
    
    enum CodingKeys: String, CodingKey {
        case status
        case styleNumber = "style_number"
        case color
        case division
        case gender
        case outsole
        case imageUrl = "image_url"
        case colors
        case message
        case sourceFiles = "source_files"
    }
}

struct SourceFile: Codable {
    let id: Int
    let filename: String
}

struct ClassificationResponse: Codable {
    let classificationId: Int
    let styleNumber: String
    let color: String
    let status: String
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case classificationId = "classification_id"
        case styleNumber = "style_number"
        case color
        case status
        case message
    }
}

struct FileUploadResponse: Codable {
    let fileId: Int
    let filename: String
    let fileType: String
    let category: String
    let parsingSummary: ParsingSummary
    let warnings: [String]
    let extractedData: [ExtractedStyle]?
    
    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case filename
        case fileType = "file_type"
        case category
        case parsingSummary = "parsing_summary"
        case warnings
        case extractedData = "extracted_data"
    }
}

struct ParsingSummary: Codable {
    let totalRowsProcessed: Int
    let totalStylesFound: Int
    let totalColorsFound: Int
    let stylesCreated: Int
    let stylesUpdated: Int
    let colorsCreated: Int
    
    enum CodingKeys: String, CodingKey {
        case totalRowsProcessed = "total_rows_processed"
        case totalStylesFound = "total_styles_found"
        case totalColorsFound = "total_colors_found"
        case stylesCreated = "styles_created"
        case stylesUpdated = "styles_updated"
        case colorsCreated = "colors_created"
    }
}

struct ExtractedStyle: Codable {
    let styleNumber: String
    let division: String?
    let gender: String?
    let outsole: String?
    let colors: [ExtractedColor]
    let widthVariants: [String]
    
    enum CodingKeys: String, CodingKey {
        case styleNumber = "style_number"
        case division
        case gender
        case outsole
        case colors
        case widthVariants = "width_variants"
    }
}

struct ExtractedColor: Codable {
    let colorName: String
    
    enum CodingKeys: String, CodingKey {
        case colorName = "color_name"
    }
}

struct PendingClassificationsResponse: Codable {
    let pendingClassifications: [PendingClassification]
    
    enum CodingKeys: String, CodingKey {
        case pendingClassifications = "pending_classifications"
    }
}

struct ApprovalResponse: Codable {
    let message: String
    let classificationId: Int
    let finalStatus: String
    let approved: Bool
    
    enum CodingKeys: String, CodingKey {
        case message
        case classificationId = "classification_id"
        case finalStatus = "final_status"
        case approved
    }
}

struct StatsResponse: Codable {
    let totalStyles: Int
    let showroomCount: Int
    let pendingApprovalsCount: Int
    let totalColors: Int
    let itemsProcessedToday: Int
    
    enum CodingKeys: String, CodingKey {
        case totalStyles = "total_styles"
        case showroomCount = "showroom_count"
        case pendingApprovalsCount = "pending_approvals_count"
        case totalColors = "total_colors"
        case itemsProcessedToday = "items_processed_today"
    }
}

struct DeleteFileResponse: Codable {
    let message: String
    let removalTasksCreated: Int
    
    enum CodingKeys: String, CodingKey {
        case message
        case removalTasksCreated = "removal_tasks_created"
    }
}
