import Foundation
import FirebaseCore
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let username: String
    let profileImageURL: String?
    var followers: [String]
    var following: [String]
    var isCreator: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case profileImageURL
        case followers
        case following
        case isCreator
    }
    
    init(username: String, profileImageURL: String?, followers: [String], following: [String], isCreator: Bool) {
        self.username = username
        self.profileImageURL = profileImageURL
        self.followers = followers
        self.following = following
        self.isCreator = isCreator
    }
}

struct Video: Identifiable, Codable {
    @DocumentID var id: String?
    let authorId: String
    let videoURL: String
    let thumbnailURL: String
    var likes: Int
    var comments: [Comment]
    let createdAt: Date
}

struct Comment: Identifiable, Codable {
    let id: String
    let authorId: String
    let text: String
    let createdAt: Date
}

