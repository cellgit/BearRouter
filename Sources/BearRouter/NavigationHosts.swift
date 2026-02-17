import SwiftUI
import BearRouterCore

// MARK: - Private helpers

private struct RouteItem<Route: Hashable & Sendable>: Identifiable, Equatable {
    let route: Route
    var id: AnyHashable { AnyHashable(route) }
}

// MARK: - StackNavigationHost

/// A `NavigationStack` host driven by a ``Navigator``.
///
/// **Preferred** — pass a `@ViewBuilder` destination closure directly
/// to avoid `AnyView`:
///
/// ```swift
/// StackNavigationHost(navigator: navigator) {
///     HomeView()
/// } destination: { route in
///     switch route {
///     case .home: HomeView()
///     case .detail(let id): DetailView(id: id)
///     }
/// }
/// ```
public struct StackNavigationHost<Route: Hashable & Sendable, Root: View, Destination: View>: View {
    private var navigator: Navigator<Route>
    private let root: () -> Root
    private let destination: (Route) -> Destination

    public init(
        navigator: Navigator<Route>,
        @ViewBuilder root: @escaping () -> Root,
        @ViewBuilder destination: @escaping (Route) -> Destination
    ) {
        self.navigator = navigator
        self.root = root
        self.destination = destination
    }

    public var body: some View {
        NavigationStack(path: pathBinding()) {
            root()
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
        .sheet(item: sheetBinding()) { item in
            destination(item.route)
        }
        .fullScreenCoverIfAvailable(item: fullScreenBinding()) { item in
            destination(item.route)
        }
    }

    private func pathBinding() -> Binding<[Route]> {
        Binding(
            get: { navigator.state.path },
            set: { navigator.updatePathFromUI($0) }
        )
    }

    private func sheetBinding() -> Binding<RouteItem<Route>?> {
        Binding<RouteItem<Route>?>(
            get: { navigator.state.sheet.map(RouteItem.init) },
            set: { navigator.updateSheetFromUI($0?.route) }
        )
    }

    private func fullScreenBinding() -> Binding<RouteItem<Route>?> {
        Binding<RouteItem<Route>?>(
            get: { navigator.state.fullScreen.map(RouteItem.init) },
            set: { navigator.updateFullScreenFromUI($0?.route) }
        )
    }
}

// MARK: - StackNavigationHost + DestinationRegistry convenience

public extension StackNavigationHost where Destination == AnyView {
    /// Convenience initialiser that accepts a ``DestinationRegistry``.
    ///
    /// > Note: This uses `AnyView` internally. Prefer the `@ViewBuilder`
    /// > destination overload for best performance.
    init(
        navigator: Navigator<Route>,
        registry: DestinationRegistry<Route>,
        @ViewBuilder root: @escaping () -> Root
    ) {
        self.navigator = navigator
        self.root = root
        self.destination = { route in registry.view(for: route) }
    }
}

// MARK: - AnyNavigableTab

/// Type-erased tab descriptor for ``TabNavigationHost``.
public struct AnyNavigableTab<TabID: Hashable & Sendable>: Identifiable {
    public let id: TabID
    private let labelBuilder: () -> AnyView
    private let contentBuilder: () -> AnyView

    public init(id: TabID, label: @escaping () -> AnyView, content: @escaping () -> AnyView) {
        self.id = id
        self.labelBuilder = label
        self.contentBuilder = content
    }

    public func label() -> AnyView { labelBuilder() }
    public func content() -> AnyView { contentBuilder() }
}

// MARK: - NavigableTab

/// A strongly-typed tab descriptor that can be erased to ``AnyNavigableTab``.
public struct NavigableTab<TabID: Hashable & Sendable, Label: View, Content: View>: Identifiable {
    public var id: TabID { tabID }
    public let tabID: TabID
    private let labelBuilder: () -> Label
    private let contentBuilder: () -> Content

    public init(
        tabID: TabID,
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tabID = tabID
        self.labelBuilder = label
        self.contentBuilder = content
    }

    public func eraseToAny() -> AnyNavigableTab<TabID> {
        AnyNavigableTab(id: tabID, label: { AnyView(labelBuilder()) }, content: { AnyView(contentBuilder()) })
    }
}

// MARK: - TabNavigationHost

/// A `TabView` host driven by a ``TabNavigator``.
///
/// Each tab gets its own `NavigationStack` with destinations resolved
/// by the `destination` `@ViewBuilder` closure.
public struct TabNavigationHost<TabID: Hashable & Sendable, Route: Hashable & Sendable, Destination: View>: View {
    private var navigator: TabNavigator<TabID, Route>
    private let tabs: [AnyNavigableTab<TabID>]
    private let destination: (Route) -> Destination

    public init(
        navigator: TabNavigator<TabID, Route>,
        tabs: [AnyNavigableTab<TabID>],
        @ViewBuilder destination: @escaping (Route) -> Destination
    ) {
        self.navigator = navigator
        self.tabs = tabs
        self.destination = destination
        precondition(!tabs.isEmpty, "TabNavigationHost requires at least one tab")
        if navigator.state.selectedTab == nil, let first = tabs.first?.id {
            navigator.selectTab(first)
        }
    }

