//
//  File.swift
//  
//
//  Created by admin on 2025/1/24.
//

/// 将应用内所有路由统一到一个枚举里
public enum AppRoute: RouteProtocol {
    case main(MainRoute)
    case sub(SubModuleRoute)
    
    public var id: String {
        switch self {
        case let .main(m):
            return "AppRoute_main_\(m.id)"
        case let .sub(s):
            return "AppRoute_sub_\(s.id)"
        }
    }
}
