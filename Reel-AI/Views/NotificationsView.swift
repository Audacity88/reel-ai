import SwiftUI
import Appwrite
import AppwriteModels
import AnyCodable

// Use the AppNotificationModel defined in Models.swift
// If needed, import Models here if AppNotificationModel is declared there
// import Models

class NotificationsViewModel: ObservableObject {
    @Published var notifications: [AppNotificationModel] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    func fetchNotifications() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let currentUser = try await appWrite.getCurrentUser()
            
            let queries = [
                AppWriteConstants.Queries.equalTo(field: "userId", value: currentUser.id),
                AppWriteConstants.Queries.orderByCreatedAt(),
                AppWriteConstants.Queries.limit(50)
            ]
            
            let result = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.notifications,
                queries: queries
            )
            
            await MainActor.run {
                self.notifications = result.documents.compactMap { document in
                    if let jsonData = try? JSONSerialization.data(withJSONObject: document.data, options: []) {
                        return try? JSONDecoder().decode(AppNotificationModel.self, from: jsonData)
                    }
                    return nil
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Error fetching notifications: \(error.localizedDescription)")
            }
        }
    }
    
    func markAsRead(_ notification: AppNotificationModel) async {
        do {
            let updatedData: [String: Any] = [
                "read": true
            ]
            
            _ = try await appWrite.updateDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.notifications,
                documentId: notification.id,
                data: updatedData
            )
            
            await fetchNotifications()
        } catch {
            print("Error marking notification as read: \(error.localizedDescription)")
        }
    }
}

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.notifications.isEmpty {
                    Text("No notifications")
                        .foregroundColor(.gray)
                } else {
                    List(viewModel.notifications) { notification in
                        NotificationCell(notification: notification)
                            .onTapGesture {
                                Task {
                                    await viewModel.markAsRead(notification)
                                }
                            }
                    }
                }
            }
            .navigationTitle("Notifications")
            .task {
                await viewModel.fetchNotifications()
            }
            .refreshable {
                await viewModel.fetchNotifications()
            }
        }
    }
}

struct NotificationCell: View {
    let notification: AppNotificationModel
    
    private var iconName: String {
        switch notification.type {
        case .like:
            return "heart.fill"
        case .comment:
            return "message.fill"
        case .follow:
            return "person.fill"
        case .mention:
            return "at"
        case .system:
            return "bell.fill"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .like:
            return .red
        case .comment:
            return .blue
        case .follow:
            return .green
        case .mention:
            return .purple
        case .system:
            return .orange
        }
    }
    
    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: Date(timeIntervalSince1970: notification.createdAt), relativeTo: Date())
    }
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.type.rawValue.capitalized)
                    .font(.headline)
                Text("Target: \(notification.targetId)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(timeAgo)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if !notification.read {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
    }
}

struct NotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationsView()
    }
}