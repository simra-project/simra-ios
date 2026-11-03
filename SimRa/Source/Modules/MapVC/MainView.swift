//
//  MainView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import MapKit

struct MainView: View {

    @StateObject private var vm = MainViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .sheet(
                    isPresented: $vm.showHazardMap
                ) {
                    SimRaHazardMapView()
                }
                .sheet(
                    isPresented: $vm.showOBSConfig
                ) {
                    NavigationStack {
                        OBSConfigView()
                    }
                }
                .alert(
                    NSLocalizedString(
                        "How To",
                        comment: "How To"
                    ),
                    isPresented: $vm.showHowToAlert
                ) {
                    howToAlertButtons
                } message: {
                    Text(
                        NSLocalizedString(
                            "Would you like to view the User Manual?\n\nIf not, you can access it later via Settings / How To.",
                            comment: "User manual prompt"
                        )
                    )
                }
                .alert(
                    NSLocalizedString(
                        "Please choose a Region",
                        comment: "Region alert title"
                    ),
                    isPresented: $vm.showRegionAlert
                ) {
                    regionAlertButtons
                } message: {
                    Text(vm.regionAlertMessage)
                }
                .navigationDestination(
                    isPresented: $vm.navigateToTrips
                ) {
                    MyTripsView()
                }
                .navigationDestination(
                    isPresented: $vm.navigateToTripEdit
                ) {
                    if let trip = vm.tripToEdit {
                        TripEditView(
                            viewModel:
                                TripEditViewModel(
                                    trip: trip
                                ),
                            showDetailsOnAppear: true
                        )
                    }
                }
        }
    }

    // MARK: - Content

    private var content: some View {
        ZStack {
            mapView
            recordingAction
        }
        .ignoresSafeArea(
            edges: [
                .horizontal,
                .bottom
            ]
        )
    }

    // MARK: - Map

    private var mapView: some View {
        Group {
            if vm.offlineMapMode {
                OfflineRecordingRouteView(
                    coordinates:
                        vm.recordingRouteCoordinates,
                    incidents:
                        vm.recordingIncidents,
                    showRoute:
                        vm.shouldRenderRecordingRoute
                )
            } else {
                Map(
                    position: $vm.cameraPosition
                ) {
                    UserAnnotation()
                    if vm.shouldRenderRecordingRoute {
                        recordingRoute
                    }
                    recordingIncidentMarkers
                }
                .mapStyle(
                    .standard(
                        elevation: .realistic
                    )
                )
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
            }
        }
        .accessibilityElement(
            children: .contain
        )
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "Map",
                    comment: "Map accessibility label"
                )
            )
        )
    }

    @MapContentBuilder
    private var recordingRoute: some MapContent {
        if let route = vm.recordingRouteOverlay {
            MapPolyline(route)
                .stroke(
                    .tint,
                    style: StrokeStyle(
                        lineWidth: 5,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
        }
    }

    @MapContentBuilder
    private var recordingIncidentMarkers: some MapContent {
        ForEach(vm.recordingIncidents) { incident in
            Annotation(
                "",
                coordinate: incident.coordinate
            ) {
                Image(
                    systemName:
                        "exclamationmark.triangle.fill"
                )
                .font(
                    .caption.weight(.bold)
                )
                .foregroundStyle(.white)
                .frame(
                    width: 30,
                    height: 30
                )
                .background(
                    incidentColor(
                        for: incident
                    ),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(
                            .white,
                            lineWidth: 2
                        )
                }
                .accessibilityLabel(
                    Text(
                        NSLocalizedString(
                            "Reported danger",
                            comment: "Recorded danger marker"
                        )
                    )
                )
            }
        }
    }

    // MARK: - Recording Action

    private var recordingAction: some View {
        VStack {
            Spacer()

            RecordingControl(
                isRecording: vm.isRecording,
                recordingStatusText: vm.recordingStatusText,
                isTransitioning: vm.recordingTransitionInProgress,
                startAction: vm.toggleRecording,
                stopAction: vm.toggleRecording,
                incidentAction: vm.markIncident
            )
            .frame(
                maxWidth: 420
            )
            .padding(
                .horizontal,
                20
            )
            .padding(
                .bottom,
                28
            )
        }
        .allowsHitTesting(true)
    }

    private func incidentColor(
        for incident: RecordingIncident
    ) -> Color {
        switch incident.source {
        case "Siri":
            return .blue

        case "Live Activity":
            return .purple

        default:
            return .orange
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(
            placement: .topBarLeading
        ) {
            settingsButton
        }

        ToolbarItemGroup(
            placement: .topBarTrailing
        ) {
            hazardMapButton
            tripsButton

            if vm.showOpenBikeSensorButton {
                bikeSensorButton
            }
        }
    }

    private var settingsButton: some View {
        NavigationLink {
            SettingsView()
        } label: {
            Image(
                systemName: "gearshape"
            )
        }
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "Settings",
                    comment: "Settings"
                )
            )
        )
        .accessibilityHint(
            Text(
                NSLocalizedString(
                    "Open SimRa settings",
                    comment: "Settings hint"
                )
            )
        )
        .disabled(
            vm.isRecording
        )
    }

    private var hazardMapButton: some View {
        Button {
            vm.toggleHazardMap()
        } label: {
            Image(
                systemName:
                    "exclamationmark.triangle"
            )
        }
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "SimRa Hazard Map",
                    comment: "SimRa Hazard Map"
                )
            )
        )
        .accessibilityHint(
            Text(
                NSLocalizedString(
                    "Open the SimRa street safety map",
                    comment: "Hazard map hint"
                )
            )
        )
        .disabled(
            vm.isRecording
        )
    }

    private var tripsButton: some View {
        NavigationLink {
            MyTripsView()
        } label: {
            Image(
                systemName:
                    "list.bullet"
            )
        }
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "My Trips",
                    comment: "My Trips"
                )
            )
        )
        .accessibilityHint(
            Text(
                NSLocalizedString(
                    "Open recorded trips",
                    comment: "My Trips hint"
                )
            )
        )
        .disabled(
            vm.isRecording
        )
    }

    private var bikeSensorButton: some View {
        Button {
            vm.openOBSConfig()
        } label: {
            Image(
                systemName:
                    "sensor.tag.radiowaves.forward"
            )
        }
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "OpenBikeSensor",
                    comment: "OpenBikeSensor"
                )
            )
        )
        .accessibilityHint(
            Text(
                NSLocalizedString(
                    "Open OpenBikeSensor settings",
                    comment: "OBS hint"
                )
            )
        )
        .disabled(
            vm.isRecording
        )
    }

    // MARK: - How To Alert

    @ViewBuilder
    private var howToAlertButtons: some View {
        Button(
            NSLocalizedString(
                "OK",
                comment: "OK"
            )
        ) {
            vm.confirmHowTo()
        }

        Button(
            NSLocalizedString(
                "Cancel",
                comment: "Cancel"
            ),
            role: .cancel
        ) {
            vm.skipHowTo()
        }
    }

    // MARK: - Region Alert

    @ViewBuilder
    private var regionAlertButtons: some View {
        Button(
            NSLocalizedString(
                "Yes",
                comment: "Yes"
            )
        ) {
            vm.openRegionSettings()
        }

        Button(
            NSLocalizedString(
                "Later",
                comment: "Later"
            ),
            role: .cancel
        ) {
        }

        Button(
            NSLocalizedString(
                "Don't show this again",
                comment: "Don't show this again"
            )
        ) {
            vm.suppressRegionMessage()
        }
    }
}

