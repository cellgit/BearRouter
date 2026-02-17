import XCTest
import SwiftUI
@testable import BearRouter
@testable import BearRouterCore

private enum DemoRoute: String, Hashable, Sendable {
    case home
    case detail
}

private enum DemoIntent: Hashable {
    case goHome
    case goDetail
}

final class BearRouterSwiftUITests: XCTestCase {
    @MainActor
    func testRegistryProvidesFallback() {
        let registry = DestinationRegistry<DemoRoute> { route in AnyView(Text("Fallback: \(route.rawValue)")) }
        let view = registry.view(for: .home)
        XCTAssertNotNil(view)
    }

    @MainActor
    func testRegistryRegisterBuilder() {
        let registry = DestinationRegistry<DemoRoute>()
        registry.register { route in
            Text(route.rawValue)
        }
        let view = registry.view(for: .home)
        XCTAssertNotNil(view)
    }

    @MainActor
    func testIntentNavigator() async {
        let navigator = Navigator<DemoRoute>()
        let router = AnyIntentRouter<DemoIntent, DemoRoute> { intent in
            switch intent {
            case .goHome: return [.push(.home)]
            case .goDetail: return [.push(.detail)]
            }
        }
        let intentNav = IntentNavigator(navigator: navigator, router: router)
        await intentNav.send(.goHome)
        XCTAssertEqual(navigator.state.path, [.home])
    }

    @MainActor
    func testIntentDispatcher() async {
        let navigator = Navigator<DemoRoute>()
        let router = AnyIntentRouter<DemoIntent, DemoRoute> { intent in
            switch intent {
            case .goHome: return [.push(.home)]
            case .goDetail: return [.push(.detail)]
            }
        }
        let intentNav = IntentNavigator(navigator: navigator, router: router)
        let dispatcher = intentNav.makeDispatcher()
        await dispatcher.send(.goDetail)
        XCTAssertEqual(navigator.state.path, [.detail])
    }
}
