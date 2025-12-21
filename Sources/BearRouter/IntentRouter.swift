import Foundation
import SwiftUI
import BearRouterCore

public protocol IntentRouterProtocol<Intent, Route> {
    associatedtype Intent
    associatedtype Route: Hashable & Sendable
    func route(_ intent: Intent) -> [NavigationAction<Route>]
}

public struct AnyIntentRouter<Intent, Route: Hashable & Sendable>: IntentRouterProtocol {
    private let handler: (Intent) -> [NavigationAction<Route>]

    public init(_ handler: @escaping (Intent) -> [NavigationAction<Route>]) {
        self.handler = handler
    }

    public init<R: IntentRouterProtocol>(_ router: R) where R.Intent == Intent, R.Route == Route {
        self.handler = router.route
    }

    public func route(_ intent: Intent) -> [NavigationAction<Route>] {
        handler(intent)
    }
}

public struct IntentDispatcher<Intent>: @unchecked Sendable {
    private let asyncHandler: (Intent) async -> Void
    private let syncHandler: (Intent) -> Void

    public init(async: @escaping (Intent) async -> Void, sync: @escaping (Intent) -> Void = { _ in }) {
        self.asyncHandler = async
        self.syncHandler = sync
    }

    public func send(_ intent: Intent) async {
        await asyncHandler(intent)
    }

    public func sendSync(_ intent: Intent) {
        syncHandler(intent)
    }
}

public struct AnyIntentDispatcher: @unchecked Sendable {
    private let asyncHandler: (Any) async -> Void
    private let syncHandler: (Any) -> Void

    public init(async: @escaping (Any) async -> Void, sync: @escaping (Any) -> Void = { _ in }) {
        self.asyncHandler = async
        self.syncHandler = sync
    }

    public init<Intent>(_ dispatcher: IntentDispatcher<Intent>) {
        self.asyncHandler = { anyIntent in
            guard let intent = anyIntent as? Intent else { return }
            await dispatcher.send(intent)
        }
        self.syncHandler = { anyIntent in
            guard let intent = anyIntent as? Intent else { return }
            dispatcher.sendSync(intent)
        }
    }

    public func send(_ intent: Any) async {
        await asyncHandler(intent)
    }

    public func sendSync(_ intent: Any) {
        syncHandler(intent)
    }

    public func typed<Intent>(as type: Intent.Type = Intent.self) -> IntentDispatcher<Intent> {
        IntentDispatcher<Intent>(
            async: { intent in await asyncHandler(intent) },
            sync: { intent in syncHandler(intent) }
        )
    }
}

@MainActor
public struct BearRouterigator<Intent, Route: Hashable & Sendable> {
    @MainActor public let navigator: Navigator<Route>
    private let router: AnyIntentRouter<Intent, Route>

    public init(navigator: Navigator<Route>, router: AnyIntentRouter<Intent, Route>) {
        self.navigator = navigator
        self.router = router
    }

    public init<R: IntentRouterProtocol>(navigator: Navigator<Route>, router: R) where R.Intent == Intent, R.Route == Route {
        self.navigator = navigator
        self.router = AnyIntentRouter(router)
    }

    @MainActor
    public func send(_ intent: Intent) async {
        let actions = router.route(intent)
        for action in actions {
            await navigator.handle(action)
        }
    }

    public func sendSync(_ intent: Intent) {
        Task { @MainActor in
            await send(intent)
        }
    }

    public func makeDispatcher() -> IntentDispatcher<Intent> {
        IntentDispatcher(
            async: { intent in await send(intent) },
            sync: { intent in
                Task { @MainActor in
                    await send(intent)
                }
            }
        )
    }
}

@MainActor
public struct TabBearRouterigator<Intent, TabID: Hashable & Sendable, Route: Hashable & Sendable> {
    @MainActor public let navigator: TabNavigator<TabID, Route>
    private let router: AnyIntentRouter<Intent, Route>

    public init(navigator: TabNavigator<TabID, Route>, router: AnyIntentRouter<Intent, Route>) {
        self.navigator = navigator
        self.router = router
    }

    public init<R: IntentRouterProtocol>(navigator: TabNavigator<TabID, Route>, router: R) where R.Intent == Intent, R.Route == Route {
        self.navigator = navigator
        self.router = AnyIntentRouter(router)
    }

    @MainActor
    public func send(_ intent: Intent, tabID: TabID? = nil) async {
        guard let targetTab = tabID ?? navigator.state.selectedTab ?? navigator.state.perTab.keys.first else { return }
        let actions = router.route(intent)
        for action in actions {
            await navigator.handle(.navigate(tab: targetTab, action: action))
        }
    }

    public func sendSync(_ intent: Intent, tabID: TabID? = nil) {
        Task { @MainActor in
            await send(intent, tabID: tabID)
        }
    }

    public func makeDispatcher(defaultTab: TabID? = nil) -> IntentDispatcher<Intent> {
        IntentDispatcher(
            async: { intent in await send(intent, tabID: defaultTab) },
            sync: { intent in
                Task { @MainActor in
                    await send(intent, tabID: defaultTab)
                }
            }
        )
    }
}

@MainActor
public struct SplitBearRouterigator<Intent, Selection: Hashable & Sendable, Route: Hashable & Sendable> {
    @MainActor public let navigator: SplitNavigator<Selection, Route>
    private let router: AnyIntentRouter<Intent, Route>

    public init(navigator: SplitNavigator<Selection, Route>, router: AnyIntentRouter<Intent, Route>) {
        self.navigator = navigator
        self.router = router
    }

    public init<R: IntentRouterProtocol>(navigator: SplitNavigator<Selection, Route>, router: R) where R.Intent == Intent, R.Route == Route {
        self.navigator = navigator
        self.router = AnyIntentRouter(router)
    }

    @MainActor
    public func send(_ intent: Intent) async {
        let actions = router.route(intent)
        for action in actions {
            await navigator.handle(.navigateDetail(action))
        }
    }

    public func sendSync(_ intent: Intent) {
        Task { @MainActor in
            await send(intent)
        }
    }

    public func makeDispatcher() -> IntentDispatcher<Intent> {
        IntentDispatcher(
            async: { intent in await send(intent) },
            sync: { intent in
                Task { @MainActor in
                    await send(intent)
                }
            }
        )
    }
}

private struct IntentDispatcherEnvironmentKey: EnvironmentKey {
    static let defaultValue: AnyIntentDispatcher? = nil
}

public extension EnvironmentValues {
    var intentDispatcher: AnyIntentDispatcher? {
        get { self[IntentDispatcherEnvironmentKey.self] }
        set { self[IntentDispatcherEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func intentDispatcher(_ dispatcher: AnyIntentDispatcher?) -> some View {
        environment(\.intentDispatcher, dispatcher)
    }
}
