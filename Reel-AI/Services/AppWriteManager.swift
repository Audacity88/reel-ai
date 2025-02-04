import Foundation
import Appwrite

class AppWriteManager: ObservableObject {
    static let shared = AppWriteManager()
    
    let client: Client
    let account: Account
    let database: Databases
    let storage: Storage
    let realtime: Realtime
    
    // Replace these with your AppWrite project details
    private let endpoint = "YOUR_APPWRITE_ENDPOINT"
    private let projectId = "YOUR_PROJECT_ID"
    
    private init() {
        client = Client()
            .setEndpoint(endpoint)
            .setProject(projectId)
            .setSelfSigned(true) // Remove in production
        
        account = Account(client)
        database = Databases(client)
        storage = Storage(client)
        realtime = Realtime(client)
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async throws -> Account.User {
        return try await account.create(
            userId: ID.unique(),
            email: email,
            password: password
        )
    }
    
    func signIn(email: String, password: String) async throws -> Session {
        return try await account.createEmailSession(
            email: email,
            password: password
        )
    }
    
    func signOut() async throws {
        let session = try await account.getSession(sessionId: "current")
        try await account.deleteSession(sessionId: session.$id)
    }
    
    func getCurrentUser() async throws -> Account.User {
        return try await account.get()
    }
    
    // MARK: - Database Operations
    
    func createDocument(
        databaseId: String,
        collectionId: String,
        documentId: String,
        data: [String: Any]
    ) async throws -> Document {
        return try await database.createDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: documentId,
            data: data
        )
    }
    
    func getDocument(
        databaseId: String,
        collectionId: String,
        documentId: String
    ) async throws -> Document {
        return try await database.getDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: documentId
        )
    }
    
    func updateDocument(
        databaseId: String,
        collectionId: String,
        documentId: String,
        data: [String: Any]
    ) async throws -> Document {
        return try await database.updateDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: documentId,
            data: data
        )
    }
    
    func deleteDocument(
        databaseId: String,
        collectionId: String,
        documentId: String
    ) async throws {
        try await database.deleteDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: documentId
        )
    }
    
    func listDocuments(
        databaseId: String,
        collectionId: String,
        queries: [String]? = nil
    ) async throws -> DocumentList {
        return try await database.listDocuments(
            databaseId: databaseId,
            collectionId: collectionId,
            queries: queries
        )
    }
    
    // MARK: - Storage Operations
    
    func uploadFile(
        bucketId: String,
        fileId: String,
        file: File
    ) async throws -> Storage.File {
        return try await storage.createFile(
            bucketId: bucketId,
            fileId: fileId,
            file: file
        )
    }
    
    func getFile(
        bucketId: String,
        fileId: String
    ) async throws -> Storage.File {
        return try await storage.getFile(
            bucketId: bucketId,
            fileId: fileId
        )
    }
    
    func deleteFile(
        bucketId: String,
        fileId: String
    ) async throws {
        try await storage.deleteFile(
            bucketId: bucketId,
            fileId: fileId
        )
    }
    
    // MARK: - Realtime
    
    func subscribe(
        channels: [String],
        callback: @escaping (RealtimeMessage) -> Void
    ) -> RealtimeSubscription {
        return realtime.subscribe(channels) { message in
            callback(message)
        }
    }
} 