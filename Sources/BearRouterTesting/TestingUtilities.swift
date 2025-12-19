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

public final class TestNavigationLogger<Route: Hashable & Sendable>: @unchecked Sendable {
    public private(set) var events: [NavigationLogEvent<Route>] = []

    public init() {}

    public func logger() -> NavigationLogger<Route> {
        NavigationLogger { [weak self] event in
            self?.events.append(event)
        }
    }
}
