//
//  SimRaRecordingActivityManager.swift
//  SimRa
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import ActivityKit
import Foundation

@available(iOS 16.2, *)
@MainActor
public final class SimRaRecordingActivityManager {

    // MARK: - Singleton

    public static let shared =
        SimRaRecordingActivityManager()

    private init() {}

    // MARK: - Current Activity

    private var currentActivity:
        Activity<SimRaRecordingAttributes>?

    // MARK: - Start

    @discardableResult
    public func start(
        tripId: Int,
        bikeTypeId: Int,
        startDate: Date
    ) -> Bool {

        guard ActivityAuthorizationInfo()
            .areActivitiesEnabled
        else {
            return false
        }

        // Do not create duplicates.
        if let existing = activeActivity() {
            currentActivity = existing
            return true
        }

        let attributes =
            SimRaRecordingAttributes(
                tripId: tripId,
                bikeTypeId: bikeTypeId,
                startDate: startDate
            )

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds: 0,
                distanceMeters: 0,
                incidents: 0
            )

        let content =
            ActivityContent(
                state: state,
                staleDate: nil
            )

        do {

            let activity =
                try Activity<
                    SimRaRecordingAttributes
                >.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )

            currentActivity = activity

            return true

        } catch {

            print(
                "SimRa Live Activity start failed:",
                error
            )

            currentActivity = nil

            return false
        }
    }

    // MARK: - Update

    public func update(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) async {

        guard
            let activity = activeActivity()
        else {
            return
        }

        currentActivity = activity

        let state =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds:
                    max(
                        0,
                        elapsedSeconds
                    ),
                distanceMeters:
                    max(
                        0,
                        distanceMeters
                    ),
                incidents:
                    max(
                        0,
                        incidents
                    )
            )

        let content =
            ActivityContent(
                state: state,
                staleDate: nil
            )

        await activity.update(
            content
        )
    }

    // MARK: - Stop

    public func stop(
        elapsedSeconds: Int,
        distanceMeters: Int,
        incidents: Int
    ) async {

        guard
            let activity = activeActivity()
        else {
            return
        }

        currentActivity = activity

        let finalState =
            SimRaRecordingAttributes.ContentState(
                elapsedSeconds:
                    max(
                        0,
                        elapsedSeconds
                    ),
                distanceMeters:
                    max(
                        0,
                        distanceMeters
                    ),
                incidents:
                    max(
                        0,
                        incidents
                    )
            )

        let finalContent =
            ActivityContent(
                state:
                    finalState,
                staleDate: nil
            )

        await activity.end(
            finalContent,
            dismissalPolicy: .immediate
        )

        currentActivity = nil
    }

    // MARK: - End Existing Activity

    public func endActivity() async {

        guard
            let activity = activeActivity()
        else {
            currentActivity = nil
            return
        }

        await activity.end(
            activity.content,
            dismissalPolicy: .immediate
        )

        currentActivity = nil
    }

    // MARK: - Lookup

    private func activeActivity()
        -> Activity<SimRaRecordingAttributes>?
    {
        if let currentActivity {

            switch currentActivity.activityState {

            case .active,
                 .stale,
                 .pending:

                return currentActivity

            case .dismissed:

                return nil

            case .ended:

                return nil

            @unknown default:

                return currentActivity
            }
        }

        return Activity<
            SimRaRecordingAttributes
        >.activities.first
    }
}
