//
//  AppDelegate.swift
//  SimRa
//
//  Main application delegate.
//

import SwiftUI
import UIKit
import CoreLocation
import CoreMotion
import ActivityKit
import WidgetKit

@objcMembers
final class AppDelegate:
    NSObject,
    UIApplicationDelegate,
    CLLocationManagerDelegate
{

    // MARK: - Shared

    private static weak var sharedInstance:
        AppDelegate?

    @objc(sharedDelegate)
    class func shared() -> AppDelegate {

        if let sharedInstance {
            return sharedInstance
        }

        guard
            let delegate =
                UIApplication.shared.delegate
                as? AppDelegate
        else {
            fatalError(
                "AppDelegate is not initialized."
            )
        }

        sharedInstance =
            delegate

        return delegate
    }

    // MARK: - Widget State

    private enum WidgetStateKey {

        static let suiteName =
            "group.de.tu-berlin.mcc.simra"

        static let isRecording =
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

        static let tripStatistics =
            "widgetTripStatistics"
    }

    // MARK: - Dependencies

    let defaults:
        UserDefaults

    let lm:
        CLLocationManager

    let mm:
        CMMotionManager

    var trips:
        Trips!

    private lazy var loadedConstants: [String: Any] = {
        let localization =
            defaults.string(forKey: "appLanguage")
            ?? "Base"

        let url =
            Bundle.main.url(
                forResource: "constants",
                withExtension: "plist",
                subdirectory: nil,
                localization: localization
            )
            ?? Bundle.main.url(
                forResource: "constants",
                withExtension: "plist"
            )

        guard
            let url,
            let dictionary = NSDictionary(
                contentsOf: url
            ) as? [String: Any]
        else {
            return [:]
        }

        return dictionary
    }()

    var constants: [String: Any] {
        loadedConstants
    }

    // MARK: - Recording

    private(set) var activeTrip:
        Trip?

    private(set) var lastStoppedTrip:
        Trip?

    private var recordingActivity:
        Activity<SimRaRecordingAttributes>?

    private var metricsTimer:
        Timer?

    private var lastWidgetReload:
        Date?

    private var lastActivityUpdate:
        Date?

    private(set) var recoveryInProgress =
        false

    // MARK: - Lazy Components

    private var _regions:
        Regions?

    private var _news:
        News?

    var regions: Regions {

        if let regions = _regions {
            return regions
        }

        let regions =
            Regions()

        _regions =
            regions

        return regions
    }

    var news: News {

        if let news = _news {
            return news
        }

        let news =
            News()

        _news =
            news

        return news
    }

    // MARK: - Init

    override init() {

        defaults =
            .standard

        lm =
            CLLocationManager()

        mm =
            CMMotionManager()

        super.init()

        Self.sharedInstance =
            self

        trips =
            Trips(
                appDelegate: self
            )

        registerRecordingObservers()

        restoreActiveRecording()
    }

    // MARK: - Application Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions
        launchOptions:
            [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        DispatchQueue.global(
            qos: .utility
        ).async { [weak self] in

            Utility.createSimraPrefs()
            Utility.createAppsPrefs()
            Utility.createProfilePrefs()
            Utility.createKeyPrefs()

            self?.trips.save()
        }

        lm.delegate =
            self

        lm.requestWhenInUseAuthorization()

        startTripRecovery()

        return true
    }

    func applicationDidBecomeActive(
        _ application: UIApplication
    ) {

        lm.requestWhenInUseAuthorization()

        processPendingLiveActivityIncidents()
        processPendingWidgetCommand()
    }

    private func processPendingWidgetCommand() {
        guard
            let pending = WidgetRecordingCommandStore.takeCommand()
        else {
            return
        }

        switch pending.command {
        case "start":
            _ = startRecordingRequested()

        case "stop":
            _ = stopRecordingRequested()

        default:
            break
        }
    }

    // MARK: - Recording Recovery

    private func restoreActiveRecording() {

        guard
            let trip =
                Trip.loadIncompleteTrip(),

            let startDate =
                trip.recordingStartDate
        else {
            return
        }

        activeTrip =
            trip

        // Wichtig:
        // Nicht erneut startRecording() aufrufen.
        //
        // Der Trip wurde bereits als unvollständig
        // gespeichert und wird lediglich wieder als
        // aktive Session übernommen.

        startRecordingActivity(
            for: trip,
            startDate: startDate
        )

        updateWidgetState(
            isRecording: true,
            startDate: startDate,
            elapsedSeconds:
                currentElapsedSeconds(
                    from: startDate
                ),
            distanceMeters:
                max(
                    trip.length(),
                    0
                ),
            incidents:
                max(
                    trip.tripValidAnnotations(),
                    0
                )
        )

        startMetricsTimer()

        notifyRecordingStateChanged()
    }

    // MARK: - Start Recording

    @objc
    func startRecordingRequested()
        -> Bool
    {

        guard
            activeTrip == nil
        else {
            return false
        }

        let trip =
            trips.newTrip()

        activeTrip =
            trip

        trip.startRecording()

        guard
            let startDate =
                trip.recordingStartDate
        else {

            activeTrip =
                nil

            return false
        }

        startRecordingActivity(
            for: trip,
            startDate: startDate
        )

        updateWidgetState(
            isRecording: true,
            startDate: startDate,
            elapsedSeconds: 0,
            distanceMeters: 0,
            incidents: 0
        )

        startMetricsTimer()

        notifyRecordingStateChanged()

        return true
    }

    // MARK: - Stop Recording

    @objc
    func stopRecordingRequested()
        -> Bool
    {

        guard
            let trip =
                activeTrip
        else {
            return false
        }

        let startDate =
            trip.recordingStartDate

        let elapsedSeconds =
            startDate.map {
                currentElapsedSeconds(
                    from: $0
                )
            } ?? 0

        let distanceMeters =
            max(
                trip.length(),
                0
            )

        let incidents =
            max(
                trip.tripValidAnnotations(),
                0
            )

        // Shared widget state zuerst aktualisieren.

        updateWidgetState(
            isRecording: false,
            startDate: nil,
            elapsedSeconds:
                elapsedSeconds,
            distanceMeters:
                distanceMeters,
            incidents:
                incidents
        )

        // Live Activity beenden.

        stopRecordingActivity(
            elapsedSeconds:
                elapsedSeconds,
            distanceMeters:
                distanceMeters,
            incidents:
                incidents
        )

        // Trip finalisieren.

        trip.stopRecording()

        lastStoppedTrip =
            trip

        activeTrip =
            nil

        stopMetricsTimer()

        notifyRecordingStateChanged()

        scheduleWidgetStatisticsRefresh()

        return true
    }

    // MARK: - Elapsed Time

    private func currentElapsedSeconds(
        from startDate: Date
    ) -> Int {

        max(
            0,
            Int(
                Date()
                    .timeIntervalSince(
                        startDate
                    )
                    .rounded()
            )
        )
    }

    // MARK: - Metrics

    private func startMetricsTimer() {

        metricsTimer?.invalidate()

        updateRecordingMetrics()

        let timer =
            Timer(
                timeInterval: 5.0,
                repeats: true
            ) { [weak self] _ in

                self?.updateRecordingMetrics()
            }

        metricsTimer =
            timer

        RunLoop.main.add(
            timer,
            forMode: .common
        )
    }

    private func stopMetricsTimer() {

        metricsTimer?.invalidate()

        metricsTimer =
            nil

        lastWidgetReload =
            nil

        lastActivityUpdate =
            nil
    }

    private func updateRecordingMetrics() {

        processPendingLiveActivityIncidents()
        processPendingWidgetCommand()

        guard
            let trip =
                activeTrip,

            let startDate =
                trip.recordingStartDate
        else {
            return
        }

        let elapsedSeconds =
            currentElapsedSeconds(
                from: startDate
            )

        let distanceMeters =
            max(
                trip.length(),
                0
            )

        let incidents =
            max(
                trip.tripValidAnnotations(),
                0
            )

        SimRaWidgetState.setMetrics(
            elapsedSeconds:
                elapsedSeconds,
            distanceMeters:
                distanceMeters,
            incidents:
                incidents
        )

        let now =
            Date()

        let shouldUpdateActivity =
            lastActivityUpdate == nil
            || now.timeIntervalSince(
                lastActivityUpdate!
            ) >= 15

        if shouldUpdateActivity {
            updateRecordingActivity(
                elapsedSeconds:
                    elapsedSeconds,
                distanceMeters:
                    distanceMeters,
                incidents:
                    incidents
            )

            lastActivityUpdate =
                now
        }

        let shouldReload =
            lastWidgetReload == nil
            ||
            now.timeIntervalSince(
                lastWidgetReload!
            ) >= 15

        synchronizeWidgetRecordingState(
            trip: trip,
            elapsedSeconds:
                elapsedSeconds,
            distanceMeters:
                distanceMeters,
            incidents:
                incidents,
            reload:
                shouldReload
        )

        if shouldReload {
            lastWidgetReload =
                now
        }
    }

    // MARK: - Live Activity

    private func startRecordingActivity(
        for trip: Trip,
        startDate: Date
    ) {

        guard
            #available(iOS 16.2, *)
        else {
            return
        }

        guard
            ActivityAuthorizationInfo()
                .areActivitiesEnabled
        else {
            return
        }

        // Niemals eine zweite Activity erzeugen.

        if let existing =
            Activity<
                SimRaRecordingAttributes
            >.activities.first {

            recordingActivity =
                existing

            return
        }

        let attributes =
            SimRaRecordingAttributes(
                tripId:
                    trip.identifier,
                bikeTypeId:
                    trip.bikeTypeId,
                startDate:
                    startDate
            )

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds: 0,
                distanceMeters: 0,
                incidents: 0,
                route: []
            )

        let content =
            ActivityContent(
                state:
                    state,
                staleDate:
                    startDate.addingTimeInterval(
                        12 * 60 * 60
                    )
            )

        do {

            recordingActivity =
                try Activity.request(
                    attributes:
                        attributes,
                    content:
                        content,
                    pushType:
                        nil
                )

        } catch {

            recordingActivity =
                nil

            print(
                "[SimRa] Could not start Live Activity: \(error)"
            )
        }
    }

    private func updateRecordingActivity(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) {

        guard
            #available(iOS 16.2, *)
        else {
            return
        }

        guard
            let activity =
                recordingActivity
                ??
                Activity<
                    SimRaRecordingAttributes
                >.activities.first
        else {
            return
        }

        recordingActivity =
            activity

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds:
                    max(
                        elapsedSeconds,
                        0
                    ),
                distanceMeters:
                    max(
                        distanceMeters,
                        0
                    ),
                incidents:
                    max(
                        incidents,
                        0
                    ),
                route:
                    activityRoute(for: activeTrip)
            )

        let content =
            ActivityContent(
                state:
                    state,
                staleDate:
                    Date()
                        .addingTimeInterval(
                            60
                        )
            )

        Task {

            await activity.update(
                content
            )
        }
    }

    private func activityRoute(
        for trip: Trip?
    ) -> [SimRaRecordingAttributes.ContentState.RoutePoint] {
        guard let trip else {
            return []
        }

        let locations =
            (trip.tripLocations as NSArray)
                .compactMap { $0 as? TripLocation }

        guard !locations.isEmpty else {
            return []
        }

        let step = max(1, locations.count / 80)
        return locations.enumerated().compactMap { index, location in
            guard index % step == 0 else {
                return nil
            }

            let coordinate = location.location.coordinate
            guard CLLocationCoordinate2DIsValid(coordinate) else {
                return nil
            }

            return SimRaRecordingAttributes.ContentState.RoutePoint(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }

    private func stopRecordingActivity(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) {

        guard
            #available(iOS 16.2, *)
        else {
            return
        }

        guard
            let activity =
                recordingActivity
                ??
                Activity<
                    SimRaRecordingAttributes
                >.activities.first
        else {
            recordingActivity =
                nil

            return
        }

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds:
                    max(
                        elapsedSeconds,
                        0
                    ),
                distanceMeters:
                    max(
                        distanceMeters,
                        0
                    ),
                incidents:
                    max(
                        incidents,
                        0
                    )
            )

        let content =
            ActivityContent(
                state:
                    state,
                staleDate:
                    nil
            )

        Task {

            await activity.end(
                content,
                dismissalPolicy:
                    .immediate
            )
        }

        recordingActivity =
            nil
    }

    // MARK: - Widget State

    private func updateWidgetState(
        isRecording: Bool,
        startDate: Date?,
        elapsedSeconds: Int? = nil,
        distanceMeters: Int? = nil,
        incidents: Int? = nil
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

        defaults.set(
            isRecording,
            forKey:
                WidgetStateKey.isRecording
        )

        if
            isRecording,
            let startDate
        {

            defaults.set(
                startDate.timeIntervalSince1970,
                forKey:
                    WidgetStateKey.startDate
            )

        } else {

            defaults.removeObject(
                forKey:
                    WidgetStateKey.startDate
            )
        }

        defaults.set(
            max(
                elapsedSeconds ?? 0,
                0
            ),
            forKey:
                WidgetStateKey.elapsedSeconds
        )

        defaults.set(
            max(
                distanceMeters ?? 0,
                0
            ),
            forKey:
                WidgetStateKey.distanceMeters
        )

        defaults.set(
            max(
                incidents ?? 0,
                0
            ),
            forKey:
                WidgetStateKey.incidents
        )

        WidgetCenter.shared.reloadTimelines(
            ofKind:
                "SimRaRecordingWidget"
        )
    }

    private func scheduleWidgetStatisticsRefresh() {
        WidgetCenter.shared.reloadTimelines(ofKind: "SimRaRecordingWidget")
    }

    private func synchronizeWidgetRecordingState(
        trip: Trip,
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int,
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

        defaults.set(
            true,
            forKey:
                WidgetStateKey.isRecording
        )

        if
            let startDate =
                trip.recordingStartDate
        {

            defaults.set(
                startDate.timeIntervalSince1970,
                forKey:
                    WidgetStateKey.startDate
            )
        }

        defaults.set(
            elapsedSeconds,
            forKey:
                WidgetStateKey.elapsedSeconds
        )

        defaults.set(
            distanceMeters,
            forKey:
                WidgetStateKey.distanceMeters
        )

        defaults.set(
            incidents,
            forKey:
                WidgetStateKey.incidents
        )

        let route =
            (trip.tripLocations as NSArray)
                .compactMap { value -> [String: Double]? in
                    guard
                        let location = value as? TripLocation,
                        CLLocationCoordinate2DIsValid(
                            location.location.coordinate
                        )
                    else {
                        return nil
                    }

                    let coordinate = location.location.coordinate
                    return [
                        "latitude": coordinate.latitude,
                        "longitude": coordinate.longitude
                    ]
                }

        if let routeData = try? JSONSerialization.data(
            withJSONObject: route,
            options: []
        ) {
            defaults.set(
                routeData,
                forKey:
                    WidgetStateKey.routeCoordinates
            )
        }

        if reload {

            WidgetCenter.shared.reloadTimelines(
                ofKind:
                    "SimRaRecordingWidget"
            )
        }
    }

    // MARK: - Pending Incidents

    private func processPendingLiveActivityIncidents() {
        _ = RecordingShortcutBridge
            .processPendingLiveActivityIncidents()
    }

    private var defaultsForWidget:
        UserDefaults
    {
        UserDefaults(
            suiteName:
                WidgetStateKey.suiteName
        )
        ?? .standard
    }

    // MARK: - Shortcut Notifications

    private func registerRecordingObservers() {

        NotificationCenter.default.addObserver(
            self,
            selector:
                #selector(
                    handleStartRecordingShortcut
                ),
            name:
                .startRecordingFromShortcut,
            object:
                nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector:
                #selector(
                    handleStopRecordingShortcut
                ),
            name:
                .stopRecordingFromShortcut,
            object:
                nil
        )
    }

    @objc
    private func handleStartRecordingShortcut(
        _ notification: Notification
    ) {

        _ =
            startRecordingRequested()
    }

    @objc
    private func handleStopRecordingShortcut(
        _ notification: Notification
    ) {

        _ =
            stopRecordingRequested()
    }

    private func notifyRecordingStateChanged() {

        NotificationCenter.default.post(
            name:
                .recordingSessionDidChange,
            object:
                self
        )
    }

    // MARK: - Trip Recovery

    private func startTripRecovery() {

        guard
            !recoveryInProgress
        else {
            return
        }

        recoveryInProgress =
            true

        DispatchQueue.global(
            qos: .utility
        ).async { [weak self] in

            Trip.recoverIncompleteTrips()

            DispatchQueue.main.async {

                self?.recoveryInProgress =
                    false
            }
        }
    }

    // MARK: - Deep Links

    func application(
        _ application: UIApplication,
        open url: URL,
        options:
            [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {

        guard
            url.scheme == "simra"
        else {
            return false
        }

        if url.host == "recording" {

            switch url.path {

            case "/start":
                return startRecordingRequested()

            case "/stop":
                return stopRecordingRequested()

            default:
                break
            }
        }

        if url.host == "incident" {

            if
                url.path == "/mark"
                ||
                url.path == "/report"
            {

                let components =
                    URLComponents(
                        url: url,
                        resolvingAgainstBaseURL:
                            false
                    )

                let typeString =
                    components?
                        .queryItems?
                        .first {
                            $0.name == "type"
                        }?
                        .value
                    ?? "0"

                let incidentType =
                    Int(typeString)
                    ?? 0

                return RecordingShortcutBridge.markIncident(
                    incidentType,
                    source:
                        "Deep Link"
                )
            }
        }

        return false
    }

    // MARK: - External URLs

    @objc
    func openURL(
        _ dict: [String: String]
    ) {

        let appLang =
            defaults.string(
                forKey:
                    "appLanguage"
            )
            ?? "auto"

        let languageCode: String

        if appLang == "auto" {

            languageCode =
                Locale.current
                    .language
                    .languageCode?
                    .identifier
                ?? "de"

        } else {

            languageCode =
                appLang
        }

        let urlString =
            dict[languageCode]
            ?? dict["de"]
            ?? dict["en"]

        guard
            let urlString,
            let url =
                URL(
                    string:
                        urlString
                )
        else {
            return
        }

        UIApplication.shared.open(
            url,
            options: [:],
            completionHandler:
                nil
        )
    }

    @objc
    func showHowTo() {

        openURL(
            [
                "en":
                    "https://simra-backend.3s-rg.de:4998/SimRa_Instructions_IOS.pdf",

                "de":
                    "https://simra-backend.3s-rg.de:4998/SimRa_Anleitung_IOS.pdf"
            ]
        )
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations:
            [CLLocation]
    ) {

        activeTrip?
            .locationManager(
                manager,
                didUpdateLocations:
                    locations
            )
    }
}

// MARK: - Notifications

public extension Notification.Name {

    static let recordingSessionDidChange =
        Notification.Name(
            "recordingSessionDidChangeNotification"
        )
}
