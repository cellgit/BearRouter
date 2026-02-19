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

/// Workaround for SwiftUI framework bug:
///
/// `matchedTransitionSource` internally sets the source view's opacity to 0
/// during a zoom transition. When the user returns via the **system back
/// button** the opacity is correctly restored to 1. However, when the user
/// returns via an **interactive gesture** (edge swipe / vertical drag), the
/// opacity sometimes gets stuck at 0, making the source view invisible.
///
/// The fix: when the source view disappears (navigation push), we set
/// `isActive = false`. When it reappears (navigation pop), SwiftUI renders
/// the view **without** `matchedTransitionSource` for one frame (clearing
/// the stuck opacity), then `onAppear` re-enables it asynchronously with a
/// fresh registration. `.transition(.identity)` ensures no visual flicker
/// during the branch switch.
///
/// > Note: This approach does NOT use `.id()` — that would break `ForEach`
/// > by collapsing all items into one.

private struct BearTransitionSourceModifier<ID: Hashable>: ViewModifier {
    let id: ID
    @Environment(\.bearTransitionNamespace) private var namespace

    /// When `true` the `matchedTransitionSource` modifier is applied.
    /// Toggling off → on forces SwiftUI to destroy the old registration
    /// (with stuck opacity) and create a fresh one.
    @State private var isActive = true

    func body(content: Content) -> some View {
        if let namespace {
            if isActive {
                content
                    .matchedTransitionSource(id: id, in: namespace)
                    .transition(.identity)
                    .onDisappear { isActive = false }
            } else {
                content
                    .transition(.identity)
                    .onAppear {
                        // Re-register on the next run-loop tick so SwiftUI
                        // fully tears down the old (stuck) registration first.
                        DispatchQueue.main.async { isActive = true }
                    }
            }
        } else {
            content
        }
    }
}

private struct BearTransitionSourceConfiguredModifier<ID: Hashable, Config: MatchedTransitionSourceConfiguration>: ViewModifier {
    let id: ID
    let configuration: (EmptyMatchedTransitionSourceConfiguration) -> Config
    @Environment(\.bearTransitionNamespace) private var namespace

    @State private var isActive = true

    func body(content: Content) -> some View {
        if let namespace {
            if isActive {
                content
                    .matchedTransitionSource(id: id, in: namespace, configuration: configuration)
                    .transition(.identity)
                    .onDisappear { isActive = false }
            } else {
                content
                    .transition(.identity)
                    .onAppear {
                        DispatchQueue.main.async { isActive = true }
                    }
                }
        } else {
            content
        }
    }
}
