import Foundation
import SwiftData

@Model
class WeightEntry {
    var id: UUID = UUID()
    var date: Date
    var weight: Double // stored in kg
    
    // MARK: - Cloud Sync Metadata
    var remoteID: String? = nil
    var needsSync: Bool = true
    var lastModifiedAt: Date = Date()
    
    @Relationship(inverse: \User.weightHistory)
    var user: User?

    init(date: Date, weight: Double) {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.remoteID = nil
        self.needsSync = true
        self.lastModifiedAt = Date()
    }
}

