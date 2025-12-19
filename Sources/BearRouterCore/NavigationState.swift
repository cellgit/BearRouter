import Foundation

public struct NavigationState<Route: Hashable & Sendable>: Hashable, Sendable {
    public var path: [Route]
    public var sheet: Route?
    public var fullScreen: Route?

    public init(path: [Route] = [], sheet: Route? = nil, fullScreen: Route? = nil) {
        self.path = path
        self.sheet = sheet
        self.fullScreen = fullScreen
    }
}

extension NavigationState: Codable where Route: Codable {}

public struct TabState<TabID: Hashable & Sendable, Route: Hashable & Sendable>: Hashable, Sendable {
    public var selectedTab: TabID?
    public var perTab: [TabID: NavigationState<Route>]

    public init(selectedTab: TabID? = nil, perTab: [TabID: NavigationState<Route>] = [:]) {
        self.selectedTab = selectedTab
        self.perTab = perTab
    }

    public func state(for tabID: TabID) -> NavigationState<Route> {
        perTab[tabID] ?? NavigationState()
    }

    public mutating func setState(_ state: NavigationState<Route>, for tabID: TabID) {
        perTab[tabID] = state
    }
}

extension TabState: Codable where TabID: Codable, Route: Codable {}

public struct SplitState<Selection: Hashable & Sendable, Route: Hashable & Sendable>: Hashable, Sendable {
    public var selection: Selection?
    public var detail: NavigationState<Route>

    public init(selection: Selection? = nil, detail: NavigationState<Route> = NavigationState()) {
        self.selection = selection
        self.detail = detail
    }
}

extension SplitState: Codable where Selection: Codable, Route: Codable {}
