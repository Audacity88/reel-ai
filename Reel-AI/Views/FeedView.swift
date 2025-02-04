import SwiftUI
import Appwrite

struct Video: Codable, Identifiable {
    let id: String
    let title: String
    let caption: String
    let authorId: String
    let author: String
    let videoFileId: String
    let thumbnailFileId: String
    let likes: Int
    let comments: Int
    let shares: Int
    let createdAt: Double
    
    // Computed property for thumbnail URL
    var thumbnailUrl: String {
        return AppWriteManager.shared.getFilePreview(
            bucketId: AppWriteConstants.Buckets.thumbnails,
            fileId: thumbnailFileId
        ).absoluteString
    }
}

class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    func fetchVideos() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let queries = [
                Query.orderDesc("createdAt"),
                Query.limit(50)
            ]
            
            let result = try await appWrite.database.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.videos,
                queries: queries
            )
            
            await MainActor.run {
                self.videos = result.documents.compactMap { document in
                    try? document.decode()
                }
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Error fetching videos: \(error.localizedDescription)")
            }
        }
    }
    
    func likeVideo(_ video: Video) async {
        guard let currentUser = try? await appWrite.account.get() else { return }
        
        // Create a like document
        let likeData: [String: Any] = [
            "userId": currentUser.id,
            "videoId": video.id,
            "createdAt": Date().timeIntervalSince1970
        ]
        _ = try? await appWrite.database.createDocument(
            databaseId: AppWriteConstants.databaseId,
            collectionId: AppWriteConstants.Collections.likes,
            documentId: ID.unique(),
            data: likeData
        )
        
        // Update video likes count
        let updatedData: [String: Any] = [
            "likes": video.likes + 1
        ]
        _ = try? await appWrite.database.updateDocument(
            databaseId: AppWriteConstants.databaseId,
            collectionId: AppWriteConstants.Collections.videos,
            documentId: video.id,
            data: updatedData
        )
        
        // Refresh videos
        await fetchVideos()
    }
}

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.videos.isEmpty {
                    Text("No videos yet")
                        .foregroundColor(.gray)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.videos) { video in
                                VideoCell(video: video) {
                                    Task {
                                        await viewModel.likeVideo(video)
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
                await viewModel.fetchVideos()
            }
            .refreshable {
                await viewModel.fetchVideos()
            }
        }
    }
}

struct VideoCell: View {
    let video: Video
    let onLike: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(video.title)
                .font(.headline)
                .lineLimit(1)
            
            // Thumbnail
            AsyncImage(url: URL(string: video.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            .frame(height: 200)
            .clipped()
            
            // Author
            Text(video.author)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Caption
            Text(video.caption)
                .font(.body)
                .lineLimit(2)
            
            // Interaction buttons
            HStack(spacing: 16) {
                Button(action: onLike) {
                    HStack {
                        Image(systemName: "heart")
                        Text("\(video.likes)")
                    }
                }
                
                HStack {
                    Image(systemName: "message")
                    Text("\(video.comments)")
                }
                
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("\(video.shares)")
                }
            }
            .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}
