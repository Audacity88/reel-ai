import SwiftUI
import Appwrite

@main
struct Reel_AIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Initialize AppWrite client
        let client = Client()
            .setEndpoint("YOUR_APPWRITE_ENDPOINT") // Replace with your AppWrite endpoint
            .setProject("67a24702001e52a8b032")         // Replace with your project ID
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