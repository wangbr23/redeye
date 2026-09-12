import Foundation

// MARK: - DTOs

struct TripDayDTO: Codable, Identifiable {
    let id: UUID
    let tripId: UUID
    let date: String
    let dayNumber: Int
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case date
        case dayNumber = "day_number"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct ActivityDTO: Codable, Identifiable {
    let id: UUID
    let tripId: UUID
    let tripDayId: UUID?
    let name: String
    let description: String?
    let category: String
    let area: String?
    let latitude: Double?
    let longitude: Double?
    let address: String?
    let startTime: String?
    let endTime: String?
    let durationMin: Int?
    let sortOrder: Int
    let source: String
    let placeId: String?
    let status: String
    let notes: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case tripId = "trip_id"
        case tripDayId = "trip_day_id"
        case name, description, category, area
        case latitude, longitude, address
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMin = "duration_min"
        case sortOrder = "sort_order"
        case source
        case placeId = "place_id"
        case status, notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TripDTO: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let title: String
    let destination: String
    let startDate: String
    let endDate: String
    let mode: String
    let homeBaseName: String?
    let homeBaseAddress: String?
    let homeBaseLat: Double?
    let homeBaseLng: Double?
    let preferences: [String: AnyCodable]?
    let status: String
    let createdAt: String
    let updatedAt: String
    let days: [TripDayDTO]?
    let activities: [ActivityDTO]?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, destination
        case startDate = "start_date"
        case endDate = "end_date"
        case mode
        case homeBaseName = "home_base_name"
        case homeBaseAddress = "home_base_address"
        case homeBaseLat = "home_base_lat"
        case homeBaseLng = "home_base_lng"
        case preferences, status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case days, activities
    }
}

// MARK: - Request DTOs

struct CreateTripDTO: Encodable {
    let title: String
    let destination: String
    let startDate: String
    let endDate: String
    let mode: String
    let homeBaseName: String?
    let homeBaseAddress: String?
    let homeBaseLat: Double?
    let homeBaseLng: Double?
    let preferences: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case title, destination
        case startDate = "startDate"
        case endDate = "endDate"
        case mode
        case homeBaseName = "homeBaseName"
        case homeBaseAddress = "homeBaseAddress"
        case homeBaseLat = "homeBaseLat"
        case homeBaseLng = "homeBaseLng"
        case preferences
    }
}

struct UpdateTripDTO: Encodable {
    var title: String?
    var destination: String?
    var startDate: String?
    var endDate: String?
    var mode: String?
    var homeBaseName: String?
    var homeBaseAddress: String?
    var homeBaseLat: Double?
    var homeBaseLng: Double?
    var status: String?
    var preferences: [String: AnyCodable]?
}

struct CreateActivityDTO: Encodable {
    let name: String
    let category: String
    var tripDayId: String?
    var area: String?
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var startTime: String?
    var endTime: String?
    var durationMin: Int?
    var sortOrder: Int?
    var source: String?
    var placeId: String?
    var notes: String?
}

struct UpdateActivityDTO: Encodable {
    var name: String?
    var category: String?
    var tripDayId: String?
    var area: String?
    var latitude: Double?
    var longitude: Double?
    var address: String?
    var startTime: String?
    var endTime: String?
    var durationMin: Int?
    var sortOrder: Int?
    var source: String?
    var placeId: String?
    var status: String?
    var notes: String?
}

struct ReorderItemDTO: Encodable {
    let id: UUID
    let sortOrder: Int
    let tripDayId: UUID?
}

struct PlaceResultDTO: Codable, Identifiable {
    let placeId: String
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let category: String?

    var id: String { placeId }

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name, address, latitude, longitude, category
    }
}

struct PlaceDetailDTO: Codable {
    let placeId: String
    let name: String
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let category: String?
    let phone: String?
    let website: String?
    let rating: Double?
    let priceLevel: Int?

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case name, address, latitude, longitude, category
        case phone, website, rating
        case priceLevel = "price_level"
    }
}

// MARK: - AnyCodable (lightweight wrapper for [String: Any] JSON values)

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: encoder.codingPath, debugDescription: "Unsupported value"))
        }
    }
}

