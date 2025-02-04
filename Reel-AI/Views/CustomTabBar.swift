import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            TabBarButton(imageName: "house", text: "Home", isSelected: selectedTab == 0)
                .onTapGesture { selectedTab = 0 }
            TabBarButton(imageName: "magnifyingglass", text: "Discover", isSelected: selectedTab == 1)
                .onTapGesture { selectedTab = 1 }
            TabBarButton(imageName: "plus.square", text: "Upload", isSelected: selectedTab == 2)
                .onTapGesture { selectedTab = 2 }
            TabBarButton(imageName: "message", text: "Inbox", isSelected: selectedTab == 3)
                .onTapGesture { selectedTab = 3 }
            TabBarButton(imageName: "person", text: "Profile", isSelected: selectedTab == 4)
                .onTapGesture { selectedTab = 4 }
        }
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(Color.black.opacity(0.8))
    }
}

struct TabBarButton: View {
    let imageName: String
    let text: String
    let isSelected: Bool
    
    var body: some View {
        VStack {
            Image(systemName: imageName)
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .white : .gray)
            Text(text)
                .font(.caption)
                .foregroundColor(isSelected ? .white : .gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CustomTabBar(selectedTab: .constant(0))
}

