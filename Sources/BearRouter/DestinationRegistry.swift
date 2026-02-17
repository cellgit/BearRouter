import SwiftUI
import BearRouterCore

/// Optional convenience registry for modular apps that register destinations
/// from multiple feature modules.
///
/// > **Preferred pattern**: Pass a `@ViewBuilder` destination closure directly
/// > to the Host views — this avoids `AnyView` and preserves SwiftUI's diff
/// > performance. Only use `DestinationRegistry` when you need runtime
/// > registration from separate modules.
///
/// ```swift
/// let registry = DestinationRegistry<Route>()
/// registry.register { route in
///     switch route {
///     case .home: HomeView()
///     case .detail(let id): DetailView(id: id)
///     }
/// }
/// ```
@MainActor
public final class DestinationRegistry<Route: Hashable & Sendable> {
    public typealias Builder = @MainActor (Route) -> AnyView

    private var builder: Builder?
    private let fallback: Builder

    public init(fallback: @escaping Builder = { _ in AnyView(EmptyView()) }) {
        self.fallback = fallback
    }

    /// Register a view builder for all routes.
    public func register(builder: @escaping @MainActor (Route) -> some View) {
        self.builder = { route in AnyView(builder(route)) }
    }

    /// Resolve the view for a given route.
    public func view(for route: Route) -> AnyView {
        (builder ?? fallback)(route)
    }
}
