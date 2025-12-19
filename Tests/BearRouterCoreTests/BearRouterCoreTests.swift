import XCTest
@testable import BearRouterCore
@testable import BearRouterTesting

private enum TestRoute: Hashable, Sendable, Codable {
    case home
    case detail(Int)
    case redirected
}

@MainActor
final class BearRouterCoreTests: XCTestCase {
    func testNavigatorPushPop() async {
        let navigator = Navigator<TestRoute>()
        await navigator.handle(.push(.home))
        await navigator.handle(.push(.detail(1)))
        XCTAssertEqual(navigator.state.path, [.home, .detail(1)])

        await navigator.handle(.pop)
        XCTAssertEqual(navigator.state.path, [.home])

        await navigator.handle(.popToRoot)
        XCTAssertTrue(navigator.state.path.isEmpty)
    }

    func testGuardRedirect() async {
        let navigationGuard = NavigationGuard<TestRoute> { descriptions, _ in
            if descriptions.contains(where: { $0.contains("push") }) {
                return .redirect(path: [.redirected], replay: false)
            }
            return .allow
        }
        let navigator = Navigator<TestRoute>(navigationGuard: navigationGuard)
        await navigator.handle(.push(.home))
        XCTAssertEqual(navigator.state.path, [.redirected])
    }

    func testPersistence() async throws {
        let navigator = Navigator<TestRoute>()
        await navigator.handle(.push(.detail(2)))
        await navigator.handle(.presentSheet(.home))

        let persistence = InMemoryNavigationPersistence()
        try await navigator.persist(key: "snapshot", using: persistence)

        let restored = Navigator<TestRoute>()
        try await restored.restore(key: "snapshot", using: persistence)
        XCTAssertEqual(restored.state.path, [.detail(2)])
        XCTAssertEqual(restored.state.sheet, .home)
    }
}
