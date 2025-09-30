import Foundation

public protocol UseCase {
    associatedtype Input
    associatedtype Output
    func execute(_ input: Input) async throws -> Output
}

public protocol Validator {
    associatedtype Value
    func validate(_ value: Value) throws
}

public enum ValidationError: Error {
    case invalidInput
    case missingRequiredField(String)
    case outOfRange(String)
    case custom(String)
}

public struct EmailValidator: Validator {
    public typealias Value = String

    public func validate(_ value: String) throws {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)

        if !emailPredicate.evaluate(with: value) {
            throw ValidationError.custom("Invalid email format")
        }
    }
}

public struct PasswordValidator: Validator {
    public typealias Value = String
    private let minLength: Int
    private let requiresUppercase: Bool
    private let requiresNumbers: Bool
    private let requiresSpecialCharacters: Bool

    public init(minLength: Int = 8, requiresUppercase: Bool = true, requiresNumbers: Bool = true, requiresSpecialCharacters: Bool = true) {
        self.minLength = minLength
        self.requiresUppercase = requiresUppercase
        self.requiresNumbers = requiresNumbers
        self.requiresSpecialCharacters = requiresSpecialCharacters
    }

    public func validate(_ value: String) throws {
        if value.count < minLength {
            throw ValidationError.custom("Password must be at least \(minLength) characters")
        }

        if requiresUppercase && !value.contains(where: { $0.isUppercase }) {
            throw ValidationError.custom("Password must contain at least one uppercase letter")
        }

        if requiresNumbers && !value.contains(where: { $0.isNumber }) {
            throw ValidationError.custom("Password must contain at least one number")
        }

        if requiresSpecialCharacters {
            let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
            if value.rangeOfCharacter(from: specialCharacters) == nil {
                throw ValidationError.custom("Password must contain at least one special character")
            }
        }
    }
}

public struct AuthenticationUseCase: UseCase {
    public struct Input {
        let email: String
        let password: String
    }

    public struct Output {
        let userId: String
        let token: String
        let refreshToken: String
    }

    private let emailValidator = EmailValidator()
    private let passwordValidator = PasswordValidator()

    public func execute(_ input: Input) async throws -> Output {
        try emailValidator.validate(input.email)
        try passwordValidator.validate(input.password)

        // Simulate authentication logic
        let userId = UUID().uuidString
        let token = generateToken()
        let refreshToken = generateToken()

        return Output(userId: userId, token: token, refreshToken: refreshToken)
    }

    private func generateToken() -> String {
        return UUID().uuidString + UUID().uuidString
    }
}

public struct CreateUserUseCase: UseCase {
    public struct Input {
        let email: String
        let password: String
        let firstName: String
        let lastName: String
    }

    public struct Output {
        let userId: String
        let createdAt: Date
    }

    private let emailValidator = EmailValidator()
    private let passwordValidator = PasswordValidator()

    public func execute(_ input: Input) async throws -> Output {
        try emailValidator.validate(input.email)
        try passwordValidator.validate(input.password)

        if input.firstName.isEmpty {
            throw ValidationError.missingRequiredField("firstName")
        }

        if input.lastName.isEmpty {
            throw ValidationError.missingRequiredField("lastName")
        }

        let userId = UUID().uuidString
        let createdAt = Date()

        return Output(userId: userId, createdAt: createdAt)
    }
}

public class BusinessRulesEngine {
    private var rules: [String: (Any) -> Bool] = [:]

    public func addRule(name: String, rule: @escaping (Any) -> Bool) {
        rules[name] = rule
    }

    public func evaluate(_ context: Any) -> [String: Bool] {
        var results: [String: Bool] = [:]
        for (name, rule) in rules {
            results[name] = rule(context)
        }
        return results
    }

    public func evaluateAll(_ context: Any) -> Bool {
        return rules.values.allSatisfy { $0(context) }
    }

    public func evaluateAny(_ context: Any) -> Bool {
        return rules.values.contains { $0(context) }
    }
}

public protocol EventHandler {
    associatedtype Event
    func handle(_ event: Event) async throws
}

public class EventBus {
    private var handlers: [String: [(Any) async throws -> Void]] = [:]
    private let queue = DispatchQueue(label: "com.fiftyfour.eventbus")

    public func register<E>(eventType: E.Type, handler: @escaping (E) async throws -> Void) {
        let key = String(describing: eventType)
        queue.sync {
            if handlers[key] == nil {
                handlers[key] = []
            }
            handlers[key]?.append { event in
                if let typedEvent = event as? E {
                    try await handler(typedEvent)
                }
            }
        }
    }

    public func publish<E>(_ event: E) async throws {
        let key = String(describing: type(of: event))
        let eventHandlers = queue.sync { handlers[key] ?? [] }

        for handler in eventHandlers {
            try await handler(event)
        }
    }
}

public struct PaginationInfo {
    public let page: Int
    public let pageSize: Int
    public let total: Int
    public let totalPages: Int

    public init(page: Int, pageSize: Int, total: Int) {
        self.page = page
        self.pageSize = pageSize
        self.total = total
        self.totalPages = Int(ceil(Double(total) / Double(pageSize)))
    }

    public var hasNextPage: Bool {
        return page < totalPages
    }

    public var hasPreviousPage: Bool {
        return page > 1
    }
}

public struct PaginatedResult<T> {
    public let items: [T]
    public let pagination: PaginationInfo

    public init(items: [T], pagination: PaginationInfo) {
        self.items = items
        self.pagination = pagination
    }
}

public class PaginationHelper {
    public static func paginate<T>(_ items: [T], page: Int, pageSize: Int) -> PaginatedResult<T> {
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, items.count)

        let paginatedItems = startIndex < items.count
            ? Array(items[startIndex..<endIndex])
            : []

        let pagination = PaginationInfo(page: page, pageSize: pageSize, total: items.count)
        return PaginatedResult(items: paginatedItems, pagination: pagination)
    }
}

public protocol Middleware {
    func process<T>(_ input: T, next: (T) async throws -> T) async throws -> T
}

public class MiddlewarePipeline<T> {
    private var middlewares: [Middleware] = []

    public func add(_ middleware: Middleware) {
        middlewares.append(middleware)
    }

    public func execute(_ input: T, final: @escaping (T) async throws -> T) async throws -> T {
        var index = 0

        func next(_ value: T) async throws -> T {
            if index < middlewares.count {
                let middleware = middlewares[index]
                index += 1
                return try await middleware.process(value) { try await next($0) }
            } else {
                return try await final(value)
            }
        }

        return try await next(input)
    }
}

public class LoggingMiddleware: Middleware {
    public func process<T>(_ input: T, next: (T) async throws -> T) async throws -> T {
        print("Processing: \(input)")
        let result = try await next(input)
        print("Result: \(result)")
        return result
    }
}

public class TimingMiddleware: Middleware {
    public func process<T>(_ input: T, next: (T) async throws -> T) async throws -> T {
        let start = Date()
        let result = try await next(input)
        let duration = Date().timeIntervalSince(start)
        print("Execution time: \(duration)s")
        return result
    }
}
