import Foundation
import SwiftUI
import BearRouterCore

// MARK: - IntentRouterProtocol

/// Maps an intent (deep-link, user action, etc.) to navigation actions.
public protocol IntentRouterProtocol<Intent, Route> {
    associatedtype Intent
    associatedtype Route: Hashable & Sendable
    func route(_ intent: Intent) -> [NavigationAction<Route>]
}

// MARK: - AnyIntentRouter

/// Type-erased wrapper for ``IntentRouterProtocol``.
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

// MARK: - IntentDispatcher

/// A typed dispatcher that sends intents asynchronously or synchronously.
public struct IntentDispatcher<Intent>: @unchecked Sendable {
    private let asyncHandler: (Intent) async -> Void
    private let syncHandler: (Intent) -> Void

    public init(async handler: @escaping (Intent) async -> Void, sync: @escaping (Intent) -> Void = { _ in }) {
        self.asyncHandler = handler
        self.syncHandler = sync
    }

    public func send(_ intent: Intent) async {
        await asyncHandler(intent)
    }

    public func sendSync(_ intent: Intent) {
        syncHandler(intent)
    }
}

// MARK: - IntentNavigator (was BearRouterigator)

/// Bridges an ``IntentRouterProtocol`` to a ``Navigator``,
/// translating intents into navigation actions.
///
/// ```swift
/// let intentNav = IntentNavigator(navigator: navigator, router: AnyIntentRouter(MyRouter()))
/// await intentNav.send(.showDetail(id: 42))
/// ```
@MainActor
public struct IntentNavigator<Intent, Route: Hashable & Sendable> {
    public let navigator: Navigator<Route>
    private let router: AnyIntentRouter<Intent, Route>

    public init(navigator: Navigator<Route>, router: AnyIntentRouter<Intent, Route>) {
        self.navigator = navigator
        self.router = router
    }

    public init<R: IntentRouterProtocol>(navigator: Navigator<Route>, router: R) where R.Intent == Intent, R.Route == Route {
        self.navigator = navigator
        self.router = AnyIntentRouter(router)
    }

    public func send(_ intent: Intent) async {
        let actions = router.route(intent)
        for action in actions {
            await navigator.handle(action)
        }
    }

    public func sendSync(_ intent: Intent) {
        Task { @MainActor in await send(intent) }
    }

    public func makeDispatcher() -> IntentDispatcher<Intent> {
        IntentDispatcher(
            async: { intent in await send(intent) },
            sync: { intent in Task { @MainActor in await send(intent) } }
        )
    }
}

// MARK: - TabIntentNavigator (was TabBearRouterigator)

/// Bridges an ``IntentRouterProtocol`` to a ``TabNavigator``.
@MainActor
public struct TabIntentNavigator<Intent, TabID: Hashable & Sendable, Route: Hashable & Sendable> {
    public let navigator: TabNavigator<TabID, Route>
    private let router: AnyIntentRouter<Intent, Route>

    public init(navigator: TabNavigator<TabID, Route>, router: AnyIntentRouter<Intent, Route>) {
        self.navigator = navigator
        self.router = router
    }

    public init<R: IntentRouterProtocol>(navigator: TabNavigator<TabID, Route>, router: R) where R.Intent == Intent, R.Route == Route {
        self.navigator = navigator
        self.router = AnyIntentRouter(router)
    }

    public func send(_ intent: Intent, tabID: TabID? = nil) async {
        guard let targetTab = tabID ?? navigator.state.selectedTab ?? navigator.state.perTab.keys.first else { return }
        let actions = router.route(intent)
        for action in actions {
            await navigator.handle(.navigate(tab: targetTab, action: action))
        }
    }

    public func sendSync(_ intent: Intent, tabID: TabID? = nil) {
        Task { @MainActor in await send(intent, tabID: tabID) }
    }

    public func makeDispatcher(defaultTab: TabID? = nil) -> IntentDispatcher<Intent> {
        IntentDispatcher(
            async: { intent in await send(intent, tabID: defaultTab) },
            sync: { intent in Task { @MainActor in await send(intent, tabID: defaultTab) } }
        )
    }
}

// MARK: - SplitIntentNavigator (was SplitBearRouterigator)

/// Bridges an ``IntentRouterProtocol`` to a ``SplitNavigator``.
@MainActor
public struct SplitIntentNavigator<Intent, Selection: Hashable & Sendable, Route: Hashable & Sendable> {
    public let navigator: SplitNavigator<Selection, Route>
    private let router: AnyIntentRouter<Intent, Route>

    public init(navigator: SplitNavigator<Selection, Route>, router: AnyIntentRouter<Intent, Route>) {
        self.navigator = navigator
        self.router = router
    }

    public init<R: IntentRouterProtocol>(navigator: SplitNavigator<Selection, Route>, router: R) where R.Intent == Intent, R.Route == Route {
        self.navigator = navigator
        self.router = AnyIntentRouter(router)
    }

    public func send(_ intent: Intent) async {
        let actions = router.route(intent)
        for action in actions {
            await navigator.handle(.navigateDetail(action))
        }
    }

    public func sendSync(_ intent: Intent) {
        Task { @MainActor in await send(intent) }
    }

    public func makeDispatcher() -> IntentDispatcher<Intent> {
        IntentDispatcher(
            async: { intent in await send(intent) },
            sync: { intent in Task { @MainActor in await send(intent) } }
        )
    }
}

// MARK: - Environment injection helpers
//
// Swift EnvironmentKey doesn't support generic type parameters.
// Create a concrete EnvironmentKey for your intent type:
//
// ```swift
// struct MyDispatcherKey: EnvironmentKey {
//     static let defaultValue: IntentDispatcher<MyIntent>? = nil
// }
// extension EnvironmentValues {
//     var myDispatcher: IntentDispatcher<MyIntent>? {
//         get { self[MyDispatcherKey.self] }
//         set { self[MyDispatcherKey.self] = newValue }
//     }
// }
// ```
