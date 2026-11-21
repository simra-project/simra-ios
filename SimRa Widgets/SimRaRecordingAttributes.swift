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
public struct SimRaRecordingAttributes: ActivityAttributes {

    // MARK: - Dynamic Content

    public struct ContentState: Codable, Hashable {

        public struct RoutePoint: Codable, Hashable {
            public let latitude: Double
            public let longitude: Double

            public init(latitude: Double, longitude: Double) {
                self.latitude = latitude
                self.longitude = longitude
            }
        }

        public var elapsedSeconds: Int
        public var distanceMeters: Int
        public var incidents: Int
        public var route: [RoutePoint]
        public var uploadProgress: Double?
        public var uploadCompletedCount: Int?
        public var uploadTotalCount: Int?
        public var uploadFailureCount: Int?
        public var uploadFinished: Bool?

        public init(
            elapsedSeconds: Int = 0,
            distanceMeters: Int = 0,
            incidents: Int = 0,
            route: [RoutePoint] = [],
            uploadProgress: Double? = nil,
            uploadCompletedCount: Int? = nil,
            uploadTotalCount: Int? = nil,
            uploadFailureCount: Int? = nil,
            uploadFinished: Bool? = nil
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
            self.uploadProgress = uploadProgress.map { min(max($0, 0), 1) }
            self.uploadCompletedCount = uploadCompletedCount.map { max($0, 0) }
            self.uploadTotalCount = uploadTotalCount.map { max($0, 0) }
            self.uploadFailureCount = uploadFailureCount.map { max($0, 0) }
            self.uploadFinished = uploadFinished
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
