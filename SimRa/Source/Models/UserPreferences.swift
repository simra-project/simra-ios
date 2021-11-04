//
//  UserPreferences.swift
//  SimRa
//
//  Created by Hamza Khan on 21/05/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
struct Preferences: Codable {
    var version: Int?
    var uploaded: Bool?
    var fileHash: String?
    var filePasswd: String?
    var copyStatisticsOnce: Bool?
    var totalRides : Int?
    var totalDuration : Int?
    var totalIncidents: Int?
    var totalLength: Int?
    var totalIdle : Int?
    var numberOfScary : Int?
    var totalSlots: [Int]?
    var ageId : Int?
    var sexId: Int?
    var experienceId : Int?
    var behaviour: Bool?
    var behaviourValue: Int?
    var lastTripId: Int?
    var deferredSecs: Int?
    var deferredMeters: Int?
    var bikeTypeId: Int?
    var positionId: Int?
    var childSeat : Int?
    var trailer: Bool?
    var initialMessage: Bool?
    var suppressRegionMessage: Bool?
    var onceRegionMessage: Bool?
    var AI: Bool?
//    var Trips: [String:AnyObject]
//    var TripsInfo:[String:AnyObject]
    
}
