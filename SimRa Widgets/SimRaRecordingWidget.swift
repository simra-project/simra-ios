//
//  SimRaRecordingWidget.swift
//  SimRa Widgets
//
//  Created by Emil Pauls on 26.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import AppIntents
import CoreLocation
import SwiftUI
import WidgetKit

// MARK: - Configuration

private enum SimRaWidgetConfiguration {

    static let appGroupIdentifier = "group.de.tu-berlin.mcc.simra"

    static let recordingKey = "isRecording"
    static let startDateKey = "startDate"
    static let distanceKey = "distanceMeters"
    static let incidentsKey = "incidents"
    static let routeCoordinatesKey = "widgetRouteCoordinates"
    static let tripStatisticsKey = "widgetTripStatistics"

    static let startURL = URL(string: "simra://recording/start")
    static let openURL = URL(string: "simra://recording")

    /// Number of weeks shown in the statistics (oldest first, current week last).
    static let weekCount = 4
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
        self.distanceMeters = max(distanceMeters, 0)
        self.recordingStartDate = recordingStartDate
        self.incidentsCount = max(incidentsCount, 0)
        self.weeklyKilometers = weeklyKilometers
        self.weeklyRideCounts = weeklyRideCounts
    }
}

private extension SimRaRecordingEntry {

    var totalKilometers: Double {
        weeklyKilometers.reduce(0, +)
    }

    var totalRides: Int {
        weeklyRideCounts.reduce(0, +)
    }
}

// MARK: - Coordinate

struct SimRaWidgetCoordinate: Codable, Equatable {

    let latitude: Double
    let longitude: Double

    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Stored Statistic

private struct SimRaStoredTripStatistic: Codable {

    let date: Date
    let distanceMeters: Double
}

// MARK: - Timeline Provider

struct SimRaRecordingProvider: TimelineProvider {

    func placeholder(in context: Context) -> SimRaRecordingEntry {
        SimRaRecordingEntry(
            recording: true,
            distanceMeters: 6_800,
            recordingStartDate: Date(timeIntervalSinceNow: -642),
            incidentsCount: 1,
            weeklyKilometers: [7.4, 15.8, 11.2, 21.6],
            weeklyRideCounts: [2, 4, 3, 5]
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (SimRaRecordingEntry) -> Void
    ) {
        // Show sample data in the widget gallery instead of an empty widget.
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<SimRaRecordingEntry>) -> Void
    ) {
        let entry = currentEntry()
        let refreshInterval: TimeInterval = entry.recording ? 5 * 60 : 15 * 60

        completion(
            Timeline(
                entries: [entry],
                policy: .after(.now.addingTimeInterval(refreshInterval))
            )
        )
    }

    // MARK: Reading

    private func currentEntry() -> SimRaRecordingEntry {
        guard let defaults = UserDefaults(suiteName: SimRaWidgetConfiguration.appGroupIdentifier)
        else {
            return SimRaRecordingEntry()
        }

        let recording = defaults.bool(forKey: SimRaWidgetConfiguration.recordingKey)

        let startTimestamp = defaults.double(forKey: SimRaWidgetConfiguration.startDateKey)
        let startDate = startTimestamp > 0 ? Date(timeIntervalSince1970: startTimestamp) : nil

        let weekly: (kilometers: [Double], rides: [Int])

        if recording {
            weekly = (Array(repeating: 0, count: SimRaWidgetConfiguration.weekCount),
                      Array(repeating: 0, count: SimRaWidgetConfiguration.weekCount))
        } else {
            weekly = calculateWeeklyStatistics(
                readStatistics(from: defaults.data(forKey: SimRaWidgetConfiguration.tripStatisticsKey))
            )
        }

        return SimRaRecordingEntry(
            routeCoordinatesData: defaults.data(forKey: SimRaWidgetConfiguration.routeCoordinatesKey),
            recording: recording,
            distanceMeters: defaults.double(forKey: SimRaWidgetConfiguration.distanceKey),
            recordingStartDate: recording ? startDate : nil,
            incidentsCount: defaults.integer(forKey: SimRaWidgetConfiguration.incidentsKey),
            weeklyKilometers: weekly.kilometers,
            weeklyRideCounts: weekly.rides
        )
    }

