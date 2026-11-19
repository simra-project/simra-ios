//
//  AnnotationView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct AnnotationView: View {
    @Environment(\.dismiss) private var dismiss

    let tripAnnotation: TripAnnotation
    let trip: Trip?
    let isNew: Bool
    let onSaved: (() -> Void)?
    let onDiscard: (() -> Void)?

    // MARK: - Draft

    @State private var incidentId = 0
    @State private var frightening = false
    @State private var car = false
    @State private var taxi = false
    @State private var delivery = false
    @State private var bus = false
    @State private var commercial = false
    @State private var pedestrian = false
    @State private var bicycle = false
    @State private var motorcycle = false
    @State private var escooter = false
    @State private var other = false
    @State private var comment = ""
    @State private var loaded = false

    // MARK: - Init

    init(
        tripAnnotation: TripAnnotation,
        trip: Trip? = nil,
        isNew: Bool = false,
        onSaved: (() -> Void)? = nil,
        onDiscard: (() -> Void)? = nil
    ) {
        self.tripAnnotation = tripAnnotation
        self.trip = trip
        self.isNew = isNew
        self.onSaved = onSaved
        self.onDiscard = onDiscard
    }

    // MARK: - Constants

    private var incidentTypes: [String] {
        AppDelegate.shared()
            .constants["incidents"] as? [String] ?? []
    }

    // MARK: - Source

    private var storedSource: String {
        tripAnnotation.source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedSource: TripAnnotationSource {
        TripAnnotationSource(rawSource: storedSource)
    }

    private var sourceTitle: String {
        switch normalizedSource {
        case .automatic:
            return NSLocalizedString(
                "Automatische Erkennung",
                comment: "Automatic detection"
            )
        case .widget:
            return NSLocalizedString(
                "Widget",
                comment: "Widget or Live Activity"
            )
        case .shortcut:
            return NSLocalizedString(
                "Kurzbefehle",
                comment: "Shortcut source"
            )
        case .watch:
            return NSLocalizedString(
                "Apple Watch",
                comment: "Apple Watch source"
            )
        case .siri:
            return NSLocalizedString(
                "Siri",
                comment: "Siri"
            )
        case .manual:
            return NSLocalizedString(
                "Manuell eingetragen",
                comment: "Manually added"
            )
        case .unknown:
            return NSLocalizedString(
                "Quelle nicht bekannt",
                comment: "Unknown source"
            )
        }
    }

    private var sourceDescription: String {
        switch normalizedSource {
        case .automatic:
            return NSLocalizedString(
                "Automatisch erkannt",
                comment: "Automatic detection"
            )
        case .widget:
            return NSLocalizedString(
                "Über Widget oder Live Activity erfasst",
                comment: "Widget or Live Activity"
            )
        case .shortcut:
            return NSLocalizedString(
                "Über Kurzbefehle erfasst",
                comment: "Shortcut source"
            )
        case .watch:
            return NSLocalizedString(
                "Über die Apple Watch erfasst",
                comment: "Apple Watch source"
            )
        case .siri:
            return NSLocalizedString(
                "Über Siri erfasst",
                comment: "Siri"
            )
        case .manual:
            return NSLocalizedString(
                "Manuell auf der Karte eingetragen.",
                comment: "Added manually on map"
            )
        case .unknown:
            return NSLocalizedString(
                "Die Quelle dieses Ereignisses ist nicht bekannt.",
                comment: "Unknown source"
            )
        }
    }

    private var sourceSymbol: String {
        normalizedSource.symbolName
    }

    private var sourceTint: Color {
        switch normalizedSource {
        case .automatic:
            return .orange
        case .widget:
            return .blue
        case .shortcut:
            return .purple
        case .watch:
            return .teal
        case .siri:
            return .mint
        case .manual:
            return .blue
        case .unknown:
            return .secondary
        }
    }

    // MARK: - Change Tracking

    private var hasChanges: Bool {
        if isNew {
            return true
        }

        guard loaded else {
            return false
        }

        return incidentId != Int(tripAnnotation.incidentId)
            || frightening != tripAnnotation.frightening
            || car != tripAnnotation.car
            || taxi != tripAnnotation.taxi
            || delivery != tripAnnotation.delivery
            || bus != tripAnnotation.bus
            || commercial != tripAnnotation.commercial
            || pedestrian != tripAnnotation.pedestrian
            || bicycle != tripAnnotation.bicycle
            || motorcycle != tripAnnotation.motorcycle
            || escooter != tripAnnotation.escooter
            || other != tripAnnotation.other
            || comment != (tripAnnotation.comment ?? "")
    }

    // MARK: - Body

    var body: some View {
        Form {
            sourceSection
            incidentSection
            participantsSection
            commentSection
        }
        .navigationTitle(
            NSLocalizedString(
                "Vorfall bearbeiten",
                comment: "Edit incident"
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(
                placement: .topBarTrailing
            ) {
                Button {
                    if hasChanges {
                        saveAndDismiss()
                    } else {
                        discardAndDismiss()
                    }
                } label: {
                    Image(
                        systemName: hasChanges
                            ? "checkmark"
                            : "xmark"
                    )
                }
                .fontWeight(.semibold)
                .accessibilityLabel(
                    hasChanges
                    ? NSLocalizedString(
                        "Speichern",
                        comment: "Save"
                    )
                    : NSLocalizedString(
                        "Schließen",
                        comment: "Close"
                    )
                )
            }
        }
        .task {
            loadValuesIfNeeded()
        }
    }

    // MARK: - Source Section

    @ViewBuilder
    private var sourceSection: some View {
        Section {
            HStack(
                spacing: 12
            ) {
                Image(
                    systemName: sourceSymbol
                )
                .font(
                    .system(
                        size: 16,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    sourceTint
                )
                .frame(
                    width: 36,
                    height: 36
                )
                .background(
                    sourceTint.opacity(
                        0.12
                    ),
                    in: RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(
                        sourceTitle
                    )
                    .font(
                        .subheadline.weight(
                            .semibold
                        )
                    )

                    Text(
                        sourceDescription
                    )
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(
                        2
                    )
                }

                Spacer(
                    minLength: 0
                )
            }
            .padding(
                .vertical,
                3
            )

        } header: {
            Text(
                NSLocalizedString(
                    "Quelle",
                    comment: "Incident source"
                )
            )
        }
    }

    // MARK: - Incident Section

    private var incidentSection: some View {
        Section {
            if incidentTypes.isEmpty {
                Text(
                    NSLocalizedString(
                        "Vorfall-Art nicht verfügbar",
                        comment: "Missing incident types"
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            } else {
                Picker(
                    NSLocalizedString(
                        "Vorfall",
                        comment: "Incident type"
                    ),
                    selection: $incidentId
                ) {
                    ForEach(
                        incidentTypes.indices,
                        id: \.self
                    ) { index in
                        Text(
                            incidentTypes[
                                index
                            ]
                        )
                        .tag(
                            index
                        )
                    }
                }
            }

            Toggle(
                NSLocalizedString(
                    "Erschrecken / Gefährdung",
                    comment: "Scary or dangerous"
                ),
                isOn: $frightening
            )

        } header: {
            Text(
                NSLocalizedString(
                    "Vorfall-Art",
                    comment: "Incident type"
                )
            )
        }
    }

    // MARK: - Participants

    private var participantsSection: some View {
        Section {
            vehicleToggle(
                "Auto",
                "car.fill",
                $car
            )

            vehicleToggle(
                "Taxi",
                "car.fill",
                $taxi
            )

            vehicleToggle(
                "Lieferwagen / Transporter",
                "truck.box.fill",
                $delivery
            )

            vehicleToggle(
                "Bus",
                "bus.fill",
                $bus
            )

            vehicleToggle(
                "LKW",
                "truck.box.fill",
                $commercial
            )

            vehicleToggle(
                "Fußgänger",
                "figure.walk",
                $pedestrian
            )

            vehicleToggle(
                "Fahrrad",
                "bicycle",
                $bicycle
            )

            vehicleToggle(
                "Motorrad",
                "motorcycle.fill",
                $motorcycle
            )

            vehicleToggle(
                "E-Scooter",
                "scooter",
                $escooter
            )

            vehicleToggle(
                "Andere",
                "ellipsis.circle",
                $other
            )

        } header: {
            Text(
                NSLocalizedString(
                    "Beteiligte Verkehrsteilnehmer",
                    comment: "Involved road users"
                )
            )
        }
    }

    // MARK: - Comment

    private var commentSection: some View {
        Section {
            TextEditor(
                text: $comment
            )
            .frame(
                minHeight: 110
            )

        } header: {
            Text(
                NSLocalizedString(
                    "Kommentar",
                    comment: "Comment"
                )
            )
        }
    }

    // MARK: - Toggle

    @ViewBuilder
    private func vehicleToggle(
        _ title: String,
        _ systemImage: String,
        _ binding: Binding<Bool>
    ) -> some View {
        Toggle(
            isOn: binding
        ) {
            Label(
                NSLocalizedString(
                    title,
                    comment: "Road user"
                ),
                systemImage: systemImage
            )
        }
    }

    // MARK: - Load

    private func loadValuesIfNeeded() {
        guard !loaded else {
            return
        }

        let rawIncidentID = Int(
            tripAnnotation.incidentId
        )

        if incidentTypes.isEmpty {
            incidentId = 0
        } else {
            incidentId = min(
                max(
                    rawIncidentID,
                    0
                ),
                incidentTypes.count - 1
            )
        }

        frightening = tripAnnotation.frightening
        car = tripAnnotation.car
        taxi = tripAnnotation.taxi
        delivery = tripAnnotation.delivery
        bus = tripAnnotation.bus
        commercial = tripAnnotation.commercial
        pedestrian = tripAnnotation.pedestrian
        bicycle = tripAnnotation.bicycle
        motorcycle = tripAnnotation.motorcycle
        escooter = tripAnnotation.escooter
        other = tripAnnotation.other
        comment = tripAnnotation.comment ?? ""

        loaded = true
    }

    // MARK: - Discard

    private func discardAndDismiss() {
        if isNew {
            onDiscard?()
        }

        dismiss()
    }

    // MARK: - Save

    private func saveAndDismiss() {
        tripAnnotation.incidentId = incidentId
        tripAnnotation.frightening = frightening
        tripAnnotation.car = car
        tripAnnotation.taxi = taxi
        tripAnnotation.delivery = delivery
        tripAnnotation.bus = bus
        tripAnnotation.commercial = commercial
        tripAnnotation.pedestrian = pedestrian
        tripAnnotation.bicycle = bicycle
        tripAnnotation.motorcycle = motorcycle
        tripAnnotation.escooter = escooter
        tripAnnotation.other = other
        tripAnnotation.comment = comment.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        trip?.edited = true
        trip?.save()

        onSaved?()

        NotificationCenter.default.post(
            name: NSNotification.Name(
                "annotationChanged"
            ),
            object: trip,
            userInfo: [
                "annotation": tripAnnotation
            ]
        )

        NotificationCenter.default.post(
            name: NSNotification.Name(
                "tripEdited"
            ),
            object: trip
        )

        dismiss()
    }
}
