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
            let response = try await apiService.login(username: username, password: password)
            
            if response.success, let user = response.user {
                await MainActor.run {
                    authManager.login(user: user)
                }
            } else {
                alertMessage = response.message
                showingAlert = true
            }
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isLoading = false
    }
    
    private func register() async {
        isLoading = true
        
        do {
            let response = try await apiService.register(username: username, password: password)
            
            if response.success, let user = response.user {
                await MainActor.run {
                    authManager.login(user: user)
                }
            } else {
                alertMessage = response.message
                showingAlert = true
            }
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isLoading = false
    }
}

#Preview {
    LoginView()
} 
 