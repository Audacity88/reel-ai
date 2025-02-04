import SwiftUI

struct Message: Identifiable {
    let id = UUID()
    let username: String
    let lastMessage: String
    let timestamp: String
}

struct InboxView: View {
    let messages: [Message] = [
        Message(username: "user1", lastMessage: "Hey, great video!", timestamp: "2m"),
        Message(username: "user2", lastMessage: "Thanks for the follow!", timestamp: "1h"),
        Message(username: "user3", lastMessage: "Let's collab sometime", timestamp: "3h"),
    ]
    
    var body: some View {
        NavigationView {
            List(messages) { message in
                HStack {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading) {
                        Text(message.username)
                            .font(.headline)
                        Text(message.lastMessage)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text(message.timestamp)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("Inbox")
        }
    }
}

