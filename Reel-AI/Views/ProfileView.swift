import SwiftUI
import Appwrite

class ProfileViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var userPosts: [Post] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    func loadProfile(userId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let userId = userId {
                // Load specific user's profile
                let document = try await appWrite.getDocument(
                    databaseId: AppWriteConstants.databaseId,
                    collectionId: AppWriteConstants.Collections.users,
                    documentId: userId
                )
                await MainActor.run {
                    self.userProfile = try? JSONDecoder().decode(UserProfile.self, from: document.data)
                }
            } else {
                // Load current user's profile
                let currentUser = try await appWrite.getCurrentUser()
                let document = try await appWrite.getDocument(
                    databaseId: AppWriteConstants.databaseId,
                    collectionId: AppWriteConstants.Collections.users,
                    documentId: currentUser.$id
                )
                await MainActor.run {
                    self.userProfile = try? JSONDecoder().decode(UserProfile.self, from: document.data)
                }
            }
            
            await loadUserPosts()
        } catch {
            await MainActor.run {
                self.error = error
                print("Error loading profile: \(error.localizedDescription)")
            }
        }
    }
    
    func loadUserPosts() async {
        guard let userId = userProfile?.id else { return }
        
        do {
            let queries = [
                AppWriteConstants.Queries.equalTo(field: "userId", value: userId),
                AppWriteConstants.Queries.orderByCreatedAt(),
                AppWriteConstants.Queries.limit(50)
            ]
            
            let result = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.posts,
                queries: queries
            )
            
            await MainActor.run {
                self.userPosts = result.documents.compactMap { document in
                    try? JSONDecoder().decode(Post.self, from: document.data)
                }
            }
        } catch {
            print("Error loading user posts: \(error.localizedDescription)")
        }
    }
    
    func updateProfile(username: String, bio: String) async {
        guard let userId = userProfile?.id else { return }
        
        do {
            let updatedData: [String: Any] = [
                "username": username,
                "bio": bio
            ]
            
            try await appWrite.updateDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.users,
                documentId: userId,
                data: updatedData
            )
            
            await loadProfile()
        } catch {
            print("Error updating profile: \(error.localizedDescription)")
        }
    }
    
    func uploadAvatar(_ imageData: Data) async {
        guard let userId = userProfile?.id else { return }
        
        do {
            let file = InputFile(data: imageData, filename: "avatar.jpg")
            let uploadedFile = try await appWrite.uploadFile(
                bucketId: AppWriteConstants.storageBucketId,
                fileId: ID.unique(),
                file: file
            )
            
            let updatedData: [String: Any] = [
                "avatarUrl": uploadedFile.url
            ]
            
            try await appWrite.updateDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.users,
                documentId: userId,
                data: updatedData
            )
            
            await loadProfile()
        }
    }
    
    func followUser() async {
        guard let currentUser = try? await appWrite.getCurrentUser(),
              let targetUserId = userProfile?.id else { return }
        
        do {
            // Create follow relationship
            let followData: [String: Any] = [
                "followerId": currentUser.$id,
                "followingId": targetUserId,
                "createdAt": Date().timeIntervalSince1970
            ]
            
            try await appWrite.createDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: "follows",
                documentId: ID.unique(),
                data: followData
            )
            
            // Update follower/following counts
            let updatedFollowerData: [String: Any] = [
                "followers": (userProfile?.followers ?? 0) + 1
            ]
            
            try await appWrite.updateDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.users,
                documentId: targetUserId,
                data: updatedFollowerData
            )
            
            await loadProfile(userId: targetUserId)
        } catch {
            print("Error following user: \(error.localizedDescription)")
        }
    }
}

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    let userId: String?
    @State private var isEditingProfile = false
    @State private var newUsername = ""
    @State private var newBio = ""
    
    init(userId: String? = nil) {
        self.userId = userId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Header
                if let profile = viewModel.userProfile {
                    ProfileHeader(
                        profile: profile,
                        isCurrentUser: userId == nil,
                        onFollowTap: {
                            Task {
                                await viewModel.followUser()
                            }
                        },
                        onEditTap: {
                            newUsername = profile.username
                            newBio = profile.bio ?? ""
                            isEditingProfile = true
                        }
                    )
                }
                
                // User Posts Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 2) {
                    ForEach(viewModel.userPosts) { post in
                        NavigationLink(destination: PostDetailView(post: post)) {
                            PostThumbnail(post: post)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.userProfile?.username ?? "Profile")
        .task {
            await viewModel.loadProfile(userId: userId)
        }
        .refreshable {
            await viewModel.loadProfile(userId: userId)
        }
        .sheet(isPresented: $isEditingProfile) {
            EditProfileView(
                username: $newUsername,
                bio: $newBio,
                onSave: {
                    Task {
                        await viewModel.updateProfile(
                            username: newUsername,
                            bio: newBio
                        )
                    }
                    isEditingProfile = false
                }
            )
        }
    }
}

struct ProfileHeader: View {
    let profile: UserProfile
    let isCurrentUser: Bool
    let onFollowTap: () -> Void
    let onEditTap: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            
            // Username and Bio
            VStack(spacing: 8) {
                Text(profile.username)
                    .font(.title2)
                    .bold()
                
                if let bio = profile.bio {
                    Text(bio)
                        .font(.body)
                        .foregroundColor(.gray)
                }
            }
            
            // Stats
            HStack(spacing: 40) {
            // Removed posts count display since UserProfile does not have a 'posts' property.
                
                VStack {
                    Text("\(profile.followers)")
                        .font(.headline)
                    Text("Followers")
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text("\(profile.following)")
                        .font(.headline)
                    Text("Following")
                        .foregroundColor(.gray)
                }
            }
            
            // Action Button
            if isCurrentUser {
                Button(action: onEditTap) {
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            } else {
                Button(action: onFollowTap) {
                    Text("Follow")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
    }
}

struct PostThumbnail: View {
    let post: Post
    
    var body: some View {
        AsyncImage(url: URL(string: post.thumbnailUrl)) { image in
            image
                .resizable()
                .aspectRatio(1, contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
        }
        .frame(height: UIScreen.main.bounds.width / 3)
        .clipped()
    }
}

struct EditProfileView: View {
    @Binding var username: String
    @Binding var bio: String
    let onSave: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Username", text: $username)
                    TextField("Bio", text: $bio)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    onSave()
                }
            )
        }
    }
}
