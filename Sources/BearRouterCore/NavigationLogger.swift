import Foundation

public struct NavigationLogEvent<Route: Hashable & Sendable>: Sendable {
    public let sceneID: String?
    public let actionDescription: String
    public let state: NavigationState<Route>

    public init(sceneID: String?, actionDescription: String, state: NavigationState<Route>) {
        self.sceneID = sceneID
        self.actionDescription = actionDescription
        self.state = state
    }
}

public struct NavigationLogger<Route: Hashable & Sendable>: Sendable {
    private let handler: @Sendable (NavigationLogEvent<Route>) -> Void

    public init(_ handler: @escaping @Sendable (NavigationLogEvent<Route>) -> Void) {
        self.handler = handler
    }

    public func log(_ event: NavigationLogEvent<Route>) {
        handler(event)
    }
}

public extension NavigationLogger {
    static var console: NavigationLogger<Route> {
        NavigationLogger { event in
            let sceneText = event.sceneID.map { "[scene:\($0)] " } ?? ""
            print("BearRouter: \(sceneText)\(event.actionDescription) -> path:\(event.state.path) sheet:\(String(describing: event.state.sheet)) fullScreen:\(String(describing: event.state.fullScreen))")
        }
    }

    static var noOp: NavigationLogger<Route> {
        NavigationLogger { _ in }
    }
}

public typealias ConsoleLogger<Route: Hashable & Sendable> = NavigationLogger<Route>
public typealias NoOpLogger<Route: Hashable & Sendable> = NavigationLogger<Route>