    private func readStatistics(from data: Data?) -> [SimRaStoredTripStatistic] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([SimRaStoredTripStatistic].self, from: data)) ?? []
    }

    private func calculateWeeklyStatistics(
        _ statistics: [SimRaStoredTripStatistic]
    ) -> (kilometers: [Double], rides: [Int]) {

        let weekCount = SimRaWidgetConfiguration.weekCount
        var kilometers = Array(repeating: 0.0, count: weekCount)
        var rides = Array(repeating: 0, count: weekCount)

        let calendar = Calendar.current

        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
        else {
            return (kilometers, rides)
        }

        for statistic in statistics {
            // Compare week starts with each other. Comparing the current week start
            // with the trip date directly would truncate partial weeks to 0 and
            // count trips from last week as "this week".
            guard
                let tripWeekStart = calendar.dateInterval(of: .weekOfYear, for: statistic.date)?.start,
                let weekDifference = calendar.dateComponents(
                    [.weekOfYear],
                    from: currentWeekStart,
                    to: tripWeekStart
                ).weekOfYear,
                (-(weekCount - 1)...0).contains(weekDifference)
            else {
                continue
            }

            let index = weekDifference + weekCount - 1
            kilometers[index] += max(statistic.distanceMeters, 0) / 1_000
            rides[index] += 1
        }

        return (kilometers, rides)
    }
}

// MARK: - Widget

struct SimRaRecordingWidget: Widget {

    static let kind = "SimRaRecordingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: SimRaRecordingProvider()) { entry in
            SimRaRecordingWidgetView(entry: entry)
        }
        .configurationDisplayName("SimRa")
        .description("Aktuelle Aufzeichnung und Fahrtenstatistik.")
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

private struct SimRaRecordingWidgetView: View {

    let entry: SimRaRecordingEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if entry.recording {
                RecordingWidgetView(entry: entry, family: family)
            } else {
                StatisticsWidgetView(entry: entry, family: family)
            }
        }
        // Tapping outside of buttons opens the app (only tap target in .systemSmall
        // besides intent buttons, because Link is not supported there).
        .widgetURL(entry.recording ? SimRaWidgetConfiguration.openURL : SimRaWidgetConfiguration.startURL)
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

// MARK: - Recording Widget

private struct RecordingWidgetView: View {

    let entry: SimRaRecordingEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall:
            SmallRecordingView(entry: entry)
        case .systemMedium:
            MediumRecordingView(entry: entry)
        case .systemLarge:
            LargeRecordingView(entry: entry)
        case .systemExtraLarge:
            ExtraLargeRecordingView(entry: entry)
        case .accessoryCircular:
            CircularRecordingView(entry: entry)
        case .accessoryRectangular:
            RectangularRecordingView(entry: entry)
        case .accessoryInline:
            InlineRecordingView(entry: entry)
        default:
            MediumRecordingView(entry: entry)
        }
    }
}

// MARK: - Small Recording

private struct SmallRecordingView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        ZStack {
            RecordingRouteBackground(routeData: entry.routeCoordinatesData, accent: .blue)
                .opacity(0.48)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    RecordingIndicator()

                    Text(verbatim: "SimRa")
                        .font(.caption.weight(.bold))

                    Text("Aufnahme")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 4)

                    if entry.incidentsCount > 0 {
                        IncidentBadge(count: entry.incidentsCount)
                    }
                }
                .lineLimit(1)

                Spacer(minLength: 0)

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    RecordingDuration(startDate: entry.recordingStartDate, size: 25)

                    Spacer(minLength: 0)

                    Text(formatDistance(entry.distanceMeters))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    DangerButton(diameter: 36)
                    StopButton(diameter: 36)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Medium Recording

private struct MediumRecordingView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        ZStack {
            RecordingRouteBackground(routeData: entry.routeCoordinatesData, accent: .blue)
                .opacity(0.40)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        RecordingIndicator()

                        Text(verbatim: "SimRa")
                            .font(.subheadline.weight(.bold))

                        Text("Aufnahme")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if entry.incidentsCount > 0 {
                            IncidentBadge(count: entry.incidentsCount)
                        }
                    }

                    Spacer(minLength: 0)

                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        RecordingDuration(startDate: entry.recordingStartDate, size: 31)

                        Text(formatDistance(entry.distanceMeters))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    DangerButton(diameter: 44)
                    StopButton(diameter: 44)
                }
            }
        }
    }
}

// MARK: - Large Recording

