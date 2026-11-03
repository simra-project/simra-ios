//
//  NSString+hashCode.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

private let HASH_SUFFIX = "_simra"

import Foundation

extension String {
    // Java-konformes hashCode() (basiert auf UTF-16 Code Units wie in Objective-C)
    var hashCode: UInt32 {
        var hash: UInt32 = 0
        let utf16Chars = Array(self.utf16)
        if let first = utf16Chars.first {
            hash = UInt32(first)
        }
        for i in 1..<utf16Chars.count {
            hash = hash &* 31 &+ UInt32(utf16Chars[i])
        }
        return hash
    }
    
    var hashString: String {
        return String(format: "%08x", hashCode)
    }
    
    // Generiert den Client-Hash basierend auf aktuellem Datum und Suffix[cite: 31]
    static var clientHash: String {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        let dateString = df.string(from: Date())
        let client = dateString + HASH_SUFFIX // HASH_SUFFIX muss global oder via Header verfügbar sein
        return client.hashString
    }
}

