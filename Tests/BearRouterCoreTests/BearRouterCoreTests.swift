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

    func testBindingFriendlyProperties() async {
        let navigator = Navigator<TestRoute>()
        await navigator.handle(.push(.home))
        XCTAssertEqual(navigator.path, [.home])

        await navigator.handle(.presentSheet(.detail(1)))
        XCTAssertEqual(navigator.sheet, .detail(1))

        await navigator.handle(.presentFullScreen(.detail(2)))
        XCTAssertEqual(navigator.fullScreen, .detail(2))
    }

    func testGuardRedirect() async {
        let guard_ = NavigationGuard<TestRoute> { descriptions, _ in
            if descriptions.contains(where: { $0.contains("push") }) {
                return .redirect(path: [.redirected], replay: false)
            }
            return .allow
        }
        let navigator = Navigator<TestRoute>(navigationGuard: guard_)
        await navigator.handle(.push(.home))
        XCTAssertEqual(navigator.state.path, [.redirected])
    }

    func testGuardDeny() async {
        let guard_ = NavigationGuard<TestRoute> { _, _ in
            .deny(reason: "blocked")
        }
        let navigator = Navigator<TestRoute>(navigationGuard: guard_)
        await navigator.handle(.push(.home))
        XCTAssertTrue(navigator.state.path.isEmpty)
    }

    func testBatchActions() async {
        let navigator = Navigator<TestRoute>()
        await navigator.handle(.batch(.push(.home), .push(.detail(1)), .presentSheet(.detail(2))))
        XCTAssertEqual(navigator.state.path, [.home, .detail(1)])
        XCTAssertEqual(navigator.state.sheet, .detail(2))
    }

    func testDismissAll() async {
        let navigator = Navigator<TestRoute>()
        await navigator.handle(.batch(.push(.home), .presentSheet(.detail(1)), .presentFullScreen(.detail(2))))
        await navigator.handle(.dismissAll)
        XCTAssertTrue(navigator.state.path.isEmpty)
        XCTAssertNil(navigator.state.sheet)
        XCTAssertNil(navigator.state.fullScreen)
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

    func testTabNavigator() async {
        let tabNav = TabNavigator<String, TestRoute>()
        await tabNav.handle(.selectTab("home"))
        XCTAssertEqual(tabNav.state.selectedTab, "home")

        await tabNav.handle(.navigate(tab: "home", action: .push(.detail(1))))
        XCTAssertEqual(tabNav.state.state(for: "home").path, [.detail(1)])
    }

    func testTabNavigatorSelectedTabBinding() async {
        let tabNav = TabNavigator<String, TestRoute>()
        tabNav.selectedTab = "settings"
        XCTAssertEqual(tabNav.state.selectedTab, "settings")
    }

    func testSplitNavigator() async {
        let splitNav = SplitNavigator<String, TestRoute>()
        await splitNav.handle(.setSelection("category1"))
        XCTAssertEqual(splitNav.state.selection, "category1")

        await splitNav.handle(.navigateDetail(.push(.detail(1))))
        XCTAssertEqual(splitNav.state.detail.path, [.detail(1)])
    }

    func testSplitNavigatorSelectionBinding() async {
        let splitNav = SplitNavigator<String, TestRoute>()
        splitNav.selection = "test"
        XCTAssertEqual(splitNav.state.selection, "test")
    }

    func testSplitNavigatorDetailPathBinding() async {
        let splitNav = SplitNavigator<String, TestRoute>()
        await splitNav.handle(.navigateDetail(.push(.home)))
        XCTAssertEqual(splitNav.detailPath, [.home])
    }

    func testLogger() async {
        let testLogger = TestNavigationLogger<TestRoute>()
        let navigator = Navigator<TestRoute>(logger: testLogger.logger())
        await navigator.handle(.push(.home))
        XCTAssertFalse(testLogger.events.isEmpty)
    }
}
