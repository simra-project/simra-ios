//
//  SimRaRecordingWidget.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import WidgetKit
import CoreLocation

// MARK: - Configuration

private enum SimRaWidgetConfiguration {

    static let appGroupIdentifier =
        "group.de.tu-berlin.mcc.simra"

    static let recordingKey =
        "isRecording"

    static let startDateKey =
        "startDate"

    static let distanceKey =
        "distanceMeters"

    static let incidentsKey =
        "incidents"

    static let routeCoordinatesKey =
        "widgetRouteCoordinates"

    static let tripStatisticsKey =
        "widgetTripStatistics"

    static let startURL =
        URL(string: "simra://recording/start")

    static let stopURL =
        URL(string: "simra://recording/stop")

    static let dangerURL =
        URL(string: "simra://recording/danger")
}

// MARK: - Timeline Entry

struct SimRaRecordingEntry: TimelineEntry {

    let date: Date
    let routeCoordinatesData: Data?
    let recording: Bool
    let distanceMeters: Double
    let recordingStartDate: Date?
    let incidentsCount: Int
    let weeklyKilometers: [Double]
    let weeklyRideCounts: [Int]

    init(
        date: Date = .now,
        routeCoordinatesData: Data? = nil,
        recording: Bool = false,
        distanceMeters: Double = 0,
        recordingStartDate: Date? = nil,
        incidentsCount: Int = 0,
        weeklyKilometers: [Double] = [0, 0, 0, 0],
        weeklyRideCounts: [Int] = [0, 0, 0, 0]
    ) {
        self.date = date
        self.routeCoordinatesData = routeCoordinatesData
        self.recording = recording
        self.distanceMeters = max(
            distanceMeters,
            0
        )
        self.recordingStartDate = recordingStartDate
        self.incidentsCount = max(
            incidentsCount,
            0
        )
        self.weeklyKilometers = weeklyKilometers
        self.weeklyRideCounts = weeklyRideCounts
    }
}

// MARK: - Coordinate

struct SimRaWidgetCoordinate:
    Codable,
    Equatable {

    let latitude: Double
    let longitude: Double

    var location:
        CLLocationCoordinate2D {

        CLLocationCoordinate2D(
            latitude: latitude,
            longitude: longitude
        )
    }
}

// MARK: - Stored Statistic

private struct SimRaStoredTripStatistic:
    Codable {

    let date: Date
    let distanceMeters: Double
}

// MARK: - Timeline Provider

struct SimRaRecordingProvider:
    TimelineProvider {

    func placeholder(
        in context: Context
    ) -> SimRaRecordingEntry {

        SimRaRecordingEntry(
            routeCoordinatesData: nil,
            recording: true,
            distanceMeters: 6_800,
            recordingStartDate:
                Date(
                    timeIntervalSinceNow: -642
                ),
            incidentsCount: 1,
            weeklyKilometers: [
                7.4,
                15.8,
                11.2,
                21.6
            ],
            weeklyRideCounts: [
                2,
                4,
                3,
                5
            ]
        )
    }

    func getSnapshot(
        in context: Context,
        completion:
            @escaping (
                SimRaRecordingEntry
            ) -> Void
    ) {
        completion(
            currentEntry()
        )
    }

    func getTimeline(
        in context: Context,
        completion:
            @escaping (
                Timeline<SimRaRecordingEntry>
            ) -> Void
    ) {

        let entry = currentEntry()

        let refreshInterval =
            entry.recording
            ? 5.0 * 60.0
            : 15.0 * 60.0

        let nextRefresh =
            Date.now.addingTimeInterval(
                refreshInterval
            )

        completion(
            Timeline(
                entries: [entry],
                policy: .after(nextRefresh)
            )
        )
    }

    private func currentEntry()
        -> SimRaRecordingEntry {

        guard
            let defaults =
                UserDefaults(
                    suiteName:
                        SimRaWidgetConfiguration
                        .appGroupIdentifier
                )
        else {
            return SimRaRecordingEntry()
        }

        let recording =
            defaults.bool(
                forKey:
                    SimRaWidgetConfiguration
                    .recordingKey
            )

        let startTimestamp =
            defaults.double(
                forKey:
                    SimRaWidgetConfiguration
                    .startDateKey
            )

        let startDate:
            Date? =
                startTimestamp > 0
                ? Date(
                    timeIntervalSince1970:
                        startTimestamp
                )
                : nil

        let distance =
            max(
                defaults.double(
                    forKey:
                        SimRaWidgetConfiguration
                        .distanceKey
                ),
                0
            )

        let incidents =
            max(
                defaults.integer(
                    forKey:
                        SimRaWidgetConfiguration
                        .incidentsKey
                ),
                0
            )

        let routeData =
            defaults.data(
                forKey:
                    SimRaWidgetConfiguration
                    .routeCoordinatesKey
            )

        let weekly:
            (
                kilometers: [Double],
                rides: [Int]
            )

        if recording {

            weekly = (
                [0, 0, 0, 0],
                [0, 0, 0, 0]
            )

        } else {

            let statisticsData =
                defaults.data(
                    forKey:
                        SimRaWidgetConfiguration
                        .tripStatisticsKey
                )

            let statistics =
                readStatistics(
                    from:
                        statisticsData
                )

            weekly =
                calculateWeeklyStatistics(
                    statistics
                )
        }

        return SimRaRecordingEntry(
            date: .now,
            routeCoordinatesData:
                routeData,
            recording:
                recording,
            distanceMeters:
                distance,
            recordingStartDate:
                recording
                ? startDate
                : nil,
            incidentsCount:
                incidents,
            weeklyKilometers:
                weekly.kilometers,
            weeklyRideCounts:
                weekly.rides
        )
    }

    private func readStatistics(
        from data: Data?
    ) -> [
        SimRaStoredTripStatistic
    ] {

        guard
            let data,
            let values =
                try? JSONDecoder()
                    .decode(
                        [
                            SimRaStoredTripStatistic
                        ].self,
                        from:
                            data
                    )
        else {
            return []
        }

        return values
    }

    private func calculateWeeklyStatistics(
        _ statistics:
            [SimRaStoredTripStatistic]
    ) -> (
        kilometers: [Double],
        rides: [Int]
    ) {

        let calendar =
            Calendar.current

        guard
            let currentWeek =
                calendar.dateInterval(
                    of: .weekOfYear,
                    for: .now
                )
        else {
            return (
                [0, 0, 0, 0],
                [0, 0, 0, 0]
            )
        }

        var kilometers =
            [0.0, 0.0, 0.0, 0.0]

        var rides =
            [0, 0, 0, 0]

        for statistic in statistics {

            guard
                let weekDifference =
                    calendar.dateComponents(
                        [.weekOfYear],
                        from:
                            currentWeek.start,
                        to:
                            statistic.date
                    ).weekOfYear,
                (-3...0).contains(
                    weekDifference
                )
            else {
                continue
            }

            let index =
                weekDifference + 3

            guard
                (0..<4).contains(index)
            else {
                continue
            }

            kilometers[index] +=
                max(
                    statistic.distanceMeters,
                    0
                ) / 1_000

            rides[index] += 1
        }

        return (
            kilometers,
            rides
        )
    }
}

