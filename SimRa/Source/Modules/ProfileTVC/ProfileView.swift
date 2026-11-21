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

    // MARK: - Localization Keys

    // Keep picker values in a stable order so changing the app language
    // re-localizes the labels without changing the stored selection IDs.
    private var ages: [String] {
        [
            "Please select",
            "after 2004",
            "2000-2004",
            "1995-1999",
            "1990-1994",
            "1985-1989",
            "1980-1984",
            "1975-1979",
            "1970-1974",
            "1965-1969",
            "1960-1964",
            "1955-1959",
            "1950-1954",
            "before 1950"
        ]
    }

    private var sexes: [String] {
        ["Please select", "male", "female", "diverse"]
    }

    private var experiences: [String] {
        [
            "Please select",
            "more than 10 years",
            "5 to 10 years",
            "2 to 4 years",
            "less than 2 years"
        ]
    }

    private var bikeTypes: [String] {
        [
            "(not selected)",
            "City or Trecking Bike",
            "Racing Bike",
            "E-Bike",
            "Recumbent Bike",
            "Cargo Bike",
            "Tandem",
            "Mountain Bike",
            "Other"
        ]
    }

    private var positions: [String] {
        [
            "Trouser Pocket",
            "Handlebar",
            "Jacket Pocket",
            "Handheld",
            "Bike Basket / Pannier",
            "Backpack etc.",
            "Other (please comment)"
        ]
    }

    private var regionNames: [String] {
        [
            "Please select",
            "Berlin/Potsdam",
            "London (inactive)",
            "Other",
            "Bern",
            "Pforzheim/Enzkreis",
            "Augsburg",
            "Bochum",
            "Stuttgart"
        ]
    }

    private func localizedProfileValue(_ value: String) -> String {
        NSLocalizedString(value, comment: "Profile picker value")
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
                            Text(localizedProfileValue(ages[index]))
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
                            Text(localizedProfileValue(sexes[index]))
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
                            Text(localizedProfileValue(experiences[index]))
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
                            Text(localizedProfileValue(bikeTypes[index]))
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
                            Text(localizedProfileValue(positions[index]))
                                .tag(index)
                        }
                    }
                }

                Picker(NSLocalizedString("Region", comment: "Region"), selection: $regionId) {
                    if regionNames.isEmpty {
                        Text(NSLocalizedString("Not selected", comment: "Not selected")).tag(0)
                    } else {
                        ForEach(regionNames.indices, id: \.self) { index in
                            Text(localizedProfileValue(regionNames[index])).tag(index)
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
        .onAppear {
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
