import Foundation

/// Represents a single weight measurement as it travels across the network boundary.
struct WeightEntryDTO: Codable {
    let remoteID: String
    let userID: String
    let date: Date
    let weight: Double
    let lastModifiedAt: Date

    private enum CodingKeys: String, CodingKey {
        case remoteID = "remoteId"
        case userID = "userId"
        case date, weight, lastModifiedAt
    }
}
