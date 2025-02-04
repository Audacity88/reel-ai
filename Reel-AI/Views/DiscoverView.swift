import SwiftUI
import Appwrite

struct TrendingPost: Identifiable, Codable {
    let id: String
    let thumbnailUrl: String
    let views: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case thumbnailUrl
        case views
    }
}

struct PopularHashtag: Identifiable, Codable {
    let id: String
    let name: String
    let postCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case name
        case postCount
    }
}

struct SuggestedUser: Identifiable, Codable {
    let id: String
    let username: String
    let avatarUrl: String?
    let followers: Int
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case username
        case avatarUrl
        case followers
    }
}

class DiscoverViewModel: ObservableObject {
    @Published var trendingPosts: [TrendingPost] = []
    @Published var popularHashtags: [PopularHashtag] = []
    @Published var suggestedUsers: [SuggestedUser] = []
    @Published var searchResults: [Any] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    func fetchTrendingPosts() async {
        do {
            let queries = [
                AppWriteConstants.Queries.orderByCreatedAt(descending: true),
                AppWriteConstants.Queries.limit(9)
            ]
            
            let result = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.posts,
                queries: queries
            )
            
            await MainActor.run {
                self.trendingPosts = result.documents.compactMap { document in
                    try? JSONDecoder().decode(TrendingPost.self, from: document.data)
                }
            }
        } catch {
            print("Error fetching trending posts: \(error.localizedDescription)")
        }
    }
    
    func fetchPopularHashtags() async {
        do {
            let queries = [
                AppWriteConstants.Queries.orderByCreatedAt(descending: true),
                AppWriteConstants.Queries.limit(10)
            ]
            
            let result = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: "hashtags",
                queries: queries
            )
            
            await MainActor.run {
                self.popularHashtags = result.documents.compactMap { document in
                    try? JSONDecoder().decode(PopularHashtag.self, from: document.data)
                }
            }
        } catch {
            print("Error fetching popular hashtags: \(error.localizedDescription)")
        }
    }
    
    func fetchSuggestedUsers() async {
        do {
            let queries = [
                AppWriteConstants.Queries.orderByCreatedAt(descending: true),
                AppWriteConstants.Queries.limit(5)
            ]
            
            let result = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.users,
                queries: queries
            )
            
            await MainActor.run {
                self.suggestedUsers = result.documents.compactMap { document in
                    try? JSONDecoder().decode(SuggestedUser.self, from: document.data)
                }
            }
        } catch {
            print("Error fetching suggested users: \(error.localizedDescription)")
        }
    }
    
    func search(query: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let queries = [
                AppWriteConstants.Queries.limit(20)
            ]
            
            // Search users
            let usersResult = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.users,
                queries: queries
            )
            
            let users = usersResult.documents.compactMap { document -> SuggestedUser? in
                try? JSONDecoder().decode(SuggestedUser.self, from: document.data)
            }
            
            // Search posts
            let postsResult = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.posts,
                queries: queries
            )
            
            let posts = postsResult.documents.compactMap { document -> Post? in
                try? JSONDecoder().decode(Post.self, from: document.data)
            }
            
            await MainActor.run {
                self.searchResults = users + posts
            }
        } catch {
            print("Error searching: \(error.localizedDescription)")
        }
    }
}

struct DiscoverView: View {
    @StateObject private var viewModel = DiscoverViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SearchBar(text: $searchText, onSearchButtonClicked: {
                        Task {
                            await viewModel.search(query: searchText)
                        }
                    })
                    
                    if !searchText.isEmpty {
                        SearchResultsView(results: viewModel.searchResults)
                    } else {
                        TrendingPostsSection(posts: viewModel.trendingPosts)
                        PopularHashtagsSection(hashtags: viewModel.popularHashtags)
                        SuggestedUsersSection(users: viewModel.suggestedUsers)
                    }
                }
                .padding()
            }
            .navigationTitle("Discover")
            .task {
                await viewModel.fetchTrendingPosts()
                await viewModel.fetchPopularHashtags()
                await viewModel.fetchSuggestedUsers()
            }
            .refreshable {
                await viewModel.fetchTrendingPosts()
                await viewModel.fetchPopularHashtags()
                await viewModel.fetchSuggestedUsers()
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit(onSearchButtonClicked)
            
            Button(action: onSearchButtonClicked) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
            }
        }
    }
}

struct TrendingPostsSection: View {
    let posts: [TrendingPost]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Trending")
                .font(.title2)
                .bold()
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(posts) { post in
                    AsyncImage(url: URL(string: post.thumbnailUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        Text("\(post.views) views")
                            .font(.caption)
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                            .padding(4),
                        alignment: .bottomTrailing
                    )
                }
            }
        }
    }
}

struct PopularHashtagsSection: View {
    let hashtags: [PopularHashtag]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Popular Hashtags")
                .font(.title2)
                .bold()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(hashtags) { hashtag in
                        VStack {
                            Text("#\(hashtag.name)")
                                .font(.headline)
                            Text("\(hashtag.postCount) posts")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct SuggestedUsersSection: View {
    let users: [SuggestedUser]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Suggested Users")
                .font(.title2)
                .bold()
            
            ForEach(users) { user in
                HStack {
                    AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading) {
                        Text(user.username)
                            .font(.headline)
                        Text("\(user.followers) followers")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Text("Follow")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct SearchResultsView: View {
    let results: [Any]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Search Results")
                .font(.title2)
                .bold()
            
            ForEach(0..<results.count, id: \.self) { index in
                if let user = results[index] as? SuggestedUser {
                    NavigationLink(destination: ProfileView(userId: user.id)) {
                        HStack {
                            AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            
                            Text(user.username)
                                .font(.headline)
                        }
                    }
                } else if let post = results[index] as? Post {
                    NavigationLink(destination: PostDetailView(post: post)) {
                        HStack {
                            AsyncImage(url: URL(string: post.thumbnailUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            
                            Text(post.caption)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    DiscoverView()
}

