import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainView()
                    .environmentObject(authManager)
            } else {
                AuthView()
                    .environmentObject(authManager)
            }
        }
    }
}

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    func login(username: String, password: String) async {
        do {
            let token = try await APIClient.shared.login(username: username, password: password)
            APIClient.shared.setAuthToken(token)
            await MainActor.run {
                self.isAuthenticated = true
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func register(username: String, password: String) async {
        do {
            try await APIClient.shared.register(username: username, password: password)
            await login(username: username, password: password)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func logout() {
        isAuthenticated = false
        APIClient.shared.setAuthToken("")
    }
}

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                }
                
                if let error = authManager.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button(isRegistering ? "Register" : "Login") {
                        Task {
                            if isRegistering {
                                await authManager.register(username: username, password: password)
                            } else {
                                await authManager.login(username: username, password: password)
                            }
                        }
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                }
                
                Section {
                    Button(isRegistering ? "Already have an account? Login" : "Need an account? Register") {
                        isRegistering.toggle()
                    }
                }
            }
            .navigationTitle(isRegistering ? "Register" : "Login")
        }
    }
}

struct MainView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var postcodes: [Postcode] = []
    @State private var selectedPostcode1: Postcode?
    @State private var selectedPostcode2: Postcode?
    @State private var distance: Distance?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List {
                Section("Postcodes") {
                    ForEach(postcodes) { postcode in
                        PostcodeRow(postcode: postcode)
                    }
                }
                
                Section("Calculate Distance") {
                    Picker("First Postcode", selection: $selectedPostcode1) {
                        Text("Select").tag(nil as Postcode?)
                        ForEach(postcodes) { postcode in
                            Text(postcode.code).tag(postcode as Postcode?)
                        }
                    }
                    
                    Picker("Second Postcode", selection: $selectedPostcode2) {
                        Text("Select").tag(nil as Postcode?)
                        ForEach(postcodes) { postcode in
                            Text(postcode.code).tag(postcode as Postcode?)
                        }
                    }
                    
                    if let distance = distance {
                        HStack {
                            Text("Distance:")
                            Spacer()
                            Text("\(distance.distance) \(distance.unit)")
                        }
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                    
                    Button("Calculate") {
                        calculateDistance()
                    }
                    .disabled(selectedPostcode1 == nil || selectedPostcode2 == nil)
                }
            }
            .navigationTitle("Postcode Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout") {
                        authManager.logout()
                    }
                }
            }
            .task {
                await loadPostcodes()
            }
        }
    }
    
    private func loadPostcodes() async {
        do {
            postcodes = try await APIClient.shared.getPostcodes()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func calculateDistance() {
        guard let postcode1 = selectedPostcode1, let postcode2 = selectedPostcode2 else { return }
        
        Task {
            do {
                distance = try await APIClient.shared.calculateDistance(
                    postcode1: postcode1.code,
                    postcode2: postcode2.code
                )
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct PostcodeRow: View {
    let postcode: Postcode
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(postcode.code)
                .font(.headline)
            Text("Lat: \(postcode.latitude), Lon: \(postcode.longitude)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
} 