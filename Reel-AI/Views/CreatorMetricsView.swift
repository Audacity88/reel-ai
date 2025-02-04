import SwiftUI
import FirebaseCore
import FirebaseFirestore
import Charts

struct CreatorMetricsView: View {
    @StateObject private var viewModel = MetricsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                TotalMetricsView(
                    views: viewModel.totalViews,
                    likes: viewModel.totalLikes,
                    followers: viewModel.totalFollowers
                )
                
                ChartView(data: viewModel.viewsData, title: "Views Over Time")
                ChartView(data: viewModel.likesData, title: "Likes Over Time")
                ChartView(data: viewModel.followersData, title: "Followers Over Time")
            }
            .padding(.vertical)
        }
        .navigationTitle("Creator Metrics")
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                viewModel.fetchMetrics(for: userId)
            }
        }
    }
}

#Preview {
    CreatorMetricsView()
        .environmentObject(AuthViewModel())
}

