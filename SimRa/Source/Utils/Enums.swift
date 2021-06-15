//
//  Enums.swift
//  SimRa
//
//  Created by Hamza Khan on 01/06/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation


enum PreferenceFileNames: String{
    case profile = "Profile"
    case simraPrefs = "SimRaPrefs"
    case appPrefs = "AppPrefs"
    case keyPrefs = "KeyPrefs"
    func getFileName()->String{
        self.rawValue
    }
}
