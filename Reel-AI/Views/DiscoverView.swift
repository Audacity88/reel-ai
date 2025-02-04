import SwiftUI
import FirebaseCore
import FirebaseFirestore

struct TrendingVideo: Identifiable {
    let id: String
    let thumbnailURL: String
    let views: Int
}

struct PopularHashtag: Identifiable {
    let id: String
    let name: String
    let postCount: Int
}

struct SuggestedUser: Identifiable {
    let id: String
    let username: String
    let profileImageURL: String
    let followerCount: Int
}

class DiscoverViewModel: ObservableObject {
    @Published var trendingVideos: [TrendingVideo] = []
    @Published var popularHashtags: [PopularHashtag] = []
    @Published var suggestedUsers: [SuggestedUser] = []
    @Published var searchResults: [Any] = []
    
    private var db = Firestore.firestore()
    
    func fetchTrendingVideos() {
        db.collection("videos")
            .order(by: "views", descending: true)
            .limit(to: 9)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching trending videos: \(error.localizedDescription)")
                    return
                }
                
                self.trendingVideos = querySnapshot?.documents.compactMap { document -> TrendingVideo? in
                    let data = document.data()
                    guard let thumbnailURL = data["thumbnailURL"] as? String,
                          let views = data["views"] as? Int else {
                        return nil
                    }
                    return TrendingVideo(id: document.documentID, thumbnailURL: thumbnailURL, views: views)
                } ?? []
            }
    }
    
    func fetchPopularHashtags() {
        db.collection("hashtags")
            .order(by: "postCount", descending: true)
            .limit(to: 10)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching popular hashtags: \(error.localizedDescription)")
                    return
                }
                
                self.popularHashtags = querySnapshot?.documents.compactMap { document -> PopularHashtag? in
                    let data = document.data()
                    guard let name = data["name"] as? String,
                          let postCount = data["postCount"] as? Int else {
                        return nil
                    }
                    return PopularHashtag(id: document.documentID, name: name, postCount: postCount)
                } ?? []
            }
    }
    
    func fetchSuggestedUsers() {
        db.collection("users")
            .order(by: "followerCount", descending: true)
            .limit(to: 5)
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching suggested users: \(error.localizedDescription)")
                    return
                }
                
                self.suggestedUsers = querySnapshot?.documents.compactMap { document -> SuggestedUser? in
                    let data = document.data()
                    guard let username = data["username"] as? String,
                          let profileImageURL = data["profileImageURL"] as? String,
                          let followerCount = data["followerCount"] as? Int else {
                        return nil
                    }
                    return SuggestedUser(id: document.documentID, username: username, profileImageURL: profileImageURL, followerCount: followerCount)
                } ?? []
            }
    }
    
    func search(query: String) {
        // Implement search functionality here
        // This could search for users, videos, and hashtags
        // For now, we'll just print the query
        print("Searching for: \(query)")
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
                        viewModel.search(query: searchText)
                    })
                    
                    TrendingVideosSection(videos: viewModel.trendingVideos)
                    
                    PopularHashtagsSection(hashtags: viewModel.popularHashtags)
                    
                    SuggestedUsersSection(users: viewModel.suggestedUsers)
                }
                .padding()
            }
            .navigationTitle("Discover")
        }
        .onAppear {
            viewModel.fetchTrendingVideos()
            viewModel.fetchPopularHashtags()
            viewModel.fetchSuggestedUsers()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearchButtonClicked: () -> Void
    
    var body: some View {
        HStack {
            TextField("Search", text: $text)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                    }
                )
            
            Button(action: onSearchButtonClicked) {
                Text("Search")
            }
        }
    }
}

struct TrendingVideosSection: View {
    let videos: [TrendingVideo]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Trending Videos")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(videos) { video in
                    AsyncImage(url: URL(string: video.thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .cornerRadius(8)
                            .overlay(
                                Text("\(video.views) views")
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                    .padding(4),
                                alignment: .bottomTrailing
                            )
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 120)
                            .cornerRadius(8)
                    }
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
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(hashtags) { hashtag in
                        VStack {
                            Text("#\(hashtag.name)")
                                .font(.subheadline)
                            Text("\(hashtag.postCount) posts")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
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
                .font(.headline)
            
            ForEach(users) { user in
                HStack {
                    AsyncImage(url: URL(string: user.profileImageURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 50, height: 50)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(user.username)
                            .font(.subheadline)
                        Text("\(user.followerCount) followers")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Follow user action
                    }) {
                        Text("Follow")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .cornerRadius(20)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview {
    DiscoverView()
}

