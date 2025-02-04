import Foundation
import AppWrite

// MARK: - User Profile
struct UserProfile: Codable, Identifiable {
    let id: String
    let email: String
    let username: String
    let createdAt: TimeInterval
    var avatarUrl: String?
    var bio: String?
    var followers: Int
    var following: Int
    var totalLikes: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case email
        case username
        case createdAt
        case avatarUrl
        case bio
        case followers
        case following
        case totalLikes
    }
}

// MARK: - Post
struct Post: Codable, Identifiable {
    let id: String
    let userId: String
    let caption: String
    let videoUrl: String
    let thumbnailUrl: String
    let createdAt: TimeInterval
    var likes: Int
    var comments: Int
    var shares: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case caption
        case videoUrl
        case thumbnailUrl
        case createdAt
        case likes
        case comments
        case shares
    }
}

// MARK: - Comment
struct Comment: Codable, Identifiable {
    let id: String
    let postId: String
    let userId: String
    let text: String
    let createdAt: TimeInterval
    var likes: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case postId
        case userId
        case text
        case createdAt
        case likes
    }
}

// MARK: - Like
struct Like: Codable, Identifiable {
    let id: String
    let userId: String
    let postId: String
    let createdAt: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case postId
        case createdAt
    }
}

// MARK: - Notification
struct Notification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: NotificationType
    let targetId: String // postId, userId, or commentId depending on type
    let createdAt: TimeInterval
    var read: Bool
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case type
        case targetId
        case createdAt
        case read
    }
}

enum NotificationType: String, Codable {
    case like
    case comment
    case follow
    case mention
}

// MARK: - AppWrite Constants
struct AppWriteConstants {
    static let databaseId = "YOUR_DATABASE_ID"
    static let storageBucketId = "YOUR_STORAGE_BUCKET_ID"
    
    struct Collections {
        static let users = "users"
        static let posts = "posts"
        static let comments = "comments"
        static let likes = "likes"
        static let notifications = "notifications"
    }
    
    struct Queries {
        static func orderByCreatedAt(descending: Bool = true) -> String {
            return descending ? "orderDesc(\"createdAt\")" : "orderAsc(\"createdAt\")"
        }
        
        static func equalTo(field: String, value: String) -> String {
            return "equal(\"\(field)\", [\"\(value)\"])"
        }
        
        static func limit(_ count: Int) -> String {
            return "limit(\(count))"
        }
    }
}

