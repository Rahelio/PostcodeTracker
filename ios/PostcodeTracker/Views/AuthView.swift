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
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
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
                    .disabled(isLoading)
                }
                .padding()
            }
            .padding()
        }
    }
    
    private func performAction() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                if isLogin {
                    let token = try await APIService.shared.login(username: username, password: password)
                    await MainActor.run {
                        authManager.login(token: token)
                    }
                } else {
                    let message = try await APIService.shared.register(username: username, password: password)
                    await MainActor.run {
                        // After successful registration, automatically log in
                        Task {
                            do {
                                let token = try await APIService.shared.login(username: username, password: password)
                                await MainActor.run {
                                    authManager.login(token: token)
                                }
                            } catch {
                                await MainActor.run {
                                    errorMessage = error.localizedDescription
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
} 
