//
//  SimRaRecordingAttributes.swift
//  SimRa
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import ActivityKit
import Foundation

@available(iOS 16.2, *)
public struct SimRaUploadAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var completedCount: Int
        public var succeededCount: Int
        public var failedCount: Int

        public init(
            completedCount: Int = 0,
            succeededCount: Int = 0,
            failedCount: Int = 0
        ) {
            self.completedCount = max(0, completedCount)
            self.succeededCount = max(0, succeededCount)
            self.failedCount = max(0, failedCount)
        }
    }

    public let totalCount: Int
    public let startDate: Date

    public init(totalCount: Int, startDate: Date = .now) {
        self.totalCount = max(0, totalCount)
        self.startDate = startDate
    }
}

@available(iOS 16.2, *)
public struct SimRaRecordingAttributes: ActivityAttributes {

    // MARK: - Dynamic Content

    public struct ContentState: Codable, Hashable {

        public struct RoutePoint: Codable, Hashable {
            public let latitude: Double
            public let longitude: Double
            public let speedKmh: Double?

            public init(
                latitude: Double,
                longitude: Double,
                speedKmh: Double? = nil
            ) {
                self.latitude = latitude
                self.longitude = longitude
                self.speedKmh = speedKmh
            }
        }

        public var elapsedSeconds: Int
        public var distanceMeters: Int
        public var incidents: Int
        public var route: [RoutePoint]

        public init(
            elapsedSeconds: Int = 0,
            distanceMeters: Int = 0,
            incidents: Int = 0,
            route: [RoutePoint] = []
        ) {
            self.elapsedSeconds = max(
                0,
                elapsedSeconds
            )

            self.distanceMeters = max(
                0,
                distanceMeters
            )

            self.incidents = max(
                0,
                incidents
            )
            self.route = route
        }
    }

    // MARK: - Static Content

    public let tripId: Int
    public let bikeTypeId: Int
    public let startDate: Date

    public init(
        tripId: Int,
        bikeTypeId: Int,
        startDate: Date
    ) {
        self.tripId = tripId
        self.bikeTypeId = bikeTypeId
        self.startDate = startDate
    }
}