private struct LargeRecordingView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        ZStack {
            RecordingRouteBackground(routeData: entry.routeCoordinatesData, accent: .blue)
                .opacity(0.42)

            VStack(alignment: .leading, spacing: 0) {
                RecordingTopBar(entry: entry)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 20) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Aufnahmezeit")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        RecordingDuration(startDate: entry.recordingStartDate, size: 40)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Strecke")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(formatDistance(entry.distanceMeters))
                            .font(.system(size: 31, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .fixedSize()
                    }
                }

                Spacer(minLength: 14)

                HStack(spacing: 10) {
                    DangerButton(diameter: 50)
                    StopButton(diameter: 50)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Extra Large Recording

private struct ExtraLargeRecordingView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        ZStack {
            RecordingRouteBackground(routeData: entry.routeCoordinatesData, accent: .blue)
                .opacity(0.36)

            VStack(alignment: .leading, spacing: 0) {
                RecordingTopBar(entry: entry)

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 36) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aufnahmezeit")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        RecordingDuration(startDate: entry.recordingStartDate, size: 48)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Strecke")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(formatDistance(entry.distanceMeters))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .fixedSize()
                    }

                    if entry.incidentsCount > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gefahren")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(entry.incidentsCount, format: .number)
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .monospacedDigit()
                        }
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 18)

                HStack(spacing: 12) {
                    DangerButton(diameter: 56)
                    StopButton(diameter: 56)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Recording Top Bar

private struct RecordingTopBar: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        HStack(spacing: 7) {
            RecordingIndicator()

            Text(verbatim: "SimRa")
                .font(.headline.weight(.bold))

            Text("Aufnahme")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer(minLength: 4)

            if entry.incidentsCount > 0 {
                IncidentBadge(count: entry.incidentsCount)
            }
        }
    }
}

// MARK: - Recording Indicator

private struct RecordingIndicator: View {

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }
}

// MARK: - Incident Badge

private struct IncidentBadge: View {

    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption2.weight(.semibold))

            Text(count, format: .number)
                .font(.caption2.weight(.bold))
                .monospacedDigit()
        }
        .foregroundStyle(.orange)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) gemeldete Gefahren")
    }
}

// MARK: - Duration

private struct RecordingDuration: View {

    let startDate: Date?
    let size: CGFloat

