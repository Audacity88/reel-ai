import Foundation
import Appwrite

class NotificationService {
    static let shared = NotificationService()
    private init() {}
    
    private let appWrite = AppWriteManager.shared
    
    func sendNotification(to userId: String, title: String, body: String) async throws {
        // Get user's device token
        let userDoc = try await appWrite.getDocument(
            databaseId: AppWriteConstants.databaseId,
            collectionId: AppWriteConstants.Collections.users,
            documentId: userId
        )
        
        guard let deviceToken = userDoc.data["deviceToken"] as? String else {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No device token found"])
        }
        
        // Create notification document
        let notificationData: [String: Any] = [
            "userId": userId,
            "title": title,
            "body": body,
            "type": NotificationType.system.rawValue,
            "read": false,
            "createdAt": Date().timeIntervalSince1970
        ]
        
        // Create notification document in database
        try await appWrite.createDocument(
            databaseId: AppWriteConstants.databaseId,
            collectionId: AppWriteConstants.Collections.notifications,
            documentId: ID.unique(),
            data: notificationData
        )
        
        // Trigger AppWrite function to send push notification
        let payload: [String: Any] = [
            "deviceToken": deviceToken,
            "title": title,
            "body": body
        ]
        
        // Execute function and store result
        let execution = try await appWrite.executeFunction(
            functionId: "sendPushNotification",
            data: payload
        )
        
        // Check execution status
        if execution.status != "completed" {
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to send push notification"])
        }
    }
}