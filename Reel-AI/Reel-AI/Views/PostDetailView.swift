import SwiftUI
import Appwrite

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

struct PostDetailView: View {
    let post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AsyncImage(url: URL(string: post.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            Text(post.caption)
                .font(.body)
            Spacer()
        }
        .padding()
        .navigationTitle("Post Details")
    }
}

struct PostDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let samplePost = Post(id: "1", userId: "user1", caption: "Sample Caption", videoUrl: "", thumbnailUrl: "https://via.placeholder.com/150", createdAt: Date().timeIntervalSince1970, likes: 10, comments: 5, shares: 2)
        PostDetailView(post: samplePost)
    }
}