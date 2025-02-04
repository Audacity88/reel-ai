import SwiftUI
import AppWrite

class AuthViewModel: ObservableObject {
    @Published var userSession: Session?
    @Published var currentUser: Account.User?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    init() {
        Task {
            await loadCurrentUser()
        }
    }
    
    @MainActor
    func loadCurrentUser() async {
        do {
            currentUser = try await appWrite.getCurrentUser()
        } catch {
            self.error = error
            print("DEBUG: Failed to get current user: \(error.localizedDescription)")
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
                "userId": user.$id
            ]
            
            try await appWrite.createDocument(
                databaseId: "YOUR_DATABASE_ID",
                collectionId: "users",
                documentId: user.$id,
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
            self.currentUser = nil
        } catch {
            self.error = error
            throw error
        }
    }
}

