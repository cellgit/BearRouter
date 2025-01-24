//
//  File.swift
//  
//
//  Created by admin on 2025/1/24.
//

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
public class AppRouter: RouterProtocol {
    public typealias RouteType = AppRoute
    
    @Published public var navigationPath: [AppRoute] = []
    @Published public var presentedRoute: AppRoute? = nil
    
    // 导航到下一页
    public func push(_ route: AppRoute) {
        navigationPath.append(route)
    }
    
    /// 返回上一页
    public func pop() {
        _ = navigationPath.popLast()
    }
    
    /// 模态弹出
    public func present(_ route: AppRoute) {
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
    
    // 深链处理
    public func handleDeepLink(_ url: URL) {
        // 修正路径部分的解析，避免 pathComponents 为空
        guard let routerPath = url.routerPath, !routerPath.isEmpty else {
            print("Invalid deep link URL: \(url)")
            return
        }
        print("routerPath: \(routerPath)")  // 打印路径部分
        let params = url.queryParameters
        debugPrint("params====: \(params)")
        switch routerPath {
        case "detail":
            if let msg = params["message"] {
                push(.main(.detail(message: msg))) { data in
                    debugPrint("Detail page dismissed with data: \(data ?? "nil")")
                }
            }
        case "profile":
            if let userID = params["userID"] {
                push(.sub(.profile(userID: userID)))
            }
        case "settings":
            push(.sub(.settings))
        default:
            print("Unhandled deep link: \(routerPath)")
        }
    }
    
    // 路由到视图的映射
    public func destinationView(for route: AppRoute) -> AnyView {
        switch route {
        case let .main(mainRoute):
            return mainRoute.destinationView()
        case let .sub(subRoute):
            return subRoute.destinationView()
        }
    }
}


public extension AppRouter {
    
    func push(_ route: AppRoute, completion: ((Any?) -> Void)?) {
        // 将路由和回调一并管理
        navigationPath.append(route)
        if let completion = completion {
            // 存储回调 (需要额外的逻辑来保存回调，例如通过 Dictionary 绑定)
            RouteCallbacks.shared.setCallback(for: route, completion: completion)
        }
    }
    
    func present(_ route: AppRoute, completion: ((Any?) -> Void)?) {
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
    
    func popTo(_ route: AppRoute, _ data: Any?) {
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
