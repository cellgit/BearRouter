//
//  File.swift
//  
//
//  Created by admin on 2025/1/24.
//

import SwiftUI

public extension URL {
    // URL扩展，用于处理查询参数
    var queryParameters: [String: String] {
        var params = [String: String]()
        if let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            for item in queryItems {
                params[item.name] = item.value
            }
        }
        return params
    }
}


public extension URL {
    /// 正则解析 URL 路径部分
    var routerPath: String? {
        // 获取 URL 的完整路径部分
        let fullPath = self.absoluteString
        
        // 使用正则表达式去除协议部分并获取路径
        let regex = try? NSRegularExpression(pattern: "^\\w+://([^?]+)", options: [])
        let range = NSRange(location: 0, length: fullPath.utf16.count)
        
        if let match = regex?.firstMatch(in: fullPath, options: [], range: range) {
            // 提取匹配的路径部分
            let pathRange = match.range(at: 1)
            let path = (fullPath as NSString).substring(with: pathRange)
            
            // 返回去除斜杠后的路径
            return path.trimmingCharacters(in: .init(charactersIn: "/"))
        }
        
        return nil
    }
    
}
