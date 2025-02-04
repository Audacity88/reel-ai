import SwiftUI
import Appwrite
import AnyCodable

class AuthViewModel: ObservableObject {
    @Published var userSession: Session?
    @Published var currentUser: AppwriteModels.User<AnyCodable>?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    var isAuthenticated: Bool {
        return userSession != nil
    }
    
    init() {
        Task {
            await loadCurrentUser()
        }
    }
    
    @MainActor
    func loadCurrentUser() async {
        if let user = try? await appWrite.getCurrentUser() {
            currentUser = user
        }
    }
    
    @MainActor
    func signIn(withEmail email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            userSession = try await appWrite.signIn(email: email, password: password)
            await loadCurrentUser()
        } catch {
            self.error = error
            throw error
        }
    }
    
    @MainActor
    func createUser(withEmail email: String, password: String, username: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            // Create the user account
            let user = try await appWrite.signUp(email: email, password: password)
            
            // Create a session
            userSession = try await appWrite.signIn(email: email, password: password)
            
            // Create user profile document
            let userData: [String: Any] = [
                "email": email,
                "username": username,
                "createdAt": Date().timeIntervalSince1970,
                "userId": user.id
            ]
            
            try await appWrite.createDocument(
                databaseId: "YOUR_DATABASE_ID",
                collectionId: "users",
                documentId: user.id,
                data: userData
            )
            
            await loadCurrentUser()
        } catch {
            self.error = error
            throw error
        }
    }
    
    @MainActor
    func signOut() async throws {
        do {
            try await appWrite.signOut()
            self.userSession = nil
            self.currentUser = nil as AppwriteModels.User<AnyCodable>?
        } catch {
            self.error = error
            throw error
        }
    }
}