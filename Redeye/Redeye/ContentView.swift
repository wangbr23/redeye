import SwiftUI
import SwiftData

struct ContentView: View {
    let userId: String

    var body: some View {
        TabView {
            TripListView(userId: userId)
                .tabItem {
                    Label("Trips", systemImage: "suitcase.fill")
                }

            Text("Map")
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            Text("Nearby")
                .tabItem {
                    Label("Nearby", systemImage: "location.fill")
                }
        }
    }
}

#Preview {
    ContentView(userId: "preview-user")
        .modelContainer(for: [Trip.self, TripDay.self, Activity.self], inMemory: true)
}
