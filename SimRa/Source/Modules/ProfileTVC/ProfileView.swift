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
            NSLocalizedString("City or Trekking Bike", comment: "Bike type"),
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
        }
        .navigationTitle(NSLocalizedString("Profile", comment: "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .animation(
            .smooth,
            value: behaviour
        )
        .task {
            loadRegion()
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
    }

    // MARK: - Set Language

    private func setAppLanguage(_ languageCode: String) {
        LanguageLocalization.apply(languageCode)
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
