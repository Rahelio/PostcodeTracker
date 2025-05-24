import SwiftUI

struct MainView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        if authManager.isAuthenticated {
            TabView {
                JourneyTrackerView()
                    .tabItem {
                        Label("Track Journey", systemImage: "map")
                    }
                
                PostcodeListView()
                    .tabItem {
                        Label("Postcodes", systemImage: "list.bullet")
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