// MARK: - Widget

struct SimRaRecordingWidget:
    Widget {

    static let kind =
        "SimRaRecordingWidget"

    var body:
        some WidgetConfiguration {

        StaticConfiguration(
            kind: Self.kind,
            provider:
                SimRaRecordingProvider()
        ) { entry in

            SimRaRecordingWidgetView(
                entry:
                    entry
            )
        }
        .configurationDisplayName(
            "SimRa"
        )
        .description(
            "Aktuelle Aufzeichnung und Fahrtenstatistik."
        )
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Root

private struct SimRaRecordingWidgetView:
    View {

    let entry:
        SimRaRecordingEntry

    @Environment(\.widgetFamily)
    private var family

    var body: some View {

        Group {

            if entry.recording {

                RecordingWidgetView(
                    entry:
                        entry,
                    family:
                        family
                )

            } else {

                StatisticsWidgetView(
                    entry:
                        entry,
                    family:
                        family
                )
            }
        }
        .containerBackground(
            for: .widget
        ) {
            Color.clear
        }
    }
}

// MARK: - Recording Widget

private struct RecordingWidgetView:
    View {

    let entry:
        SimRaRecordingEntry

    let family:
        WidgetFamily

    var body: some View {

        switch family {

        case .systemSmall:

            SmallRecordingView(
                entry:
                    entry
            )

        case .systemMedium:

            MediumRecordingView(
                entry:
                    entry
            )

        case .systemLarge:

            LargeRecordingView(
                entry:
                    entry
            )

        case .systemExtraLarge:

            ExtraLargeRecordingView(
                entry:
                    entry
            )

        case .accessoryCircular:

            CircularRecordingView(
                entry:
                    entry
            )

        case .accessoryRectangular:

            RectangularRecordingView(
                entry:
                    entry
            )

        case .accessoryInline:

            InlineRecordingView(
                entry:
                    entry
            )

        @unknown default:

            MediumRecordingView(
                entry:
                    entry
            )
        }
    }
}

// MARK: - Small Recording

private struct SmallRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        ZStack {

            RecordingRouteBackground(
                routeData:
                    entry.routeCoordinatesData,
                accent:
                    Color.blue
            )
            .opacity(0.48)

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                HStack(spacing: 6) {

                    RecordingIndicator()

                    Text("SimRa")
                        .font(
                            .caption.weight(
                                .bold
                            )
                        )

                    Text("Aufnahme")
                        .font(
                            .caption2.weight(
                                .medium
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )

                    Spacer(
                        minLength: 4
                    )

                    if entry.incidentsCount > 0 {

                        IncidentBadge(
                            count:
                                entry.incidentsCount
                        )
                    }
                }

                Spacer(
                    minLength: 0
                )

                HStack(
                    alignment:
                        .lastTextBaseline,
                    spacing: 8
                ) {

                    RecordingDuration(
                        startDate:
                            entry.recordingStartDate,
                        size:
                            25
                    )

                    Spacer(
                        minLength: 0
                    )

                    Text(
                        formatDistance(
                            entry.distanceMeters
                        )
                    )
                    .font(
                        .caption.weight(
                            .semibold
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer(
                    minLength: 8
                )

                HStack(spacing: 8) {

                    DangerButton(
                        diameter:
                            36
                    )

                    StopButton(
                        diameter:
                            36
                    )

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Medium Recording

private struct MediumRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        ZStack {

            RecordingRouteBackground(
                routeData:
                    entry.routeCoordinatesData,
                accent:
                    Color.blue
            )
            .opacity(0.40)

            HStack(
                alignment: .top,
                spacing: 12
            ) {

                VStack(
                    alignment:
                        .leading,
                    spacing: 0
                ) {

                    HStack(spacing: 6) {

                        RecordingIndicator()

                        Text("SimRa")
                            .font(
                                .subheadline.weight(
                                    .bold
                                )
                            )

                        Text("Aufnahme")
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        if entry.incidentsCount > 0 {

                            IncidentBadge(
                                count:
                                    entry.incidentsCount
                            )
                        }
                    }

                    Spacer(
                        minLength: 0
                    )

                    HStack(
                        alignment:
                            .lastTextBaseline,
                        spacing: 10
                    ) {

                        RecordingDuration(
                            startDate:
                                entry.recordingStartDate,
                            size:
                                31
                        )

                        Text(
                            formatDistance(
                                entry.distanceMeters
                            )
                        )
                        .font(
                            .subheadline.weight(
                                .semibold
                            )
                        )
                        .monospacedDigit()
                        .foregroundStyle(
                            .secondary
                        )
                    }
                }

                Spacer(
                    minLength: 0
                )

                HStack(spacing: 8) {

                    DangerButton(
                        diameter:
                            44
                    )

                    StopButton(
                        diameter:
                            44
                    )
                }
            }
        }
    }
}

// MARK: - Large Recording

private struct LargeRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        ZStack {

            RecordingRouteBackground(
                routeData:
                    entry.routeCoordinatesData,
                accent:
                    Color.blue
            )
            .opacity(0.42)

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                RecordingTopBar(
                    entry:
                        entry
                )

                Spacer(
                    minLength: 0
                )

                HStack(
                    alignment:
                        .bottom,
                    spacing: 20
                ) {

                    VStack(
                        alignment:
                            .leading,
                        spacing: 3
                    ) {

                        Text(
                            "Aufnahmezeit"
                        )
                        .font(
                            .caption
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        RecordingDuration(
                            startDate:
                                entry.recordingStartDate,
                            size:
                                40
                        )
                    }

                    Spacer(
                        minLength: 0
                    )

                    VStack(
                        alignment:
                            .trailing,
                        spacing: 3
                    ) {

                        Text("Strecke")
                            .font(
                                .caption
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        Text(
                            formatDistance(
                                entry.distanceMeters
                            )
                        )
                        .font(
                            .system(
                                size: 31,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                    }
                }

                Spacer(
                    minLength: 14
                )

                HStack(
                    spacing: 10
                ) {

                    DangerButton(
                        diameter:
                            50
                    )

                    StopButton(
                        diameter:
                            50
                    )

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Extra Large Recording

private struct ExtraLargeRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        ZStack {

            RecordingRouteBackground(
                routeData:
                    entry.routeCoordinatesData,
                accent:
                    Color.blue
            )
            .opacity(0.36)

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                RecordingTopBar(
                    entry:
                        entry
                )

                Spacer(
                    minLength: 0
                )

                HStack(
                    alignment:
                        .bottom,
                    spacing: 36
                ) {

                    VStack(
                        alignment:
                            .leading,
                        spacing: 4
                    ) {

                        Text(
                            "Aufnahmezeit"
                        )
                        .font(
                            .subheadline
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        RecordingDuration(
                            startDate:
                                entry.recordingStartDate,
                            size:
                                48
                        )
                    }

                    VStack(
                        alignment:
                            .leading,
                        spacing: 4
                    ) {

                        Text("Strecke")
                            .font(
                                .subheadline
                            )
                            .foregroundStyle(
                                .secondary
                            )

                        Text(
                            formatDistance(
                                entry.distanceMeters
                            )
                        )
                        .font(
                            .system(
                                size: 40,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                    }

                    if entry.incidentsCount > 0 {

                        VStack(
                            alignment:
                                .leading,
                            spacing: 4
                        ) {

                            Text("Gefahren")
                                .font(
                                    .subheadline
                                )
                                .foregroundStyle(
                                    .secondary
                                )

                            Text(
                                "\(entry.incidentsCount)"
                            )
                            .font(
                                .system(
                                    size: 40,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .monospacedDigit()
                        }
                    }

                    Spacer(
                        minLength: 0
                    )
                }

                Spacer(
                    minLength: 18
                )

                HStack(
                    spacing: 12
                ) {

                    DangerButton(
                        diameter:
                            56
                    )

                    StopButton(
                        diameter:
                            56
                    )

                    Spacer()
                }
            }
        }
    }
}

// MARK: - Recording Top Bar

private struct RecordingTopBar:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        HStack(spacing: 7) {

            RecordingIndicator()

            Text("SimRa")
                .font(
                    .headline.weight(
                        .bold
                    )
                )

            Text("Aufnahme")
                .font(
                    .subheadline.weight(
                        .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )

            Spacer(
                minLength: 4
            )

            if entry.incidentsCount > 0 {

                IncidentBadge(
                    count:
                        entry.incidentsCount
                )
            }
        }
    }
}

// MARK: - Recording Indicator

private struct RecordingIndicator:
    View {

    var body: some View {

        Circle()
            .fill(.red)
            .frame(
                width: 8,
                height: 8
            )
            .accessibilityHidden(
                true
            )
    }
}

// MARK: - Incident Badge

private struct IncidentBadge:
    View {

    let count: Int

    var body: some View {

        HStack(spacing: 4) {

            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(
                .caption2.weight(
                    .semibold
                )
            )

            Text(
                "\(count)"
            )
            .font(
                .caption2.weight(
                    .bold
                )
            )
            .monospacedDigit()
        }
        .foregroundStyle(
            .orange
        )
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            "\(count) gemeldete Gefahren"
        )
    }
}

// MARK: - Duration

private struct RecordingDuration: View {

    let startDate: Date?
    let size: CGFloat

    private var endDate: Date {
        Date.distantFuture
    }

    var body: some View {
        Group {
            if let startDate {
                Text(
                    timerInterval: startDate...endDate,
                    pauseTime: nil,
                    countsDown: false
                )
            } else {
                Text("00:00")
            }
        }
        .font(
            .system(
                size: size,
                weight: .bold,
                design: .rounded
            )
        )
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .contentTransition(.numericText())
    }
}

// MARK: - Danger Button

private struct DangerButton:
    View {

    let diameter: CGFloat

    var body: some View {

        if let url =
            SimRaWidgetConfiguration
                .dangerURL {

            Link(
                destination:
                    url
            ) {
                content
            }
            .accessibilityLabel(
                "Gefahr melden"
            )
            .accessibilityHint(
                "Öffnet SimRa zum Melden einer Gefahr"
            )

        } else {

            content
        }
    }

    private var content: some View {

        Image(
            systemName:
                "exclamationmark.triangle.fill"
        )
        .font(
            .system(
                size:
                    diameter * 0.33,
                weight: .bold
            )
        )
        .foregroundStyle(
            .orange
        )
        .frame(
            width:
                diameter,
            height:
                diameter
        )
        .background(
            .orange.opacity(0.15),
            in:
                Circle()
        )
        .overlay {

            Circle()
                .stroke(
                    .orange.opacity(0.30),
                    lineWidth:
                        1
                )
        }
        .contentShape(
            Circle()
        )
    }
}

// MARK: - Stop Button

private struct StopButton:
    View {

    let diameter: CGFloat

    var body: some View {

        if let url =
            SimRaWidgetConfiguration
                .stopURL {

            Link(
                destination:
                    url
            ) {
                content
            }
            .accessibilityLabel(
                "Aufnahme stoppen"
            )
            .accessibilityHint(
                "Beendet die aktuelle Aufnahme"
            )

        } else {

            content
        }
    }

    private var content: some View {

        Image(
            systemName:
                "stop.fill"
        )
        .font(
            .system(
                size:
                    diameter * 0.29,
                weight: .bold
            )
        )
        .foregroundStyle(
            .red
        )
        .frame(
            width:
                diameter,
            height:
                diameter
        )
        .background(
            .red.opacity(0.14),
            in:
                Circle()
        )
        .overlay {

            Circle()
                .stroke(
                    .red.opacity(0.30),
                    lineWidth:
                        1
                )
        }
        .contentShape(
            Circle()
        )
    }
}

// MARK: - Route Background

private struct RecordingRouteBackground:
    View {

    let routeData: Data?
    let accent: Color

    private var coordinates:
        [CLLocationCoordinate2D] {

        guard
            let routeData,
            let values =
                try? JSONDecoder()
                    .decode(
                        [
                            SimRaWidgetCoordinate
                        ].self,
                        from:
                            routeData
                    )
        else {
            return []
        }

        let validCoordinates =
            values
                .map(\.location)
                .filter {
                    CLLocationCoordinate2DIsValid(
                        $0
                    )
                }

        return simplifiedCoordinates(
            validCoordinates
        )
    }

    var body: some View {

        GeometryReader { geometry in

            if coordinates.count >= 2 {

                RouteDrawingView(
                    coordinates:
                        coordinates,
                    size:
                        geometry.size,
                    accent:
                        accent
                )

            } else if coordinates.count == 1 {

                RouteSinglePointView(
                    accent:
                        accent
                )
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .allowsHitTesting(
            false
        )
        .clipped()
    }

    private func simplifiedCoordinates(
        _ coordinates:
            [CLLocationCoordinate2D]
    ) -> [
        CLLocationCoordinate2D
    ] {

        guard
            coordinates.count > 100
        else {
            return coordinates
        }

        let targetCount = 100

        let step =
            Double(
                coordinates.count - 1
            )
            /
            Double(
                targetCount - 1
            )

        var result:
            [CLLocationCoordinate2D] = []

        result.reserveCapacity(
            targetCount
        )

        for index in 0..<targetCount {

            let sourceIndex =
                min(
                    Int(
                        (
                            Double(index) *
                            step
                        )
                        .rounded()
                    ),
                    coordinates.count - 1
                )

            result.append(
                coordinates[
                    sourceIndex
                ]
            )
        }

        return result
    }
}

// MARK: - Single Route Point

private struct RouteSinglePointView:
    View {

    let accent: Color

    var body: some View {

        ZStack {

            Circle()
                .fill(
                    accent.opacity(0.10)
                )
                .frame(
                    width: 34,
                    height: 34
                )

            Circle()
                .fill(
                    accent.opacity(0.85)
                )
                .frame(
                    width: 9,
                    height: 9
                )
                .overlay {

                    Circle()
                        .stroke(
                            .background,
                            lineWidth:
                                2
                        )
                }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
    }
}

// MARK: - Route Drawing

private struct RouteDrawingView:
    View {

    let coordinates:
        [CLLocationCoordinate2D]

    let size: CGSize
    let accent: Color

    var body: some View {

        let layout =
            RouteLayout(
                coordinates:
                    coordinates,
                size:
                    size
            )

        ZStack {

            if layout.points.count >= 2 {

                routePath(
                    points:
                        layout.points
                )
                .stroke(
                    accent.opacity(0.10),
                    style:
                        StrokeStyle(
                            lineWidth:
                                layout.lineWidth + 7,
                            lineCap:
                                .round,
                            lineJoin:
                                .round
                        )
                )

                routePath(
                    points:
                        layout.points
                )
                .stroke(
                    accent.opacity(0.78),
                    style:
                        StrokeStyle(
                            lineWidth:
                                layout.lineWidth,
                            lineCap:
                                .round,
                            lineJoin:
                                .round
                        )
                )

                if let first =
                    layout.points.first {

                    Circle()
                        .fill(
                            .background
                        )
                        .frame(
                            width: 9,
                            height: 9
                        )
                        .overlay {

                            Circle()
                                .fill(
                                    .secondary
                                )
                                .frame(
                                    width: 5,
                                    height: 5
                                )
                        }
                        .position(
                            first
                        )
                }

                if let last =
                    layout.points.last {

                    ZStack {

                        Circle()
                            .fill(
                                accent.opacity(
                                    0.12
                                )
                            )
                            .frame(
                                width: 28,
                                height: 28
                            )

                        Circle()
                            .fill(
                                accent
                            )
                            .frame(
                                width: 10,
                                height: 10
                            )
                            .overlay {

                                Circle()
                                    .stroke(
                                        .background,
                                        lineWidth:
                                            2
                                    )
                            }
                    }
                    .position(
                        last
                    )
                }
            }
        }
        .frame(
            width:
                size.width,
            height:
                size.height
        )
    }

    private func routePath(
        points:
            [CGPoint]
    ) -> Path {

        Path { path in

            guard
                let first =
                    points.first
            else {
                return
            }

            path.move(
                to:
                    first
            )

            for point
                in points.dropFirst() {

                path.addLine(
                    to:
                        point
                )
            }
        }
    }
}

// MARK: - Route Layout

private struct RouteLayout {

    let points: [CGPoint]
    let lineWidth: CGFloat

    init(
        coordinates:
            [CLLocationCoordinate2D],
        size:
            CGSize
    ) {

        guard
            coordinates.count >= 2,
            size.width > 0,
            size.height > 0
        else {

            points = []
            lineWidth = 3
            return
        }

        let latitudes =
            coordinates.map(
                \.latitude
            )

        let longitudes =
            coordinates.map(
                \.longitude
            )

        guard
            let minLatitude =
                latitudes.min(),
            let maxLatitude =
                latitudes.max(),
            let minLongitude =
                longitudes.min(),
            let maxLongitude =
                longitudes.max()
        else {

            points = []
            lineWidth = 3
            return
        }

        let centerLatitude =
            (
                minLatitude +
                maxLatitude
            ) / 2

        let latitudeSpan =
            max(
                maxLatitude -
                    minLatitude,
                0.00001
            )

        let longitudeScale =
            max(
                cos(
                    centerLatitude *
                    Double.pi /
                    180
                ),
                0.1
            )

        let longitudeSpan =
            max(
                (
                    maxLongitude -
                    minLongitude
                ) *
                longitudeScale,
                0.00001
            )

        let padding =
            max(
                min(
                    min(
                        size.width,
                        size.height
                    ) *
                    0.08,
                    16
                ),
                6
            )

        let availableWidth =
            max(
                size.width -
                    padding * 2,
                1
            )

        let availableHeight =
            max(
                size.height -
                    padding * 2,
                1
            )

        let scale =
            min(
                availableWidth /
                    longitudeSpan,
                availableHeight /
                    latitudeSpan
            )

        let usedWidth =
            longitudeSpan *
            scale

        let usedHeight =
            latitudeSpan *
            scale

        let originX =
            (
                size.width -
                usedWidth
            ) / 2

        let originY =
            (
                size.height -
                usedHeight
            ) / 2

        points =
            coordinates.map {
                coordinate in

                let xNormalized =
                    (
                        (
                            coordinate.longitude -
                            minLongitude
                        ) *
                        longitudeScale
                    )
                    /
                    longitudeSpan

                let yNormalized =
                    (
                        maxLatitude -
                        coordinate.latitude
                    )
                    /
                    latitudeSpan

                return CGPoint(
                    x:
                        originX +
                        CGFloat(
                            xNormalized
                        ) *
                        usedWidth,

                    y:
                        originY +
                        CGFloat(
                            yNormalized
                        ) *
                        usedHeight
                )
            }

        let minimumDimension =
            min(
                size.width,
                size.height
            )

        lineWidth =
            min(
                max(
                    minimumDimension *
                        0.020,
                    2.0
                ),
                4.0
            )
    }
}

// MARK: - Accessory Circular

private struct CircularRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        ZStack {

            Circle()
                .fill(
                    .background
                )

            Circle()
                .stroke(
                    .red.opacity(0.75),
                    lineWidth:
                        2
                )
                .padding(3)

            VStack(spacing: 1) {

                Image(
                    systemName:
                        "bicycle"
                )
                .font(
                    .caption.weight(
                        .bold
                    )
                )

                RecordingDuration(
                    startDate:
                        entry.recordingStartDate,
                    size:
                        12
                )
            }
        }
        .widgetLabel {

            Text(
                formatDistance(
                    entry.distanceMeters
                )
            )
        }
    }
}

// MARK: - Accessory Rectangular

private struct RectangularRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        HStack(spacing: 7) {

            RecordingIndicator()

            VStack(
                alignment: .leading,
                spacing: 1
            ) {

                Text("SimRa")
                    .font(
                        .caption.weight(
                            .semibold
                        )
                    )

                RecordingDuration(
                    startDate:
                        entry.recordingStartDate,
                    size:
                        16
                )
            }

            Spacer(
                minLength: 4
            )

            Text(
                formatDistance(
                    entry.distanceMeters
                )
            )
            .font(
                .caption.weight(
                    .semibold
                )
            )
            .monospacedDigit()
        }
    }
}

// MARK: - Accessory Inline

private struct InlineRecordingView:
    View {

    let entry:
        SimRaRecordingEntry

    var body: some View {

        Label {

            HStack(spacing: 4) {

                RecordingDuration(
                    startDate:
                        entry.recordingStartDate,
                    size:
                        14
                )

                Text("·")

                Text(
                    formatDistance(
                        entry.distanceMeters
                    )
                )
                .monospacedDigit()
            }

        } icon: {

            Image(
                systemName:
                    "bicycle"
            )
        }
    }
}

// MARK: - Statistics Widget

private struct StatisticsWidgetView:
    View {

    let entry:
        SimRaRecordingEntry

    let family:
        WidgetFamily

    var body: some View {

        switch family {

        case .systemSmall:

            SmallStatisticsView(
                entry:
                    entry
            )

        case .systemMedium:

            MediumStatisticsView(
                entry:
                    entry
            )

        case .systemLarge:

            LargeStatisticsView(
                entry:
                    entry,
                family:
                    family
            )

        case .systemExtraLarge:

            LargeStatisticsView(
                entry:
                    entry,
                family:
                    family
            )

        case .accessoryCircular:

            CircularStatisticsView(
                entry:
                    entry
            )

        case .accessoryRectangular:

            RectangularStatisticsView(
                entry:
                    entry
            )

        case .accessoryInline:

            InlineStatisticsView(
                entry:
                    entry
            )

        @unknown default:

            MediumStatisticsView(
                entry:
                    entry
            )
        }
    }
}

// MARK: - Small Statistics

private struct SmallStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 0
        ) {

            StatisticsHeader(
                compact:
                    true
            )

            Spacer(
                minLength: 8
            )

            HStack(
                alignment:
                    .firstTextBaseline,
                spacing: 4
            ) {

                Text(
                    String(
                        format:
                            "%.1f",
                        totalKilometers
                    )
                )
                .font(
                    .system(
                        size: 30,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .monospacedDigit()

                Text("km")
                    .font(
                        .caption.weight(
                            .medium
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
            }

            Text("in 4 Wochen")
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )

            Spacer(
                minLength: 7
            )

            MiniWeeklyBars(
                values:
                    entry.weeklyKilometers
            )

            Spacer(
                minLength: 7
            )

            StartRecordingButton(
                compact:
                    true
            )
        }
        .padding(12)
    }
}

// MARK: - Medium Statistics

private struct MediumStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }

    private var totalRides:
        Int {

        entry.weeklyRideCounts.reduce(
            0,
            +
        )
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            StatisticsHeader(
                compact:
                    false
            )

            HStack(
                alignment:
                    .bottom,
                spacing:
                    16
            ) {

                VStack(
                    alignment:
                        .leading,
                    spacing: 2
                ) {

                    HStack(
                        alignment:
                            .firstTextBaseline,
                        spacing: 4
                    ) {

                        Text(
                            String(
                                format:
                                    "%.1f",
                                totalKilometers
                            )
                        )
                        .font(
                            .system(
                                size: 36,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()

                        Text("km")
                            .font(
                                .subheadline.weight(
                                    .medium
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                    }

                    Text(
                        "\(totalRides) Fahrten"
                    )
                    .font(
                        .subheadline
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }

                Spacer(
                    minLength: 0
                )

                MiniWeeklyBars(
                    values:
                        entry.weeklyKilometers
                )
                .frame(
                    width: 145
                )
            }

            Spacer(
                minLength: 0
            )

            StartRecordingButton(
                compact:
                    false
            )
        }
        .padding(14)
    }
}

// MARK: - Large Statistics

private struct LargeStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    let family:
        WidgetFamily

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }

    private var totalRides:
        Int {

        entry.weeklyRideCounts.reduce(
            0,
            +
        )
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            StatisticsHeader(
                compact:
                    false
            )

            HStack(
                spacing:
                    family ==
                    .systemExtraLarge
                    ? 18
                    : 12
            ) {

                StatisticBlock(
                    title:
                        "Kilometer",
                    value:
                        String(
                            format:
                                "%.1f",
                            totalKilometers
                        ),
                    unit:
                        "km",
                    icon:
                        "bicycle"
                )

                StatisticBlock(
                    title:
                        "Fahrten",
                    value:
                        String(
                            totalRides
                        ),
                    unit:
                        nil,
                    icon:
                        "arrow.triangle.2.circlepath"
                )
            }

            WeeklyBars(
                values:
                    entry.weeklyKilometers,
                compact:
                    family ==
                    .systemLarge
            )

            Spacer(
                minLength: 0
            )

            StartRecordingButton(
                compact:
                    false
            )
        }
        .padding(
            family ==
                .systemExtraLarge
            ? 20
            : 16
        )
    }
}

// MARK: - Statistics Header

private struct StatisticsHeader:
    View {

    let compact: Bool

    var body: some View {

        HStack(spacing: 7) {

            Image(
                systemName:
                    "bicycle"
            )
            .font(
                .system(
                    size:
                        compact
                        ? 12
                        : 14,
                    weight:
                        .semibold
                )
            )

            Text("SimRa")
                .font(
                    compact
                    ? .caption.weight(
                        .bold
                    )
                    : .headline.weight(
                        .semibold
                    )
                )

            Spacer(
                minLength: 4
            )

            if !compact {

                Text("4 Wochen")
                    .font(
                        .caption2.weight(
                            .medium
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
            }
        }
    }
}

// MARK: - Statistic Block

private struct StatisticBlock:
    View {

    let title: String
    let value: String
    let unit: String?
    let icon: String

    var body: some View {

        HStack(spacing: 9) {

            Image(
                systemName:
                    icon
            )
            .font(
                .title3.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                .green
            )

            VStack(
                alignment:
                    .leading,
                spacing: 1
            ) {

                Text(title)
                    .font(
                        .caption
                    )
                    .foregroundStyle(
                        .secondary
                    )

                HStack(
                    alignment:
                        .firstTextBaseline,
                    spacing: 3
                ) {

                    Text(value)
                        .font(
                            .system(
                                size: 28,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()

                    if let unit {

                        Text(unit)
                            .font(
                                .caption.weight(
                                    .medium
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Weekly Bars

private struct WeeklyBars:
    View {

    let values:
        [Double]

    let compact:
        Bool

    var body: some View {

        GeometryReader { geometry in

            let safeValues =
                normalizedValues

            let maximum =
                max(
                    safeValues.max() ?? 0,
                    1
                )

            HStack(
                alignment: .bottom,
                spacing:
                    compact
                    ? 8
                    : 12
            ) {

                ForEach(
                    safeValues.indices,
                    id:
                        \.self
                ) { index in

                    VStack(
                        spacing: 5
                    ) {

                        Spacer(
                            minLength: 0
                        )

                        RoundedRectangle(
                            cornerRadius: 5,
                            style:
                                .continuous
                        )
                        .fill(
                            .green.opacity(
                                index ==
                                    safeValues.count -
                                    1
                                ? 0.95
                                : 0.42
                            )
                        )
                        .frame(
                            height:
                                max(
                                    6,
                                    geometry.size.height *
                                        0.68 *
                                        CGFloat(
                                            safeValues[index] /
                                            maximum
                                        )
                                )
                        )

                        Text(
                            weekLabel(
                                index
                            )
                        )
                        .font(
                            .system(
                                size:
                                    compact
                                    ? 8
                                    : 9,
                                weight:
                                    .medium
                            )
                        )
                        .foregroundStyle(
                            .tertiary
                        )
                    }
                    .frame(
                        maxWidth:
                            .infinity
                    )
                }
            }
        }
        .frame(
            height:
                compact
                ? 72
                : 92
        )
    }

    private var normalizedValues:
        [Double] {

        let suffix =
            Array(
                values.suffix(4)
            )

        return
            Array(
                repeating:
                    0,
                count:
                    max(
                        0,
                        4 -
                        suffix.count
                    )
            )
            +
            suffix
    }

    private func weekLabel(
        _ index: Int
    ) -> String {

        let calendar =
            Calendar.current

        guard
            let currentWeek =
                calendar.dateInterval(
                    of:
                        .weekOfYear,
                    for:
                        .now
                ),
            let date =
                calendar.date(
                    byAdding:
                        .weekOfYear,
                    value:
                        index - 3,
                    to:
                        currentWeek.start
                )
        else {
            return "-"
        }

        let week =
            calendar.component(
                .weekOfYear,
                from:
                    date
            )

        return "KW \(week)"
    }
}

// MARK: - Mini Weekly Bars

private struct MiniWeeklyBars:
    View {

    let values:
        [Double]

    var body: some View {

        GeometryReader { geometry in

            let safeValues =
                normalizedValues

            let maximum =
                max(
                    safeValues.max() ?? 0,
                    1
                )

            HStack(
                alignment:
                    .bottom,
                spacing:
                    6
            ) {

                ForEach(
                    safeValues.indices,
                    id:
                        \.self
                ) { index in

                    RoundedRectangle(
                        cornerRadius: 3,
                        style:
                            .continuous
                    )
                    .fill(
                        .green.opacity(
                            index == 3
                            ? 0.95
                            : 0.40
                        )
                    )
                    .frame(
                        height:
                            max(
                                4,
                                geometry.size.height *
                                    CGFloat(
                                        safeValues[index] /
                                        maximum
                                    )
                            )
                    )
                    .frame(
                        maxWidth:
                            .infinity,
                        alignment:
                            .bottom
                    )
                }
            }
        }
        .frame(
            height:
                42
        )
    }

    private var normalizedValues:
        [Double] {

        let suffix =
            Array(
                values.suffix(4)
            )

        return
            Array(
                repeating:
                    0,
                count:
                    max(
                        0,
                        4 -
                        suffix.count
                    )
            )
            +
            suffix
    }
}

// MARK: - Start Recording

private struct StartRecordingButton:
    View {

    let compact:
        Bool

    var body: some View {

        if let url =
            SimRaWidgetConfiguration
                .startURL {

            Link(
                destination:
                    url
            ) {
                content
            }
            .accessibilityLabel(
                "Aufnahme starten"
            )

        } else {

            content
        }
    }

    private var content:
        some View {

        HStack(spacing: 7) {

            Image(
                systemName:
                    "record.circle.fill"
            )
            .font(
                .system(
                    size:
                        compact
                        ? 13
                        : 14,
                    weight:
                        .bold
                )
            )

            Text(
                "Aufnahme starten"
            )
            .font(
                compact
                ? .caption.weight(
                    .semibold
                )
                : .subheadline.weight(
                    .semibold
                )
            )
            .lineLimit(1)
            .minimumScaleFactor(
                0.8
            )
        }
        .foregroundStyle(
            .green
        )
        .frame(
            maxWidth:
                .infinity,
            minHeight:
                compact
                ? 30
                : 34
        )
        .background(
            .green.opacity(0.10),
            in:
                Capsule()
        )
    }
}

// MARK: - Accessory Statistics

private struct CircularStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }

    var body: some View {

        VStack(spacing: 0) {

            Image(
                systemName:
                    "bicycle"
            )
            .font(
                .caption.weight(
                    .semibold
                )
            )

            Text(
                String(
                    format:
                        "%.0f",
                    totalKilometers
                )
            )
            .font(
                .caption.weight(
                    .bold
                )
            )
            .monospacedDigit()
        }
    }
}

private struct RectangularStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }

    var body: some View {

        HStack {

            Image(
                systemName:
                    "bicycle"
            )

            VStack(
                alignment:
                    .leading,
                spacing: 1
            ) {

                Text("SimRa")
                    .font(
                        .caption.weight(
                            .semibold
                        )
                    )

                Text(
                    String(
                        format:
                            "%.1f km",
                        totalKilometers
                    )
                )
                .font(
                    .caption2
                )
                .monospacedDigit()
            }
        }
    }
}

private struct InlineStatisticsView:
    View {

    let entry:
        SimRaRecordingEntry

    private var totalKilometers:
        Double {

        entry.weeklyKilometers.reduce(
            0,
            +
        )
    }

    var body: some View {

        Label(
            String(
                format:
                    "%.1f km",
                totalKilometers
            ),
            systemImage:
                "bicycle"
        )
    }
}

// MARK: - Distance Formatting

private func formatDistance(
    _ meters: Double
) -> String {

    let safeMeters =
        max(
            meters,
            0
        )

    if safeMeters < 1_000 {

        return String(
            format:
                "%.0f m",
            safeMeters
        )
    }

    let kilometers =
        safeMeters / 1_000

    if kilometers < 10 {

        return String(
            format:
                "%.1f km",
            kilometers
        )
    }

    return String(
        format:
            "%.0f km",
        kilometers
    )
}
