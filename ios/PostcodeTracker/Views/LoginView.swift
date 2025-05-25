import SwiftUI
import Foundation

@_exported import struct Foundation.URL
@_exported import class Foundation.URLSession

struct LoginView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isRegistering = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo or App Name
                VStack(spacing: 10) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    Text("Postcode Tracker")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .padding(.bottom, 40)
                
                // Login Form
                VStack(spacing: 15) {
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button(action: {
                        if isRegistering {
                            register()
                        } else {
                            login()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isRegistering ? "Register" : "Login")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                    
                    Button(action: {
                        isRegistering.toggle()
                    }) {
                        Text(isRegistering ? "Already have an account? Login" : "Don't have an account? Register")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
            .alert("Authentication", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func login() {
        isLoading = true
        
        Task {
            do {
                let token = try await APIService.shared.login(username: username, password: password)
                await MainActor.run {
                    authManager.login(token: token)
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Login failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func register() {
        isLoading = true
        
        Task {
            do {
                _ = try await APIService.shared.register(username: username, password: password)
                await MainActor.run {
                    alertMessage = "Registration successful! Please login."
                    showingAlert = true
                    isRegistering = false
                    password = ""
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Registration failed: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    LoginView()
} 
