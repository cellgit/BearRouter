# BearRouter

A low-boilerplate, strongly typed navigation toolkit for SwiftUI. BearRouter ships with a pure Swift core (state, actions, guard/logger, snapshots), SwiftUI hosts, and testing helpers. Define your route, register destinations, pick a host (Stack/Tab/Split), and you are ready to navigate.

## Quick start (3 steps)
```swift
import BearRouter
import BearRouterCore

// 1) Route
enum Route: Hashable, Sendable, Codable { case home, detail(id: Int) }

// 2) Destinations (fallback prevents blank screens)
let registry = DestinationRegistry<Route> { _ in AnyView(Text("Missing route")) }
registry.register(Route.self) { route in
    switch route {
    case .home: HomeView()
    case .detail(let id): DetailView(id: id)
    }
}

// 3) Host
let navigator = Navigator<Route>(sceneID: "main")
StackNavigationHost(navigator: navigator, registry: registry) {
    HomeView()
}

// Navigate
Task { await navigator.handle(.push(.detail(id: 42))) }
```

## Platform support
- iOS 18+, macOS 15+, tvOS 18+, watchOS 11+, visionOS 2+.
- `SplitNavigationHost` is available on iOS/macOS/visionOS only.

## Targets
- `BearRouterCore`: pure Swift state machines (`Navigator`, `TabNavigator`, `SplitNavigator`), actions, guard/logger, snapshots & persistence helpers.
- `BearRouter`: SwiftUI integration (`DestinationRegistry`, stack/tab/split hosts, `NavigationPathAdapter`, intent dispatchers).
- `BearRouterTesting`: mock guard/logger and in-memory persistence helpers.

## Core concepts
- **NavigationState/TabState/SplitState** capture stack + modal state (sheet/fullScreen), tab selection, and split selection.
- **NavigationAction**: push/pop/popToRoot/replaceStack/present+dismiss sheet/fullScreen/dismissAll/batch.
- **Guard & Logger**: plug `NavigationGuard` for auth/permission checks and `NavigationLogger` (`console`/`noOp` or custom) with optional `sceneID` tagging.
- **Snapshots**: `NavigationSnapshot`, `TabSnapshot`, and `SplitSnapshot` are `Codable` when Route/Tab/Selection are `Codable`; persist via `NavigationPersistence`.
- **String compatibility**: `SelectionTranslator` turns legacy string tab/selection IDs into strong types (works with `TabNavigationAction.selectTab(string:using:)`).

## SwiftUI hosts
- `StackNavigationHost`: typed `[Route]` binding; modal via `sheet` and `fullScreenCover`.
- `TabNavigationHost`: one `NavigationStack` per tab with its own modal state.
- `SplitNavigationHost`: `NavigationSplitView` + detail stack (iOS/macOS/visionOS only).
- `NavigationPathAdapter`: bridge strong routes to `NavigationPath`; use `PathStackNavigationHost` or `withNavigationPath` for `NavigationPath`-driven stacks.

## Intent layer
Transform app intents into navigation actions without leaking UI concerns:
```swift
struct AppIntentRouter: IntentRouterProtocol {
    func route(_ intent: AppIntent) -> [NavigationAction<AppRoute>] {
        switch intent {
        case .openDetail(let id): return [.push(.detail(id: id))]
        case .logout: return [.dismissAll]
        }
    }
}

let routerigator = BearRouterigator(navigator: navigator, router: AppIntentRouter())
let dispatcher = routerigator.makeDispatcher() // async send
```
Inject into SwiftUI with `.intentDispatcher(AnyIntentDispatcher(dispatcher))` and read via `@Environment(\.intentDispatcher)`.

## Migration notes
- `BearRouterOS26` was removed; use `StackNavigationHost`, `TabNavigationHost`, or `SplitNavigationHost` directly.
- Minimum OS versions were raised to the latest platform baselines listed above.
- `BearRouterigator`, `TabBearRouterigator`, and `SplitBearRouterigator` are `@MainActor`-isolated; call them on the main actor.
- Keep routes/tab IDs/selection types `Hashable & Sendable`; add `Codable` if you need snapshots.
- For legacy string-based tabs or split selection, use `SelectionTranslator.rawValue` (for `RawRepresentable<String>`) or custom parse/stringify closures.
- Prefer setting a non-crashing fallback view in `DestinationRegistry`; switch to `fatalError` during development if you want strict registration.

## Testing helpers
- `MockNavigationGuard` to stub guard decisions.
- `InMemoryNavigationPersistence` for snapshot persistence in tests.
- `TestNavigationLogger` captures emitted log events.
