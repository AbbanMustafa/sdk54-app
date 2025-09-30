import Foundation

public protocol Service {
    func initialize() async throws
    func shutdown() async throws
}

public protocol LoggerService: Service {
    func log(_ message: String, level: LogLevel)
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}

public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"

    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
}

public class ConsoleLogger: LoggerService {
    private var minimumLevel: LogLevel = .debug
    private let dateFormatter: DateFormatter

    public init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    public func initialize() async throws {}
    public func shutdown() async throws {}

    public func log(_ message: String, level: LogLevel) {
        guard level.priority >= minimumLevel.priority else { return }
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] [\(level.rawValue)] \(message)")
    }

    public func debug(_ message: String) {
        log(message, level: .debug)
    }

    public func info(_ message: String) {
        log(message, level: .info)
    }

    public func warning(_ message: String) {
        log(message, level: .warning)
    }

    public func error(_ message: String) {
        log(message, level: .error)
    }

    public func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
    }
}

public protocol AnalyticsService: Service {
    func track(event: String, properties: [String: Any]?)
    func setUserProperty(_ property: String, value: Any)
    func identifyUser(_ userId: String)
}

public class MockAnalyticsService: AnalyticsService {
    private var events: [(event: String, properties: [String: Any]?, timestamp: Date)] = []
    private var userProperties: [String: Any] = [:]
    private var userId: String?

    public init() {}

    public func initialize() async throws {}
    public func shutdown() async throws {}

    public func track(event: String, properties: [String: Any]?) {
        events.append((event, properties, Date()))
        print("Analytics: \(event) with properties: \(properties ?? [:])")
    }

    public func setUserProperty(_ property: String, value: Any) {
        userProperties[property] = value
        print("User property set: \(property) = \(value)")
    }

    public func identifyUser(_ userId: String) {
        self.userId = userId
        print("User identified: \(userId)")
    }

    public func getEvents() -> [(event: String, properties: [String: Any]?, timestamp: Date)] {
        return events
    }
}

public protocol StorageService: Service {
    func save<T: Encodable>(_ value: T, forKey key: String) throws
    func load<T: Decodable>(forKey key: String) throws -> T?
    func delete(forKey key: String) throws
    func clear() throws
}

public class UserDefaultsStorage: StorageService {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(suiteName: String? = nil) {
        if let suiteName = suiteName {
            userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        } else {
            userDefaults = .standard
        }
    }

    public func initialize() async throws {}
    public func shutdown() async throws {}

    public func save<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try encoder.encode(value)
        userDefaults.set(data, forKey: key)
    }

    public func load<T: Decodable>(forKey key: String) throws -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(T.self, from: data)
    }

    public func delete(forKey key: String) throws {
        userDefaults.removeObject(forKey: key)
    }

    public func clear() throws {
        let domain = Bundle.main.bundleIdentifier ?? "com.fiftyfour"
        userDefaults.removePersistentDomain(forName: domain)
    }
}

public protocol CacheService: Service {
    associatedtype Key: Hashable
    associatedtype Value

    func set(_ value: Value, forKey key: Key, ttl: TimeInterval?)
    func get(forKey key: Key) -> Value?
    func remove(forKey key: Key)
    func clear()
}

public class InMemoryCache<K: Hashable, V>: CacheService {
    public typealias Key = K
    public typealias Value = V

    private struct CacheEntry {
        let value: V
        let expirationDate: Date?

        var isExpired: Bool {
            guard let expirationDate = expirationDate else { return false }
            return Date() > expirationDate
        }
    }

    private var cache: [K: CacheEntry] = [:]
    private let lock = NSLock()
    private var cleanupTimer: Timer?

    public init() {}

    public func initialize() async throws {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.cleanupExpiredEntries()
        }
    }

    public func shutdown() async throws {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        clear()
    }

    public func set(_ value: V, forKey key: K, ttl: TimeInterval? = nil) {
        lock.lock()
        defer { lock.unlock() }

        let expirationDate = ttl.map { Date().addingTimeInterval($0) }
        cache[key] = CacheEntry(value: value, expirationDate: expirationDate)
    }

    public func get(forKey key: K) -> V? {
        lock.lock()
        defer { lock.unlock() }

        guard let entry = cache[key] else { return nil }

        if entry.isExpired {
            cache.removeValue(forKey: key)
            return nil
        }

        return entry.value
    }

    public func remove(forKey key: K) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }

    private func cleanupExpiredEntries() {
        lock.lock()
        defer { lock.unlock() }

        cache = cache.filter { !$0.value.isExpired }
    }
}

public class ServiceLocator {
    public static let shared = ServiceLocator()
    private var services: [String: Any] = [:]
    private let lock = NSRecursiveLock()

    private init() {}

    public func register<T>(_ service: T, forType type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        services[key] = service
    }

    public func resolve<T>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        return services[key] as? T
    }

    public func unregister<T>(_ type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        services.removeValue(forKey: key)
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
    }
}

public protocol Injectable {
    static func inject() -> Self
}

@propertyWrapper
public struct Injected<T> {
    private var service: T?

    public init() {
        self.service = ServiceLocator.shared.resolve(T.self)
    }

    public var wrappedValue: T {
        guard let service = service else {
            fatalError("Service \(T.self) not registered in ServiceLocator")
        }
        return service
    }

    public mutating func update() {
        service = ServiceLocator.shared.resolve(T.self)
    }
}

public class DependencyContainer {
    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]
    private let lock = NSRecursiveLock()

    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        factories[key] = factory
    }

    public func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        factories[key] = {
            if let singleton = self.singletons[key] as? T {
                return singleton
            }
            let instance = factory()
            self.singletons[key] = instance
            return instance
        }
    }

    public func resolve<T>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        guard let factory = factories[key] else { return nil }
        return factory() as? T
    }
}

public protocol Feature {
    var isEnabled: Bool { get }
    var name: String { get }
}

public class FeatureFlag: Feature {
    public let name: String
    public private(set) var isEnabled: Bool

    public init(name: String, isEnabled: Bool = false) {
        self.name = name
        self.isEnabled = isEnabled
    }

    public func enable() {
        isEnabled = true
    }

    public func disable() {
        isEnabled = false
    }

    public func toggle() {
        isEnabled.toggle()
    }
}

public class FeatureFlagManager {
    private var flags: [String: FeatureFlag] = [:]
    private let lock = NSLock()

    public func register(_ flag: FeatureFlag) {
        lock.lock()
        defer { lock.unlock() }
        flags[flag.name] = flag
    }

    public func isEnabled(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return flags[name]?.isEnabled ?? false
    }

    public func enable(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        flags[name]?.enable()
    }

    public func disable(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        flags[name]?.disable()
    }
}
