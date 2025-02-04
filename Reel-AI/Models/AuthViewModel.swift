import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let firebaseManager = FirebaseManager.shared
    
    init() {
        isAuthenticated = firebaseManager.isAuthenticated
        if isAuthenticated {
            refreshCurrentUser()
        }
    }
    
    private func refreshCurrentUser() {
        firebaseManager.getCurrentUser { [weak self] (result: Result<User?, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.currentUser = user
                case .failure(let error):
                    print("Error fetching current user: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func signUp(email: String, password: String) {
        firebaseManager.signUp(email: email, password: password) { [weak self] (result: Result<User, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    self?.isAuthenticated = true
                case .failure(let error):
                    print("Error signing up: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func signIn(email: String, password: String) {
        firebaseManager.signIn(email: email, password: password) { [weak self] (result: Result<User, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    self?.isAuthenticated = true
                case .failure(let error):
                    print("Error signing in: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func signOut() {
        do {
            try firebaseManager.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
}

