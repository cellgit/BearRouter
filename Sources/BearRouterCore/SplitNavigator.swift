import Foundation
import Combine

@MainActor
public final class SplitNavigator<Selection: Hashable & Sendable, Route: Hashable & Sendable>: ObservableObject {
    @Published public private(set) var state: SplitState<Selection, Route>

    public var navigationGuard: NavigationGuard<Route>?
    public var logger: NavigationLogger<Route>
    public var sceneID: String?

    public init(
        initialState: SplitState<Selection, Route> = SplitState(),
        sceneID: String? = nil,
        navigationGuard: NavigationGuard<Route>? = nil,
        logger: NavigationLogger<Route> = .noOp
    ) {
        self.state = initialState
        self.sceneID = sceneID
        self.navigationGuard = navigationGuard
        self.logger = logger
    }

    public func handle(_ action: SplitNavigationAction<Selection, Route>) async {
        switch action {
        case .setSelection(let selection):
            state.selection = selection
            log("setSelection(\(String(describing: selection)))")
        case .navigateDetail(let navAction):
            await handleDetail(navAction, allowGuard: true)
        case .reset(let newState):
            state = newState
            log("reset")
        }
    }

    public func updateSelectionFromUI(_ selection: Selection?) {
        state.selection = selection
        log("ui.selection(\(String(describing: selection)))")
    }

    public func updatePathFromUI(_ path: [Route]) {
        state.detail.path = path
        log("ui.replaceStack(\(path))")
    }

    public func updateSheetFromUI(_ route: Route?) {
        state.detail.sheet = route
        log("ui.sheet(\(String(describing: route)))")
    }

    public func updateFullScreenFromUI(_ route: Route?) {
        state.detail.fullScreen = route
        log("ui.fullScreen(\(String(describing: route)))")
    }

    public func setSelection(from string: String, translator: SelectionTranslator<Selection>) {
        state.selection = translator.parse(string)
        log("setSelection(\(string))")
    }

    public func snapshot() -> SplitSnapshot<Selection, Route> where Selection: Codable, Route: Codable {
        SplitSnapshot(selection: state.selection, detail: NavigationSnapshot(state: state.detail, sceneID: sceneID), sceneID: sceneID)
    }

    public func restore(from snapshot: SplitSnapshot<Selection, Route>) {
        state = SplitState(selection: snapshot.selection, detail: NavigationState(path: snapshot.detail.path, sheet: snapshot.detail.sheet, fullScreen: snapshot.detail.fullScreen))
        sceneID = snapshot.sceneID
        log("restore")
    }

    public func persist(key: String, using persistence: NavigationPersistence, coder: SnapshotCoder = SnapshotCoder()) async throws where Selection: Codable, Route: Codable {
        let data = try coder.encode(snapshot())
        try await persistence.saveData(data, for: key)
    }

    public func restore(key: String, using persistence: NavigationPersistence, coder: SnapshotCoder = SnapshotCoder()) async throws where Selection: Codable, Route: Codable {
        guard let data = try await persistence.loadData(for: key) else { return }
        let snapshot = try coder.decode(SplitSnapshot<Selection, Route>.self, from: data)
        restore(from: snapshot)
    }

    private func handleDetail(_ action: NavigationAction<Route>, allowGuard: Bool) async {
        if allowGuard, let navigationGuard {
            let decision = await navigationGuard.evaluate(actionDescriptions: action.descriptions, context: GuardContext(state: state.detail, sceneID: sceneID))
            switch decision {
            case .allow:
                await handleDetail(action, allowGuard: false)
            case .deny(let reason):
                log("deny: \(reason)")
                return
            case .redirect(let path, let replay):
                state.detail.path = path
                state.detail.sheet = nil
                state.detail.fullScreen = nil
                log("redirect -> \(path)")
                if replay {
                    await handleDetail(action, allowGuard: false)
                }
                return
            }
            return
        }

        reduce(action)
    }

    private func reduce(_ action: NavigationAction<Route>) {
        switch action {
        case .push(let route):
            state.detail.path.append(route)
        case .pop:
            if !state.detail.path.isEmpty {
                state.detail.path.removeLast()
            }
        case .popToRoot:
            state.detail.path.removeAll()
        case .replaceStack(let routes):
            state.detail.path = routes
        case .presentSheet(let route):
            state.detail.sheet = route
        case .presentFullScreen(let route):
            state.detail.fullScreen = route
        case .dismissSheet:
            state.detail.sheet = nil
        case .dismissFullScreen:
            state.detail.fullScreen = nil
        case .dismissAll:
            state.detail.path.removeAll()
            state.detail.sheet = nil
            state.detail.fullScreen = nil
        case .batch(let actions):
            for action in actions {
                reduce(action)
            }
        }
        log(action.description)
    }

    private func log(_ description: String) {
        logger.log(NavigationLogEvent(sceneID: sceneID, actionDescription: description, state: state.detail))
    }
}
