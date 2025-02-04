import SwiftUI
import Charts
import Appwrite

// MARK: - Data Models
struct MetricData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

// MARK: - View Models
class MetricsViewModel: ObservableObject {
    @Published var totalViews: Int = 0
    @Published var totalLikes: Int = 0
    @Published var totalFollowers: Int = 0
    @Published var viewsData: [MetricData] = []
    @Published var likesData: [MetricData] = []
    @Published var followersData: [MetricData] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let appWrite = AppWriteManager.shared
    
    func fetchMetrics(for userId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let currentUserId = userId ?? (try await appWrite.getCurrentUser()?.$id)
            guard let userId = currentUserId else { return }
            
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.fetchTotalMetrics(for: userId) }
                group.addTask { await self.fetchHistoricalData(for: userId) }
            }
        } catch {
            await MainActor.run {
                self.error = error
                print("Error fetching metrics: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchTotalMetrics(for userId: String) async {
        do {
            let userDoc = try await appWrite.getDocument(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.users,
                documentId: userId
            )
            
            if let userProfile = try? JSONDecoder().decode(UserProfile.self, from: userDoc.data) {
                await MainActor.run {
                    self.totalFollowers = userProfile.followers
                }
            }
            
            // Fetch total views and likes from posts
            let postsQueries = [
                AppWriteConstants.Queries.equalTo(field: "userId", value: userId)
            ]
            
            let postsResult = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: AppWriteConstants.Collections.posts,
                queries: postsQueries
            )
            
            let posts = postsResult.documents.compactMap { document -> Post? in
                try? JSONDecoder().decode(Post.self, from: document.data)
            }
            
            let totalViews = posts.reduce(0) { $0 + $1.views }
            let totalLikes = posts.reduce(0) { $0 + $1.likes }
            
            await MainActor.run {
                self.totalViews = totalViews
                self.totalLikes = totalLikes
            }
        } catch {
            print("Error fetching total metrics: \(error.localizedDescription)")
        }
    }
    
    private func fetchHistoricalData(for userId: String) async {
        do {
            let calendar = Calendar.current
            let endDate = Date()
            let startDate = calendar.date(byAdding: .day, value: -30, to: endDate)!
            
            let queries = [
                AppWriteConstants.Queries.equalTo(field: "userId", value: userId),
                AppWriteConstants.Queries.greaterThan(field: "createdAt", value: startDate.timeIntervalSince1970),
                AppWriteConstants.Queries.lessThanEqual(field: "createdAt", value: endDate.timeIntervalSince1970),
                AppWriteConstants.Queries.orderByCreatedAt()
            ]
            
            let result = try await appWrite.listDocuments(
                databaseId: AppWriteConstants.databaseId,
                collectionId: "dailyMetrics",
                queries: queries
            )
            
            let metrics = result.documents.compactMap { document -> (date: Date, views: Int, likes: Int, followers: Int)? in
                guard let createdAt = document.data["createdAt"] as? TimeInterval,
                      let views = document.data["views"] as? Int,
                      let likes = document.data["likes"] as? Int,
                      let followers = document.data["followers"] as? Int else {
                    return nil
                }
                return (Date(timeIntervalSince1970: createdAt), views, likes, followers)
            }
            
            await MainActor.run {
                self.viewsData = metrics.map { MetricData(date: $0.date, value: $0.views) }
                self.likesData = metrics.map { MetricData(date: $0.date, value: $0.likes) }
                self.followersData = metrics.map { MetricData(date: $0.date, value: $0.followers) }
            }
        } catch {
            print("Error fetching historical data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Shared Views
struct TotalMetricsView: View {
    let views: Int
    let likes: Int
    let followers: Int
    
    var body: some View {
        HStack(spacing: 20) {
            MetricCard(title: "Views", value: views)
            MetricCard(title: "Likes", value: likes)
            MetricCard(title: "Followers", value: followers)
        }
        .padding()
    }
}

struct MetricCard: View {
    let title: String
    let value: Int
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

struct ChartView: View {
    let data: [MetricData]
    let title: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            
            Chart(data) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Value", item.value)
                )
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day().month())
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
} 