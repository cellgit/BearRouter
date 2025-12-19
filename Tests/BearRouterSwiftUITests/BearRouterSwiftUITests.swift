import XCTest
import SwiftUI
@testable import BearRouter

private enum DemoRoute: String, Hashable, Sendable {
    case home
    case detail
}

final class BearRouterSwiftUITests: XCTestCase {
    @MainActor
    func testRegistryProvidesFallback() {
        let registry = DestinationRegistry<DemoRoute> { route in AnyView(Text("Fallback: \(route.rawValue)")) }
        let view = registry.view(for: .home)
        XCTAssertNotNil(view)
    }
}