private struct OfflineRecordingRouteView: View {
    let coordinates: [CLLocationCoordinate2D]
    let incidents: [RecordingIncident]
    let showRoute: Bool

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                guard showRoute, coordinates.count > 1 else {
                    return
                }

                let latitudes = coordinates.map(\.latitude)
                let longitudes = coordinates.map(\.longitude)
                guard
                    let minLatitude = latitudes.min(),
                    let maxLatitude = latitudes.max(),
                    let minLongitude = longitudes.min(),
                    let maxLongitude = longitudes.max()
                else {
                    return
                }

                let latitudeSpan = max(maxLatitude - minLatitude, 0.00001)
                let longitudeSpan = max(maxLongitude - minLongitude, 0.00001)
                let inset: CGFloat = 24

                func point(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
                    CGPoint(
                        x: inset + (coordinate.longitude - minLongitude) / longitudeSpan
                            * max(size.width - inset * 2, 1),
                        y: size.height - inset - (coordinate.latitude - minLatitude) / latitudeSpan
                            * max(size.height - inset * 2, 1)
                    )
                }

                var path = Path()
                path.move(to: point(coordinates[0]))
                for coordinate in coordinates.dropFirst() {
                    path.addLine(to: point(coordinate))
                }

                context.stroke(
                    path,
                    with: .color(.blue),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )
            }
            .background(Color(.secondarySystemBackground))
            .overlay {
                if coordinates.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("No route recorded", comment: "Offline route empty state"),
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Recording Control

private struct RecordingControl: View {

    let isRecording: Bool
    let recordingStatusText: String?
    let isTransitioning: Bool
    let startAction: () -> Void
    let stopAction: () -> Void
    let incidentAction: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                LiquidGlassRecordingControl(
                    isRecording: isRecording,
                    recordingStatusText: recordingStatusText,
                    startAction: startAction,
                    stopAction: stopAction,
                    incidentAction: incidentAction
                )
            } else {
                LegacyRecordingControl(
                    isRecording: isRecording,
                    recordingStatusText: recordingStatusText,
                    startAction: startAction,
                    stopAction: stopAction,
                    incidentAction: incidentAction
                )
            }
        }
        .allowsHitTesting(!isTransitioning)
        .opacity(isTransitioning ? 0.65 : 1)
    }
}

