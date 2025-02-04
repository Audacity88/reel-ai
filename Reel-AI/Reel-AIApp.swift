import SwiftUI
import AppWrite

@main
struct ReelAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Initialize AppWrite client
        let client = Client()
            .setEndpoint("YOUR_APPWRITE_ENDPOINT") // Replace with your AppWrite endpoint
            .setProject("YOUR_PROJECT_ID")         // Replace with your project ID
            .setSelfSigned(true)                  // Remove in production
        
        // Initialize AppWrite manager
        AppWriteManager.shared.initialize(client: client)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}