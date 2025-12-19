import SwiftUI
import BearRouterCore

public struct NavigationPathAdapter<Route: Hashable & Sendable>: Sendable {
    public let encode: @Sendable (Route) -> AnyHashable?
    public let decode: @Sendable (AnyHashable) -> Route?
    public let onDrop: (@Sendable (AnyHashable) -> Void)?

    public init(
        encode: @escaping @Sendable (Route) -> AnyHashable?,
        decode: @escaping @Sendable (AnyHashable) -> Route?,
        onDrop: (@Sendable (AnyHashable) -> Void)? = nil
    ) {
        self.encode = encode
        self.decode = decode
        self.onDrop = onDrop
    }

    public static var hashable: NavigationPathAdapter<Route> {
        NavigationPathAdapter<Route>(encode: { AnyHashable($0) }, decode: { $0.base as? Route })
    }

    @MainActor
    public func binding(for navigator: Navigator<Route>) -> Binding<NavigationPath> {
        Binding<NavigationPath>(
            get: { self.makePath(from: navigator.state.path) },
            set: { path in
                navigator.updatePathFromUI(self.decode(path))
            }
        )
    }

    @MainActor
    public func binding<TabID>(for tabNavigator: TabNavigator<TabID, Route>, tabID: TabID) -> Binding<NavigationPath> where TabID: Hashable & Sendable {
        Binding<NavigationPath>(
            get: { self.makePath(from: tabNavigator.state.state(for: tabID).path) },
            set: { path in
                tabNavigator.updatePathFromUI(self.decode(path), tabID: tabID)
            }
        )
    }

    @MainActor
    public func detailBinding<Selection>(for splitNavigator: SplitNavigator<Selection, Route>) -> Binding<NavigationPath> where Selection: Hashable & Sendable {
        Binding<NavigationPath>(
            get: { self.makePath(from: splitNavigator.state.detail.path) },
            set: { path in
                splitNavigator.updatePathFromUI(self.decode(path))
            }
        )
    }

    private func makePath(from routes: [Route]) -> NavigationPath {
        var path = NavigationPath()
        for route in routes {
            guard let encoded = encode(route) else { continue }
            path.append(encoded)
        }
        return path
    }

    private func decode(_ path: NavigationPath) -> [Route] {
        let elements = extractElements(from: path)
        return elements.compactMap { element in
            if let route = decode(element) {
                return route
            }
            onDrop?(element)
            return nil
        }
    }

    // NavigationPath does not expose its elements publicly. We extract them through reflection,
    // falling back to an empty array if the internal storage changes in future OS releases.
    private func extractElements(from path: NavigationPath) -> [AnyHashable] {
        let mirror = Mirror(reflecting: path)
        for child in mirror.children {
            if let hashables = child.value as? [AnyHashable] {
                return hashables
            }
            if let hashables = extractHashables(from: child.value) {
                return hashables
            }
            let inner = Mirror(reflecting: child.value)
            for innerChild in inner.children {
                if let hashables = innerChild.value as? [AnyHashable] {
                    return hashables
                }
                if let hashables = extractHashables(from: innerChild.value) {
                    return hashables
                }
            }
        }
        return []
    }

    private func extractHashables(from value: Any) -> [AnyHashable]? {
        guard let array = value as? [Any] else { return nil }
        let mapped = array.compactMap { element -> AnyHashable? in
            if let hashable = element as? AnyHashable {
                return hashable
            }
            let boxMirror = Mirror(reflecting: element)
            if let baseChild = boxMirror.children.first(where: { $0.label == "base" || $0.label == "_value" }),
               let hashable = baseChild.value as? AnyHashable {
                return hashable
            }
            return nil
        }
        return mapped.isEmpty ? nil : mapped
    }
}