    var body: some View {
        Group {
            if let startDate {
                Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
            } else {
                Text(verbatim: "00:00")
            }
        }
        .font(.system(size: size, weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }
}

// MARK: - Action Buttons

/// Runs the action directly via App Intent. Unlike `Link`, this also works
/// in `.systemSmall` and does not have to open the app.
private struct CircleIntentButton<Intent: AppIntent>: View {

    let intent: Intent
    let systemImage: String
    let tint: Color
    let iconScale: CGFloat
    let diameter: CGFloat
    let label: LocalizedStringKey

    var body: some View {
        Button(intent: intent) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * iconScale, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: diameter, height: diameter)
                .background(tint.opacity(0.15), in: Circle())
                .overlay {
                    Circle().stroke(tint.opacity(0.30), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

private struct DangerButton: View {

    let diameter: CGFloat

    var body: some View {
        CircleIntentButton(
            intent: MarkGeneralIncidentIntent(),
            systemImage: "exclamationmark.triangle.fill",
            tint: .orange,
            iconScale: 0.33,
            diameter: diameter,
            label: "Gefahr melden"
        )
    }
}

private struct StopButton: View {

    let diameter: CGFloat

    var body: some View {
        CircleIntentButton(
            intent: StopRecordingIntent(),
            systemImage: "stop.fill",
            tint: .red,
            iconScale: 0.29,
            diameter: diameter,
            label: "Aufnahme stoppen"
        )
    }
}

// MARK: - Route Background

private struct RecordingRouteBackground: View {

    let routeData: Data?
    let accent: Color

    var body: some View {
        // Decode once per render instead of once per access.
        let coordinates = Self.coordinates(from: routeData)

        GeometryReader { geometry in
            if coordinates.count >= 2 {
                RouteDrawingView(coordinates: coordinates, size: geometry.size, accent: accent)
            } else if coordinates.count == 1 {
                RouteSinglePointView(accent: accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .clipped()
        .accessibilityHidden(true)
    }

    private static func coordinates(from data: Data?) -> [CLLocationCoordinate2D] {
        guard
            let data,
            let values = try? JSONDecoder().decode([SimRaWidgetCoordinate].self, from: data)
        else {
            return []
        }

        return simplified(values.map(\.location).filter(CLLocationCoordinate2DIsValid))
    }

    /// Evenly thins out the route to at most `targetCount` points.
    private static func simplified(
        _ coordinates: [CLLocationCoordinate2D],
        targetCount: Int = 100
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count > targetCount else { return coordinates }

        let step = Double(coordinates.count - 1) / Double(targetCount - 1)

        return (0..<targetCount).map { index in
            coordinates[min(Int((Double(index) * step).rounded()), coordinates.count - 1)]
        }
    }
}

// MARK: - Single Route Point

private struct RouteSinglePointView: View {

    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.10))
                .frame(width: 34, height: 34)

            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: 9, height: 9)
                .overlay {
                    Circle().stroke(.background, lineWidth: 2)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Route Drawing

private struct RouteDrawingView: View {

    let coordinates: [CLLocationCoordinate2D]
    let size: CGSize
    let accent: Color

    var body: some View {
        let layout = RouteLayout(coordinates: coordinates, size: size)

        ZStack {
            if layout.points.count >= 2, let first = layout.points.first, let last = layout.points.last {
                let path = Path { $0.addLines(layout.points) }

                path.stroke(
                    accent.opacity(0.10),
                    style: StrokeStyle(lineWidth: layout.lineWidth + 7, lineCap: .round, lineJoin: .round)
                )

                path.stroke(
                    accent.opacity(0.78),
                    style: StrokeStyle(lineWidth: layout.lineWidth, lineCap: .round, lineJoin: .round)
                )

                // Start point
                Circle()
                    .fill(.background)
                    .frame(width: 9, height: 9)
                    .overlay {
                        Circle()
                            .fill(.secondary)
                            .frame(width: 5, height: 5)
                    }
                    .position(first)

                // Current position
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 28, height: 28)

                    Circle()
                        .fill(accent)
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle().stroke(.background, lineWidth: 2)
                        }
                }
                .position(last)
            }
        }
        .frame(width: size.width, height: size.height)
    }
}

// MARK: - Route Layout

private struct RouteLayout {

    let points: [CGPoint]
    let lineWidth: CGFloat

    init(coordinates: [CLLocationCoordinate2D], size: CGSize) {
        let minimumDimension = min(size.width, size.height)
        lineWidth = min(max(minimumDimension * 0.020, 2.0), 4.0)

        guard
            coordinates.count >= 2,
            size.width > 0,
            size.height > 0,
            let minLatitude = coordinates.map(\.latitude).min(),
            let maxLatitude = coordinates.map(\.latitude).max(),
            let minLongitude = coordinates.map(\.longitude).min(),
            let maxLongitude = coordinates.map(\.longitude).max()
        else {
            points = []
            return
        }

        // Equirectangular approximation, sufficient for a single ride.
        let centerLatitude = (minLatitude + maxLatitude) / 2
        let longitudeScale = max(cos(centerLatitude * .pi / 180), 0.1)

        let latitudeSpan = max(maxLatitude - minLatitude, 0.00001)
        let longitudeSpan = max((maxLongitude - minLongitude) * longitudeScale, 0.00001)

        let padding = max(min(minimumDimension * 0.08, 16), 6)
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)

        let scale = min(
            availableWidth / CGFloat(longitudeSpan),
            availableHeight / CGFloat(latitudeSpan)
        )

        let usedWidth = CGFloat(longitudeSpan) * scale
        let usedHeight = CGFloat(latitudeSpan) * scale
        let originX = (size.width - usedWidth) / 2
        let originY = (size.height - usedHeight) / 2

        points = coordinates.map { coordinate in
            let x = (coordinate.longitude - minLongitude) * longitudeScale / longitudeSpan
            let y = (maxLatitude - coordinate.latitude) / latitudeSpan

            return CGPoint(
                x: originX + CGFloat(x) * usedWidth,
                y: originY + CGFloat(y) * usedHeight
            )
        }
    }
}

// MARK: - Accessory Recording

private struct CircularRecordingView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Circle()
                .stroke(.red.opacity(0.75), lineWidth: 2)
                .padding(3)

            VStack(spacing: 1) {
                Image(systemName: "bicycle")
                    .font(.caption.weight(.bold))

                RecordingDuration(startDate: entry.recordingStartDate, size: 12)
                    .padding(.horizontal, 6)
            }
        }
        .widgetLabel {
            Text(formatDistance(entry.distanceMeters))
        }
    }
}

