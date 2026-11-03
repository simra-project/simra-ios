//
//  SimRaWidgetsBundle.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import WidgetKit

@main
struct SimRaWidgetsBundle: WidgetBundle {

    var body: some Widget {
        SimRaRecordingWidget()
        SimRaLiveActivity()
    }
}
