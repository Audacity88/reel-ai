import Foundation

public enum MuxConfig {
    public static let accessTokenId = ProcessInfo.processInfo.environment["MUX_ACCESS_TOKEN_ID"] ?? ""
    public static let secretKey = ProcessInfo.processInfo.environment["MUX_SECRET_KEY"] ?? ""
    
    public static var isConfigured: Bool {
        return !accessTokenId.isEmpty && !secretKey.isEmpty
    }
} 