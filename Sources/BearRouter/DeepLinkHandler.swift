//
//  File.swift
//  
//
//  Created by admin on 2025/1/24.
//

import Foundation

/// 深链处理器协议
public protocol DeepLinkHandler {
    func handleDeepLink(_ url: URL)
}