// MARK: - iOS 26 Recording Control

@available(iOS 26.0, *)
private struct LiquidGlassRecordingControl: View {

    let isRecording: Bool
    let recordingStatusText: String?
    let startAction: () -> Void
    let stopAction: () -> Void
    let incidentAction: () -> Void

    private let controlHeight: CGFloat = 76
    private let spacing: CGFloat = 8

    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(
            spacing: spacing
        ) {
            ZStack {
                if isRecording {
                    recordingControls
                } else {
                    startButton
                }
            }
        }
        .animation(
            .spring(
                response: 0.46,
                dampingFraction: 0.84
            ),
            value: isRecording
        )
    }

    // MARK: Start

    private var startButton: some View {
        Button(
            action: startAction
        ) {
            HStack(
                spacing: 8
            ) {
                Image(
                    systemName:
                        "record.circle"
                )
                .font(
                    .system(
                        size: 20,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .green
                )

                Text(
                    NSLocalizedString(
                        "Start Ride",
                        comment: "Start ride button"
                    )
                )
                .font(
                    .body.weight(.semibold)
                )
                .foregroundStyle(
                    .primary
                )
                .lineLimit(1)
            }
            .padding(
                .horizontal,
                28
            )
            .frame(
                height: controlHeight
            )
        }
        .buttonStyle(
            .plain
        )
        .glassEffect(
            .clear
                .tint(
                    .green.opacity(0.32)
                )
                .interactive(),
            in: Capsule()
        )
        .glassEffectID(
            "recordingMainControl",
            in: glassNamespace
        )
        .glassEffectTransition(
            .matchedGeometry
        )
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "Start Ride",
                    comment: "Start ride button"
                )
            )
        )
        .accessibilityHint(
            Text(
                NSLocalizedString(
                    "Start a new ride",
                    comment: "Start ride hint"
                )
            )
        )
    }

    // MARK: Recording Controls

    private var recordingControls: some View {
        HStack(
            alignment: .center,
            spacing: spacing
        ) {
            stopButton
            incidentButton
        }
        .fixedSize(
            horizontal: true,
            vertical: true
        )
        .transition(
            .opacity
                .combined(
                    with: .scale(
                        scale: 0.96
                    )
                )
        )
    }

    // MARK: Stop

    private var stopButton: some View {
        Button(
            action: stopAction
        ) {
            HStack(
                spacing: 8
            ) {
                Image(
                    systemName:
                        "stop.fill"
                )
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .red
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(
                        NSLocalizedString(
                            "Stop",
                            comment: "Stop recording button"
                        )
                    )
                    .font(
                        .body.weight(.semibold)
                    )
                    .foregroundStyle(
                        .primary
                    )
                    .lineLimit(1)

                    if let recordingStatusText,
                       !recordingStatusText.isEmpty {
                        Text(
                            recordingStatusText
                        )
                        .font(
                            .caption.weight(.medium)
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .monospacedDigit()
                        .lineLimit(1)
                    }
                }
            }
            .padding(
                .horizontal,
                22
            )
            .frame(
                height: controlHeight
            )
        }
        .buttonStyle(
            .plain
        )
        .glassEffect(
            .clear
                .tint(
                    .red.opacity(0.32)
                )
                .interactive(),
            in: Capsule()
        )
        .glassEffectID(
            "recordingMainControl",
            in: glassNamespace
        )
        .glassEffectTransition(
            .matchedGeometry
        )
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "Stop",
                    comment: "Stop recording button"
                )
            )
        )
        .accessibilityValue(
            Text(
                recordingStatusText ?? ""
            )
        )
        .accessibilityHint(
            Text(
                NSLocalizedString(
                    "Stop the current ride",
                    comment: "Stop ride hint"
                )
            )
        )
    }

    // MARK: Incident

    private var incidentButton: some View {
        Button(
            action: incidentAction
        ) {
            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(
                .system(
                    size: 20,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .orange
            )
            .frame(
                width: controlHeight,
                height: controlHeight
            )
        }
        .buttonStyle(
            .plain
        )
        .glassEffect(
            .clear
                .tint(
                    .orange.opacity(0.32)
                )
                .interactive(),
            in: Circle()
        )
        .glassEffectID(
            "incidentControl",
            in: glassNamespace
        )
        .glassEffectTransition(
            .matchedGeometry
        )
        .transition(
            .asymmetric(
                insertion:
                    .scale(
                        scale: 0.55
                    )
                    .combined(
                        with: .opacity
                    )
                    .combined(
                        with: .offset(
                            x: -55,
                            y: 0
                        )
                    ),
                removal:
                    .scale(
                        scale: 0.55
                    )
                    .combined(
                        with: .opacity
                    )
                    .combined(
                        with: .offset(
                            x: -55,
                            y: 0
                        )
                    )
            )
        )
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            Text(
                NSLocalizedString(
                    "Report danger",
                    comment: "Report danger button"
                )
            )
        )
        .accessibilityHint(
            Text(
                NSLocalizedString(
                    "Report a dangerous situation during the ride",
                    comment: "Report danger hint"
                )
            )
        )
    }
}

