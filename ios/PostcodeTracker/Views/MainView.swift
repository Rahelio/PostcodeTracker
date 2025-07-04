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
                
                PostcodesView()
                    .tabItem {
                        Label("Postcodes", systemImage: "mappin.and.ellipse")
                    }
                
                JourneysView()
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }
                
                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.circle")
                    }
            }
            .tint(.accentColor)
        } else {
            LoginView()
        }
    }
}

#Preview {
    MainView()
} 