private struct RectangularRecordingView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        HStack(spacing: 7) {
            RecordingIndicator()

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "SimRa")
                    .font(.caption.weight(.semibold))

                RecordingDuration(startDate: entry.recordingStartDate, size: 16)
            }

            Spacer(minLength: 4)

            Text(formatDistance(entry.distanceMeters))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .fixedSize()
        }
    }
}

private struct InlineRecordingView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        // Inline widgets render only a single Text plus icon, no stacks.
        Label {
            if let startDate = entry.recordingStartDate {
                Text("\(Text(timerInterval: startDate...Date.distantFuture, countsDown: false)) · \(formatDistance(entry.distanceMeters))")
            } else {
                Text(formatDistance(entry.distanceMeters))
            }
        } icon: {
            Image(systemName: "bicycle")
        }
    }
}

// MARK: - Statistics Widget

private struct StatisticsWidgetView: View {

    let entry: SimRaRecordingEntry
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall:
            SmallStatisticsView(entry: entry)
        case .systemMedium:
            MediumStatisticsView(entry: entry)
        case .systemLarge, .systemExtraLarge:
            LargeStatisticsView(entry: entry, family: family)
        case .accessoryCircular:
            CircularStatisticsView(entry: entry)
        case .accessoryRectangular:
            RectangularStatisticsView(entry: entry)
        case .accessoryInline:
            InlineStatisticsView(entry: entry)
        default:
            MediumStatisticsView(entry: entry)
        }
    }
}

// MARK: - Small Statistics

private struct SmallStatisticsView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StatisticsHeader(compact: true)

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatKilometers(entry.totalKilometers))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Text(verbatim: "km")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.totalRides) Fahrten · 4 Wochen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 7)

            MiniWeeklyBars(values: entry.weeklyKilometers)

            Spacer(minLength: 7)

            StartRecordingButton(compact: true)
        }
    }
}

// MARK: - Medium Statistics

private struct MediumStatisticsView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatisticsHeader(compact: false)

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatKilometers(entry.totalKilometers))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text(verbatim: "km")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Text("\(entry.totalRides) Fahrten")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                MiniWeeklyBars(values: entry.weeklyKilometers)
                    .frame(width: 145)
            }

            Spacer(minLength: 0)

            StartRecordingButton(compact: false)
        }
    }
}

// MARK: - Large Statistics

private struct LargeStatisticsView: View {

    let entry: SimRaRecordingEntry
    let family: WidgetFamily

    private var isExtraLarge: Bool {
        family == .systemExtraLarge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatisticsHeader(compact: false)

            HStack(spacing: isExtraLarge ? 18 : 12) {
                StatisticBlock(
                    title: "Kilometer",
                    value: formatKilometers(entry.totalKilometers),
                    unit: "km",
                    icon: "bicycle"
                )

                StatisticBlock(
                    title: "Fahrten",
                    value: entry.totalRides.formatted(),
                    unit: nil,
                    icon: "arrow.triangle.2.circlepath"
                )
            }

            WeeklyBars(values: entry.weeklyKilometers, compact: !isExtraLarge)

            Spacer(minLength: 0)

            StartRecordingButton(compact: false)
        }
        .padding(isExtraLarge ? 4 : 0)
    }
}

// MARK: - Statistics Header

private struct StatisticsHeader: View {

