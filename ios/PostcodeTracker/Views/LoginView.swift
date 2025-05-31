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
            VStack(spacing: 30) {
                // Logo or App Name
                VStack(spacing: 15) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.accentColor)
                    Text("Postcode Tracker")
                        .playfairDisplay(.largeTitle)
                        .foregroundColor(.primary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // Login Form
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .playfairDisplay(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("", text: $username)
                            .textFieldStyle(CustomTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .playfairDisplay(.body)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .playfairDisplay(.subheadline)
                            .foregroundColor(.secondary)
                        SecureField("", text: $password)
                            .textFieldStyle(CustomTextFieldStyle())
                            .playfairDisplay(.body)
                    }
                    
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
                                .playfairDisplay(.headline)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 5, x: 0, y: 3)
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                    
                    Button(action: {
                        withAnimation {
                            isRegistering.toggle()
                        }
                    }) {
                        Text(isRegistering ? "Already have an account? Login" : "Don't have an account? Register")
                            .playfairDisplay(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.horizontal, 30)
            }
            .padding()
            .navigationBarHidden(true)
            .alert("Authentication", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
                    .playfairDisplay(.body)
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

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    LoginView()
} 
 