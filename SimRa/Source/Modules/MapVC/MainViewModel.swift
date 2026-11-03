//
//  MainViewModel.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import MapKit
import WidgetKit
import Foundation

// MARK: - Recording Incident

struct RecordingIncident: Identifiable {

    let id: String
    let coordinate: CLLocationCoordinate2D
    let source: String

    var isQuickRecorded: Bool {
        switch source.lowercased() {
        case "siri", "widget", "live activity", "shortcut", "watch":
            return true

        default:
            return false
        }
    }
}

// MARK: - Main View Model

@MainActor
final class MainViewModel: ObservableObject {

    // MARK: - Widget State

    private enum WidgetStateKey {

        static let suiteName =
            "group.de.tu-berlin.mcc.simra"

        static let recording =
            "isRecording"

        static let startDate =
            "startDate"

        static let elapsedSeconds =
            "elapsedSeconds"

        static let distanceMeters =
            "distanceMeters"

        static let incidents =
            "incidents"

        static let routeCoordinates =
            "widgetRouteCoordinates"
    }

    private struct WidgetCoordinate: Codable {

        let latitude: Double
        let longitude: Double
    }

    // MARK: - Map

    @Published
    var cameraPosition: MapCameraPosition =
        .userLocation(
            fallback: .automatic
        )

    // MARK: - Recording

    @Published
    private(set) var isRecording = false

    @Published
    private(set) var recordingTransitionInProgress = false

    @Published
    var recordingStatusText: String?

    @Published
    var recordingRouteOverlay: MKPolyline?

    @Published
    private(set) var recordingRouteCoordinates:
        [CLLocationCoordinate2D] = []

    @Published
    private(set) var isLowPowerMode =
        ProcessInfo.processInfo.isLowPowerModeEnabled

    @Published
    var offlineMapMode =
        UserDefaults.standard.bool(forKey: "offlineMapMode")

    @Published
    var showRecordedRoute =
        UserDefaults.standard.object(forKey: "showRecordedRoute") as? Bool
        ?? true

    var shouldRenderRecordingRoute: Bool {
        showRecordedRoute && !isLowPowerMode
    }

    @Published
    private(set) var recordingIncidents: [RecordingIncident] = []

    // MARK: - Navigation

    @Published
    var navigateToTrips = false

    @Published
    var tripToEdit: Trip?

    @Published
    var navigateToTripEdit = false

    // MARK: - Bike Sensor

    @Published
    var showOpenBikeSensorButton = false

    @Published
    var showOBSConfig = false

    // MARK: - Hazard Map

    @Published
    var showHazardMap = false

    // MARK: - Alerts

    @Published
    var showHowToAlert = false

    @Published
    var showRegionAlert = false

    @Published
    var regionAlertMessage = ""

    // MARK: - Dependencies

    private let appDelegate = AppDelegate.shared()

    // MARK: - Recording Runtime

    private var timer: Timer?

    private var recordingStartedAt: Date?

    private var lastKnownRecordingState = false

    private var pendingRecordingTarget: Bool?

    // MARK: - Notifications

    private var recordingStateObserver: NSObjectProtocol?

    private var incidentObserver: NSObjectProtocol?

    private var incidentAnalysisObserver: NSObjectProtocol?

    private var powerModeObserver: NSObjectProtocol?

    private var preferencesObserver: NSObjectProtocol?

    // MARK: - Route Cache

    private var lastOverlayPointCount = 0

    private var lastRouteUpdateDate: Date?

    // MARK: - Metrics Cache

    private var cachedDistanceMeters = 0

    private var cachedIncidents = 0

    private var lastMetricsPointCount = 0

    private var lastMetricsUpdate: Date?

    private var isComputingMetrics = false

    // MARK: - Widget Cache

    private var lastWidgetRoutePointCount = -1

    private var lastWidgetTimelineReload: Date?

    private var lastWidgetSyncDate: Date?

    // MARK: - Init

    init() {

        checkInitialMessages()
        setupBluetooth()
        setupObservers()

        powerModeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isLowPowerMode =
                    ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }

        preferencesObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.offlineMapMode = UserDefaults.standard.bool(
                    forKey: "offlineMapMode"
                )
                self.showRecordedRoute = UserDefaults.standard.object(
                    forKey: "showRecordedRoute"
                ) as? Bool ?? true
            }
        }

        syncRecordingState(
            refreshHistoricalStatistics: false
        )
    }

    deinit {

        if let observer = recordingStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = incidentObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = incidentAnalysisObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = powerModeObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        if let observer = preferencesObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        timer?.invalidate()
    }

    // MARK: - Notification Setup

    private func setupObservers() {

        // Recording state changes.

        recordingStateObserver =
            NotificationCenter.default.addObserver(
                forName: .recordingSessionDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in

                Task { @MainActor in

                    guard let self else {
                        return
                    }

                    self.syncRecordingState()
                }
            }

        // Incident created from:
        // app, Siri, Widget, Live Activity, etc.

        incidentObserver =
            NotificationCenter.default.addObserver(
                forName: .incidentMarked,
                object: nil,
                queue: .main
            ) { [weak self] _ in

                Task { @MainActor in
                    self?.refreshRecordingPresentation()
                }
            }

        // Sensor analysis may finish asynchronously.

        incidentAnalysisObserver =
            NotificationCenter.default.addObserver(
                forName: .incidentAnalysisDidFinish,
                object: nil,
                queue: .main
            ) { [weak self] notification in

                Task { @MainActor in

                    guard
                        let self,
                        let trip =
                            notification.object as? Trip,
                        let activeTrip =
                            self.appDelegate.activeTrip
                    else {
                        return
                    }

                    guard
                        activeTrip.identifier ==
                        trip.identifier
                    else {
                        return
                    }

                    self.refreshRecordingPresentation()
                }
            }
    }

    // MARK: - Recording Presentation

    private func refreshRecordingPresentation() {

        guard appDelegate.activeTrip != nil else {
            return
        }

        refreshIncidentCacheOnly()

        updateRouteOverlay(
            force: true
        )

        updateStatusText()

        synchronizeWidgetState(
            reload: false
        )
    }

    // MARK: - Recording

    func toggleRecording() {

        guard !recordingTransitionInProgress else {
            return
        }

        let targetState = !isRecording

        recordingTransitionInProgress = true
        pendingRecordingTarget = targetState

        if targetState {

            let started =
                appDelegate.startRecordingRequested()

            if !started {
                recordingTransitionInProgress = false
                pendingRecordingTarget = nil
            }

        } else {

            let stopped =
                appDelegate.stopRecordingRequested()

            if !stopped {
                recordingTransitionInProgress = false
                pendingRecordingTarget = nil
            }
        }
    }

    // MARK: - Incident

    func markIncident() {

        guard isRecording else {
            return
        }

        _ = RecordingShortcutBridge.markIncident(
            0,
            source: "Manual"
        )
    }

    // MARK: - Recording State

    private func syncRecordingState(
        refreshHistoricalStatistics: Bool = false
    ) {

        let activeTrip =
            appDelegate.activeTrip

        let currentlyRecording =
            activeTrip != nil

        let previousState =
            lastKnownRecordingState

        let stateChanged =
            currentlyRecording != previousState

        isRecording =
            currentlyRecording

        recordingStartedAt =
            activeTrip?.recordingStartDate

        if currentlyRecording {

            // Hazard map must never be visible
            // while recording.

            if showHazardMap {
                showHazardMap = false
            }

            if timer == nil {
                startTimer()
            }

            updateStatusText()

            updateRouteOverlay(
                force: stateChanged
            )

            if stateChanged {

                refreshRecordingMetrics(
                    force: true
                )
            }

            synchronizeWidgetState(
                reload: stateChanged
            )

        } else {

            stopTimer()

            recordingStatusText = nil
            recordingStartedAt = nil
            recordingRouteOverlay = nil
            recordingRouteCoordinates = []
            recordingIncidents = []

            lastOverlayPointCount = 0
            lastRouteUpdateDate = nil

            lastMetricsPointCount = 0
            lastMetricsUpdate = nil
            isComputingMetrics = false

            lastWidgetRoutePointCount = -1
            lastWidgetSyncDate = nil

            synchronizeWidgetState(
                reload: true
            )

            if previousState {
                tripToEdit = appDelegate.lastStoppedTrip
                navigateToTripEdit = tripToEdit != nil
            }

            if refreshHistoricalStatistics {
                reloadWidgetTimeline()
            }
        }

        // Finish the UI transition only once the
        // actual recording state matches the requested state.

        if let pendingTarget = pendingRecordingTarget,
           pendingTarget == currentlyRecording {

            recordingTransitionInProgress = false
            pendingRecordingTarget = nil
        }

        lastKnownRecordingState =
            currentlyRecording
    }

    // MARK: - Timer

    private func startTimer() {

        timer?.invalidate()

        let newTimer =
            Timer(
                timeInterval: 1.0,
                repeats: true
            ) { [weak self] _ in

                Task { @MainActor in
                    self?.recordingTimerTick()
                }
            }

        timer = newTimer

        RunLoop.main.add(
            newTimer,
            forMode: .common
        )
    }

    private func recordingTimerTick() {

        guard isRecording else {
            return
        }

        updateStatusText()

        let now = Date()

        if shouldUpdateRoute(at: now) {
            updateRouteOverlay(
                force: true
            )
        }

        if shouldUpdateMetrics(at: now) {
            refreshRecordingMetrics()
        }

        if shouldSyncWidget(at: now) {
            synchronizeWidgetState(
                reload: false
            )
        }
    }

    private func stopTimer() {

        timer?.invalidate()
        timer = nil

        recordingStatusText = nil

        lastOverlayPointCount = 0
        lastRouteUpdateDate = nil

        lastMetricsPointCount = 0
        lastMetricsUpdate = nil

        isComputingMetrics = false

        cachedDistanceMeters = 0
        cachedIncidents = 0
    }

    // MARK: - Status

    private func updateStatusText() {

        guard let start = recordingStartedAt else {

            recordingStatusText = nil
            return
        }

        let elapsed =
            max(
                0,
                Int(
                    Date()
                        .timeIntervalSince(start)
                        .rounded()
                )
            )

        recordingStatusText =
            "\(formatElapsedTime(elapsed)) · \(formatDistance(cachedDistanceMeters))"
    }

    // MARK: - Scheduling

    private func shouldUpdateRoute(
        at date: Date
    ) -> Bool {

        guard let last = lastRouteUpdateDate else {
            return true
        }

        return date.timeIntervalSince(last) >= 2.0
    }

    private func shouldUpdateMetrics(
        at date: Date
    ) -> Bool {

        guard let last = lastMetricsUpdate else {
            return true
        }

        return date.timeIntervalSince(last) >= 5.0
    }

    private func shouldSyncWidget(
        at date: Date
    ) -> Bool {

        guard let last = lastWidgetSyncDate else {
            return true
        }

        return date.timeIntervalSince(last) >= 15.0
    }

    // MARK: - Recording Metrics

    private func refreshRecordingMetrics(
        force: Bool = false
    ) {

        guard
            let trip = appDelegate.activeTrip
        else {
            return
        }

        guard !isComputingMetrics else {
            return
        }

        let pointCount =
            trip.tripLocations.count

        if !force {

            guard
                pointCount != lastMetricsPointCount ||
                shouldUpdateMetrics(at: .now)
            else {
                return
            }
        }

        isComputingMetrics = true

        let distance =
            max(
                trip.length(),
                0
            )

        let incidents =
            max(
                trip.tripValidAnnotations(),
                0
            )

        cachedDistanceMeters =
            distance

        cachedIncidents =
            incidents

        lastMetricsPointCount =
            pointCount

        lastMetricsUpdate =
            .now

        isComputingMetrics = false

        updateStatusText()
    }

    // MARK: - Incident Cache

    private func refreshIncidentCacheOnly() {

        guard
            let trip = appDelegate.activeTrip
        else {
            return
        }

        cachedIncidents =
            max(
                trip.tripValidAnnotations(),
                0
            )

        lastMetricsPointCount =
            trip.tripLocations.count

        lastMetricsUpdate =
            .now

        updateStatusText()
    }

    // MARK: - Route Overlay

    private func updateRouteOverlay(
        force: Bool = false
    ) {
        guard isRecording,
              let trip = appDelegate.activeTrip
        else {
            recordingRouteOverlay = nil
            recordingRouteCoordinates = []
            recordingIncidents = []

            lastOverlayPointCount = 0
            lastRouteUpdateDate = nil

            return
        }

        let locations: [TripLocation] =
            (trip.tripLocations as NSArray)
                .compactMap { $0 as? TripLocation }

        let pointCount = locations.count

        // Wenn nichts Neues hinzugekommen ist, müssen wir die
        // teure Polyline-Erzeugung nicht wiederholen.
        //
        // Bei force=true wird trotzdem immer neu aufgebaut.
        if !force,
           pointCount == lastOverlayPointCount {
            return
        }

        let coordinates: [CLLocationCoordinate2D] =
            locations.compactMap { location in
                let coordinate =
                    location.location.coordinate

                guard CLLocationCoordinate2DIsValid(coordinate) else {
                    return nil
                }

                return coordinate
            }

        recordingRouteCoordinates = coordinates

        if coordinates.count >= 2 {
            recordingRouteOverlay =
                MKPolyline(
                    coordinates: coordinates,
                    count: coordinates.count
                )
        } else {
            recordingRouteOverlay = nil
        }

        // MARK: Incidents

        recordingIncidents =
            locations.compactMap { location in

                guard let annotation =
                    location.tripAnnotation
                else {
                    return nil
                }

                let coordinate =
                    location.location.coordinate

                guard CLLocationCoordinate2DIsValid(
                    coordinate
                ) else {
                    return nil
                }

                let timestamp =
                    location.location.timestamp
                        .timeIntervalSince1970

                let identifier =
                    String(
                        format:
                            "%.6f:%.6f:%.3f",
                        coordinate.latitude,
                        coordinate.longitude,
                        timestamp
                    )

                return RecordingIncident(
                    id: identifier,
                    coordinate: coordinate,
                    source: annotation.source
                )
            }

        lastOverlayPointCount = pointCount
        lastRouteUpdateDate = .now
    }
    
    // MARK: - Widget Synchronization

    private func synchronizeWidgetState(
        reload: Bool
    ) {

        guard
            let defaults =
                UserDefaults(
                    suiteName:
                        WidgetStateKey.suiteName
                )
        else {
            return
        }

        let activeTrip =
            appDelegate.activeTrip

        let recording =
            activeTrip != nil

        defaults.set(
            recording,
            forKey:
                WidgetStateKey.recording
        )

        if recording,
           let startDate =
                activeTrip?.recordingStartDate {

            defaults.set(
                startDate.timeIntervalSince1970,
                forKey:
                    WidgetStateKey.startDate
            )

            defaults.set(
                currentElapsedSeconds(),
                forKey:
                    WidgetStateKey.elapsedSeconds
            )

            defaults.set(
                Double(
                    max(
                        cachedDistanceMeters,
                        0
                    )
                ),
                forKey:
                    WidgetStateKey.distanceMeters
            )

            defaults.set(
                max(
                    cachedIncidents,
                    0
                ),
                forKey:
                    WidgetStateKey.incidents
            )

            let locations = (activeTrip?.tripLocations as NSArray?)?.compactMap {
                            $0 as? TripLocation
                        } ?? []

            if locations.count !=
                lastWidgetRoutePointCount {

                let coordinates =
                    locations.compactMap {
                        location
                        -> WidgetCoordinate? in

                        let coordinate =
                            location.location.coordinate

                        guard
                            CLLocationCoordinate2DIsValid(
                                coordinate
                            )
                        else {
                            return nil
                        }

                        return WidgetCoordinate(
                            latitude:
                                coordinate.latitude,
                            longitude:
                                coordinate.longitude
                        )
                    }

                let widgetCoordinates =
                    downsampleWidgetCoordinates(
                        coordinates,
                        maximumCount: 300
                    )

                if let data =
                    try? JSONEncoder()
                        .encode(
                            widgetCoordinates
                        ) {

                    defaults.set(
                        data,
                        forKey:
                            WidgetStateKey.routeCoordinates
                    )
                }

                lastWidgetRoutePointCount =
                    locations.count
            }

        } else {

            defaults.removeObject(
                forKey:
                    WidgetStateKey.startDate
            )

            defaults.removeObject(
                forKey:
                    WidgetStateKey.routeCoordinates
            )

            lastWidgetRoutePointCount =
                -1
        }

        lastWidgetSyncDate =
            .now

        guard reload else {
            return
        }

        reloadWidgetTimeline()
    }

    // MARK: - Widget Route Downsampling

    private func downsampleWidgetCoordinates(
        _ coordinates: [WidgetCoordinate],
        maximumCount: Int
    ) -> [WidgetCoordinate] {

        guard
            maximumCount >= 2,
            coordinates.count > maximumCount
        else {
            return coordinates
        }

        var result: [WidgetCoordinate] = []

        result.reserveCapacity(
            maximumCount
        )

        let step =
            Double(coordinates.count - 1) /
            Double(maximumCount - 1)

        for index in 0..<maximumCount {

            let sourceIndex =
                min(
                    coordinates.count - 1,
                    Int(
                        (
                            Double(index) * step
                        )
                        .rounded()
                    )
                )

            result.append(
                coordinates[sourceIndex]
            )
        }

        return result
    }

    // MARK: - Widget

    private func reloadWidgetTimeline() {

        WidgetCenter.shared
            .reloadTimelines(
                ofKind:
                    "SimRaRecordingWidget"
            )

        lastWidgetTimelineReload =
            .now
    }

    // MARK: - Time

    private func currentElapsedSeconds() -> Int {

        guard
            let start = recordingStartedAt
        else {
            return 0
        }

        return max(
            0,
            Int(
                Date()
                    .timeIntervalSince(start)
                    .rounded()
            )
        )
    }

    // MARK: - Formatting

    private func formatElapsedTime(
        _ seconds: Int
    ) -> String {

        let safe =
            max(
                seconds,
                0
            )

        let hours =
            safe / 3_600

        let minutes =
            (safe % 3_600) / 60

        let remaining =
            safe % 60

        if hours > 0 {

            return String(
                format:
                    "%d:%02d:%02d",
                hours,
                minutes,
                remaining
            )
        }

        return String(
            format:
                "%02d:%02d",
            minutes,
            remaining
        )
    }

    private func formatDistance(
        _ meters: Int
    ) -> String {

        let safe =
            max(
                meters,
                0
            )

        if safe >= 1_000 {

            return String(
                format:
                    "%.1f km",
                Double(safe) / 1_000.0
            )
        }

        return String(
            format:
                "%d m",
            safe
        )
    }

    // MARK: - Bluetooth

    private func setupBluetooth() {

        showOpenBikeSensorButton =
            UserDefaults.standard.bool(
                forKey:
                    "openBikeSensor"
            )
    }

    func openOBSConfig() {

        showOBSConfig = true
    }

    // MARK: - Hazard Map

    func toggleHazardMap() {

        guard !isRecording else {
            return
        }

        showHazardMap.toggle()
    }

    func closeHazardMap() {

        showHazardMap = false
    }

    // MARK: - Initial Messages

    private func checkInitialMessages() {

        if !UserDefaults.standard.bool(
            forKey:
                "initialMessage"
        ) {

            showHowToAlert = true
        }
    }

    func confirmHowTo() {

        UserDefaults.standard.set(
            true,
            forKey:
                "initialMessage"
        )
    }

    func skipHowTo() {

        UserDefaults.standard.set(
            true,
            forKey:
                "initialMessage"
        )
    }

    func suppressRegionMessage() {

        UserDefaults.standard.set(
            true,
            forKey:
                "suppressRegionMessage"
        )
    }

    func openRegionSettings() {
        // Existing region-selection flow.
    }
}
