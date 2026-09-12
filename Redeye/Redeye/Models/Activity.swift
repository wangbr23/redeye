import Foundation
import SwiftData

enum ActivitySource: String, Codable {
    case manual
    case aiGenerated = "ai_generated"
    case placesAPI = "places_api"
}

enum ActivityStatus: String, Codable {
    case planned
    case visited
    case skipped
}

@Model
final class Activity {
    var id: UUID
    var serverId: UUID?
    var trip: Trip?
    var tripDay: TripDay?
    var name: String
    var descriptionText: String?
    var category: ActivityCategory
    var area: String?
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var startTime: Date?
    var endTime: Date?
    var durationMin: Int?
    var sortOrder: Int
    var source: ActivitySource
    var placeId: String?
    var status: ActivityStatus
    var notes: String?
    var isProposed: Bool
    var syncStatus: SyncStatus
    var lastModified: Date
    var createdAt: Date

    init(
        trip: Trip,
        name: String,
        category: ActivityCategory,
        tripDay: TripDay? = nil,
        area: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        address: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        durationMin: Int? = nil,
        sortOrder: Int = 0,
        source: ActivitySource = .manual,
        placeId: String? = nil,
        status: ActivityStatus = .planned,
        notes: String? = nil,
        isProposed: Bool = false,
        syncStatus: SyncStatus = .pendingCreate
    ) {
        self.id = UUID()
        self.trip = trip
        self.tripDay = tripDay
        self.name = name
        self.descriptionText = nil
        self.category = category
        self.area = area
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.startTime = startTime
        self.endTime = endTime
        self.durationMin = durationMin
        self.sortOrder = sortOrder
        self.source = source
        self.placeId = placeId
        self.status = status
        self.notes = notes
        self.isProposed = isProposed
        self.syncStatus = syncStatus
        self.lastModified = Date()
        self.createdAt = Date()
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }
}
