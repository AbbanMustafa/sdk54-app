import Foundation

public protocol Container {
    associatedtype Item
    var count: Int { get }
    mutating func append(_ item: Item)
    subscript(index: Int) -> Item { get }
}

public protocol Transformable {
    associatedtype Input
    associatedtype Output
    func transform(_ input: Input) -> Output
}

public protocol Combinable {
    static func combine(_ lhs: Self, _ rhs: Self) -> Self
}

public struct GenericContainer<T>: Container {
    public typealias Item = T
    private var items: [T] = []

    public var count: Int {
        return items.count
    }

    public init() {}

    public mutating func append(_ item: T) {
        items.append(item)
    }

    public subscript(index: Int) -> T {
        return items[index]
    }

    public func map<U>(_ transform: (T) -> U) -> GenericContainer<U> {
        var result = GenericContainer<U>()
        for item in items {
            result.append(transform(item))
        }
        return result
    }

    public func filter(_ predicate: (T) -> Bool) -> GenericContainer<T> {
        var result = GenericContainer<T>()
        for item in items where predicate(item) {
            result.append(item)
        }
        return result
    }

    public func reduce<U>(_ initialValue: U, _ combine: (U, T) -> U) -> U {
        var result = initialValue
        for item in items {
            result = combine(result, item)
        }
        return result
    }
}

public class TransformerChain<A, B, C>: Transformable {
    public typealias Input = A
    public typealias Output = C

    private let firstTransform: (A) -> B
    private let secondTransform: (B) -> C

    public init(first: @escaping (A) -> B, second: @escaping (B) -> C) {
        self.firstTransform = first
        self.secondTransform = second
    }

    public func transform(_ input: A) -> C {
        let intermediate = firstTransform(input)
        return secondTransform(intermediate)
    }

    public func compose<D>(with next: @escaping (C) -> D) -> TransformerChain<A, C, D> {
        return TransformerChain<A, C, D>(
            first: transform,
            second: next
        )
    }
}

public struct AsyncOperation<Input, Output> {
    private let operation: (Input, @escaping (Result<Output, Error>) -> Void) -> Void

    public init(operation: @escaping (Input, @escaping (Result<Output, Error>) -> Void) -> Void) {
        self.operation = operation
    }

    public func execute(with input: Input, completion: @escaping (Result<Output, Error>) -> Void) {
        operation(input, completion)
    }

    public func then<NewOutput>(
        _ next: @escaping (Output, @escaping (Result<NewOutput, Error>) -> Void) -> Void
    ) -> AsyncOperation<Input, NewOutput> {
        return AsyncOperation<Input, NewOutput> { input, completion in
            self.execute(with: input) { result in
                switch result {
                case .success(let output):
                    next(output, completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}

public protocol Repository {
    associatedtype Entity
    associatedtype ID

    func save(_ entity: Entity) throws
    func find(by id: ID) throws -> Entity?
    func findAll() throws -> [Entity]
    func delete(by id: ID) throws
}

public class GenericRepository<T: Codable, ID: Hashable>: Repository {
    public typealias Entity = T
    private var storage: [ID: T] = [:]
    private let lock = NSLock()

    public init() {}

    public func save(_ entity: T) throws {
        lock.lock()
        defer { lock.unlock() }
        // Would need ID extraction logic in real implementation
    }

    public func find(by id: ID) throws -> T? {
        lock.lock()
        defer { lock.unlock() }
        return storage[id]
    }

    public func findAll() throws -> [T] {
        lock.lock()
        defer { lock.unlock() }
        return Array(storage.values)
    }

    public func delete(by id: ID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: id)
    }
}

public struct Either<Left, Right> {
    private enum Value {
        case left(Left)
        case right(Right)
    }

    private let value: Value

    private init(_ value: Value) {
        self.value = value
    }

    public static func left(_ left: Left) -> Either<Left, Right> {
        return Either(.left(left))
    }

    public static func right(_ right: Right) -> Either<Left, Right> {
        return Either(.right(right))
    }

    public func fold<T>(onLeft: (Left) -> T, onRight: (Right) -> T) -> T {
        switch value {
        case .left(let left):
            return onLeft(left)
        case .right(let right):
            return onRight(right)
        }
    }

    public func map<T>(_ transform: (Right) -> T) -> Either<Left, T> {
        switch value {
        case .left(let left):
            return .left(left)
        case .right(let right):
            return .right(transform(right))
        }
    }

    public func flatMap<T>(_ transform: (Right) -> Either<Left, T>) -> Either<Left, T> {
        switch value {
        case .left(let left):
            return .left(left)
        case .right(let right):
            return transform(right)
        }
    }
}

public struct Observable<T> {
    private var observers: [(T) -> Void] = []
    private var value: T

    public init(value: T) {
        self.value = value
    }

    public mutating func subscribe(_ observer: @escaping (T) -> Void) {
        observers.append(observer)
        observer(value)
    }

    public mutating func update(_ newValue: T) {
        value = newValue
        observers.forEach { $0(newValue) }
    }

    public func map<U>(_ transform: @escaping (T) -> U) -> Observable<U> {
        return Observable<U>(value: transform(value))
    }
}

public class StateMachine<State: Hashable, Event> {
    private var currentState: State
    private var transitions: [State: [Event: State]] = [:]
    private var observers: [(State) -> Void] = []

    public init(initialState: State) {
        self.currentState = initialState
    }

    public func addTransition(from: State, on event: Event, to: State) {
        if transitions[from] == nil {
            transitions[from] = [:]
        }
        transitions[from]?[event] = to
    }

    public func send(_ event: Event) -> Bool {
        guard let nextState = transitions[currentState]?[event] else {
            return false
        }
        currentState = nextState
        observers.forEach { $0(currentState) }
        return true
    }

    public func observe(_ observer: @escaping (State) -> Void) {
        observers.append(observer)
        observer(currentState)
    }
}

public protocol Monoid {
    static var empty: Self { get }
    static func combine(_ lhs: Self, _ rhs: Self) -> Self
}

extension String: Monoid {
    public static var empty: String { "" }
    public static func combine(_ lhs: String, _ rhs: String) -> String {
        return lhs + rhs
    }
}

extension Array: Monoid {
    public static var empty: Array { [] }
    public static func combine(_ lhs: Array, _ rhs: Array) -> Array {
        return lhs + rhs
    }
}

public func reduce<M: Monoid>(_ values: [M]) -> M {
    return values.reduce(M.empty, M.combine)
}
