import SwiftUI
import AppWrite

class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    func fetchPosts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let queries = [
                AppWriteConstants.Queries.orderByCreatedAt(),
                AppWriteConstants.Queries.limit(50)
            ]
            
            let result = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.posts,
                queries: queries
            )
            
            await MainActor.run {
                self.posts = result.documents.compactMap { document in
                    try? JSONDecoder().decode(Post.self, from: document.data)
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Error fetching posts: \(error.localizedDescription)")
            }
        }
    }
    
    func likePost(_ post: Post) async {
        guard let currentUser = try? await appWrite.getCurrentUser() else { return }
        
        do {
            // Create a like document
            let likeData: [String: Any] = [
                "userId": currentUser.$id,
                "postId": post.id,
                "createdAt": Date().timeIntervalSince1970
            ]
            
            try await appWrite.createDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.likes,
                documentId: ID.unique(),
                data: likeData
            )
            
            // Update post likes count
            let updatedData: [String: Any] = [
                "likes": post.likes + 1
            ]
            
            try await appWrite.updateDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.posts,
                documentId: post.id,
                data: updatedData
            )
            
            // Refresh posts
            await fetchPosts()
        } catch {
            print("Error liking post: \(error.localizedDescription)")
        }
    }
}

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.posts.isEmpty {
                    Text("No posts yet")
                        .foregroundColor(.gray)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.posts) { post in
                                PostCell(post: post) {
                                    Task {
                                        await viewModel.likePost(post)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Feed")
            .task {
                await viewModel.fetchPosts()
            }
            .refreshable {
                await viewModel.fetchPosts()
            }
        }
    }
}

struct PostCell: View {
    let post: Post
    let onLike: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            AsyncImage(url: URL(string: post.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(height: 200)
            .clipped()
            
            // Caption
            Text(post.caption)
                .font(.body)
                .lineLimit(2)
            
            // Interaction buttons
            HStack(spacing: 16) {
                Button(action: onLike) {
                    HStack {
                        Image(systemName: "heart")
                        Text("\(post.likes)")
                    }
                }
                
                HStack {
                    Image(systemName: "message")
                    Text("\(post.comments)")
                }
                
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("\(post.shares)")
                }
            }
            .foregroundColor(.gray)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

