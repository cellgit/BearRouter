import Foundation

public enum NavigationAction<Route: Hashable & Sendable>: Hashable, Sendable {
    case push(Route)
    case pop
    case popToRoot
    case replaceStack([Route])
    case presentSheet(Route)
    case presentFullScreen(Route)
    case dismissSheet
    case dismissFullScreen
    case dismissAll
    case batch([NavigationAction<Route>])
}

public extension NavigationAction {
    static func batch(_ actions: NavigationAction<Route>...) -> NavigationAction<Route> {
        .batch(actions)
    }

    var description: String {
        switch self {
        case .push(let route):
            return "push(\(route))"
        case .pop:
            return "pop"
        case .popToRoot:
            return "popToRoot"
        case .replaceStack(let routes):
            return "replaceStack(\(routes))"
        case .presentSheet(let route):
            return "presentSheet(\(route))"
        case .presentFullScreen(let route):
            return "presentFullScreen(\(route))"
        case .dismissSheet:
            return "dismissSheet"
        case .dismissFullScreen:
            return "dismissFullScreen"
        case .dismissAll:
            return "dismissAll"
        case .batch(let actions):
            return "batch(\(actions.map { $0.description }.joined(separator: ",")))"
        }
    }

    var descriptions: [String] {
        switch self {
        case .batch(let actions):
            return actions.flatMap { $0.descriptions }
        default:
            return [description]
        }
    }
}

public enum TabNavigationAction<TabID: Hashable & Sendable, Route: Hashable & Sendable>: Hashable, Sendable {
    case selectTab(TabID)
    case navigate(tab: TabID, action: NavigationAction<Route>)
    case navigateCurrent(NavigationAction<Route>)
    case reset(TabState<TabID, Route>)
}

public enum SplitNavigationAction<Selection: Hashable & Sendable, Route: Hashable & Sendable>: Hashable, Sendable {
    case setSelection(Selection?)
    case navigateDetail(NavigationAction<Route>)
    case reset(SplitState<Selection, Route>)
}

public struct SelectionTranslator<ID: Hashable & Sendable>: Sendable {
    public let parse: @Sendable (String) -> ID?
    public let stringify: @Sendable (ID) -> String

    public init(parse: @escaping @Sendable (String) -> ID?, stringify: @escaping @Sendable (ID) -> String) {
        self.parse = parse
        self.stringify = stringify
    }
}

public extension SelectionTranslator where ID: RawRepresentable, ID.RawValue == String {
    static var rawValue: SelectionTranslator<ID> {
        SelectionTranslator<ID>(parse: { ID(rawValue: $0) }, stringify: { $0.rawValue })
    }
}

public extension TabNavigationAction {
    static func selectTab(string: String, using translator: SelectionTranslator<TabID>) -> TabNavigationAction<TabID, Route>? {
        guard let tab = translator.parse(string) else { return nil }
        return .selectTab(tab)
    }
}

public extension SplitNavigationAction {
    static func setSelection(string: String, using translator: SelectionTranslator<Selection>) -> SplitNavigationAction<Selection, Route>? {
        .setSelection(translator.parse(string))
    }
}
