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
                    let token = try await APIService.shared.login(username: username, password: password)
                    print("Login successful, token received")
                    authManager.login(token: token)
                    print("AuthManager updated, isAuthenticated: \(authManager.isAuthenticated)")
                } else {
                    print("Attempting registration...")
                    // First register
                    _ = try await APIService.shared.register(username: username, password: password)
                    print("Registration successful")
                    
                    // Then login
                    print("Attempting login after registration...")
                    let token = try await APIService.shared.login(username: username, password: password)
                    print("Login successful after registration, token received")
                    authManager.login(token: token)
                    print("AuthManager updated after registration, isAuthenticated: \(authManager.isAuthenticated)")
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
