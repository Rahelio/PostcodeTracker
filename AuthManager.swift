import Foundation
import SwiftUI

// Custom URLProtocol to intercept and log network traffic
class NetworkLoggerProtocol: URLProtocol {
    static var requestLogs: [String] = []
    static var responseLogs: [String] = []
    
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var response: URLResponse?
    private var receivedData: Data?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        var request = self.request
        request.addValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.addValue("no-cache", forHTTPHeaderField: "Pragma")
        request.addValue("0", forHTTPHeaderField: "Expires")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
        
        NetworkLoggerProtocol.requestLogs.append("""
            Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")
            Headers: \(request.allHTTPHeaderFields ?? [:])
            Body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")
            """)
        
        dataTask = session?.dataTask(with: request)
        dataTask?.resume()
    }
    
    override func stopLoading() {
        dataTask?.cancel()
        dataTask = nil
        session = nil
    }
}

extension NetworkLoggerProtocol: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        self.response = response
        
        if let httpResponse = response as? HTTPURLResponse {
            NetworkLoggerProtocol.responseLogs.append("""
                Response: \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "")
                Headers: \(httpResponse.allHeaderFields)
                """)
        }
        
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if receivedData == nil {
            receivedData = Data()
        }
        receivedData?.append(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            NetworkLoggerProtocol.responseLogs.append("Error: \(error)")
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        
        if let response = response, let data = receivedData {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
        }
        
        client?.urlProtocolDidFinishLoading(self)
    }
}

class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var error: String?
    
    private let baseURL = "https://rickys.ddns.net/LocationApp/api"
    private let defaults = UserDefaults.standard
    private let tokenKey = "authToken"
    private let session: URLSession
    
    init() {
        print("AuthManager: Initializing...")
        
        // Register custom protocol
        URLProtocol.registerClass(NetworkLoggerProtocol.self)
        
        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.protocolClasses = [NetworkLoggerProtocol.self]
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        
        self.session = URLSession(configuration: config)
        
        // Check for existing token
        if let token = defaults.string(forKey: tokenKey) {
            print("AuthManager: Found saved token")
            validateToken(token)
        } else {
            print("AuthManager: No saved token found in UserDefaults")
        }
    }
    
    private func createRequest(for endpoint: String, method: String = "GET") -> URLRequest? {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            print("Failed to create URL for endpoint: \(endpoint)")
            return nil
        }
        
        print("Creating request for URL: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.addValue("no-cache", forHTTPHeaderField: "Pragma")
        request.addValue("0", forHTTPHeaderField: "Expires")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
        
        if let token = defaults.string(forKey: tokenKey) {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func validateToken(_ token: String) {
        guard let request = createRequest(for: "auth/validate") else { return }
        
        print("Validating token with request: \(request)")
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Token validation error: \(error)")
                DispatchQueue.main.async {
                    self?.handleError(error)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Token validation response status: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
            }
            
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        self?.isAuthenticated = true
                        self?.error = nil
                    } else {
                        self?.isAuthenticated = false
                        self?.defaults.removeObject(forKey: self?.tokenKey ?? "")
                        self?.handleError(NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid token"]))
                    }
                }
            }
        }.resume()
    }
    
    func login(username: String, password: String) {
        guard let request = createRequest(for: "auth/login", method: "POST") else { return }
        
        let parameters = ["username": username, "password": password]
        print("Login parameters: \(parameters)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            print("Login request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "none")")
        } catch {
            print("Error creating login request body: \(error)")
            handleError(error)
            return
        }
        
        print("Making login request: \(request)")
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Login error: \(error)")
                DispatchQueue.main.async {
                    self?.handleError(error)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Login response status: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
            }
            
            if let data = data {
                print("Login response data: \(String(data: data, encoding: .utf8) ?? "none")")
            }
            
            DispatchQueue.main.async {
                guard let data = data else {
                    self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            if let token = json["access_token"] as? String {
                                self?.defaults.set(token, forKey: self?.tokenKey ?? "")
                                self?.isAuthenticated = true
                                self?.error = nil
                            } else {
                                self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No token received"]))
                            }
                        } else {
                            let message = json["message"] as? String ?? "Unknown error"
                            self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                        }
                    }
                } catch {
                    print("Error parsing login response: \(error)")
                    self?.handleError(error)
                }
            }
        }.resume()
    }
    
    func register(username: String, password: String) {
        guard let request = createRequest(for: "auth/register", method: "POST") else { return }
        
        let parameters = ["username": username, "password": password]
        print("Register parameters: \(parameters)")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
            print("Register request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "none")")
        } catch {
            print("Error creating register request body: \(error)")
            handleError(error)
            return
        }
        
        print("Making register request: \(request)")
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Register error: \(error)")
                DispatchQueue.main.async {
                    self?.handleError(error)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Register response status: \(httpResponse.statusCode)")
                print("Response headers: \(httpResponse.allHeaderFields)")
            }
            
            if let data = data {
                print("Register response data: \(String(data: data, encoding: .utf8) ?? "none")")
            }
            
            DispatchQueue.main.async {
                guard let data = data else {
                    self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let success = json["success"] as? Bool, success {
                            // Registration successful, now login
                            self?.login(username: username, password: password)
                        } else {
                            let message = json["message"] as? String ?? "Unknown error"
                            self?.handleError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
                        }
                    }
                } catch {
                    print("Error parsing register response: \(error)")
                    self?.handleError(error)
                }
            }
        }.resume()
    }
    
    func logout() {
        defaults.removeObject(forKey: tokenKey)
        isAuthenticated = false
        currentUser = nil
        error = nil
    }
    
    private func handleError(_ error: Error) {
        print("Handling error: \(error)")
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            self.isAuthenticated = false
        }
    }
}

// Custom URLSession delegate to handle redirects
class URLSessionDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        print("Redirect detected:")
        print("From: \(response.url?.absoluteString ?? "unknown")")
        print("To: \(request.url?.absoluteString ?? "unknown")")
        print("Status code: \(response.statusCode)")
        print("Headers: \(response.allHeaderFields)")
        
        // Only allow redirects to HTTPS URLs
        if let newURL = request.url, newURL.scheme == "https" {
            var newRequest = request
            // Add headers to prevent redirect loops
            newRequest.addValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
            newRequest.addValue("no-cache", forHTTPHeaderField: "Pragma")
            newRequest.addValue("0", forHTTPHeaderField: "Expires")
            newRequest.addValue("keep-alive", forHTTPHeaderField: "Connection")
            completionHandler(newRequest)
        } else {
            completionHandler(nil)
        }
    }
}

struct User: Codable {
    let id: Int
    let username: String
} 