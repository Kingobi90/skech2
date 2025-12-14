import Foundation

struct InventoryItem: Identifiable {
    let id: Int
    let styleNumber: String
    let color: String
    let status: ItemStatus
    let division: String?
    let gender: String?
    let shelfLocation: String?
}
