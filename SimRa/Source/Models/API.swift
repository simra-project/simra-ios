//
//  API.swift
//  SimRa
//
//  Created by Christoph Krey on 26.04.22.
//  Copyright © 2022-2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation

@objcMembers
public class API: NSObject {
    
    private static let scheme = "https:"
    private static let host = "simra-backend.3s-rg.de:8082"
    private static let version = 13
    
    public static var APIPrefix: String {
        let prefix = "\(scheme)//\(host)/\(version)"
        print("APIprefix: \(prefix)")
        return prefix
    }
    
    public static var APIShortPrefix: String {
        let prefix = "\(scheme)//\(host)"
        print("APIprefix: \(prefix)")
        return prefix
    }
    
    public static func apiPrefix() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "API_PREFIX") as? String ?? "https://simra-backend.3s-rg.de:4998"
    }
    
    public static var apiShortPrefix: String? {
        apiPrefix()
    }
    
    public static func clientHash() -> String {
        // Centralized client hash provider; mirrors String.clientHash extension
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        let dateString = df.string(from: Date())
        let suffix = "_simra"
        let client = dateString + suffix
        // Java-like hashCode based on UTF-16 code units
        var hash: UInt32 = 0
        let utf16Chars = Array(client.utf16)
        if let first = utf16Chars.first { hash = UInt32(first) }
        for i in 1..<utf16Chars.count { hash = hash &* 31 &+ UInt32(utf16Chars[i]) }
        return String(format: "%08x", hash)
    }
}
