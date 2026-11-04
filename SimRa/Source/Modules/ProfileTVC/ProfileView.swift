//
//  ProfileView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct ProfileView: View {

    // MARK: - Profile

    @AppStorage("ageId")
    private var ageId: Int = 0

    @AppStorage("sexId")
    private var sexId: Int = 0

    @AppStorage("experienceId")
    private var experienceId: Int = 0

    @AppStorage("bikeTypeId")
    private var profileBikeTypeId: Int = 0

    @AppStorage("positionId")
    private var profilePositionId: Int = 0

    @State private var regionId: Int = 0
    @State private var regionSelected: Bool = false

    // MARK: - Language

    @AppStorage("appLanguage")
    private var appLanguage: String = "auto"

    // MARK: - Behaviour

    @AppStorage("behaviour")
    private var behaviour: Bool = false

    @AppStorage("behaviourValue")
    private var behaviourValue: Double = 0.5

    // MARK: - Statistics

    @State private var totalRides: Int = 0
    @State private var totalLength: Double = 0
    @State private var totalDuration: Int = 0
    @State private var totalIncidents: Int = 0

    // MARK: - Constants

    private var constants: [String: Any] {
        AppDelegate.shared().constants
    }

    private var ages: [String] {
        if let arr = constants["ages"] as? [String], !arr.isEmpty { return arr }
        return [
            NSLocalizedString("Please select", comment: "Age fallback"),
            "<18",
            "18-25",
            "26-35",
            "36-45",
            "46-55",
            "56-65",
            ">65"
        ]
    }

    private var sexes: [String] {
        if let arr = constants["sexes"] as? [String], !arr.isEmpty { return arr }
        return [
            NSLocalizedString("Please select", comment: "Gender fallback"),
            NSLocalizedString("male", comment: "Gender"),
            NSLocalizedString("female", comment: "Gender"),
            NSLocalizedString("diverse", comment: "Gender")
        ]
    }

    private var experiences: [String] {
        if let arr = constants["experiences"] as? [String], !arr.isEmpty { return arr }
        return [
            NSLocalizedString("Please select", comment: "Experience fallback"),
            NSLocalizedString("more than 10 years", comment: "Experience"),
            NSLocalizedString("5 to 10 years", comment: "Experience"),
            NSLocalizedString("2 to 4 years", comment: "Experience"),
            NSLocalizedString("less than 2 years", comment: "Experience")
        ]
    }

    private var bikeTypes: [String] {
        if let arr = constants["bikeTypes"] as? [String], !arr.isEmpty { return arr }
        return [
            NSLocalizedString("(not selected)", comment: "Bike type fallback"),
            NSLocalizedString("City or Trecking Bike", comment: "Bike type"),
            NSLocalizedString("Racing Bike", comment: "Bike type"),
            NSLocalizedString("E-Bike", comment: "Bike type"),
            NSLocalizedString("Recumbent Bike", comment: "Bike type"),
            NSLocalizedString("Cargo Bike", comment: "Bike type"),
            NSLocalizedString("Tandem", comment: "Bike type"),
            NSLocalizedString("Mountain Bike", comment: "Bike type"),
            NSLocalizedString("Other", comment: "Bike type")
        ]
    }

    private var positions: [String] {
        if let arr = constants["positions"] as? [String], !arr.isEmpty { return arr }
        return [
            NSLocalizedString("Trouser Pocket", comment: "Position"),
            NSLocalizedString("Handlebar", comment: "Position"),
            NSLocalizedString("Jacket Pocket", comment: "Position"),
            NSLocalizedString("Handheld", comment: "Position"),
            NSLocalizedString("Bike Basket / Pannier", comment: "Position"),
            NSLocalizedString("Backpack etc.", comment: "Position"),
            NSLocalizedString("Other (please comment)", comment: "Position")
        ]
    }

    private var regionNames: [String] {
        if let regionsArray = constants["regions"] as? [String], !regionsArray.isEmpty {
            return regionsArray
        }
        return AppDelegate.shared().regions.regionTextsSorted()
    }

    private var languages: [(code: String, name: String)] {
        [
            ("auto", NSLocalizedString("Automatic", comment: "Language")),
            ("de", "Deutsch"),
            ("en", "English"),
            ("fr", "Français")
        ]
    }

    // MARK: - Body

    var body: some View {

        Form {

            // MARK: Profile

            Section {
                Picker(NSLocalizedString("Age", comment: "Age"), selection: $ageId) {
                    if ages.isEmpty {
                        Text(NSLocalizedString("Not available", comment: "Not available"))
                            .tag(0)
                    } else {
                        ForEach(ages.indices, id: \.self) { index in
                            Text(ages[index])
                                .tag(index)
                        }
                    }
                }

                Picker(NSLocalizedString("Gender", comment: "Gender"), selection: $sexId) {
                    if sexes.isEmpty {
                        Text(NSLocalizedString("Not available", comment: "Not available"))
                            .tag(0)
                    } else {
                        ForEach(sexes.indices, id: \.self) { index in
                            Text(sexes[index])
                                .tag(index)
                        }
                    }
                }

                Picker(NSLocalizedString("Experience", comment: "Experience"), selection: $experienceId) {
                    if experiences.isEmpty {
                        Text(NSLocalizedString("Not available", comment: "Not available"))
                            .tag(0)
                    } else {
                        ForEach(experiences.indices, id: \.self) { index in
                            Text(experiences[index])
                                .tag(index)
                        }
                    }
                }

                Picker(NSLocalizedString("Bicycle type", comment: "Bicycle type"), selection: $profileBikeTypeId) {
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

                Picker(NSLocalizedString("Position", comment: "Position"), selection: $profilePositionId) {
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

                Picker(NSLocalizedString("Region", comment: "Region"), selection: $regionId) {
                    if regionNames.isEmpty {
                        Text(NSLocalizedString("Not selected", comment: "Not selected")).tag(0)
                    } else {
                        ForEach(regionNames.indices, id: \.self) { index in
                            Text(regionNames[index]).tag(index)
                        }
                    }
                }
                .onChange(of: regionId) { _, _ in
                    saveRegion()
                }

                Picker(NSLocalizedString("Language", comment: "Language"), selection: $appLanguage) {
                    ForEach(languages, id: \.code) { language in
                        Text(language.name).tag(language.code)
                    }
                }
                .onChange(of: appLanguage) { _, newLanguage in
                    setAppLanguage(newLanguage)
                }
            } header: {
                Text(NSLocalizedString("Profile", comment: "Profile"))
            } footer: {
                Text(NSLocalizedString("These data are used exclusively for statistical evaluations.", comment: "These data are used exclusively for statistical evaluations."))
            }

            // MARK: Behaviour

            Section {
                Toggle(
                    NSLocalizedString("Record riding behavior", comment: "Record riding behavior"),
                    isOn: $behaviour
                )

                if behaviour {

                    VStack(
                        alignment: .leading,
                        spacing: 8
                    ) {

                        HStack {

                            Text(NSLocalizedString("Stick to rules", comment: "Stick to rules"))

                            Spacer()

                            Text(
                                "\(Int(behaviourValue * 100)) %"
                            )
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }

                        Slider(
                            value: $behaviourValue,
                            in: 0...1,
                            step: 0.1
                        )
                    }
                    .transition(.opacity)
                }

            } header: {

                Text(NSLocalizedString("Riding behavior", comment: "Riding behavior"))

            } footer: {

                Text(NSLocalizedString("SimRa can record and evaluate your riding behavior during a ride.", comment: "SimRa can record and evaluate your riding behavior during a ride."))
            }

            // MARK: Statistics

            Section {

                HStack {

                    Label(
                        NSLocalizedString("Trips", comment: "Trips"),
                        systemImage: "bicycle"
                    )

                    Spacer()

                    Text(
                        "\(totalRides)"
                    )
                    .fontWeight(.semibold)
                    .monospacedDigit()
                }

                HStack {

                    Label(
                        NSLocalizedString("Total distance", comment: "Total distance"),
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )

                    Spacer()

                    Text(
                        formattedDistance
                    )
                    .fontWeight(.semibold)
                    .monospacedDigit()
                }

                HStack {

                    Label(
                        NSLocalizedString("Total duration", comment: "Total duration"),
                        systemImage: "clock"
                    )

                    Spacer()

                    Text(
                        formattedDuration
                    )
                    .fontWeight(.semibold)
                    .monospacedDigit()
                }

                HStack {

                    Label(
                        NSLocalizedString("Total incidents", comment: "Total incidents"),
                        systemImage: "exclamationmark.triangle"
                    )

                    Spacer()

                    Text(
                        "\(totalIncidents)"
                    )
                    .fontWeight(.semibold)
                    .monospacedDigit()
                }

                if totalRides > 0 {
                    HStack {
                        Label(
                            NSLocalizedString("Average distance", comment: "Average distance"),
                            systemImage: "arrow.triangle.swap"
                        )

                        Spacer()

                        Text(
                            formattedAverageDistance
                        )
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    }

                    HStack {
                        Label(
                            NSLocalizedString("CO₂ saved", comment: "CO₂ saved"),
                            systemImage: "leaf"
                        )

                        Spacer()

                        Text(
                            formattedCO2
                        )
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    }
                }

            } header: {

                Text(NSLocalizedString("Overview", comment: "Overview"))
            }

            // MARK: Chart

            Section {

                DSBarChart(
                    references: [
                        NSLocalizedString("Trips", comment: "Trips"),
                        NSLocalizedString("Distance (km)", comment: "Distance in km")
                    ],
                    values: [
                        Double(totalRides),
                        totalLength / 1000.0
                    ]
                )
                .frame(height: 190)

            } header: {

                Text(NSLocalizedString("Statistics", comment: "Statistics"))

            } footer: {

                Text(NSLocalizedString("The bars show your previous rides and the distance covered.", comment: "The bars show your previous rides and the distance covered."))
            }
        }
        .navigationTitle(NSLocalizedString("Profile", comment: "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(
            .smooth,
            value: behaviour
        )
        .onAppear {
            loadRegion()
            loadStatistics()
        }
    }

    // MARK: - Load Region

    private func loadRegion() {
        let appDelegate = AppDelegate.shared()
        regionId = appDelegate.regions.regionId
        regionSelected = appDelegate.regions.regionSelected
    }

    // MARK: - Save Region

    private func saveRegion() {
        let appDelegate = AppDelegate.shared()
        appDelegate.regions.selectPosition(regionId)
        loadStatistics()
    }

    // MARK: - Set Language

    private func setAppLanguage(_ languageCode: String) {
        if languageCode == "auto" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }

    // MARK: - Load Statistics

    private func loadStatistics() {
        let appDelegate = AppDelegate.shared()
        let regionId = appDelegate.regions.regionId

        totalRides = appDelegate.defaults.integer(forKey: withRegionId("totalRides", regionId: regionId))
        totalLength = Double(appDelegate.defaults.integer(forKey: withRegionId("totalLength", regionId: regionId)))
        totalDuration = appDelegate.defaults.integer(forKey: withRegionId("totalDuration", regionId: regionId))
        totalIncidents = appDelegate.defaults.integer(forKey: withRegionId("totalIncidents", regionId: regionId))
    }

    private func withRegionId(_ key: String, regionId: Int) -> String {
        if regionId == 0 {
            return key
        }
        return "\(key)-\(regionId)"
    }

    // MARK: - Formatting

    private var durationInSeconds: Int {
        // If stored in milliseconds (legacy SimRa stored ms, e.g. 3,600,000 for 1h)
        if totalDuration > 100_000 {
            return totalDuration / 1000
        }
        return totalDuration
    }

    private var formattedDistance: String {

        let kilometers = totalLength / 1000.0

        if kilometers < 100 {
            return String(
                format: "%.1f km",
                kilometers
            )
        }

        return String(
            format: "%.0f km",
            kilometers
        )
    }

    private var formattedAverageDistance: String {
        guard totalRides > 0 else { return "0.0 km" }
        let avgKm = (totalLength / 1000.0) / Double(totalRides)
        return String(format: "%.1f km", avgKm)
    }

    private var formattedCO2: String {
        let kilometers = totalLength / 1000.0
        let co2Kg = kilometers * 0.138
        if co2Kg < 10 {
            return String(format: "%.2f kg", co2Kg)
        }
        return String(format: "%.1f kg", co2Kg)
    }

    private var formattedDuration: String {
        let seconds = durationInSeconds
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return String(format: "%d h %d min", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ProfileView()
        }
    }
}
