import Foundation

enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case restaurant
    case attraction
    case shopping
    case museum
    case nightlife
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .restaurant: "Restaurant"
        case .attraction: "Attraction"
        case .shopping: "Shopping"
        case .museum: "Museum"
        case .nightlife: "Nightlife"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .shopping: "bag.fill"
        case .museum: "building.columns.fill"
        case .nightlife: "moon.stars.fill"
        case .other: "mappin"
        }
    }
}
