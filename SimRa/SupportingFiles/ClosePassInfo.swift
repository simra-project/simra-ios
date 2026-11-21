//
//  ClosePassInfo.swift
//  SimRa
//
//  Created by Emil Pauls on 21.10.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import CoreLocation

@objcMembers
public final class ClosePassInfo: NSObject {
    public var location: CLLocation?
    public var rightSensorValue: NSNumber?
    public var leftSensorValue: NSNumber?
    public var leftSensor1Value: NSNumber?
    public var leftSensor2Value: NSNumber?
    public var rightSensor1Value: NSNumber?
    public var rightSensor2Value: NSNumber?
    public var detectionType: Int = 0

    public override init() {
        super.init()
    }
}
