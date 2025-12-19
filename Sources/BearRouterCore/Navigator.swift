import Foundation
import Combine

@MainActor
public final class Navigator<Route: Hashable & Sendable>: ObservableObject {
    @Published public private(set) var state: NavigationState<Route>

    public var navigationGuard: NavigationGuard<Route>?
    public var logger: NavigationLogger<Route>
    public var sceneID: String?

    public init(
        initialState: NavigationState<Route> = NavigationState(),
        sceneID: String? = nil,
        navigationGuard: NavigationGuard<Route>? = nil,
        logger: NavigationLogger<Route> = .noOp
    ) {
        self.state = initialState
        self.sceneID = sceneID
        self.navigationGuard = navigationGuard
        self.logger = logger
    }

    public func handle(_ action: NavigationAction<Route>) async {
        await handle(action, allowGuard: true)
    }

    public func updatePathFromUI(_ path: [Route]) {
        state.path = path
        log("ui.replaceStack(\(path))")
    }

    public func updateSheetFromUI(_ route: Route?) {
        state.sheet = route
        log("ui.sheet(\(String(describing: route)))")
    }

    public func updateFullScreenFromUI(_ route: Route?) {
        state.fullScreen = route
        log("ui.fullScreen(\(String(describing: route)))")
    }

    public func snapshot() -> NavigationSnapshot<Route> where Route: Codable {
        NavigationSnapshot(state: state, sceneID: sceneID)
    }

    public func restore(from snapshot: NavigationSnapshot<Route>) {
        state = NavigationState(path: snapshot.path, sheet: snapshot.sheet, fullScreen: snapshot.fullScreen)
        sceneID = snapshot.sceneID
        log("restore")
    }

    public func persist(key: String, using persistence: NavigationPersistence, coder: SnapshotCoder = SnapshotCoder()) async throws where Route: Codable {
        let data = try coder.encode(snapshot())
        try await persistence.saveData(data, for: key)
    }

    public func restore(key: String, using persistence: NavigationPersistence, coder: SnapshotCoder = SnapshotCoder()) async throws where Route: Codable {
        guard let data = try await persistence.loadData(for: key) else { return }
        let snapshot = try coder.decode(NavigationSnapshot<Route>.self, from: data)
        restore(from: snapshot)
    }

    private func handle(_ action: NavigationAction<Route>, allowGuard: Bool) async {
        if allowGuard, let navigationGuard {
            let decision = await navigationGuard.evaluate(actionDescriptions: action.descriptions, context: GuardContext(state: state, sceneID: sceneID))
            switch decision {
            case .allow:
                await handle(action, allowGuard: false)
            case .deny(let reason):
                log("deny: \(reason)")
                return
            case .redirect(let path, let replay):
                state.path = path
                state.sheet = nil
                state.fullScreen = nil
                log("redirect -> \(path)")
                if replay {
                    await handle(action, allowGuard: false)
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
            state.path.append(route)
        case .pop:
            if !state.path.isEmpty {
                state.path.removeLast()
            }
        case .popToRoot:
            state.path.removeAll()
        case .replaceStack(let routes):
            state.path = routes
        case .presentSheet(let route):
            state.sheet = route
        case .presentFullScreen(let route):
            state.fullScreen = route
        case .dismissSheet:
            state.sheet = nil
        case .dismissFullScreen:
            state.fullScreen = nil
        case .dismissAll:
            state.path.removeAll()
            state.sheet = nil
            state.fullScreen = nil
        case .batch(let actions):
            for action in actions {
                reduce(action)
            }
        }
        log(action.description)
    }

    private func log(_ description: String) {
        logger.log(NavigationLogEvent(sceneID: sceneID, actionDescription: description, state: state))
    }
}
