import SwiftUI
import BearRouter
import BearRouterCore

@available(iOS 18, macOS 15, *)
public struct StackNavigationHostOS26<Route: Hashable & Sendable, Root: View>: View {
    private let host: StackNavigationHost<Route, Root>

    public init(navigator: Navigator<Route>, registry: DestinationRegistry<Route>, @ViewBuilder root: @escaping () -> Root) {
        self.host = StackNavigationHost(navigator: navigator, registry: registry, root: root)
    }

    public var body: some View {
        host
    }
}

@available(iOS 18, macOS 15, *)
public struct TabNavigationHostOS26<TabID: Hashable & Sendable, Route: Hashable & Sendable>: View {
    private let host: TabNavigationHost<TabID, Route>

    public init(navigator: TabNavigator<TabID, Route>, registry: DestinationRegistry<Route>, tabs: [AnyNavigableTab<TabID>], adapter: NavigationPathAdapter<Route> = .hashable) {
        self.host = TabNavigationHost(navigator: navigator, registry: registry, tabs: tabs, adapter: adapter)
    }

    public var body: some View {
        host
    }
}

@available(iOS 18, macOS 15, *)
public struct SplitNavigationHostOS26<Selection: Hashable & Sendable, Route: Hashable & Sendable, Sidebar: View, Detail: View>: View {
    private let host: SplitNavigationHost<Selection, Route, Sidebar, Detail>

    public init(navigator: SplitNavigator<Selection, Route>, registry: DestinationRegistry<Route>, adapter: NavigationPathAdapter<Route> = .hashable, @ViewBuilder sidebar: @escaping () -> Sidebar, @ViewBuilder detail: @escaping () -> Detail) {
        self.host = SplitNavigationHost(navigator: navigator, registry: registry, adapter: adapter, sidebar: sidebar, detail: detail)
    }

    public var body: some View {
        host
    }
}
