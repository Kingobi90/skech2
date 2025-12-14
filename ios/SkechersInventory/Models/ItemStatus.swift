import Foundation

enum ItemStatus: String, Codable {
    case keep = "keep"
    case wait = "wait"
    case drop = "drop"
    
    var displayName: String {
        rawValue.uppercased()
    }
    
    var color: String {
        switch self {
        case .keep:
            return "green"
        case .wait:
            return "orange"
        case .drop:
            return "red"
        }
    }
}
