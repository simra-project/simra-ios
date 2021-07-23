//
//  PeripheralInfo.swift
//  SimRa
//
//  Created by Hamza Khan on 15/07/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import CoreBluetooth
class PeripheralInfos: NSObject {
    @objc let peripheral: CBPeripheral
    @objc var RSSI: Int = 0
    @objc var name: String

    @objc var advertisementData: [String: Any] = [:]
    @objc var lastUpdatedTimeInterval: TimeInterval
    
    @objc init(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.lastUpdatedTimeInterval = Date().timeIntervalSince1970
        self.name = peripheral.name ?? ""
    }
    
    static func == (lhs: PeripheralInfos, rhs: PeripheralInfos) -> Bool {
        return lhs.peripheral.isEqual(rhs.peripheral)
    }
    
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(peripheral.hash)
//    }
//    override var hashValue : Int {
//        return peripheral.hash
//    }
    override var hash: Int {
        var hasher = Hasher()
        hasher.combine(peripheral.hash)
        return hasher.finalize()
    }
}
