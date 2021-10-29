//
//  Enums.swift
//  SimRa
//
//  Created by Hamza Khan on 01/06/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import CoreBluetooth

enum PreferenceFileNames: String{
    case profile = "Profile"
    case simraPrefs = "SimRaPrefs"
    case appPrefs = "AppPrefs"
    case keyPrefs = "KeyPrefs"
    func getFileName()->String{
        self.rawValue
    }
}
enum PeripheralNotificationKeys : String { // The notification name of peripheral
    case DisconnectNotif = "disconnectNotif" // Disconnect notification name
    case CharacteristicNotif = "characteristicNotif" // Characteristic discover notification name
}

enum PeripheralCBUUID : String{
    case obsServiceUUID
    func getCBUUID()->CBUUID{
        switch self {
        case .obsServiceUUID:
            return CBUUID.init(string: "1FE7FAF9-CE63-4236-0004-000000000000")
        }
    }
    func getUUID()->String{
        switch self {
        case .obsServiceUUID:
            return "1FE7FAF9-CE63-4236-0004-000000000000"
        }
    }
}
