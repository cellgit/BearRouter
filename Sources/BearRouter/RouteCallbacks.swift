//
//  File.swift
//  
//
//  Created by admin on 2025/1/24.
//

public class RouteCallbacks {
    public static let shared = RouteCallbacks()
    
    private var callbacks: [String: (Any?) -> Void] = [:]
    
    private init() {}
    
    func setCallback(for route: any RouteProtocol, completion: @escaping (Any?) -> Void) {
        callbacks[route.id] = completion
    }
    
    func executeCallback(for route: any RouteProtocol, with data: Any?) {
        callbacks[route.id]?(data)
        callbacks.removeValue(forKey: route.id) // 执行后移除回调
    }
}
