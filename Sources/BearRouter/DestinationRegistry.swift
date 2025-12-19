import SwiftUI
import BearRouterCore

public final class DestinationRegistry<Route: Hashable & Sendable>: @unchecked Sendable {
    public typealias Builder = @MainActor @Sendable (Route) -> AnyView

    private var builder: Builder?
    private let fallback: Builder

    public init(fallback: @escaping Builder = { _ in AnyView(EmptyView()) }) {
        self.fallback = fallback
    }

    public func register(_ type: Route.Type = Route.self, builder: @escaping @MainActor @Sendable (Route) -> some View) {
        self.builder = { route in AnyView(builder(route)) }
    }

    @MainActor
    public func view(for route: Route) -> AnyView {
        (builder ?? fallback)(route)
    }
}
