import Foundation
import FirebaseFirestore
import FirebaseFunctions

class NotificationService {
    static let shared = NotificationService()
    private init() {}
    
    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    
    func sendNotification(to userId: String, title: String, body: String) {
        db.collection("users").document(userId).getDocument { (document, error) in
            if let document = document, document.exists, let fcmToken = document.data()?["fcmToken"] as? String {
                let message = [
                    "token": fcmToken,
                    "notification": [
                        "title": title,
                        "body": body
                    ]
                ]
                
                self.functions.httpsCallable("sendNotification").call(message) { (result, error) in
                    if let error = error {
                        print("Error sending notification: \(error.localizedDescription)")
                    } else {
                        print("Notification sent successfully")
                    }
                }
            }
        }
    }
}

