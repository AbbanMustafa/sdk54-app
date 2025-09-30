import Foundation

public protocol Identifiable {
    var id: String { get }
}

public protocol Timestampable {
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

public struct User: Codable, Identifiable, Timestampable {
    public let id: String
    public let username: String
    public let email: String
    public let firstName: String
    public let lastName: String
    public let avatarURL: String?
    public let bio: String?
    public let createdAt: Date
    public let updatedAt: Date
    public let settings: UserSettings
    public let metadata: [String: AnyCodable]

    public var fullName: String {
        return "\(firstName) \(lastName)"
    }

    public init(id: String, username: String, email: String, firstName: String, lastName: String, avatarURL: String? = nil, bio: String? = nil, createdAt: Date, updatedAt: Date, settings: UserSettings, metadata: [String: AnyCodable] = [:]) {
        self.id = id
        self.username = username
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.avatarURL = avatarURL
        self.bio = bio
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.settings = settings
        self.metadata = metadata
    }
}

public struct UserSettings: Codable {
    public let notificationsEnabled: Bool
    public let theme: Theme
    public let language: String
    public let privacySettings: PrivacySettings

    public enum Theme: String, Codable {
        case light
        case dark
        case system
    }
}

public struct PrivacySettings: Codable {
    public let profileVisibility: Visibility
    public let showEmail: Bool
    public let showActivity: Bool

    public enum Visibility: String, Codable {
        case `public`
        case friends
        case `private`
    }
}

public struct Post: Codable, Identifiable, Timestampable {
    public let id: String
    public let authorId: String
    public let title: String
    public let content: String
    public let imageURLs: [String]
    public let tags: [String]
    public let createdAt: Date
    public let updatedAt: Date
    public let likes: Int
    public let comments: [Comment]
    public let status: PostStatus

    public enum PostStatus: String, Codable {
        case draft
        case published
        case archived
        case deleted
    }
}

public struct Comment: Codable, Identifiable, Timestampable {
    public let id: String
    public let postId: String
    public let authorId: String
    public let content: String
    public let createdAt: Date
    public let updatedAt: Date
    public let likes: Int
    public let replies: [Comment]
}

public struct AnyCodable: Codable {
    private let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Unsupported type"))
        }
    }
}

public class DataStore<T: Codable & Identifiable> {
    private var items: [String: T] = [:]
    private let lock = NSRecursiveLock()
    private let persistence: DataPersistence<T>

    public init(persistence: DataPersistence<T>) {
        self.persistence = persistence
        loadFromDisk()
    }

    public func save(_ item: T) {
        lock.lock()
        defer { lock.unlock() }
        items[item.id] = item
        persistence.save(item)
    }

    public func get(id: String) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return items[id]
    }

    public func getAll() -> [T] {
        lock.lock()
        defer { lock.unlock() }
        return Array(items.values)
    }

    public func delete(id: String) {
        lock.lock()
        defer { lock.unlock() }
        items.removeValue(forKey: id)
        persistence.delete(id: id)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        items.removeAll()
        persistence.clearAll()
    }

    private func loadFromDisk() {
        items = persistence.loadAll().reduce(into: [:]) { $0[$1.id] = $1 }
    }
}

public class DataPersistence<T: Codable> {
    private let fileManager = FileManager.default
    private let directory: URL

    public init(directory: String) {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.directory = documentsPath.appendingPathComponent(directory)

        if !fileManager.fileExists(atPath: self.directory.path) {
            try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        }
    }

    public func save(_ item: T) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(item) else { return }
        let filename = UUID().uuidString + ".json"
        let fileURL = directory.appendingPathComponent(filename)

        try? data.write(to: fileURL)
    }

    public func loadAll() -> [T] {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return files.compactMap { fileURL in
            guard let data = try? Data(contentsOf: fileURL),
                  let item = try? decoder.decode(T.self, from: data) else {
                return nil
            }
            return item
        }
    }

    public func delete(id: String) {
        guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files {
            if file.lastPathComponent.contains(id) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    public func clearAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
