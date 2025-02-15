//
//  File.swift
//  
//
//  Created by admin on 2025/1/24.
//

import SwiftUI

/// 通用视图映射协议
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol ViewMapping {
    associatedtype RouteType: RouteProtocol
    func destinationView(for route: RouteType) -> AnyView
}
