//
//  ClosePassInfo.swift
//  SimRa
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
