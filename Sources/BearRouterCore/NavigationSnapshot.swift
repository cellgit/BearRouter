import Foundation

public struct NavigationSnapshot<Route: Hashable & Sendable>: Hashable, Sendable {
    public var path: [Route]
    public var sheet: Route?
    public var fullScreen: Route?
    public var sceneID: String?

    public init(path: [Route], sheet: Route?, fullScreen: Route?, sceneID: String?) {
        self.path = path
        self.sheet = sheet
        self.fullScreen = fullScreen
        self.sceneID = sceneID
    }

    public init(state: NavigationState<Route>, sceneID: String?) {
        self.init(path: state.path, sheet: state.sheet, fullScreen: state.fullScreen, sceneID: sceneID)
    }
}

public struct TabSnapshot<TabID: Hashable & Sendable, Route: Hashable & Sendable>: Hashable, Sendable {
    public var selectedTab: TabID?
    public var perTab: [TabID: NavigationSnapshot<Route>]
    public var sceneID: String?

    public init(selectedTab: TabID?, perTab: [TabID: NavigationSnapshot<Route>], sceneID: String?) {
        self.selectedTab = selectedTab
        self.perTab = perTab
        self.sceneID = sceneID
    }
}

public struct SplitSnapshot<Selection: Hashable & Sendable, Route: Hashable & Sendable>: Hashable, Sendable {
    public var selection: Selection?
    public var detail: NavigationSnapshot<Route>
    public var sceneID: String?

    public init(selection: Selection?, detail: NavigationSnapshot<Route>, sceneID: String?) {
        self.selection = selection
        self.detail = detail
        self.sceneID = sceneID
    }
}

extension NavigationSnapshot: Codable where Route: Codable {}
extension TabSnapshot: Codable where TabID: Codable, Route: Codable {}
extension SplitSnapshot: Codable where Selection: Codable, Route: Codable {}

public protocol NavigationPersistence: Sendable {
    func loadData(for key: String) async throws -> Data?
    func saveData(_ data: Data, for key: String) async throws
}

public struct SnapshotCoder: Sendable {
    public var encoder: JSONEncoder
    public var decoder: JSONDecoder

    public init(encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        self.encoder = encoder
        self.decoder = decoder
    }

    public func encode<Snapshot: Codable>(_ snapshot: Snapshot) throws -> Data {
        try encoder.encode(snapshot)
    }

    public func decode<Snapshot: Codable>(_ type: Snapshot.Type, from data: Data) throws -> Snapshot {
        try decoder.decode(type, from: data)
    }
}
