import SwiftUI
import CoreBluetooth

private let obsServiceUUID = CBUUID(string: "1FE7FAF9-CE63-4236-0004-000000000000")

struct OBSConfigView: View {
    @StateObject private var viewModel = OBSConfigViewModel()

    var body: some View {
        List {
            if viewModel.isConnected {
                Section("Sensor Details") {
                    LabeledContent("Left Offset", value: viewModel.leftOffset)
                    LabeledContent("Right Offset", value: viewModel.rightOffset)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Distance Indicator")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ProgressView(value: viewModel.distanceProgress)
                            .tint(viewModel.distanceProgress < 0.5 ? .red : .green)
                    }

                    Button("Disconnect Sensor", role: .destructive) {
                        viewModel.disconnect()
                    }
                }
            } else {
                Section("Discovered Devices") {
                    if viewModel.isScanning && viewModel.discoveredDevices.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Scanning for OpenBikeSensor...")
                                .foregroundStyle(.secondary)
                        }
                    } else if viewModel.discoveredDevices.isEmpty {
                        Text("No devices found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.discoveredDevices, id: \.identifier) { device in
                            Button {
                                viewModel.connect(to: device)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name ?? "Unknown Device")
                                            .foregroundStyle(.primary)
                                        Text(device.identifier.uuidString)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("OpenBikeSensor")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startSetup() }
        .onDisappear { viewModel.stopSetup() }
    }
}

@MainActor
final class OBSConfigViewModel: NSObject, ObservableObject, BluetoothDelegate {
    @Published private(set) var isConnected = false
    @Published private(set) var isScanning = false
    @Published private(set) var discoveredDevices: [CBPeripheral] = []
    @Published private(set) var leftOffset = "0 cm"
    @Published private(set) var rightOffset = "0 cm"
    @Published private(set) var distanceProgress = 0.0

    private var bluetoothManager: BluetoothManager?
    private let distanceCharacteristicUUID = CBUUID(string: "1FE7FAF9-CE63-4236-0004-000000000002")
    private let offsetCharacteristicUUID = CBUUID(string: "1FE7FAF9-CE63-4236-0004-000000000004")

    func startSetup() {
        let manager = BluetoothManager.getInstance()
        bluetoothManager = manager
        manager.delegate = self

        if manager.connected {
            isConnected = true
            isScanning = false
        } else if manager.state == .poweredOn {
            startScanning()
        }
    }

    func stopSetup() {
        bluetoothManager?.stopScanPeripheral()
        isScanning = false
    }

    func connect(to peripheral: CBPeripheral) {
        guard let bluetoothManager else { return }
        isScanning = false
        bluetoothManager.stopScanPeripheral()
        bluetoothManager.connectPeripheral(peripheral)
    }

    func disconnect() {
        bluetoothManager?.disconnectPeripheral()
        isConnected = false
        isScanning = false
        discoveredDevices.removeAll()
        startSetup()
    }

    private func startScanning() {
        isScanning = true
        bluetoothManager?.startScanPeripheral()
    }

    private func updateSensorState(for characteristic: CBCharacteristic) {
        guard let value = characteristic.value else { return }
        let bytes = [UInt8](value)

        if characteristic.uuid == distanceCharacteristicUUID, let distance = unsignedInteger(from: bytes) {
            // OBS reports the measured distance in millimetres. Keep the UI bounded
            // so an invalid packet cannot produce an invalid progress value.
            let distanceCentimeters = Double(distance) / 10.0
            distanceProgress = min(max(distanceCentimeters / 200.0, 0), 1)
        } else if characteristic.uuid == offsetCharacteristicUUID {
            let offsets = parseOffsets(from: bytes)
            if let left = offsets.left {
                leftOffset = "\(left) cm"
            }
            if let right = offsets.right {
                rightOffset = "\(right) cm"
            }
        }
    }

    private func unsignedInteger(from bytes: [UInt8]) -> UInt32? {
        guard !bytes.isEmpty, bytes.count <= 4 else { return nil }
        return bytes.enumerated().reduce(UInt32(0)) { result, item in
            result | (UInt32(item.element) << UInt32(item.offset * 8))
        }
    }

    private func parseOffsets(from bytes: [UInt8]) -> (left: Int?, right: Int?) {
        guard bytes.count >= 4 else { return (nil, nil) }
        let left = Int(UInt16(bytes[0]) | (UInt16(bytes[1]) << 8))
        let right = Int(UInt16(bytes[2]) | (UInt16(bytes[3]) << 8))
        return (left, right)
    }

    nonisolated func didDiscoverPeripheral(
        _ peripheral: CBPeripheral,
        advertisementData: [String: Any],
        RSSI: NSNumber
    ) {
        Task { @MainActor in
            guard !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) else {
                return
            }
            discoveredDevices.append(peripheral)
        }
    }

    nonisolated func didConnectedPeripheral(_ connectedPeripheral: CBPeripheral) {
        Task { @MainActor in
            isConnected = true
            isScanning = false
        }
    }

    nonisolated func didDisconnectPeripheral(_ peripheral: CBPeripheral) {
        Task { @MainActor in
            isConnected = false
            startScanning()
        }
    }

    nonisolated func didUpdateState(_ state: CBManagerState) {
        Task { @MainActor in
            if state == .poweredOn {
                startScanning()
            } else {
                isScanning = false
            }
        }
    }

    nonisolated func didDiscoverServices(_ peripheral: CBPeripheral) {
        Task { @MainActor in
            bluetoothManager?.discoverCharacteristics()
        }
    }

    nonisolated func didDiscoverCharacteritics(_ service: CBService) {
        guard service.uuid == obsServiceUUID else { return }

        Task { @MainActor in
            bluetoothManager?.addCharacteristics(service)

            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid == distanceCharacteristicUUID ||
                    characteristic.uuid == offsetCharacteristicUUID {
                    bluetoothManager?.readValueForCharacteristic(characteristic: characteristic)
                    bluetoothManager?.setNotification(enable: true, forCharacteristic: characteristic)
                }
            }
        }
    }

    nonisolated func didReadValueForCharacteristic(_ characteristic: CBCharacteristic) {
        Task { @MainActor in
            updateSensorState(for: characteristic)
        }
    }
}
