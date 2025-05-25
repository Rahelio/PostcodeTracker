import SwiftUI

struct MainView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        if authManager.isAuthenticated {
            TabView {
                JourneyTrackerView()
                    .tabItem {
                        Label("Track", systemImage: "location.fill")
                    }
                
                JourneysView()
                    .tabItem {
                        Label("Journeys", systemImage: "map")
                    }
                
                PostcodeListView()
                    .tabItem {
                        Label("Postcodes", systemImage: "mappin.and.ellipse")
                    }
                
                MapView()
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }
            }
        } else {
            LoginView()
        }
    }
}

#Preview {
    MainView()
} 