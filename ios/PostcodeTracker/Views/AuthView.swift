import SwiftUI

struct AuthView: View {
    @State private var isLogin = true
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Postcode Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Picker("Mode", selection: $isLogin) {
                    Text("Login").tag(true)
                    Text("Register").tag(false)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                VStack(spacing: 15) {
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .disabled(isLoading)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isLoading)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: performAction) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isLogin ? "Login" : "Register")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                }
                .padding()
            }
            .padding()
        }
        .onAppear {
            print("AuthView appeared, isAuthenticated: \(authManager.isAuthenticated)")
        }
    }
    
    private func performAction() {
        guard !username.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both username and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                if isLogin {
                    print("Attempting login...")
                    let response = try await APIServiceV2.shared.login(username: username, password: password)
                    print("Login successful, response received")
                    
                    if let user = response.user {
                        authManager.login(user: user)
                        print("AuthManager updated, isAuthenticated: \(authManager.isAuthenticated)")
                    } else {
                        errorMessage = "Login failed: User data not received"
                    }
                } else {
                    print("Attempting registration...")
                    // First register
                    let registerResponse = try await APIServiceV2.shared.register(username: username, password: password)
                    print("Registration successful")
                    
                    if let user = registerResponse.user {
                        authManager.login(user: user)
                        print("AuthManager updated after registration, isAuthenticated: \(authManager.isAuthenticated)")
                    } else {
                        // Registration succeeded but no user data, try login
                        print("Registration succeeded, attempting login...")
                        let loginResponse = try await APIServiceV2.shared.login(username: username, password: password)
                        
                        if let user = loginResponse.user {
                            authManager.login(user: user)
                            print("AuthManager updated after login, isAuthenticated: \(authManager.isAuthenticated)")
                        } else {
                            errorMessage = "Registration succeeded but login failed"
                        }
                    }
                }
            } catch let error as APIError {
                print("API Error occurred: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            } catch {
                print("Unexpected error occurred: \(error.localizedDescription)")
                errorMessage = "An unexpected error occurred. Please try again."
            }
            
            isLoading = false
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}
