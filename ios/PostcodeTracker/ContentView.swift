import SwiftUI

struct ContentView: View {
    @ObservedObject var authManager: AuthManager
    
    init(authManager: AuthManager) {
        self.authManager = authManager
    }
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            PostcodeListView()
                .tabItem {
                    Label("Postcodes", systemImage: "list.bullet")
                }
            
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
    }
}

#Preview {
    ContentView(authManager: AuthManager())
} 
