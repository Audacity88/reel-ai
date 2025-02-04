import Foundation
import Appwrite
import AppwriteModels
import AnyCodable

public class AppWriteManager: ObservableObject {
    static let shared = AppWriteManager()
    
    var client: Client
    var account: Account
    var database: Databases
    var storage: Storage
    var realtime: Realtime
    var functions: Functions
    
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
        functions = Functions(client)
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async throws -> AppwriteModels.User<AnyCodable> {
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
        try await account.deleteSession(sessionId: session.id)
    }
    
    func getCurrentUser() async throws -> AppwriteModels.User<AnyCodable> {
        return try await account.get()
    }
    
    // MARK: - Database Operations
    
    func createDocument(
        databaseId: String,
        collectionId: String,
        documentId: String,
        data: [String: Any]
    ) async throws -> Document<[String: AnyCodable]> {
        let codableData = data.mapValues { AnyCodable($0) }
        return try await database.createDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: documentId,
            data: codableData
        )
    }
    
    func getDocument(
        databaseId: String,
        collectionId: String,
        documentId: String
    ) async throws -> Document<[String: AnyCodable]> {
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
    ) async throws -> Document<[String: AnyCodable]> {
        let codableData = data.mapValues { AnyCodable($0) }
        return try await database.updateDocument(
            databaseId: databaseId,
            collectionId: collectionId,
            documentId: documentId,
            data: codableData
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
    ) async throws -> DocumentList<[String: AnyCodable]> {
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
        file: InputFile
    ) async throws -> AppwriteModels.File {
        return try await storage.createFile(
            bucketId: bucketId,
            fileId: fileId,
            file: file
        )
    }
    
    func getFile(
        bucketId: String,
        fileId: String
    ) async throws -> AppwriteModels.File {
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
    
    // MARK: - Functions
    
    func executeFunction(
        functionId: String,
        data: [String: Any]
    ) async throws -> Execution {
        return try await functions.createExecution(
            functionId: functionId,
            data: data
        )
    }
    
    func initialize(client: Client) {
        self.client = client
        self.account = Account(client)
        self.database = Databases(client)
        self.storage = Storage(client)
        self.realtime = Realtime(client)
        self.functions = Functions(client)
    }
    
    // MARK: - Realtime
    
    func subscribe(
        channel: String,
        callback: @escaping (Any) -> Void
    ) -> RealtimeSubscription {
        return realtime.subscribe([channel]) { message in
            callback(message.payload)
        }
    }
    
    public func getFilePreview(bucketId: String, fileId: String) -> URL {
        return URL(string: "\(endpoint)/storage/buckets/\(bucketId)/files/\(fileId)/preview")!
    }
}