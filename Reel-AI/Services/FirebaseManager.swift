import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

class FirebaseManager {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    
    private init() {
        // Note: FirebaseApp.configure() is now handled in FirebaseConfig
    }
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user found"])))
                return
            }
            
            self?.fetchUser(userId: user.uid, completion: completion)
        }
    }
    
    private func fetchUser(userId: String, completion: @escaping (Result<User, Error>) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            do {
                if let data = snapshot?.data() {
                    let user = try Firestore.Decoder().decode(User.self, from: data)
                    completion(.success(user))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode user"])))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func signUp(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let userId = result?.user.uid else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user created"])))
                return
            }
            
            let newUser = User(
                username: email.components(separatedBy: "@")[0],
                profileImageURL: nil,
                followers: [],
                following: [],
                isCreator: false
            )
            
            do {
                try self?.db.collection("users").document(userId).setData(from: newUser)
                completion(.success(newUser))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    var currentUser: User? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        return nil // Return nil initially, use getCurrentUser() for actual data
    }
    
    func getCurrentUser(completion: @escaping (Result<User?, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.success(nil))
            return
        }
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            do {
                if let data = snapshot?.data() {
                    let user = try Firestore.Decoder().decode(User.self, from: data)
                    completion(.success(user))
                } else {
                    completion(.success(nil))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    var isAuthenticated: Bool {
        return Auth.auth().currentUser != nil
    }
} 