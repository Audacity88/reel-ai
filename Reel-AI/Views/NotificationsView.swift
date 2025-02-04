import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

struct Notification: Identifiable {
    let id: String
    let title: String
    let body: String
    let timestamp: Date
}

class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    private var db = Firestore.firestore()
    
    func fetchNotifications() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).collection("notifications")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching notifications: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self.notifications = documents.compactMap { document -> Notification? in
                    let data = document.data()
                    guard let title = data["title"] as? String,
                          let body = data["body"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }
                    return Notification(id: document.documentID, title: title, body: body, timestamp: timestamp.dateValue())
                }
            }
    }
}

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.notifications) { notification in
                VStack(alignment: .leading) {
                    Text(notification.title)
                        .font(.headline)
                    Text(notification.body)
                        .font(.subheadline)
                    Text(notification.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Notifications")
        }
        .onAppear {
            viewModel.fetchNotifications()
        }
    }
}

