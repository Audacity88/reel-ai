import SwiftUI
import Charts
import FirebaseFirestore

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
    
    private var db = Firestore.firestore()
    
    func fetchMetrics(for userId: String? = nil) {
        if let userId = userId {
            fetchTotalMetrics(for: userId)
            fetchHistoricalData(for: userId)
        }
    }
    
    private func fetchTotalMetrics(for userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            guard let document = document, document.exists, let data = document.data() else {
                print("Error fetching user metrics: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                self?.totalViews = data["totalViews"] as? Int ?? 0
                self?.totalLikes = data["totalLikes"] as? Int ?? 0
                self?.totalFollowers = (data["followers"] as? [String])?.count ?? 0
            }
        }
    }
    
    private func fetchHistoricalData(for userId: String) {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -30, to: endDate)!
        
        db.collection("users").document(userId).collection("dailyMetrics")
            .whereField("date", isGreaterThan: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .order(by: "date")
            .getDocuments { [weak self] querySnapshot, error in
                guard let documents = querySnapshot?.documents else {
                    print("Error fetching historical data: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                DispatchQueue.main.async {
                    self?.viewsData = documents.compactMap { doc -> MetricData? in
                        guard let date = (doc["date"] as? Timestamp)?.dateValue(),
                              let views = doc["views"] as? Int else { return nil }
                        return MetricData(date: date, value: views)
                    }
                    
                    self?.likesData = documents.compactMap { doc -> MetricData? in
                        guard let date = (doc["date"] as? Timestamp)?.dateValue(),
                              let likes = doc["likes"] as? Int else { return nil }
                        return MetricData(date: date, value: likes)
                    }
                    
                    self?.followersData = documents.compactMap { doc -> MetricData? in
                        guard let date = (doc["date"] as? Timestamp)?.dateValue(),
                              let followers = doc["followers"] as? Int else { return nil }
                        return MetricData(date: date, value: followers)
                    }
                }
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