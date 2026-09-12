import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            Text("Trips")
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
    ContentView()
        .modelContainer(for: [Trip.self, TripDay.self, Activity.self], inMemory: true)
}
