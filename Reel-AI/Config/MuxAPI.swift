import Foundation

public struct MuxLiveStream {
    public let streamKey: String
    public let playbackId: String
    
    public init(streamKey: String, playbackId: String) {
        self.streamKey = streamKey
        self.playbackId = playbackId
    }
}

public class MuxAPI {
    private static let baseURL = "https://api.mux.com/video/v1"
    private static var credentials: String {
        guard MuxConfig.isConfigured else {
            return ""
        }
        return "\(MuxConfig.accessTokenId):\(MuxConfig.secretKey)"
    }
    private static var accessToken: String {
        return Data(credentials.utf8).base64EncodedString()
    }
    
    public static func createUploadURL(completion: @escaping (Result<URL, MuxError>) -> Void) {
        guard MuxConfig.isConfigured else {
            completion(.failure(.configurationError))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/uploads") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let uploadParams: [String: Any] = [
            "new_asset_settings": [
                "playback_policy": ["public"]
            ],
            "cors_origin": "*"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: uploadParams)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let data = json["data"] as? [String: Any],
                  let url = data["url"] as? String,
                  let uploadUrl = URL(string: url) else {
                completion(.failure(.invalidResponse))
                return
            }
            
            completion(.success(uploadUrl))
        }
        
        task.resume()
    }
    
    public static func createLiveStream(completion: @escaping (Result<MuxLiveStream, MuxError>) -> Void) {
        guard MuxConfig.isConfigured else {
            completion(.failure(.notConfigured))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/live-streams") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "playback_policy": ["public"],
            "new_asset_settings": ["playback_policy": ["public"]]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.networkError(NSError(domain: "", code: -1, userInfo: nil))))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [String: Any],
                   let streamKey = data["stream_key"] as? String,
                   let playbackId = data["playback_ids"] as? [[String: Any]],
                   let id = playbackId.first?["id"] as? String {
                    let liveStream = MuxLiveStream(streamKey: streamKey, playbackId: id)
                    completion(.success(liveStream))
                } else {
                    completion(.failure(.invalidResponse))
                }
            } catch {
                completion(.failure(.networkError(error)))
            }
        }.resume()
    }
    
    public static func completeLiveStream(playbackId: String, completion: @escaping (Result<Void, MuxError>) -> Void) {
        guard MuxConfig.isConfigured else {
            completion(.failure(.notConfigured))
            return
        }
        
        guard let url = URL(string: "\(baseURL)/live-streams/\(playbackId)/complete") else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Basic \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
            } else {
                completion(.success(()))
            }
        }.resume()
    }
} 