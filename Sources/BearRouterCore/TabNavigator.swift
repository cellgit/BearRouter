import Foundation
import Combine

@MainActor
public final class TabNavigator<TabID: Hashable & Sendable, Route: Hashable & Sendable>: ObservableObject {
    @Published public private(set) var state: TabState<TabID, Route>

    public var navigationGuard: NavigationGuard<Route>?
    public var logger: NavigationLogger<Route>
    public var sceneID: String?

    public init(
        initialState: TabState<TabID, Route> = TabState(),
        sceneID: String? = nil,
        navigationGuard: NavigationGuard<Route>? = nil,
        logger: NavigationLogger<Route> = .noOp
    ) {
        self.state = initialState
        self.sceneID = sceneID
        self.navigationGuard = navigationGuard
        self.logger = logger
    }

    public func handle(_ action: TabNavigationAction<TabID, Route>) async {
        switch action {
        case .selectTab(let tabID):
            state.selectedTab = tabID
            log("selectTab(\(tabID))", tabID: tabID)
        case .navigate(let tabID, let navAction):
            state.selectedTab = state.selectedTab ?? tabID
            await handleNavigation(navAction, for: tabID, allowGuard: true)
        case .navigateCurrent(let navAction):
            guard let tabID = state.selectedTab ?? state.perTab.keys.first else { return }
            await handleNavigation(navAction, for: tabID, allowGuard: true)
        case .reset(let newState):
            state = newState
            log("reset", tabID: state.selectedTab)
        }
    }

    public func selectTab(_ tabID: TabID) {
        state.selectedTab = tabID
        log("selectTab(\(tabID))", tabID: tabID)
    }

    public func updatePathFromUI(_ path: [Route], tabID: TabID) {
        var tabState = state.state(for: tabID)
        tabState.path = path
        state.setState(tabState, for: tabID)
        log("ui.replaceStack(\(path))", tabID: tabID)
    }

    public func updateSheetFromUI(_ route: Route?, tabID: TabID) {
        var tabState = state.state(for: tabID)
        tabState.sheet = route
        state.setState(tabState, for: tabID)
        log("ui.sheet(\(String(describing: route)))", tabID: tabID)
    }

    public func updateFullScreenFromUI(_ route: Route?, tabID: TabID) {
        var tabState = state.state(for: tabID)
        tabState.fullScreen = route
        state.setState(tabState, for: tabID)
        log("ui.fullScreen(\(String(describing: route)))", tabID: tabID)
    }

    public func snapshot() -> TabSnapshot<TabID, Route> where TabID: Codable, Route: Codable {
        let snapshots = state.perTab.mapValues { NavigationSnapshot(state: $0, sceneID: sceneID) }
        return TabSnapshot(selectedTab: state.selectedTab, perTab: snapshots, sceneID: sceneID)
    }

    public func restore(from snapshot: TabSnapshot<TabID, Route>) {
        let restoredStates = snapshot.perTab.mapValues { NavigationState(path: $0.path, sheet: $0.sheet, fullScreen: $0.fullScreen) }
        state = TabState(selectedTab: snapshot.selectedTab, perTab: restoredStates)
        sceneID = snapshot.sceneID
        log("restore", tabID: state.selectedTab)
    }

    public func persist(key: String, using persistence: NavigationPersistence, coder: SnapshotCoder = SnapshotCoder()) async throws where TabID: Codable, Route: Codable {
        let data = try coder.encode(snapshot())
        try await persistence.saveData(data, for: key)
    }

    public func restore(key: String, using persistence: NavigationPersistence, coder: SnapshotCoder = SnapshotCoder()) async throws where TabID: Codable, Route: Codable {
        guard let data = try await persistence.loadData(for: key) else { return }
        let snapshot = try coder.decode(TabSnapshot<TabID, Route>.self, from: data)
        restore(from: snapshot)
    }

    public func setSelection(from string: String, translator: SelectionTranslator<TabID>) {
        guard let tab = translator.parse(string) else { return }
        state.selectedTab = tab
        log("selectTab(\(translator.stringify(tab)))", tabID: tab)
    }

    private func handleNavigation(_ action: NavigationAction<Route>, for tabID: TabID, allowGuard: Bool) async {
        var tabState = state.state(for: tabID)
        if allowGuard, let navigationGuard {
            let decision = await navigationGuard.evaluate(actionDescriptions: action.descriptions, context: GuardContext(state: tabState, sceneID: sceneID))
            switch decision {
            case .allow:
                await handleNavigation(action, for: tabID, allowGuard: false)
            case .deny(let reason):
                log("deny: \(reason)", tabID: tabID)
                return
            case .redirect(let path, let replay):
                tabState.path = path
                tabState.sheet = nil
                tabState.fullScreen = nil
                state.setState(tabState, for: tabID)
                log("redirect -> \(path)", tabID: tabID)
                if replay {
                    await handleNavigation(action, for: tabID, allowGuard: false)
                }
                return
            }
            return
        }

        reduce(action, tabID: tabID)
    }

    private func reduce(_ action: NavigationAction<Route>, tabID: TabID) {
        var tabState = state.state(for: tabID)
        switch action {
        case .push(let route):
            tabState.path.append(route)
        case .pop:
            if !tabState.path.isEmpty {
                tabState.path.removeLast()
            }
        case .popToRoot:
            tabState.path.removeAll()
        case .replaceStack(let routes):
            tabState.path = routes
        case .presentSheet(let route):
            tabState.sheet = route
        case .presentFullScreen(let route):
            tabState.fullScreen = route
        case .dismissSheet:
            tabState.sheet = nil
        case .dismissFullScreen:
            tabState.fullScreen = nil
        case .dismissAll:
            tabState.path.removeAll()
            tabState.sheet = nil
            tabState.fullScreen = nil
        case .batch(let actions):
            for action in actions {
                reduce(action, tabID: tabID)
            }
        }
        state.setState(tabState, for: tabID)
        log("[tab: \(tabID)] \(action.description)", tabID: tabID)
    }

    private func log(_ description: String, tabID: TabID?) {
        guard let tabID else {
            logger.log(NavigationLogEvent(sceneID: sceneID, actionDescription: description, state: NavigationState()))
            return
        }
        let tabState = state.state(for: tabID)
        logger.log(NavigationLogEvent(sceneID: sceneID, actionDescription: description, state: tabState))
    }
}
