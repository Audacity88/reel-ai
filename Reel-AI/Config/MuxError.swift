import Foundation

public enum MuxError: Error {
    case configurationError
    case networkError(Error)
    case invalidResponse
    case invalidURL
    case notConfigured
} 