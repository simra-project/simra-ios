//
//  OBSConfigView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import SwiftUI
import CoreBluetooth

struct OBSConfigView: View {
    @StateObject private var vm = OBSConfigViewModel()
    
    var body: some View {
        List {
            if vm.isConnected {
                Section(header: Text(NSLocalizedString("Sensor Details", comment: "Sensor Details"))) {
                    HStack {
                        Text(NSLocalizedString("Left Offset", comment: "Left Offset"))
                        Spacer()
                        Text(vm.leftOffset)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(NSLocalizedString("Right Offset", comment: "Right Offset"))
                        Spacer()
                        Text(vm.rightOffset)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("Distance Indicator", comment: "Distance Indicator"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ProgressView(value: vm.distanceProgress)
                            .tint(vm.distanceProgress < 0.5 ? .red : .green)
                    }
                    .padding(.vertical, 4)
                    
                    Button(role: .destructive) {
                        vm.disconnect()
                    } label: {
                        HStack {
                            Spacer()
                            Text(NSLocalizedString("Disconnect Sensor", comment: "Disconnect Sensor"))
                            Spacer()
                        }
                    }
                }
            } else {
                Section(header: Text(NSLocalizedString("Discovered Devices", comment: "Discovered Devices"))) {
                    if vm.isScanning && vm.discoveredDevices.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(NSLocalizedString("Scanning for OpenBikeSensor...", comment: "Scanning for OpenBikeSensor..."))
                                .foregroundColor(.secondary)
                        }
                    } else if vm.discoveredDevices.isEmpty {
                        Text(NSLocalizedString("No devices found", comment: "No devices found"))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vm.discoveredDevices, id: \.identifier) { device in
                            Button {
                                vm.connect(to: device)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(device.name ?? NSLocalizedString("Unknown Device", comment: "Unknown Device"))
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(device.identifier.uuidString)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("OpenBikeSensor", comment: "OpenBikeSensor"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.startSetup()
        }
        .onDisappear {
            vm.stopSetup()
        }
    }
}

// MARK: - ViewModel

@MainActor
final class OBSConfigViewModel: NSObject, ObservableObject, BluetoothDelegate {
    @Published var isConnected = false
    @Published var isScanning = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var leftOffset = "0 cm"
    @Published var rightOffset = "0 cm"
    @Published var distanceProgress: Double = 0.0
    
    private var bleManager: BluetoothManager?
    private let obsServiceUUID = CBUUID(string: "1FE7FAF9-CE63-4236-0004-000000000000")
    private let sensorDistanceUUID = CBUUID(string: "1FE7FAF9-CE63-4236-0004-000000000002")
    private let offsetUUID = CBUUID(string: "1FE7FAF9-CE63-4236-0004-000000000004")

    func startSetup() {
        bleManager = BluetoothManager.getInstance()
        bleManager?.delegate = self
        
        if bleManager?.connected == true {
            isConnected = true
        } else {
            isConnected = false
            isScanning = true
            bleManager?.startScanPeripheral()
        }
    }

    func stopSetup() {
        bleManager?.stopScanPeripheral()
    }

    func connect(to peripheral: CBPeripheral) {
        bleManager?.connectPeripheral(peripheral)
        bleManager?.stopScanPeripheral()
        isScanning = false
    }

    func disconnect() {
        bleManager?.disconnectPeripheral()
        isConnected = false
        discoveredDevices.removeAll()
        startSetup()
    }

    // MARK: - BluetoothDelegate Methods

    nonisolated func didDiscoverPeripheral(_ peripheral: CBPeripheral, advertisementData: [String : Any], RSSI: NSNumber) {
        Task { @MainActor in
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
            }
        }
    }

    nonisolated func didConnectedPeripheral(_ connectedPeripheral: CBPeripheral) {
        Task { @MainActor in
            self.isConnected = true
        }
    }

    nonisolated func didUpdateState(_ state: CBManagerState) {
        Task { @MainActor in
            if state == .poweredOn {
                self.isScanning = true
                self.bleManager?.startScanPeripheral()
            } else {
                self.isScanning = false
            }
        }
    }
}
