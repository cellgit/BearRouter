import Foundation

public struct GuardContext<Route: Hashable & Sendable>: Sendable {
    public let state: NavigationState<Route>
    public let sceneID: String?

    public init(state: NavigationState<Route>, sceneID: String?) {
        self.state = state
        self.sceneID = sceneID
    }
}

public enum GuardDecision<Route: Hashable & Sendable>: Sendable {
    case allow
    case deny(reason: String)
    case redirect(path: [Route], replay: Bool)
}

public struct NavigationGuard<Route: Hashable & Sendable>: Sendable {
    private let evaluator: @Sendable ([String], GuardContext<Route>) async -> GuardDecision<Route>

    public init(_ evaluator: @escaping @Sendable ([String], GuardContext<Route>) async -> GuardDecision<Route>) {
        self.evaluator = evaluator
    }

    public func evaluate(actionDescriptions: [String], context: GuardContext<Route>) async -> GuardDecision<Route> {
        await evaluator(actionDescriptions, context)
    }

    public static var allowAll: NavigationGuard<Route> {
        NavigationGuard { _, _ in .allow }
    }
}
