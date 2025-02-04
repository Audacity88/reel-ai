import SwiftUI
import AVKit
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var currentUser: User?
    
    private var db = Firestore.firestore()
    
    init() {
        fetchVideos()
        fetchCurrentUser()
    }
    
    func fetchVideos() {
        db.collection("videos").order(by: "createdAt", descending: true).addSnapshotListener { querySnapshot, error in
            guard let documents = querySnapshot?.documents else {
                print("Error fetching videos: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.videos = documents.compactMap { queryDocumentSnapshot -> Video? in
                return try? queryDocumentSnapshot.data(as: Video.self)
            }
        }
    }
    
    func fetchCurrentUser() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching current user: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.currentUser = try? document.data(as: User.self)
        }
    }
    
    func likeVideo(_ video: Video) {
        guard let videoId = video.id, let userId = currentUser?.id else { return }
        
        let videoRef = db.collection("videos").document(videoId)
        
        videoRef.updateData([
            "likes": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("Error liking video: \(error.localizedDescription)")
            } else {
                // Send notification to video author
                NotificationService.shared.sendNotification(to: video.authorId, title: "New Like", body: "\(self.currentUser?.username ?? "Someone") liked your video")
            }
        }
        
        // Add user to likes subcollection
        videoRef.collection("likes").document(userId).setData([:])
    }
    
    func addComment(_ text: String, to video: Video) {
        guard let videoId = video.id, let userId = currentUser?.id else { return }
        
        let comment = Comment(id: UUID().uuidString, authorId: userId, text: text, createdAt: Date())
        
        let videoRef = db.collection("videos").document(videoId)
        
        videoRef.updateData([
            "comments": FieldValue.arrayUnion([try! Firestore.Encoder().encode(comment)])
        ]) { error in
            if let error = error {
                print("Error adding comment: \(error.localizedDescription)")
            } else {
                // Send notification to video author
                NotificationService.shared.sendNotification(to: video.authorId, title: "New Comment", body: "\(self.currentUser?.username ?? "Someone") commented on your video")
            }
        }
    }
    
    func shareVideo(_ video: Video) {
        // Implement sharing functionality (e.g., using UIActivityViewController)
        guard let videoURL = URL(string: video.videoURL) else { return }
        let activityViewController = UIActivityViewController(activityItems: [videoURL], applicationActivities: nil)
        UIApplication.shared.windows.first?.rootViewController?.present(activityViewController, animated: true, completion: nil)
    }
}

struct VideoPlayerView: View {
    let video: Video
    @ObservedObject var viewModel: FeedViewModel
    @State private var player: AVPlayer?
    @State private var isShowingComments = false
    @State private var commentText = ""
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
            }
            
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading) {
                        Text(video.authorId) // Replace with author's username when available
                            .font(.headline)
                        Text("Description goes here")
                            .font(.subheadline)
                    }
                    Spacer()
                    VStack(spacing: 20) {
                        Button(action: { viewModel.likeVideo(video) }) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                        Button(action: { isShowingComments.toggle() }) {
                            Image(systemName: "message.fill")
                                .foregroundColor(.white)
                        }
                        Button(action: { viewModel.shareVideo(video) }) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))
            }
        }
        .onAppear {
            player = AVPlayer(url: URL(string: video.videoURL)!)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .sheet(isPresented: $isShowingComments) {
            CommentsView(video: video, viewModel: viewModel)
        }
    }
}

struct CommentsView: View {
    let video: Video
    @ObservedObject var viewModel: FeedViewModel
    @State private var commentText = ""
    
    var body: some View {
        VStack {
            List(video.comments) { comment in
                VStack(alignment: .leading) {
                    Text(comment.authorId) // Replace with author's username when available
                        .font(.headline)
                    Text(comment.text)
                        .font(.body)
                }
            }
            
            HStack {
                TextField("Add a comment", text: $commentText)
                Button("Post") {
                    viewModel.addComment(commentText, to: video)
                    commentText = ""
                }
            }
            .padding()
        }
    }
}

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.videos) { video in
                    VideoPlayerView(video: video, viewModel: viewModel)
                        .frame(height: UIScreen.main.bounds.height)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

