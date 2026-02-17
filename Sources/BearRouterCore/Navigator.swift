import Foundation
import Observation

/// A single-stack navigation state machine.
///
/// Use `@State` to own it in a view, or inject via `@Environment`.
///
/// ```swift
/// @State private var navigator = Navigator<Route>()
///
/// var body: some View {
///     @Bindable var nav = navigator
///     NavigationStack(path: $nav.path) { ... }
/// }
/// ```
@Observable
@MainActor
public final class Navigator<Route: Hashable & Sendable> {
    // MARK: - Observable state

    /// The canonical navigation state (path + sheet + fullScreen).
    public private(set) var state: NavigationState<Route>

    // MARK: - Infrastructure (not observed)

    @ObservationIgnored public var navigationGuard: NavigationGuard<Route>?
    @ObservationIgnored public var logger: NavigationLogger<Route>
    @ObservationIgnored public var sceneID: String?

    // MARK: - Binding-friendly computed properties
    //
    // Use with `@Bindable var nav = navigator`:
    //   NavigationStack(path: $nav.path)
    //   .sheet(item: …)

    /// Read/write access to the navigation path. Setting triggers `updatePathFromUI`.
    public var path: [Route] {
        get { state.path }
        set { updatePathFromUI(newValue) }
    }

    /// Read/write access to the sheet route.
    public var sheet: Route? {
        get { state.sheet }
        set { updateSheetFromUI(newValue) }
    }

    /// Read/write access to the full-screen cover route.
    public var fullScreen: Route? {
        get { state.fullScreen }
        set { updateFullScreenFromUI(newValue) }
    }

    // MARK: - Init

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

    // MARK: - Action handling

    public func handle(_ action: NavigationAction<Route>) async {
        await handle(action, allowGuard: true)
    }

    // MARK: - UI synchronisation callbacks

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

    // MARK: - Snapshot / Restore

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
        let snap = try coder.decode(NavigationSnapshot<Route>.self, from: data)
        restore(from: snap)
    }

    // MARK: - Private

    private func handle(_ action: NavigationAction<Route>, allowGuard: Bool) async {
        if allowGuard, let navigationGuard {
            let decision = await navigationGuard.evaluate(
                actionDescriptions: action.descriptions,
                context: GuardContext(state: state, sceneID: sceneID)
            )
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
            if !state.path.isEmpty { state.path.removeLast() }
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
            for a in actions { reduce(a) }
        }
        log(action.description)
    }

    private func log(_ description: String) {
        logger.log(NavigationLogEvent(sceneID: sceneID, actionDescription: description, state: state))
    }
}
