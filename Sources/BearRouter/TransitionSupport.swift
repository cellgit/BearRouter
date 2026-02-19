import SwiftUI
import BearRouterCore

// MARK: - BearTransitionStyle

/// Defines the navigation transition animation style for route destinations.
///
/// BearRouter supports two primary interactive dismiss patterns:
///
/// | Style        | Animation                  | Interactive Dismiss Gesture              |
/// |--------------|----------------------------|------------------------------------------|
/// | `.slide`     | Horizontal slide (default) | ← Left-to-right edge swipe (back)        |
/// | `.zoom`      | Zoom from source view      | ↓ Top-to-bottom swipe + edge swipe back  |
/// | `.automatic` | System-chosen              | Depends on context                        |
///
/// ## Usage
///
/// Configure per-route transition styles when creating a Host view:
///
/// ```swift
/// StackNavigationHost(
///     navigator: navigator,
///     transitionStyle: { route in
///         switch route {
///         case .detail: .zoom
///         default: .slide
///         }
///     }
/// ) {
///     ListView()
/// } destination: { route in
///     DetailView(route: route)
/// }
/// ```
///
/// Mark source views for zoom transitions:
///
/// ```swift
/// ItemCell(item: item)
///     .bearTransitionSource(id: Route.detail(item.id))
/// ```
public enum BearTransitionStyle: Sendable, Hashable {

    /// Standard horizontal slide transition.
    ///
    /// Interactive dismiss: **left-to-right edge swipe** (standard navigation
    /// back gesture). This is the default `NavigationStack` push/pop animation.
    case slide

    /// Zoom transition from a matched source view.
    ///
    /// Interactive dismiss: **top-to-bottom swipe** (vertical drag dismiss)
    /// *and* the standard left-to-right edge swipe.
    ///
    /// > Important: The source view **must** be marked with
    /// > `.bearTransitionSource(id:)` using the same route value as the
    /// > pushed/presented destination.
    case zoom

    /// Let SwiftUI choose the most appropriate transition for the context.
    ///
    /// For push navigation this behaves identically to ``slide``.
    case automatic
}

// MARK: - Environment: Transition Namespace

private struct BearTransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

public extension EnvironmentValues {
    /// The shared namespace used by BearRouter's matched transition system.
    ///
    /// Automatically injected by ``StackNavigationHost``,
    /// ``TabNavigationHost``, and ``SplitNavigationHost`` into their root
    /// content. You normally don't need to set this yourself.
    var bearTransitionNamespace: Namespace.ID? {
        get { self[BearTransitionNamespaceKey.self] }
        set { self[BearTransitionNamespaceKey.self] = newValue }
    }
}

// MARK: - Source View Modifiers

public extension View {

    /// Marks this view as the **source** of a BearRouter zoom transition.
    ///
    /// The `@Namespace` is automatically obtained from the environment
    /// (injected by the enclosing Host view), so you never need to declare
    /// or pass a namespace yourself.
    ///
    /// ```swift
    /// ForEach(items) { item in
    ///     ItemCell(item: item)
    ///         .bearTransitionSource(id: Route.detail(item.id))
    /// }
    /// ```
    ///
    /// - Parameter id: A `Hashable` identifier — typically the `Route` enum
    ///   value that corresponds to the destination this view transitions to.
    func bearTransitionSource<ID: Hashable>(id: ID) -> some View {
        modifier(BearTransitionSourceModifier(id: id))
    }

    /// Marks this view as the **source** of a BearRouter zoom transition
    /// with a custom source appearance configuration.
    ///
    /// ```swift
    /// ImageView(item: item)
    ///     .bearTransitionSource(id: Route.detail(item.id)) { config in
    ///         config
    ///             .clipShape(RoundedRectangle(cornerRadius: 16))
    ///             .shadow(radius: 8)
    ///     }
    /// ```
    ///
    /// - Parameters:
    ///   - id: A `Hashable` identifier for the transition source.
    ///   - configuration: A closure that customises the source appearance
    ///     during the transition animation.
    func bearTransitionSource<ID: Hashable>(
        id: ID,
        configuration: @escaping (EmptyMatchedTransitionSourceConfiguration) -> some MatchedTransitionSourceConfiguration
    ) -> some View {
        modifier(BearTransitionSourceConfiguredModifier(id: id, configuration: configuration))
    }
}

// MARK: - Private Modifier Implementations

private struct BearTransitionSourceModifier<ID: Hashable>: ViewModifier {
    let id: ID
    @Environment(\.bearTransitionNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content
                .matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct BearTransitionSourceConfiguredModifier<ID: Hashable, Config: MatchedTransitionSourceConfiguration>: ViewModifier {
    let id: ID
    let configuration: (EmptyMatchedTransitionSourceConfiguration) -> Config
    @Environment(\.bearTransitionNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content
                .matchedTransitionSource(id: id, in: namespace, configuration: configuration)
        } else {
            content
        }
    }
}
