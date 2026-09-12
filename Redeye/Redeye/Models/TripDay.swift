import Foundation
import SwiftData

@Model
final class TripDay {
    var id: UUID
    var serverId: UUID?
    var trip: Trip?
    var date: Date
    var dayNumber: Int
    var notes: String?
    var syncStatus: SyncStatus
    var lastModified: Date

    @Relationship(deleteRule: .nullify, inverse: \Activity.tripDay)
    var activities: [Activity] = []

    init(
        trip: Trip,
        date: Date,
        dayNumber: Int,
        notes: String? = nil,
        syncStatus: SyncStatus = .pendingCreate
    ) {
        self.id = UUID()
        self.trip = trip
        self.date = date
        self.dayNumber = dayNumber
        self.notes = notes
        self.syncStatus = syncStatus
        self.lastModified = Date()
    }

    var sortedActivities: [Activity] {
        activities.sorted { $0.sortOrder < $1.sortOrder }
    }
}
