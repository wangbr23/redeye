import SwiftUI
import SwiftData

@main
struct RedeyeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Trip.self,
            TripDay.self,
            Activity.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var authService = AuthService(
        supabaseURL: AppConfig.supabaseURL,
        supabaseAnonKey: AppConfig.supabaseAnonKey
    )
    @State private var apiClient = APIClient(baseURL: AppConfig.apiBaseURL)
    @State private var networkMonitor = NetworkMonitor()

    var body: some Scene {
        WindowGroup {
            AuthGateView(authService: authService)
                .environment(authService)
                .environment(apiClient)
                .environment(networkMonitor)
                .onAppear { wireServices() }
        }
        .modelContainer(sharedModelContainer)
    }

    private func wireServices() {
        apiClient.tokenProvider = { [authService] in
            try await authService.currentAccessToken()
        }
    }
}
