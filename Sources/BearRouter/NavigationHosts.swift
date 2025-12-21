import SwiftUI
import BearRouterCore

private struct RouteItem<Route: Hashable & Sendable>: Identifiable, Equatable {
    let route: Route
    var id: AnyHashable { AnyHashable(route) }
}

public struct StackNavigationHost<Route: Hashable & Sendable, Root: View>: View {
    @ObservedObject private var navigator: Navigator<Route>
    private let registry: DestinationRegistry<Route>
    private let root: () -> Root

    public init(navigator: Navigator<Route>, registry: DestinationRegistry<Route>, @ViewBuilder root: @escaping () -> Root) {
        self.navigator = navigator
        self.registry = registry
        self.root = root
    }

    public var body: some View {
        NavigationStack(path: pathBinding()) {
            root()
                .navigationDestination(for: Route.self) { route in
                    registry.view(for: route)
                }
        }
        .sheet(item: sheetBinding()) { item in
            registry.view(for: item.route)
        }
        .fullScreenCoverIfAvailable(item: fullScreenBinding()) { item in
            registry.view(for: item.route)
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

public struct PathStackNavigationHost<Route: Hashable & Sendable, Root: View>: View {
    @ObservedObject private var navigator: Navigator<Route>
    private let registry: DestinationRegistry<Route>
    private let adapter: NavigationPathAdapter<Route>
    private let root: () -> Root

    public init(navigator: Navigator<Route>, registry: DestinationRegistry<Route>, adapter: NavigationPathAdapter<Route> = .hashable, @ViewBuilder root: @escaping () -> Root) {
        self.navigator = navigator
        self.registry = registry
        self.adapter = adapter
        self.root = root
    }

    public var body: some View {
        NavigationStack(path: adapter.binding(for: navigator)) {
            root()
                .navigationDestination(for: AnyHashable.self) { hashable in
                    if let route = adapter.decode(hashable) {
                        registry.view(for: route)
                    } else {
                        AnyView(EmptyView())
                    }
                }
        }
        .sheet(item: sheetBinding()) { item in
            registry.view(for: item.route)
        }
        .fullScreenCoverIfAvailable(item: fullScreenBinding()) { item in
            registry.view(for: item.route)
        }
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

public struct NavigableTab<TabID: Hashable & Sendable, Label: View, Content: View>: Identifiable {
    public var id: TabID { tabID }
    public let tabID: TabID
    private let labelBuilder: () -> Label
    private let contentBuilder: () -> Content

    public init(tabID: TabID, @ViewBuilder label: @escaping () -> Label, @ViewBuilder content: @escaping () -> Content) {
        self.tabID = tabID
        self.labelBuilder = label
        self.contentBuilder = content
    }

    public func eraseToAny() -> AnyNavigableTab<TabID> {
        AnyNavigableTab(id: tabID, label: { AnyView(labelBuilder()) }, content: { AnyView(contentBuilder()) })
    }
}

public struct TabNavigationHost<TabID: Hashable & Sendable, Route: Hashable & Sendable>: View {
    @ObservedObject private var navigator: TabNavigator<TabID, Route>
    private let registry: DestinationRegistry<Route>
    private let adapter: NavigationPathAdapter<Route>
    private let tabs: [AnyNavigableTab<TabID>]

    public init(navigator: TabNavigator<TabID, Route>, registry: DestinationRegistry<Route>, tabs: [AnyNavigableTab<TabID>], adapter: NavigationPathAdapter<Route> = .hashable) {
        self.navigator = navigator
        self.registry = registry
        self.tabs = tabs
        self.adapter = adapter
        precondition(!tabs.isEmpty, "TabNavigationHost requires at least one tab")
        if navigator.state.selectedTab == nil, let first = tabs.first?.id {
            navigator.selectTab(first)
        }
    }

    public var body: some View {
        TabView(selection: selectionBinding()) {
            ForEach(tabs) { tab in
                NavigationStack(path: adapter.binding(for: navigator, tabID: tab.id)) {
                    tab.content()
                        .navigationDestination(for: AnyHashable.self) { hashable in
                            if let route = adapter.decode(hashable) {
                                registry.view(for: route)
                            } else {
                                AnyView(EmptyView())
                            }
                        }
                }
                .tabItem { tab.label() }
                .tag(tab.id)
                .sheet(item: sheetBinding(for: tab.id)) { item in
                    registry.view(for: item.route)
                }
                .fullScreenCoverIfAvailable(item: fullScreenBinding(for: tab.id)) { item in
                    registry.view(for: item.route)
                }
            }
        }
    }

    private func selectionBinding() -> Binding<TabID> {
        Binding<TabID>(
            get: { navigator.state.selectedTab ?? tabs.first!.id },
            set: { newValue in navigator.selectTab(newValue) }
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

#if os(iOS) || os(macOS) || os(visionOS)
public struct SplitNavigationHost<Selection: Hashable & Sendable, Route: Hashable & Sendable, Sidebar: View, Detail: View>: View {
    @ObservedObject private var navigator: SplitNavigator<Selection, Route>
    private let registry: DestinationRegistry<Route>
    private let sidebar: () -> Sidebar
    private let detail: () -> Detail
    private let adapter: NavigationPathAdapter<Route>

    public init(
        navigator: SplitNavigator<Selection, Route>,
        registry: DestinationRegistry<Route>,
        adapter: NavigationPathAdapter<Route> = .hashable,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.navigator = navigator
        self.registry = registry
        self.sidebar = sidebar
        self.detail = detail
        self.adapter = adapter
    }

    public var body: some View {
        NavigationSplitView(sidebar: {
            sidebar()
        }, detail: {
            NavigationStack(path: adapter.detailBinding(for: navigator)) {
                detail()
                    .navigationDestination(for: AnyHashable.self) { hashable in
                        if let route = adapter.decode(hashable) {
                            registry.view(for: route)
                        } else {
                            AnyView(EmptyView())
                        }
                    }
            }
            .sheet(item: sheetBinding()) { item in
                registry.view(for: item.route)
            }
            .fullScreenCoverIfAvailable(item: fullScreenBinding()) { item in
                registry.view(for: item.route)
            }
        })
    }

    private func selectionBinding() -> Binding<Selection?> {
        Binding<Selection?>(
            get: { navigator.state.selection },
            set: { navigator.updateSelectionFromUI($0) }
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

@MainActor
public func withNavigationPath<Route, Root>(navigator: Navigator<Route>, registry: DestinationRegistry<Route>, adapter: NavigationPathAdapter<Route> = .hashable, @ViewBuilder root: @escaping () -> Root) -> some View where Route: Hashable & Sendable, Root: View {
    PathStackNavigationHost(navigator: navigator, registry: registry, adapter: adapter, root: root)
}

private extension View {
    @ViewBuilder
    func fullScreenCoverIfAvailable<Item: Identifiable, Content: View>(item: Binding<Item?>, @ViewBuilder content: @escaping (Item) -> Content) -> some View {
        #if os(iOS) || os(tvOS)
        fullScreenCover(item: item, content: content)
        #else
        self
        #endif
    }
}
