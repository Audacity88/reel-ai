import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var videos: [Video] = []
    @Published var isCurrentUser = false
    @Published var isFollowing = false
    
    private var db = Firestore.firestore()
    
    func fetchUser(userId: String) {
        db.collection("users").document(userId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching user: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.user = try? document.data(as: User.self)
            self.isCurrentUser = userId == Auth.auth().currentUser?.uid
            self.checkFollowStatus()
        }
    }
    
    func fetchVideos(userId: String) {
        db.collection("videos")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching videos: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                self.videos = documents.compactMap { queryDocumentSnapshot -> Video? in
                    return try? queryDocumentSnapshot.data(as: Video.self)
                }
            }
    }
    
    func checkFollowStatus() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let userId = user?.id else { return }
        
        db.collection("users").document(currentUserId).getDocument { document, error in
            if let document = document, document.exists {
                if let following = document.data()?["following"] as? [String] {
                    self.isFollowing = following.contains(userId)
                }
            }
        }
    }
    
    func toggleFollow() {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              let userId = user?.id else { return }
        
        let currentUserRef = db.collection("users").document(currentUserId)
        let userRef = db.collection("users").document(userId)
        
        if isFollowing {
            // Unfollow
            currentUserRef.updateData([
                "following": FieldValue.arrayRemove([userId])
            ])
            userRef.updateData([
                "followers": FieldValue.arrayRemove([currentUserId])
            ])
        } else {
            // Follow
            currentUserRef.updateData([
                "following": FieldValue.arrayUnion([userId])
            ])
            userRef.updateData([
                "followers": FieldValue.arrayUnion([currentUserId])
            ])
            
            // Send notification to followed user
            db.collection("users").document(currentUserId).getDocument { document, error in
                if let document = document, document.exists, let username = document.data()?["username"] as? String {
                    NotificationService.shared.sendNotification(to: userId, title: "New Follower", body: "\(username) started following you")
                }
            }
        }
        
        isFollowing.toggle()
    }
}

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    let userId: String
    
    var body: some View {
        ScrollView {
            VStack {
                ProfileHeaderView(user: viewModel.user, isCurrentUser: viewModel.isCurrentUser, isFollowing: viewModel.isFollowing, toggleFollow: viewModel.toggleFollow)
                
                if viewModel.isCurrentUser {
                    NavigationLink(destination: CreatorMetricsView()) {
                        Text("View Creator Metrics")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.bottom)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                    ForEach(viewModel.videos) { video in
                        NavigationLink(destination: VideoPlayerView(video: video, viewModel: FeedViewModel())) {
                            VideoThumbnailView(video: video)
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchUser(userId: userId)
            viewModel.fetchVideos(userId: userId)
        }
    }
}

struct ProfileHeaderView: View {
    let user: User?
    let isCurrentUser: Bool
    let isFollowing: Bool
    let toggleFollow: () -> Void
    
    var body: some View {
        VStack {
            if let user = user {
                AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 100, height: 100)
                }
                
                Text(user.username)
                    .font(.title2)
                
                HStack {
                    VStack {
                        Text("\(user.followers.count)")
                            .font(.headline)
                        Text("Followers")
                            .font(.caption)
                    }
                    
                    VStack {
                        Text("\(user.following.count)")
                            .font(.headline)
                        Text("Following")
                            .font(.caption)
                    }
                }
                .padding()
                
                if !isCurrentUser {
                    Button(action: toggleFollow) {
                        Text(isFollowing ? "Unfollow" : "Follow")
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(isFollowing ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
}

struct VideoThumbnailView: View {
    let video: Video
    
    var body: some View {
        AsyncImage(url: URL(string: video.thumbnailURL)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 150)
                .clipped()
        } placeholder: {
            Rectangle()
                .fill(Color.gray)
                .frame(height: 150)
        }
    }
}

