// The Swift Programming Language
// https://docs.swift.org/swift-book


import SwiftUI

/**
 
 如何处理深度链接:
 1. 在info.plist添加URL Types，设置URL Schemes
 2. 在首页视图添加onOpenURL中处理深链接,如下:
 NavigationStack(path: $router.navigationPath) {
 
 }
 .onOpenURL { url in
 router.handleDeepLink(url)
 }
 
 
 深度链接如:
 myapp://detail?message=HelloWorld — 展示一个详情页
 myapp://profile?userID=12345
 myapp://settings — 展示设置页面
 
 
 */


// 应用路由的实现
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
open class BearRouter<RouteType: RouteProtocol>: RouterProtocol {
    
//    public typealias RouteType = RouteType
    
    @Published public var navigationPath: [RouteType] = []
    @Published public var presentedRoute: RouteType? = nil
    
    /// 公开的初始化器
    public init() {}
    
    // 导航到下一页
    public func push(_ route: RouteType) {
        navigationPath.append(route)
    }
    
    /// 返回上一页
    public func pop() {
        _ = navigationPath.popLast()
    }
    
    /// 模态弹出
    public func present(_ route: RouteType) {
        presentedRoute = route
    }
    
    /// 关闭模态
    public func dismiss() {
        presentedRoute = nil
    }
    
    /// 返回到根视图
    public func popToRoot() {
        navigationPath.removeAll()
    }
    
    /// 返回到指定路由
    public func popTo(_ route: RouteType) {
        if let index = navigationPath.firstIndex(of: route) {
            let end = navigationPath.index(after: index)
            if end <= navigationPath.count {
                navigationPath = Array(navigationPath.prefix(end))
            }
        }
    }
    
    /// 替换当前路由
    public func replaceCurrent(with route: RouteType) {
        _ = navigationPath.popLast()
        navigationPath.append(route)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public extension BearRouter {
    
    func push(_ route: RouteType, completion: ((Any?) -> Void)?) {
        // 将路由和回调一并管理
        navigationPath.append(route)
        if let completion = completion {
            // 存储回调 (需要额外的逻辑来保存回调，例如通过 Dictionary 绑定)
            RouteCallbacks.shared.setCallback(for: route, completion: completion)
        }
    }
    
    func present(_ route: RouteType, completion: ((Any?) -> Void)?) {
        presentedRoute = route
        if let completion = completion {
            RouteCallbacks.shared.setCallback(for: route, completion: completion)
        }
    }
    
    func pop(_ data: Any?) {
        if let lastRoute = navigationPath.last {
            RouteCallbacks.shared.executeCallback(for: lastRoute, with: data)
        }
        _ = navigationPath.popLast()
    }
    
    func popToRoot(_ data: Any?) {
        guard !navigationPath.isEmpty else { return }
        // Execute callback for all routes before root (if needed)
        for route in navigationPath {
            RouteCallbacks.shared.executeCallback(for: route, with: data)
        }
        // Handle root callback with data
        if let rootRoute = navigationPath.first {
            RouteCallbacks.shared.executeCallback(for: rootRoute, with: data)
        }
        navigationPath.removeAll()
    }
    
    func popTo(_ route: RouteType, _ data: Any?) {
        guard let targetIndex = navigationPath.firstIndex(of: route) else { return }
        // Execute callbacks for routes being popped off
        for i in stride(from: navigationPath.count - 1, through: targetIndex + 1, by: -1) {
            let routeToPop = navigationPath[i]
            RouteCallbacks.shared.executeCallback(for: routeToPop, with: data)
        }
        // Handle callback for target route with data
        RouteCallbacks.shared.executeCallback(for: route, with: data)
        // Trim the navigation stack
        navigationPath = Array(navigationPath.prefix(upTo: targetIndex + 1))
    }
    
    func dismiss(_ data: Any?) {
        if let currentRoute = presentedRoute {
            RouteCallbacks.shared.executeCallback(for: currentRoute, with: data)
        }
        presentedRoute = nil
    }
    
    
}
