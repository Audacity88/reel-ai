import SwiftUI
import AVKit
import FirebaseFirestore
import Charts

struct LiveStreamView: View {
    @StateObject private var viewModel = MetricsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isStreaming = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Video preview when streaming
                if isStreaming {
                    VideoPlayer(player: AVPlayer())
                        .frame(height: 300)
                        .cornerRadius(12)
                } else {
                    Button(action: {
                        isStreaming.toggle()
                    }) {
                        VStack {
                            Image(systemName: "video.fill")
                                .font(.largeTitle)
                            Text("Start Streaming")
                        }
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                TotalMetricsView(
                    views: viewModel.totalViews,
                    likes: viewModel.totalLikes,
                    followers: viewModel.totalFollowers
                )
                
                ChartView(data: viewModel.viewsData, title: "Live Views")
                ChartView(data: viewModel.likesData, title: "Live Likes")
                ChartView(data: viewModel.followersData, title: "Followers Growth")
            }
            .padding()
        }
        .navigationTitle("Live Stream")
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                viewModel.fetchMetrics(for: userId)
            }
        }
    }
}

#Preview {
    LiveStreamView()
        .environmentObject(AuthViewModel())
}

