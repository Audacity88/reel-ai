import SwiftUI
import AppWrite
import Charts

class MetricsViewModel: ObservableObject {
    @Published var totalViews = 0
    @Published var totalLikes = 0
    @Published var totalFollowers = 0
    @Published var viewsData: [(date: Date, count: Int)] = []
    @Published var likesData: [(date: Date, count: Int)] = []
    @Published var followersData: [(date: Date, count: Int)] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    func fetchMetrics() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let currentUser = try await appWrite.getCurrentUser() else { return }
            
            // Fetch total metrics
            let userDoc = try await appWrite.getDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.users,
                documentId: currentUser.$id
            )
            
            if let userProfile = try? JSONDecoder().decode(UserProfile.self, from: userDoc.data) {
                await MainActor.run {
                    self.totalFollowers = userProfile.followers
                }
            }
            
            // Fetch posts for views and likes
            let postsQueries = [
                AppWriteConstants.Queries.equalTo(field: "userId", value: currentUser.$id),
                AppWriteConstants.Queries.orderByCreatedAt()
            ]
            
            let postsResult = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.posts,
                queries: postsQueries
            )
            
            let posts = postsResult.documents.compactMap { document -> Post? in
                try? JSONDecoder().decode(Post.self, from: document.data)
            }
            
            // Calculate totals and time series data
            var totalViews = 0
            var totalLikes = 0
            var viewsByDate: [Date: Int] = [:]
            var likesByDate: [Date: Int] = [:]
            
            for post in posts {
                totalViews += post.views
                totalLikes += post.likes
                
                let date = Date(timeIntervalSince1970: post.createdAt)
                let calendar = Calendar.current
                let startOfDay = calendar.startOfDay(for: date)
                
                viewsByDate[startOfDay, default: 0] += post.views
                likesByDate[startOfDay, default: 0] += post.likes
            }
            
            // Convert to sorted arrays
            let sortedViewsData = viewsByDate.map { (date: $0.key, count: $0.value) }
                .sorted { $0.date < $1.date }
            
            let sortedLikesData = likesByDate.map { (date: $0.key, count: $0.value) }
                .sorted { $0.date < $1.date }
            
            // Fetch followers history
            let followersQueries = [
                AppWriteConstants.Queries.equalTo(field: "followingId", value: currentUser.$id),
                AppWriteConstants.Queries.orderByCreatedAt()
            ]
            
            let followersResult = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: "follows",
                queries: followersQueries
            )
            
            var followersByDate: [Date: Int] = [:]
            var runningFollowerCount = 0
            
            for document in followersResult.documents {
                if let createdAt = document.data["createdAt"] as? TimeInterval {
                    let date = Date(timeIntervalSince1970: createdAt)
                    let calendar = Calendar.current
                    let startOfDay = calendar.startOfDay(for: date)
                    
                    runningFollowerCount += 1
                    followersByDate[startOfDay] = runningFollowerCount
                }
            }
            
            let sortedFollowersData = followersByDate.map { (date: $0.key, count: $0.value) }
                .sorted { $0.date < $1.date }
            
            await MainActor.run {
                self.totalViews = totalViews
                self.totalLikes = totalLikes
                self.viewsData = sortedViewsData
                self.likesData = sortedLikesData
                self.followersData = sortedFollowersData
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Error fetching metrics: \(error.localizedDescription)")
            }
        }
    }
}

struct CreatorMetricsView: View {
    @StateObject private var viewModel = MetricsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    TotalMetricsView(
                        views: viewModel.totalViews,
                        likes: viewModel.totalLikes,
                        followers: viewModel.totalFollowers
                    )
                    
                    MetricChartView(
                        data: viewModel.viewsData,
                        title: "Views Over Time",
                        color: .blue
                    )
                    
                    MetricChartView(
                        data: viewModel.likesData,
                        title: "Likes Over Time",
                        color: .red
                    )
                    
                    MetricChartView(
                        data: viewModel.followersData,
                        title: "Followers Over Time",
                        color: .green
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Creator Metrics")
        .task {
            await viewModel.fetchMetrics()
        }
        .refreshable {
            await viewModel.fetchMetrics()
        }
    }
}

struct TotalMetricsView: View {
    let views: Int
    let likes: Int
    let followers: Int
    
    var body: some View {
        HStack(spacing: 20) {
            MetricCard(title: "Views", value: views, systemImage: "eye.fill", color: .blue)
            MetricCard(title: "Likes", value: likes, systemImage: "heart.fill", color: .red)
            MetricCard(title: "Followers", value: followers, systemImage: "person.fill", color: .green)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: Int
    let systemImage: String
    let color: Color
    
    var body: some View {
        VStack {
            Image(systemName: systemImage)
                .foregroundColor(color)
                .font(.title)
            
            Text("\(value)")
                .font(.headline)
                .bold()
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct MetricChartView: View {
    let data: [(date: Date, count: Int)]
    let title: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            
            if data.isEmpty {
                Text("No data available")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Chart {
                    ForEach(data, id: \.date) { item in
                        LineMark(
                            x: .value("Date", item.date),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(color)
                        
                        AreaMark(
                            x: .value("Date", item.date),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(color.opacity(0.1))
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

#Preview {
    CreatorMetricsView()
}

