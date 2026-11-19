//
//  BluetoothObserver.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import SwiftUI
import Combine

final class BluetoothObserver: ObservableObject {
    @Published var showDisconnectAlert = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: NSNotification.Name("disconnectNotif"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("Peripheral Disconnected")
                self?.showDisconnectAlert = true
            }
            .store(in: &cancellables)
    }
}