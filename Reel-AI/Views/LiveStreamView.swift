import SwiftUI
import Appwrite
import AVKit
import Charts

struct LiveStream: Codable, Identifiable {
    let id: String
    let userId: String
    let title: String
    let streamUrl: String
    let thumbnailUrl: String
    let isLive: Bool
    let viewerCount: Int
    let startedAt: TimeInterval
    
    enum CodingKeys: String, CodingKey {
        case id = "$id"
        case userId
        case title
        case streamUrl
        case thumbnailUrl
        case isLive
        case viewerCount
        case startedAt
    }
}

class LiveStreamViewModel: ObservableObject {
    @Published var stream: LiveStream?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var comments: [Comment] = []
    @Published var viewerCount = 0
    
    private let appWrite = AppWriteManager.shared
    private var realtime: RealtimeSubscription?
    
    func startStream(title: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let currentUser = try await appWrite.getCurrentUser() else { return }
            
            // Create a new live stream
            let streamData: [String: Any] = [
                "userId": currentUser.$id,
                "title": title,
                "streamUrl": "", // This would come from your streaming service
                "thumbnailUrl": "", // This would be generated
                "isLive": true,
                "viewerCount": 0,
                "startedAt": Date().timeIntervalSince1970
            ]
            
            let document = try await appWrite.createDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: "livestreams",
                documentId: ID.unique(),
                data: streamData
            )
            
            if let stream = try? JSONDecoder().decode(LiveStream.self, from: document.data) {
                await MainActor.run {
                    self.stream = stream
                }
                
                // Subscribe to comments
                subscribeToComments(streamId: stream.id)
                
                // Subscribe to viewer count updates
                subscribeToViewerCount(streamId: stream.id)
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Error starting stream: \(error.localizedDescription)")
            }
        }
    }
    
    func endStream() async {
        guard let stream = stream else { return }
        
        do {
            let updatedData: [String: Any] = [
                "isLive": false
            ]
            
            try await appWrite.updateDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: "livestreams",
                documentId: stream.id,
                data: updatedData
            )
            
            // Cleanup subscriptions
            realtime?.close()
            
            await MainActor.run {
                self.stream = nil
            }
        } catch {
            print("Error ending stream: \(error.localizedDescription)")
        }
    }
    
    func sendComment(_ text: String) async {
        guard let stream = stream,
              let currentUser = try? await appWrite.getCurrentUser() else { return }
        
        do {
            let commentData: [String: Any] = [
                "streamId": stream.id,
                "userId": currentUser.$id,
                "text": text,
                "createdAt": Date().timeIntervalSince1970
            ]
            
            try await appWrite.createDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: "livestream_comments",
                documentId: ID.unique(),
                data: commentData
            )
        } catch {
            print("Error sending comment: \(error.localizedDescription)")
        }
    }
    
    private func subscribeToComments(streamId: String) {
        realtime = appWrite.subscribe(
            channel: "livestream:\(streamId):comments",
            callback: { [weak self] message in
                if let commentData = message.payload,
                   let comment = try? JSONDecoder().decode(Comment.self, from: commentData) {
                    DispatchQueue.main.async {
                        self?.comments.append(comment)
                    }
                }
            }
        )
    }
    
    private func subscribeToViewerCount(streamId: String) {
        realtime = appWrite.subscribe(
            channel: "livestream:\(streamId):viewers",
            callback: { [weak self] message in
                if let count = message.payload["viewerCount"] as? Int {
                    DispatchQueue.main.async {
                        self?.viewerCount = count
                    }
                }
            }
        )
    }
}

struct LiveStreamView: View {
    @StateObject private var viewModel = LiveStreamViewModel()
    @State private var isShowingStreamSetup = false
    @State private var streamTitle = ""
    @State private var commentText = ""
    
    var body: some View {
        Group {
            if viewModel.stream == nil {
                Button("Start Streaming") {
                    isShowingStreamSetup = true
                }
                .sheet(isPresented: $isShowingStreamSetup) {
                    StreamSetupView(title: $streamTitle) {
                        Task {
                            await viewModel.startStream(title: streamTitle)
                            isShowingStreamSetup = false
                        }
                    }
                }
            } else {
                StreamView(
                    stream: viewModel.stream!,
                    comments: viewModel.comments,
                    viewerCount: viewModel.viewerCount,
                    commentText: $commentText,
                    onSendComment: {
                        Task {
                            await viewModel.sendComment(commentText)
                            commentText = ""
                        }
                    },
                    onEndStream: {
                        Task {
                            await viewModel.endStream()
                        }
                    }
                )
            }
        }
    }
}

struct StreamSetupView: View {
    @Binding var title: String
    let onStart: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Stream Details")) {
                    TextField("Stream Title", text: $title)
                }
            }
            .navigationTitle("New Stream")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Start") {
                    onStart()
                }
                .disabled(title.isEmpty)
            )
        }
    }
}

struct StreamView: View {
    let stream: LiveStream
    let comments: [Comment]
    let viewerCount: Int
    @Binding var commentText: String
    let onSendComment: () -> Void
    let onEndStream: () -> Void
    
    var body: some View {
        VStack {
            // Video player would go here
            Rectangle()
                .fill(Color.black)
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Text("Live Stream")
                        .foregroundColor(.white)
                )
            
            HStack {
                Text(stream.title)
                    .font(.headline)
                Spacer()
                HStack {
                    Image(systemName: "eye.fill")
                    Text("\(viewerCount)")
                }
                .foregroundColor(.red)
            }
            .padding()
            
            // Comments
            ScrollView {
                LazyVStack(alignment: .leading) {
                    ForEach(comments) { comment in
                        CommentView(comment: comment)
                    }
                }
                .padding()
            }
            
            // Comment input
            HStack {
                TextField("Add a comment", text: $commentText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: onSendComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                .disabled(commentText.isEmpty)
            }
            .padding()
            
            Button("End Stream") {
                onEndStream()
            }
            .foregroundColor(.red)
            .padding()
        }
    }
}

struct CommentView: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(comment.text)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

#Preview {
    LiveStreamView()
}

