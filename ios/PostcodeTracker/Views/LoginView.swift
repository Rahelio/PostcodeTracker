import SwiftUI

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var apiService = APIService.shared
    
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isRegistering = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 60)
                        
                        // App Logo/Title
                        VStack(spacing: 16) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            
                            Text("Postcode Tracker")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Track your journeys across the UK")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // Login Form
                        VStack(spacing: 20) {
                            VStack(spacing: 16) {
                                TextField("Username", text: $username)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            Button(action: {
                                Task {
                                    if isRegistering {
                                        await register()
                                    } else {
                                        await login()
                                    }
                                }
                            }) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    }
                                    Text(isRegistering ? "Create Account" : "Sign In")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading || username.isEmpty || password.isEmpty)
                            
                            Button(action: {
                                isRegistering.toggle()
                            }) {
                                Text(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(isRegistering ? "Registration" : "Login", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func login() async {
        isLoading = true
        
        do {
            print("Attempting login for user: \(username)")
            let response = try await apiService.login(username: username, password: password)
            
            print("Login response received:")
            print("- Success: \(response.success)")
            print("- Message: \(response.message)")
            print("- Token: \(response.token != nil ? "Present" : "Missing")")
            print("- User: \(response.user != nil ? "Present" : "Missing")")
            
            if response.success, let user = response.user {
                print("Login successful, updating auth manager with user: \(user)")
                await MainActor.run {
                    authManager.login(user: user)
                }
            } else {
                print("Login failed: \(response.message)")
                alertMessage = response.message
                showingAlert = true
            }
        } catch {
            print("Login error caught: \(error)")
            if let apiError = error as? APIError {
                print("API Error details: \(apiError.errorDescription ?? "Unknown")")
            }
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isLoading = false
    }
    
    private func register() async {
        isLoading = true
        
        do {
            print("Attempting registration for user: \(username)")
            let response = try await apiService.register(username: username, password: password)
            
            print("Registration response received:")
            print("- Success: \(response.success)")
            print("- Message: \(response.message)")
            print("- Token: \(response.token != nil ? "Present" : "Missing")")
            print("- User: \(response.user != nil ? "Present" : "Missing")")
            
            if response.success, let user = response.user {
                print("Registration successful, updating auth manager with user: \(user)")
                await MainActor.run {
                    authManager.login(user: user)
                }
            } else {
                print("Registration failed: \(response.message)")
                alertMessage = response.message
                showingAlert = true
            }
        } catch {
            print("Registration error caught: \(error)")
            if let apiError = error as? APIError {
                print("API Error details: \(apiError.errorDescription ?? "Unknown")")
            }
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isLoading = false
    }
}

#Preview {
    LoginView()
} 
 