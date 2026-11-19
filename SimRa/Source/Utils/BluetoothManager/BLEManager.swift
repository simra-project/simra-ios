//
//  BLEManager.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation

@objcMembers
public class BLEManager: NSObject {
    
    public static let shared = BLEManager()
    
    // Objective-C compatibility wrapper for +[BLEManager sharedManager][cite: 12]
    @objc(sharedManager)
    public static func sharedManager() -> BLEManager {
        return shared
    }
    
    public var someProperty: String = "Default Property Value"
    
    override private init() {
        super.init()
    }
}