    public var body: some View {
        TabView(selection: selectionBinding()) {
            ForEach(tabs) { tab in
                NavigationStack(path: pathBinding(for: tab.id)) {
                    tab.content()
                        .navigationDestination(for: Route.self) { route in
                            destination(route)
                        }
                }
                .tabItem { tab.label() }
                .tag(tab.id)
                .sheet(item: sheetBinding(for: tab.id)) { item in
                    destination(item.route)
                }
                .fullScreenCoverIfAvailable(item: fullScreenBinding(for: tab.id)) { item in
                    destination(item.route)
                }
            }
        }
    }

    private func selectionBinding() -> Binding<TabID> {
        Binding<TabID>(
            get: { navigator.state.selectedTab ?? tabs.first!.id },
            set: { navigator.selectTab($0) }
        )
    }

    private func pathBinding(for tabID: TabID) -> Binding<[Route]> {
        Binding(
            get: { navigator.state.state(for: tabID).path },
            set: { navigator.updatePathFromUI($0, tabID: tabID) }
        )
    }

    private func sheetBinding(for tabID: TabID) -> Binding<RouteItem<Route>?> {
        Binding<RouteItem<Route>?>(
            get: { navigator.state.state(for: tabID).sheet.map(RouteItem.init) },
            set: { navigator.updateSheetFromUI($0?.route, tabID: tabID) }
        )
    }

    private func fullScreenBinding(for tabID: TabID) -> Binding<RouteItem<Route>?> {
        Binding<RouteItem<Route>?>(
            get: { navigator.state.state(for: tabID).fullScreen.map(RouteItem.init) },
            set: { navigator.updateFullScreenFromUI($0?.route, tabID: tabID) }
        )
    }
}

// MARK: - TabNavigationHost + DestinationRegistry convenience

public extension TabNavigationHost where Destination == AnyView {
    init(
        navigator: TabNavigator<TabID, Route>,
        registry: DestinationRegistry<Route>,
        tabs: [AnyNavigableTab<TabID>]
    ) {
        self.navigator = navigator
        self.tabs = tabs
        self.destination = { route in registry.view(for: route) }
        precondition(!tabs.isEmpty, "TabNavigationHost requires at least one tab")
        if navigator.state.selectedTab == nil, let first = tabs.first?.id {
            navigator.selectTab(first)
        }
    }
}

// MARK: - SplitNavigationHost

#if os(iOS) || os(macOS) || os(visionOS)
/// A `NavigationSplitView` host driven by a ``SplitNavigator``.
///
/// The sidebar receives a `Binding<Selection?>` so it can drive selection
/// via `List(selection:)`:
///
/// ```swift
/// SplitNavigationHost(navigator: splitNav) { $selection in
///     List(categories, selection: $selection) { category in
///         Text(category.name)
///     }
/// } detail: {
///     Text("Select a category")
/// } destination: { route in
///     DetailView(route: route)
/// }
/// ```
public struct SplitNavigationHost<Selection: Hashable & Sendable, Route: Hashable & Sendable, Sidebar: View, Detail: View, Destination: View>: View {
    private var navigator: SplitNavigator<Selection, Route>
    private let sidebar: (Binding<Selection?>) -> Sidebar
    private let detail: () -> Detail
    private let destination: (Route) -> Destination

    public init(
        navigator: SplitNavigator<Selection, Route>,
        @ViewBuilder sidebar: @escaping (Binding<Selection?>) -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail,
        @ViewBuilder destination: @escaping (Route) -> Destination
    ) {
        self.navigator = navigator
        self.sidebar = sidebar
        self.detail = detail
        self.destination = destination
    }

    public var body: some View {
        NavigationSplitView {
            sidebar(selectionBinding())
        } detail: {
            NavigationStack(path: pathBinding()) {
                detail()
                    .navigationDestination(for: Route.self) { route in
                        destination(route)
                    }
            }
            .sheet(item: sheetBinding()) { item in
                destination(item.route)
            }
            .fullScreenCoverIfAvailable(item: fullScreenBinding()) { item in
                destination(item.route)
            }
        }
    }

    private func selectionBinding() -> Binding<Selection?> {
        Binding<Selection?>(
            get: { navigator.state.selection },
            set: { navigator.updateSelectionFromUI($0) }
        )
    }

    private func pathBinding() -> Binding<[Route]> {
        Binding(
            get: { navigator.state.detail.path },
            set: { navigator.updatePathFromUI($0) }
        )
    }

    private func sheetBinding() -> Binding<RouteItem<Route>?> {
        Binding<RouteItem<Route>?>(
            get: { navigator.state.detail.sheet.map(RouteItem.init) },
            set: { navigator.updateSheetFromUI($0?.route) }
        )
    }

    private func fullScreenBinding() -> Binding<RouteItem<Route>?> {
        Binding<RouteItem<Route>?>(
            get: { navigator.state.detail.fullScreen.map(RouteItem.init) },
            set: { navigator.updateFullScreenFromUI($0?.route) }
        )
    }
}
#endif

// MARK: - Internal helpers

private extension View {
    @ViewBuilder
    func fullScreenCoverIfAvailable<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        #if os(iOS) || os(tvOS)
        fullScreenCover(item: item, content: content)
        #else
        self
        #endif
    }
}
