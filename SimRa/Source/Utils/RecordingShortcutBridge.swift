//
//  RecordingShortcutBridge.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import WidgetKit
import CoreLocation

@objcMembers
public final class RecordingShortcutBridge:
    NSObject
{
    // MARK: - Shared State

    private enum SharedState {

        static let suiteName =
            "group.de.tu-berlin.mcc.simra"

        static let isRecording =
            "isRecording"

        static let elapsedSeconds =
            "elapsedSeconds"

        static let distanceMeters =
            "distanceMeters"

        static let incidents =
            "incidents"

        static let liveActivityEvents =
            "liveActivityIncidentEvents"

        static let pendingLiveActivityIncidents =
            "pendingLiveActivityIncidents"

    }

    // MARK: - Shared Defaults

    private static var sharedDefaults:
        UserDefaults
    {
        UserDefaults(
            suiteName:
                SharedState.suiteName
        )
        ??
        UserDefaults.standard
    }

    // MARK: - Live Activity Event

    private struct LiveActivityIncidentEvent {

        let id:
            String

        let tripId:
            Int

        let incidentType:
            Int

        let timestamp:
            Date

        let latitude:
            Double?

        let longitude:
            Double?

        let source:
            String

        let participantMask:
            Int

        let frightening:
            Bool

        let comment:
            String?

        init?(
            dictionary:
                [String: Any]
        ) {

            guard
                let id =
                    dictionary["id"] as? String,
                let tripId =
                    dictionary["tripId"] as? Int,
                let incidentType =
                    dictionary["incidentType"] as? Int,
                let timestampValue =
                    dictionary["timestamp"] as? Double
            else {
                return nil
            }

            self.id =
                id

            self.tripId =
                tripId

            self.incidentType =
                incidentType

            self.timestamp =
                Date(
                    timeIntervalSince1970:
                        timestampValue
                )

            self.latitude =
                dictionary["latitude"] as? Double

            self.longitude =
                dictionary["longitude"] as? Double

            self.source =
                dictionary["source"] as? String
                ?? TripAnnotationSource.widget.rawValue

            self.participantMask =
                dictionary["participantMask"] as? Int
                ?? 0

            self.frightening =
                dictionary["frightening"] as? Bool
                ?? false

            self.comment =
                (dictionary["comment"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var coordinate:
            CLLocationCoordinate2D?
        {
            guard
                let latitude,
                let longitude
            else {
                return nil
            }

            let coordinate =
                CLLocationCoordinate2D(
                    latitude:
                        latitude,
                    longitude:
                        longitude
                )

            guard
                CLLocationCoordinate2DIsValid(
                    coordinate
                )
            else {
                return nil
            }

            return coordinate
        }
    }

    // MARK: - Start Recording

    @discardableResult
    public static func startRecording()
        -> Bool
    {
        let result =
            AppDelegate.shared()
                .startRecordingRequested()

        guard result else {
            return false
        }

        waitForRecordingState(
            expectedRecording:
                true
        )

        return true
    }

    // MARK: - Stop Recording

    @discardableResult
    public static func stopRecording()
        -> Bool
    {
        let result =
            AppDelegate.shared()
                .stopRecordingRequested()

        guard result else {
            return false
        }

        waitForRecordingState(
            expectedRecording:
                false
        )

        return true
    }

    // MARK: - Recording State

    private static func waitForRecordingState(
        expectedRecording:
            Bool
    ) {

        checkRecordingState(
            expectedRecording:
                expectedRecording,
            attempt:
                0
        )
    }

    private static func checkRecordingState(
        expectedRecording:
            Bool,
        attempt:
            Int
    ) {

        let actualState =
            AppDelegate.shared()
                .activeTrip != nil

        if actualState ==
            expectedRecording
        {
            publishCurrentState()
            return
        }

        guard attempt < 30 else {
            publishCurrentState()
            return
        }

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.1
        ) {

            checkRecordingState(
                expectedRecording:
                    expectedRecording,
                attempt:
                    attempt + 1
            )
        }
    }

    // MARK: - Publish State

    private static func publishCurrentState() {

        let appDelegate =
            AppDelegate.shared()

        let activeTrip =
            appDelegate.activeTrip

        let isRecording =
            activeTrip != nil

        let defaults =
            sharedDefaults

        let elapsedSeconds:
            Int

        if let startDate =
            activeTrip?.recordingStartDate
        {

            elapsedSeconds =
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

        } else {

            elapsedSeconds =
                0
        }

        let distanceMeters =
            max(
                activeTrip?.length() ?? 0,
                0
            )

        let incidents =
            max(
                activeTrip?
                    .tripValidAnnotations()
                    ?? 0,
                0
            )

        defaults.set(
            isRecording,
            forKey:
                SharedState.isRecording
        )

        defaults.set(
            elapsedSeconds,
            forKey:
                SharedState.elapsedSeconds
        )

        defaults.set(
            distanceMeters,
            forKey:
                SharedState.distanceMeters
        )

        defaults.set(
            incidents,
            forKey:
                SharedState.incidents
        )

        let regionSuffix =
            appDelegate.regions.regionId == 0
            ? ""
            : "-\(appDelegate.regions.regionId)"

        defaults.set(
            appDelegate.defaults.integer(
                forKey:
                    "totalRides\(regionSuffix)"
            ),
            forKey:
                "totalRides"
        )

        defaults.set(
            appDelegate.defaults.integer(
                forKey:
                    "totalLength\(regionSuffix)"
            ),
            forKey:
                "totalDistanceMeters"
        )

        WidgetCenter.shared.reloadTimelines(
            ofKind:
                "SimRaRecordingWidget"
        )

        NotificationCenter.default.post(
            name:
                .recordingSessionDidChange,
            object:
                nil
        )
    }

    // MARK: - Direct Incident

    @discardableResult
    public static func markIncident(
        _ incidentType:
            Int,
        source:
            String = "Siri",
        participantMask:
            Int = 0,
        frightening:
            Bool = false,
        comment:
            String? = nil
    ) -> Bool {

        guard
            incidentType >= 0
        else {
            return false
        }

        guard
            let activeTrip =
                AppDelegate.shared().activeTrip
        else {
            return false
        }

        guard
            let targetLocation =
                bestAvailableLocation(
                    in:
                        activeTrip
                )
        else {
            return false
        }

        guard
            targetLocation.tripAnnotation == nil
        else {
            return false
        }

        let annotation =
            TripAnnotation()

        annotation.incidentId =
            incidentType

        annotation.source =
            source

        applyParticipants(
            participantMask,
            to: annotation
        )

        annotation.frightening = frightening

        annotation.comment =
            comment?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            ?? NSLocalizedString(
                "Quickly recorded. Details can be added later.",
                comment: "Quick incident comment"
            )

        targetLocation.tripAnnotation =
            annotation

        activeTrip.edited =
            true

        activeTrip.save()

        publishCurrentState()

        NotificationCenter.default.post(
            name:
                .incidentMarked,
            object:
                activeTrip
        )

        return true
    }

    // MARK: - Best Location

    private static func bestAvailableLocation(
        in trip:
            Trip
    ) -> TripLocation?
    {

        for case
            let location as TripLocation
            in trip.tripLocations.reversed()
        {
            guard
                location.tripAnnotation == nil
            else {
                continue
            }

            return location
        }

        guard
            let currentLocation =
                trip.lastLocation
        else {
            return nil
        }

        let newLocation =
            TripLocation()

        newLocation.location =
            currentLocation

        trip.tripLocations.add(
            newLocation
        )

        return newLocation
    }

    // MARK: - Live Activity Queue

    /// Called from the Live Activity extension.
    ///
    /// Stores a complete event rather than just incrementing
    /// a counter. The event survives app suspension.
    public static func enqueueLiveActivityIncident(
        tripId:
            Int,
        incidentType:
            Int = 0,
        coordinate:
            CLLocationCoordinate2D? = nil
    ) {

        guard
            tripId > 0,
            incidentType >= 0
        else {
            return
        }

        let defaults =
            sharedDefaults

        var events =
            defaults.array(
                forKey:
                    SharedState.liveActivityEvents
            ) as?
            [[String: Any]]
            ??
            []

        var event:
            [String: Any] = [

                "id":
                    UUID().uuidString,

                "tripId":
                    tripId,

                "incidentType":
                    incidentType,

                "timestamp":
                    Date()
                        .timeIntervalSince1970
            ]

        if let coordinate {

            event["latitude"] =
                coordinate.latitude

            event["longitude"] =
                coordinate.longitude
        }

        events.append(
            event
        )

        // Bounded queue.
        if events.count > 100 {

            events.removeFirst(
                events.count - 100
            )
        }

        defaults.set(
            events,
            forKey:
                SharedState.liveActivityEvents
        )

        defaults.set(
            events.count,
            forKey:
                SharedState.pendingLiveActivityIncidents
        )
    }

    // MARK: - Process Live Activity Events

    @discardableResult
    public static func processPendingLiveActivityIncidents()
        -> Int
    {

        let defaults =
            sharedDefaults

        guard
            let dictionaries =
                defaults.array(
                    forKey:
                        SharedState.liveActivityEvents
                ) as?
                [[String: Any]],
            !dictionaries.isEmpty
        else {

            defaults.removeObject(
                forKey:
                    SharedState.pendingLiveActivityIncidents
            )

            return 0
        }

        var remaining:
            [[String: Any]] =
                []

        remaining.reserveCapacity(
            dictionaries.count
        )

        var processed =
            0

        for dictionary
            in dictionaries
        {

            guard
                let event =
                    LiveActivityIncidentEvent(
                        dictionary:
                            dictionary
                    )
            else {
                // Drop malformed events.
                continue
            }

            let appDelegate =
                AppDelegate.shared()

            // Prefer the actual active Trip.
            //
            // This is crucial while the recording has not
            // necessarily been flushed to persistent storage yet.
            let trip:
                Trip?

            if event.tripId == 0,
               let activeTrip = appDelegate.activeTrip
            {
                trip = activeTrip
            } else if let activeTrip =
                appDelegate.activeTrip,
                activeTrip.identifier == event.tripId
            {

                trip =
                    activeTrip

            } else {

                trip = event.tripId > 0
                    ? Trip(fromStorage: event.tripId)
                    : nil
            }

            guard
                let trip
            else {

                remaining.append(
                    dictionary
                )

                continue
            }

            guard
                attach(
                    event:
                        event,
                    to:
                        trip
                )
            else {

                remaining.append(
                    dictionary
                )

                continue
            }

            processed += 1
        }

        defaults.set(
            remaining,
            forKey:
                SharedState.liveActivityEvents
        )

        if remaining.isEmpty {

            defaults.removeObject(
                forKey:
                    SharedState.pendingLiveActivityIncidents
            )

        } else {

            defaults.set(
                remaining.count,
                forKey:
                    SharedState.pendingLiveActivityIncidents
            )
        }

        if processed > 0 {

            let trip =
                AppDelegate.shared()
                    .activeTrip

            publishCurrentState()

            NotificationCenter.default.post(
                name:
                    .incidentMarked,
                object:
                    trip
            )
        }

        return processed
    }

    // MARK: - Attach Event

    private static func attach(
        event:
            LiveActivityIncidentEvent,
        to trip:
            Trip
    ) -> Bool {

        let location:
            TripLocation?

        if let coordinate =
            event.coordinate
        {

            location =
                nearestFreeLocation(
                    in:
                        trip,
                    to:
                        coordinate
                )

        } else {

            location = nearestFreeLocation(
                in: trip,
                to: event.timestamp
            ) ?? bestAvailableLocation(in: trip)
        }

        guard
            let location,
            location.tripAnnotation == nil
        else {
            return false
        }

        let annotation =
            TripAnnotation()

        annotation.incidentId =
            event.incidentType

        // Live Activity = Widget source.
        annotation.source =
            event.source

        applyParticipants(
            event.participantMask,
            to: annotation
        )

        annotation.frightening = event.frightening

        annotation.comment = event.comment
            ?? NSLocalizedString(
                "Quickly recorded. Details can be added later.",
                comment: "Live Activity incident"
            )

        location.tripAnnotation =
            annotation

        trip.edited =
            true

        trip.save()

        return true
    }

    // MARK: - Nearest Location

    private static func nearestFreeLocation(
        in trip:
            Trip,
        to coordinate:
            CLLocationCoordinate2D
    ) -> TripLocation?
    {

        let target =
            CLLocation(
                latitude:
                    coordinate.latitude,
                longitude:
                    coordinate.longitude
            )

        var best:
            TripLocation?

        var bestDistance =
            CLLocationDistance
                .greatestFiniteMagnitude

        for case
            let location as TripLocation
            in trip.tripLocations
        {

            guard
                location.tripAnnotation == nil
            else {
                continue
            }

            let distance =
                location.location
                    .distance(
                        from:
                            target
                    )

            if distance <
                bestDistance
            {

                bestDistance =
                    distance

                best =
                    location
            }
        }

        return best
    }

    private static func applyParticipants(
        _ mask: Int,
        to annotation: TripAnnotation
    ) {
        annotation.car = mask & (1 << 0) != 0
        annotation.taxi = mask & (1 << 1) != 0
        annotation.delivery = mask & (1 << 2) != 0
        annotation.bus = mask & (1 << 3) != 0
        annotation.pedestrian = mask & (1 << 4) != 0
        annotation.bicycle = mask & (1 << 5) != 0
        annotation.motorcycle = mask & (1 << 6) != 0
        annotation.escooter = mask & (1 << 7) != 0
        annotation.other = mask & (1 << 8) != 0
    }

    private static func nearestFreeLocation(
        in trip: Trip,
        to timestamp: Date
    ) -> TripLocation? {
        var best: TripLocation?
        var bestDifference = TimeInterval.greatestFiniteMagnitude

        for case let location as TripLocation in trip.tripLocations {
            guard location.tripAnnotation == nil else {
                continue
            }

            let difference = abs(
                location.location.timestamp.timeIntervalSince(timestamp)
            )

            if difference < bestDifference {
                bestDifference = difference
                best = location
            }
        }

        return best
    }
}

// MARK: - Notifications

public extension Notification.Name {

    static let startRecordingFromShortcut =
        Notification.Name(
            "startRecordingFromShortcutNotification"
        )

    static let stopRecordingFromShortcut =
        Notification.Name(
            "stopRecordingFromShortcutNotification"
        )

    static let incidentMarked =
        Notification.Name(
            "incidentMarkedNotification"
        )

    static let incidentAnalysisDidFinish =
        Notification.Name(
            "incidentAnalysisDidFinishNotification"
        )
}
