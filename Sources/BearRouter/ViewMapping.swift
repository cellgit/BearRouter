//
//  File.swift
//  
//
//  Created by admin on 2025/1/24.
//

import SwiftUI

/// 通用视图映射协议
public protocol ViewMapping {
    associatedtype RouteType: RouteProtocol
    func destinationView(for route: RouteType) -> AnyView
}
