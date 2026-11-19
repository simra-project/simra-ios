//
//  TripSettingsView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct TripSettingsView: View {

    // MARK: - Start Delay

    @AppStorage("deferredSecs")
    private var startSecs: Double = 0

    @AppStorage("deferredMeters")
    private var startMeters: Double = 0


    // MARK: - Default Bicycle Equipment

    @AppStorage("bikeTypeId")
    private var bikeTypeId: Int = 0

    @AppStorage("positionId")
    private var positionId: Int = 0

    @AppStorage("childSeat")
    private var childSeat: Bool = false

    @AppStorage("trailer")
    private var trailer: Bool = false

    // MARK: - Constants

    private var constants: [String: Any] {
        AppDelegate.shared().constants
    }

    private var bikeTypes: [String] {
        constants["bikeTypes"] as? [String] ?? []
    }

    private var positions: [String] {
        constants["positions"] as? [String] ?? []
    }


    // MARK: - Recording

    @AppStorage("AI")
    private var aiMode: Bool = false


    // MARK: - Sensors

    @AppStorage("openBikeSensor")
    private var openBikeSensor: Bool = false


    // MARK: - Body

    var body: some View {
        Form {

            // MARK: Recording Start

            Section {
                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    HStack {
                        Text(NSLocalizedString("Time", comment: "Time"))

                        Spacer()

                        Text("\(Int(startSecs)) s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: $startSecs,
                        in: 0...60,
                        step: 1
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {
                    HStack {
                        Text(NSLocalizedString("Distance", comment: "Distance"))

                        Spacer()

                        Text("\(Int(startMeters)) m")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Slider(
                        value: $startMeters,
                        in: 0...100,
                        step: 1
                    )
                }

            } header: {
                Text(NSLocalizedString("Recording start delay", comment: "Recording start delay"))
            } footer: {
                Text(
                    NSLocalizedString(
                        "Die Aufzeichnung beginnt erst, wenn die gewählte Zeit oder Strecke erreicht wurde.",
                        value: "Die Aufzeichnung beginnt erst, wenn die gewählte Zeit oder Strecke erreicht wurde.",
                        comment: "Recording starts when the selected time or distance is reached."
                    )
                )
            }


            // MARK: Defaults

            Section {
                Picker(NSLocalizedString("Bicycle type", comment: "Bicycle type"), selection: $bikeTypeId) {
                    if bikeTypes.isEmpty {
                        Text(NSLocalizedString("Not available", comment: "Not available"))
                            .tag(0)
                    } else {
                        ForEach(bikeTypes.indices, id: \.self) { index in
                            Text(bikeTypes[index])
                                .tag(index)
                        }
                    }
                }

                Picker(NSLocalizedString("Position", comment: "Position"), selection: $positionId) {
                    if positions.isEmpty {
                        Text(NSLocalizedString("Not available", comment: "Not available"))
                            .tag(0)
                    } else {
                        ForEach(positions.indices, id: \.self) { index in
                            Text(positions[index])
                                .tag(index)
                        }
                    }
                }

                Toggle(
                    NSLocalizedString("Child seat", comment: "Child seat"),
                    isOn: $childSeat
                )

                Toggle(
                    NSLocalizedString("Trailer", comment: "Trailer"),
                    isOn: $trailer
                )

            } header: {
                Text(NSLocalizedString("Defaults for new trips", comment: "Defaults for new trips"))
            } footer: {
                Text(
                    NSLocalizedString(
                        "These settings will be automatically applied to new trips.",
                        comment: "These settings will be automatically applied to new trips."
                    )
                )
            }


            // MARK: Recording

            Section {

                Toggle(
                    NSLocalizedString("AI Recording", comment: "AI Recording"),
                    isOn: $aiMode
                )

            } header: {
                Text(NSLocalizedString("Recording", comment: "Recording"))
            }


            // MARK: Sensors

            Section {

                Toggle(
                    NSLocalizedString("OpenBikeSensor", comment: "OpenBikeSensor"),
                    isOn: $openBikeSensor
                )

                if openBikeSensor {
                    Button {
                        openOpenBikeSensorConfiguration()
                    } label: {
                        Label(
                            NSLocalizedString("Configure sensor", comment: "Configure sensor"),
                            systemImage:
                                "sensor.tag.radiowaves.forward"
                        )
                    }
                }

            } header: {
                Text(NSLocalizedString("Sensors", comment: "Sensors"))
            }
        }

        // MARK: Navigation

        .navigationTitle(NSLocalizedString("Trip Settings", comment: "Trip Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }


    // MARK: - OpenBikeSensor

    private func openOpenBikeSensorConfiguration() {
        // Hier die bestehende OBS-Konfiguration anbinden.
        print("OBS Config öffnen")
    }
}


struct TripSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TripSettingsView()
        }
    }
}
