import Foundation

public protocol NetworkRequestProtocol {
    associatedtype ResponseType: Decodable
    var endpoint: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var body: Data? { get }
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

public enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int)
    case unknown
}

public class NetworkManager {
    public static let shared = NetworkManager()
    private let session: URLSession
    private let cache = URLCache.shared

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
    }

    public func request<T: NetworkRequestProtocol>(_ request: T, completion: @escaping (Result<T.ResponseType, NetworkError>) -> Void) {
        guard let url = URL(string: request.endpoint) else {
            completion(.failure(.invalidURL))
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(.unknown))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                    return
                }
            }

            do {
                let decoded = try JSONDecoder().decode(T.ResponseType.self, from: data)
                completion(.success(decoded))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }

        task.resume()
    }
}

public class RequestBuilder<T: Decodable> {
    private var endpoint: String = ""
    private var method: HTTPMethod = .get
    private var headers: [String: String] = [:]
    private var body: Data?

    public init() {}

    public func setEndpoint(_ endpoint: String) -> RequestBuilder<T> {
        self.endpoint = endpoint
        return self
    }

    public func setMethod(_ method: HTTPMethod) -> RequestBuilder<T> {
        self.method = method
        return self
    }

    public func addHeader(key: String, value: String) -> RequestBuilder<T> {
        self.headers[key] = value
        return self
    }

    public func setBody<U: Encodable>(_ body: U) -> RequestBuilder<T> {
        self.body = try? JSONEncoder().encode(body)
        return self
    }

    public func build() -> GenericRequest<T> {
        return GenericRequest(endpoint: endpoint, method: method, headers: headers, body: body)
    }
}

public struct GenericRequest<T: Decodable>: NetworkRequestProtocol {
    public typealias ResponseType = T
    public let endpoint: String
    public let method: HTTPMethod
    public let headers: [String: String]
    public let body: Data?
}

public class APIClient {
    private let networkManager: NetworkManager
    private let baseURL: String

    public init(baseURL: String) {
        self.baseURL = baseURL
        self.networkManager = NetworkManager.shared
    }

    public func get<T: Decodable>(path: String, completion: @escaping (Result<T, NetworkError>) -> Void) {
        let request = RequestBuilder<T>()
            .setEndpoint(baseURL + path)
            .setMethod(.get)
            .addHeader(key: "Content-Type", value: "application/json")
            .build()

        networkManager.request(request, completion: completion)
    }

    public func post<T: Decodable, U: Encodable>(path: String, body: U, completion: @escaping (Result<T, NetworkError>) -> Void) {
        let request = RequestBuilder<T>()
            .setEndpoint(baseURL + path)
            .setMethod(.post)
            .addHeader(key: "Content-Type", value: "application/json")
            .setBody(body)
            .build()

        networkManager.request(request, completion: completion)
    }
}

public class ResponseCache<T: Codable> {
    private var cache: [String: CacheEntry<T>] = [:]
    private let lock = NSLock()

    struct CacheEntry<U: Codable> {
        let value: U
        let timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > ttl
        }
    }

    public func set(_ value: T, forKey key: String, ttl: TimeInterval = 300) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = CacheEntry(value: value, timestamp: Date(), ttl: ttl)
    }

    public func get(forKey key: String) -> T? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = cache[key], !entry.isExpired else {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry.value
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}