// MARK: - Legacy Recording Control

private struct LegacyRecordingControl: View {

    let isRecording: Bool
    let recordingStatusText: String?
    let startAction: () -> Void
    let stopAction: () -> Void
    let incidentAction: () -> Void

    var body: some View {
        if isRecording {
            HStack(
                alignment: .center,
                spacing: 8
            ) {
                ModernRecordActionButton(
                    isRecording: true,
                    title: NSLocalizedString(
                        "Stop",
                        comment: "Stop recording button"
                    ),
                    subtitle: recordingStatusText,
                    action: stopAction
                )

                Button(
                    action: incidentAction
                ) {
                    Image(
                        systemName:
                            "exclamationmark.triangle.fill"
                    )
                    .font(
                        .system(
                            size: 20,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .orange
                    )
                    .frame(
                        width: 76,
                        height: 76
                    )
                }
                .background(
                    .orange.opacity(0.18),
                    in: Circle()
                )
                .accessibilityLabel(
                    Text(
                        NSLocalizedString(
                            "Report danger",
                            comment: "Report danger button"
                        )
                    )
                )
            }
            .fixedSize(
                horizontal: true,
                vertical: false
            )
        } else {
            ModernRecordActionButton(
                isRecording: false,
                title: NSLocalizedString(
                    "Start Ride",
                    comment: "Start ride button"
                ),
                subtitle: nil,
                action: startAction
            )
        }
    }
}

// MARK: - Preview

struct MainView_Previews: PreviewProvider {

    static var previews: some View {
        MainView()
    }
}
