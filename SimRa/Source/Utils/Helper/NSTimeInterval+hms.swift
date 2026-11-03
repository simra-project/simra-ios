//
//  NSTimeInterval+hms.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import Foundation

extension TimeInterval {
    func hmsFormatted() -> String {
        let absolute = abs(self)
        let hours = floor(absolute / 3600.0)
        let minutes = floor((absolute.truncatingRemainder(dividingBy: 3600.0)) / 60.0)
        let seconds = floor(absolute.truncatingRemainder(dividingBy: 60.0))
        let sign = self < 0 ? "-" : ""
        
        return String(format: "%@%02.0f:%02.0f:%02.0f", sign, hours, minutes, seconds)
    }
}