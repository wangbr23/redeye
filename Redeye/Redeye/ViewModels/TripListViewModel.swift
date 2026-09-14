import Foundation
import Observation
import SwiftData

@Observable
final class TripListViewModel {
    private(set) var errorMessage: String?

    func trips(
        with status: TripStatus,
        from trips: [Trip],
        for userId: String
    ) -> [Trip] {
        trips.filter {
            $0.userId == userId
                && $0.status == status
                && $0.syncStatus != .pendingDelete
        }
    }

    func archive(_ trip: Trip, in modelContainer: ModelContainer) {
        guard trip.status != .archived else { return }

        mutate(
            trip,
            in: modelContainer,
            failureMessage: "Couldn't archive this trip."
        ) { persistedTrip, _ in
            persistedTrip.status = .archived
            if persistedTrip.syncStatus == .synced {
                persistedTrip.syncStatus = .pendingUpdate
            }
            persistedTrip.lastModified = Date()
        }
    }

    func delete(_ trip: Trip, in modelContainer: ModelContainer) {
        mutate(
            trip,
            in: modelContainer,
            failureMessage: "Couldn't delete this trip."
        ) { persistedTrip, modelContext in
            if persistedTrip.serverId == nil {
                modelContext.delete(persistedTrip)
            } else {
                persistedTrip.syncStatus = .pendingDelete
                persistedTrip.lastModified = Date()
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func mutate(
        _ trip: Trip,
        in modelContainer: ModelContainer,
        failureMessage: String,
        mutation: (Trip, ModelContext) -> Void
    ) {
        let modelContext = ModelContext(modelContainer)

        do {
            let tripId = trip.id
            let descriptor = FetchDescriptor<Trip>(
                predicate: #Predicate { $0.id == tripId }
            )
            guard let persistedTrip = try modelContext.fetch(descriptor).first else {
                errorMessage = "\(failureMessage) The trip is no longer available."
                return
            }

            mutation(persistedTrip, modelContext)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "\(failureMessage) \(error.localizedDescription)"
        }
    }
}