    let compact: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "bicycle")
                .font(.system(size: compact ? 12 : 14, weight: .semibold))

            Text(verbatim: "SimRa")
                .font(compact ? .caption.weight(.bold) : .headline.weight(.semibold))

            Spacer(minLength: 4)

            if !compact {
                Text("4 Wochen")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Statistic Block

private struct StatisticBlock: View {

    let title: LocalizedStringKey
    let value: String
    let unit: String?
    let icon: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let unit {
                        Text(verbatim: unit)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Weekly Bars

private struct WeeklyBars: View {

    let values: [Double]
    let compact: Bool

    var body: some View {
        let safeValues = lastWeeks(values)
        let maximum = max(safeValues.max() ?? 0, 1)
        let labels = weekLabels()

        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: compact ? 8 : 12) {
                ForEach(safeValues.indices, id: \.self) { index in
                    VStack(spacing: 5) {
                        Spacer(minLength: 0)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(.green.opacity(index == safeValues.count - 1 ? 0.95 : 0.42))
                            .frame(
                                height: max(
                                    6,
                                    geometry.size.height * 0.68 * CGFloat(safeValues[index] / maximum)
                                )
                            )

                        Text(verbatim: labels[index])
                            .font(.system(size: compact ? 8 : 9, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: compact ? 72 : 92)
        .accessibilityHidden(true)
    }

    /// Calendar week labels, oldest first.
    private func weekLabels() -> [String] {
        let calendar = Calendar.current
        let weekCount = SimRaWidgetConfiguration.weekCount

        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else {
            return Array(repeating: "-", count: weekCount)
        }

        return (0..<weekCount).map { index in
            guard let date = calendar.date(
                byAdding: .weekOfYear,
                value: index - (weekCount - 1),
                to: currentWeekStart
            ) else {
                return "-"
            }

            return "KW \(calendar.component(.weekOfYear, from: date))"
        }
    }
}

// MARK: - Mini Weekly Bars

private struct MiniWeeklyBars: View {

    let values: [Double]

    var body: some View {
        let safeValues = lastWeeks(values)
        let maximum = max(safeValues.max() ?? 0, 1)

        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(safeValues.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.green.opacity(index == safeValues.count - 1 ? 0.95 : 0.40))
                        .frame(height: max(4, geometry.size.height * CGFloat(safeValues[index] / maximum)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .frame(height: 42)
        .accessibilityHidden(true)
    }
}

// MARK: - Start Recording

private struct StartRecordingButton: View {

    let compact: Bool

    var body: some View {
        // .systemSmall ignores Link; there the widgetURL of the root view applies.
        if let url = SimRaWidgetConfiguration.startURL {
            Link(destination: url) {
                content
            }
            .accessibilityLabel("Aufnahme starten")
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 7) {
            Image(systemName: "record.circle.fill")
                .font(.system(size: compact ? 13 : 14, weight: .bold))

            Text("Aufnahme starten")
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.green)
        .frame(maxWidth: .infinity, minHeight: compact ? 30 : 34)
        .background(.green.opacity(0.10), in: Capsule())
    }
}

// MARK: - Accessory Statistics

private struct CircularStatisticsView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 0) {
                Image(systemName: "bicycle")
                    .font(.caption.weight(.semibold))

                Text(formatKilometers(entry.totalKilometers, fractionDigits: 0))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
        }
        .widgetLabel {
            Text("\(formatKilometers(entry.totalKilometers)) km · 4 Wochen")
        }
    }
}

private struct RectangularStatisticsView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        HStack {
            Image(systemName: "bicycle")

            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: "SimRa")
                    .font(.caption.weight(.semibold))

                Text("\(formatKilometers(entry.totalKilometers)) km · \(entry.totalRides) Fahrten")
                    .font(.caption2)
                    .monospacedDigit()
            }
        }
    }
}

private struct InlineStatisticsView: View {

    let entry: SimRaRecordingEntry

    var body: some View {
        Label {
            Text("\(formatKilometers(entry.totalKilometers)) km")
        } icon: {
            Image(systemName: "bicycle")
        }
    }
}

// MARK: - Helpers

/// Last `weekCount` values, padded with zeros at the front.
private func lastWeeks(_ values: [Double]) -> [Double] {
    let weekCount = SimRaWidgetConfiguration.weekCount
    let suffix = Array(values.suffix(weekCount))
    return Array(repeating: 0, count: weekCount - suffix.count) + suffix
}

/// Locale-aware number, e.g. "12,3" on German devices.
private func formatKilometers(_ kilometers: Double, fractionDigits: Int = 1) -> String {
    max(kilometers, 0).formatted(.number.precision(.fractionLength(fractionDigits)))
}

/// Locale-aware distance, e.g. "850 m", "4,2 km", "27 km".
private func formatDistance(_ meters: Double) -> String {
    let meters = max(meters, 0).rounded()

    if meters < 1_000 {
        return "\(meters.formatted(.number.precision(.fractionLength(0)))) m"
    }

    let kilometers = meters / 1_000
    return "\(formatKilometers(kilometers, fractionDigits: kilometers < 10 ? 1 : 0)) km"
}
