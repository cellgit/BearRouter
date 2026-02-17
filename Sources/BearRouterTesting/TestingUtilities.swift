import Foundation
import BearRouterCore

public struct MockNavigationGuard<Route: Hashable & Sendable> {
    private let decision: @Sendable ([String], GuardContext<Route>) async -> GuardDecision<Route>

    public init(_ decision: @escaping @Sendable ([String], GuardContext<Route>) async -> GuardDecision<Route>) {
        self.decision = decision
    }

    public func asGuard() -> NavigationGuard<Route> {
        NavigationGuard(decision)
    }

    public static func allow() -> NavigationGuard<Route> {
        .allowAll
    }
}

public actor InMemoryNavigationPersistence: NavigationPersistence {
    private var storage: [String: Data] = [:]

    public init() {}

    public func loadData(for key: String) async throws -> Data? {
        storage[key]
    }

    public func saveData(_ data: Data, for key: String) async throws {
        storage[key] = data
    }
}

/// Collects navigation log events for test assertions.
///
/// Thread-safe: uses `NSLock` to protect the internal events array.
public final class TestNavigationLogger<Route: Hashable & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [NavigationLogEvent<Route>] = []

    public var events: [NavigationLogEvent<Route>] {
        lock.withLock { _events }
    }

    public init() {}

    public func logger() -> NavigationLogger<Route> {
        NavigationLogger { [weak self] event in
            guard let self else { return }
            self.lock.withLock { self._events.append(event) }
        }
    }
}
