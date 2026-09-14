import SwiftData
import SwiftUI

struct TripListView: View {
    let userId: String

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Trip.createdAt, order: .reverse) private var trips: [Trip]
    @State private var viewModel = TripListViewModel()
    @State private var tripPendingDeletion: Trip?

    var body: some View {
        let activeTrips = viewModel.trips(with: .active, from: trips, for: userId)
        let archivedTrips = viewModel.trips(with: .archived, from: trips, for: userId)

        NavigationStack {
            Group {
                if activeTrips.isEmpty && archivedTrips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "suitcase",
                        description: Text("Create a trip to start planning your next journey.")
                    )
                } else {
                    List {
                        if !activeTrips.isEmpty {
                            Section("Active") {
                                ForEach(activeTrips) { trip in
                                    tripRow(trip, canArchive: true)
                                }
                            }
                        }

                        if !archivedTrips.isEmpty {
                            Section("Archived") {
                                ForEach(archivedTrips) { trip in
                                    tripRow(trip, canArchive: false)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trips")
        }
        .alert(
            "Delete Trip?",
            isPresented: deleteConfirmationIsPresented,
            presenting: tripPendingDeletion
        ) { trip in
            Button("Delete Trip", role: .destructive) {
                viewModel.delete(trip, in: modelContext.container)
                tripPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                tripPendingDeletion = nil
            }
        } message: { trip in
            Text("\"\(trip.title)\" and all of its activities will be permanently deleted.")
        }
        .alert("Trip Update Failed", isPresented: errorIsPresented) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unexpected error occurred.")
        }
    }

    private func tripRow(_ trip: Trip, canArchive: Bool) -> some View {
        TripRowView(trip: trip)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Delete", role: .destructive) {
                    tripPendingDeletion = trip
                }

                if canArchive {
                    Button("Archive", systemImage: "archivebox") {
                        viewModel.archive(trip, in: modelContext.container)
                    }
                    .tint(.orange)
                }
            }
    }

    private var deleteConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { tripPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    tripPendingDeletion = nil
                }
            }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissError()
                }
            }
        )
    }
}

#Preview {
    TripListView(userId: "preview-user")
        .modelContainer(for: [Trip.self, TripDay.self, Activity.self], inMemory: true)
}
