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
                    .toolbarBackground(.visible, for: .tabBar)
                
                JourneysView()
                    .tabItem {
                        Label("Journeys", systemImage: "map")
                    }
                    .toolbarBackground(.visible, for: .tabBar)
                
                PostcodeListView()
                    .tabItem {
                        Label("Postcodes", systemImage: "mappin.and.ellipse")
                    }
                    .toolbarBackground(.visible, for: .tabBar)
                
                MapView()
                    .tabItem {
                        Label("Map", systemImage: "map.fill")
                    }
                    .toolbarBackground(.visible, for: .tabBar)
            }
            .tint(.accentColor)
            .onAppear {
                // Configure tab bar appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = .systemBackground
                
                // Configure tab bar item appearance
                let itemAppearance = UITabBarItemAppearance()
                itemAppearance.normal.titleTextAttributes = [
                    .font: UIFont(name: "PlayfairDisplay-Regular", size: 10) ?? .systemFont(ofSize: 10)
                ]
                itemAppearance.selected.titleTextAttributes = [
                    .font: UIFont(name: "PlayfairDisplay-Bold", size: 10) ?? .systemFont(ofSize: 10)
                ]
                appearance.stackedLayoutAppearance = itemAppearance
                
                UITabBar.appearance().standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    UITabBar.appearance().scrollEdgeAppearance = appearance
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