// MARK: - Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case notFound
    case validationError(String)
    case serverError(statusCode: Int, message: String?)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .unauthorized:
            return "Authentication required"
        case .notFound:
            return "Not found"
        case .validationError(let message):
            return message
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .networkError(let error):
            return error.localizedDescription
        case .decodingError:
            return "Failed to parse response"
        }
    }
}

struct APIErrorResponse: Decodable {
    let error: String
}

// MARK: - APIClient

@Observable
final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    var tokenProvider: (() async throws -> String)?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: - Trips

    func fetchTrips(status: String? = nil) async throws -> [TripDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/trips"), resolvingAgainstBaseURL: false)!
        if let status {
            components.queryItems = [URLQueryItem(name: "status", value: status)]
        }
        return try await request(.get, url: components.url!)
    }

    func fetchTrip(id: UUID) async throws -> TripDTO {
        try await request(.get, path: "api/trips/\(id.uuidString)")
    }

    func createTrip(_ input: CreateTripDTO) async throws -> TripDTO {
        try await request(.post, path: "api/trips", body: input)
    }

    func updateTrip(id: UUID, _ input: UpdateTripDTO) async throws -> TripDTO {
        try await request(.patch, path: "api/trips/\(id.uuidString)", body: input)
    }

    func deleteTrip(id: UUID) async throws {
        try await requestNoContent(.delete, path: "api/trips/\(id.uuidString)")
    }

    // MARK: - Activities

    func createActivity(tripId: UUID, _ input: CreateActivityDTO) async throws -> ActivityDTO {
        try await request(.post, path: "api/trips/\(tripId.uuidString)/activities", body: input)
    }

    func updateActivity(id: UUID, _ input: UpdateActivityDTO) async throws -> ActivityDTO {
        try await request(.patch, path: "api/activities/\(id.uuidString)", body: input)
    }

    func deleteActivity(id: UUID) async throws {
        try await requestNoContent(.delete, path: "api/activities/\(id.uuidString)")
    }

    func reorderActivities(tripId: UUID, _ items: [ReorderItemDTO]) async throws {
        try await requestNoContent(.patch, path: "api/trips/\(tripId.uuidString)/activities/reorder", body: items)
    }

    // MARK: - Places

    func searchPlaces(query: String, latitude: Double?, longitude: Double?) async throws -> [PlaceResultDTO] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/places/search"), resolvingAgainstBaseURL: false)!
        var queryItems = [URLQueryItem(name: "query", value: query)]
        if let latitude { queryItems.append(URLQueryItem(name: "lat", value: String(latitude))) }
        if let longitude { queryItems.append(URLQueryItem(name: "lng", value: String(longitude))) }
        components.queryItems = queryItems
        return try await request(.get, url: components.url!)
    }

    func placeDetail(placeId: String) async throws -> PlaceDetailDTO {
        try await request(.get, path: "api/places/\(placeId)")
    }

    // MARK: - Private

    private enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    private func buildRequest(_ method: HTTPMethod, url: URL) async throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let tokenProvider {
            let token = try await tokenProvider()
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return req
    }

    private func request<T: Decodable>(_ method: HTTPMethod, path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        return try await request(method, url: url)
    }

    private func request<T: Decodable, B: Encodable>(_ method: HTTPMethod, path: String, body: B) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var req = try await buildRequest(method, url: url)
        req.httpBody = try encoder.encode(body)
        return try await execute(req)
    }

    private func request<T: Decodable>(_ method: HTTPMethod, url: URL) async throws -> T {
        let req = try await buildRequest(method, url: url)
        return try await execute(req)
    }

    private func requestNoContent(_ method: HTTPMethod, path: String) async throws {
        let url = baseURL.appendingPathComponent(path)
        let req = try await buildRequest(method, url: url)
        try await executeNoContent(req)
    }

    private func requestNoContent<B: Encodable>(_ method: HTTPMethod, path: String, body: B) async throws {
        let url = baseURL.appendingPathComponent(path)
        var req = try await buildRequest(method, url: url)
        req.httpBody = try encoder.encode(body)
        try await executeNoContent(req)
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        try validateResponse(response, data: data)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func executeNoContent(_ request: URLRequest) async throws {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        try validateResponse(response, data: data)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 400, 422:
            let message = (try? decoder.decode(APIErrorResponse.self, from: data))?.error ?? "Validation failed"
            throw APIError.validationError(message)
        default:
            let message = (try? decoder.decode(APIErrorResponse.self, from: data))?.error
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
