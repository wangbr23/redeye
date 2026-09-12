import Foundation
import SwiftData

enum TripMode: String, Codable {
    case structured
    case unstructured
}

enum TripStatus: String, Codable {
    case active
    case archived
}

@Model
final class Trip {
    var id: UUID
    var serverId: UUID?
    var userId: String
    var title: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var mode: TripMode
    var homeBaseName: String?
    var homeBaseAddress: String?
    var homeBaseLat: Double?
    var homeBaseLng: Double?
    var preferencesData: Data?
    var status: TripStatus
    var syncStatus: SyncStatus
    var lastModified: Date
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TripDay.trip)
    var days: [TripDay] = []

    @Relationship(deleteRule: .cascade, inverse: \Activity.trip)
    var activities: [Activity] = []

    init(
        userId: String,
        title: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        mode: TripMode,
        homeBaseName: String? = nil,
        homeBaseAddress: String? = nil,
        homeBaseLat: Double? = nil,
        homeBaseLng: Double? = nil,
        status: TripStatus = .active,
        syncStatus: SyncStatus = .pendingCreate
    ) {
        self.id = UUID()
        self.userId = userId
        self.title = title
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.mode = mode
        self.homeBaseName = homeBaseName
        self.homeBaseAddress = homeBaseAddress
        self.homeBaseLat = homeBaseLat
        self.homeBaseLng = homeBaseLng
        self.status = status
        self.syncStatus = syncStatus
        self.lastModified = Date()
        self.createdAt = Date()
    }

    var sortedDays: [TripDay] {
        days.sorted { $0.dayNumber < $1.dayNumber }
    }

    var numberOfDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: startDate, to: endDate)
        return (components.day ?? 0) + 1
    }
}
