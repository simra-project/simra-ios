//
//  SimRaLiveActivity.swift
//  SimRa
//
//  Live Activity for an active SimRa recording.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Live Activity

struct SimRaLiveActivity: Widget {

    var body: some WidgetConfiguration {

        ActivityConfiguration(
            for: SimRaRecordingAttributes.self
        ) { context in

            SimRaLiveActivityLockScreenView(
                context: context
            )
            .activityBackgroundTint(.clear)
            .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in

            DynamicIsland(
                expanded: {

                    DynamicIslandExpandedRegion(
                        .leading
                    ) {

                        SimRaLiveActivityBrand()
                    }

                    DynamicIslandExpandedRegion(
                        .trailing
                    ) {

                        HStack(spacing: 10) {

                            SimRaHazardButton()

                            SimRaStopButton()
                        }
                    }

                    DynamicIslandExpandedRegion(
                        .bottom
                    ) {

                        ZStack {

                            ActivityRouteBackground(
                                points:
                                    context.state.route
                            )
                            .opacity(0.55)
                            .allowsHitTesting(false)

                            VStack(spacing: 14) {

                                Divider()
                                    .opacity(0.3)

                                HStack(spacing: 0) {

                                    SimRaRunningDuration(
                                        elapsedSeconds:
                                            context.state
                                            .elapsedSeconds
                                    )

                                    Spacer(
                                        minLength: 24
                                    )

                                    SimRaLargeMetric(
                                        title:
                                            "Strecke",
                                        value:
                                            context.state
                                            .formattedDistance,
                                        systemImage:
                                            "point.topleft.down.curvedto.point.bottomright.up"
                                    )
                                }
                                .padding(
                                    .horizontal,
                                    4
                                )
                            }
                        }
                    }

                },
                compactLeading: {

                    Image(
                        systemName:
                            "bicycle"
                    )
                    .font(
                        .system(
                            size: 14,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .blue
                    )

                },
                compactTrailing: {

                    Text(
                        context.state
                            .formattedDistance
                    )
                    .font(
                        .system(
                            size: 12,
                            weight: .semibold
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        .primary
                    )

                },
                minimal: {

                    Image(
                        systemName:
                            "bicycle"
                    )
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .blue
                    )
                }
            )
        }
    }
}

// MARK: - Lock Screen

private struct SimRaLiveActivityLockScreenView: View {

    let context:
        ActivityViewContext<
            SimRaRecordingAttributes
        >

    var body: some View {

        ZStack {

            ActivityRouteBackground(
                points:
                    context.state.route
            )
            .opacity(0.48)
            .allowsHitTesting(false)

            VStack(spacing: 18) {

                HStack(
                    alignment:
                        .center
                ) {

                    SimRaLiveActivityBrand()

                    Spacer(
                        minLength: 12
                    )

                    HStack(spacing: 10) {

                        SimRaHazardButton()

                        SimRaStopButton()
                    }
                }

                HStack(spacing: 0) {

                    SimRaRunningDuration(
                        elapsedSeconds:
                            context.state
                            .elapsedSeconds
                    )

                    Spacer(
                        minLength: 30
                    )

                    SimRaLargeMetric(
                        title:
                            "Strecke",
                        value:
                            context.state
                            .formattedDistance,
                        systemImage:
                            "point.topleft.down.curvedto.point.bottomright.up"
                    )
                }
            }
            .padding(
                .horizontal,
                18
            )
            .padding(
                .vertical,
                16
            )
        }
        .activitySystemActionForegroundColor(
            .primary
        )
    }
}

// MARK: - Running Duration

private struct SimRaRunningDuration: View {

    let elapsedSeconds:
        Int

    var body: some View {

        HStack(spacing: 9) {

            Image(
                systemName:
                    "clock"
            )
            .font(
                .system(
                    size: 16,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .secondary
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {

                Text(
                    timerInterval:
                        timerStart...Date.distantFuture,
                    countsDown:
                        false
                )
                .font(
                    .system(
                        size: 21,
                        weight: .semibold
                    )
                )
                .monospacedDigit()
                .foregroundStyle(
                    .primary
                )
                .lineLimit(
                    1
                )
                .minimumScaleFactor(
                    0.75
                )

                Text("Zeit")
                    .font(
                        .system(
                            size: 11,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(
                        1
                    )
            }
        }
    }

    private var timerStart:
        Date {

        Date.now.addingTimeInterval(
            -TimeInterval(
                max(
                    elapsedSeconds,
                    0
                )
            )
        )
    }
}

// MARK: - Activity Route Background

private struct ActivityRouteBackground: View {

    let points:
        [SimRaRecordingAttributes.ContentState.RoutePoint]

    var body: some View {

        GeometryReader { _ in

            Canvas { context, size in

                guard points.count > 1 else {
                    return
                }

                let layout =
                    ActivityRouteLayout(
                        points:
                            points,
                        size:
                            size
                    )

                guard layout.points.count > 1 else {
                    return
                }

                var path =
                    Path()

                path.move(
                    to:
                        layout.points[0]
                )

                for point
                    in layout.points.dropFirst() {

                    path.addLine(
                        to:
                            point
                    )
                }

                // MARK: Soft route underlay

                context.stroke(
                    path,
                    with:
                        .color(
                            Color.blue.opacity(
                                0.10
                            )
                        ),
                    style:
                        StrokeStyle(
                            lineWidth:
                                layout.lineWidth + 6,
                            lineCap:
                                .round,
                            lineJoin:
                                .round
                        )
                )

                // MARK: Main route

                context.stroke(
                    path,
                    with:
                        .color(
                            Color.blue.opacity(
                                0.72
                            )
                        ),
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

                // MARK: Start point

                if let first =
                    layout.points.first {

                    context.fill(
                        Path(
                            ellipseIn:
                                CGRect(
                                    x:
                                        first.x - 3.5,
                                    y:
                                        first.y - 3.5,
                                    width:
                                        7,
                                    height:
                                        7
                                )
                        ),
                        with:
                            .color(
                                Color.white.opacity(
                                    0.95
                                )
                            )
                    )

                    context.fill(
                        Path(
                            ellipseIn:
                                CGRect(
                                    x:
                                        first.x - 2,
                                    y:
                                        first.y - 2,
                                    width:
                                        4,
                                    height:
                                        4
                                )
                        ),
                        with:
                            .color(
                                Color.secondary
                            )
                    )
                }

                // MARK: Current position

                if let last =
                    layout.points.last {

                    context.fill(
                        Path(
                            ellipseIn:
                                CGRect(
                                    x:
                                        last.x - 7,
                                    y:
                                        last.y - 7,
                                    width:
                                        14,
                                    height:
                                        14
                                )
                        ),
                        with:
                            .color(
                                Color.blue.opacity(
                                    0.12
                                )
                            )
                    )

                    context.fill(
                        Path(
                            ellipseIn:
                                CGRect(
                                    x:
                                        last.x - 4,
                                    y:
                                        last.y - 4,
                                    width:
                                        8,
                                    height:
                                        8
                                )
                        ),
                        with:
                            .color(
                                Color.blue
                            )
                    )
                }
            }
        }
        .frame(
            maxWidth:
                .infinity,
            maxHeight:
                .infinity
        )
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Route Layout

private struct ActivityRouteLayout {

    let points:
        [CGPoint]

    let lineWidth:
        CGFloat

    init(
        points:
            [SimRaRecordingAttributes.ContentState.RoutePoint],
        size:
            CGSize
    ) {

        guard
            points.count > 1,
            size.width > 0,
            size.height > 0
        else {

            self.points = []
            self.lineWidth = 3

            return
        }

        let latitudes =
            points.map(
                \.latitude
            )

        let longitudes =
            points.map(
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

            self.points = []
            self.lineWidth = 3

            return
        }

        let latitudeSpan =
            max(
                maxLatitude -
                    minLatitude,
                0.00001
            )

        let centerLatitude =
            (
                minLatitude +
                maxLatitude
            ) / 2

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
            min(
                max(
                    min(
                        size.width,
                        size.height
                    ) * 0.06,
                    4
                ),
                12
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

        self.points =
            points.map { point in

                let normalizedX =
                    (
                        (
                            point.longitude -
                            minLongitude
                        ) *
                        longitudeScale
                    ) /
                    longitudeSpan

                let normalizedY =
                    (
                        maxLatitude -
                        point.latitude
                    ) /
                    latitudeSpan

                return CGPoint(
                    x:
                        originX +
                        CGFloat(
                            normalizedX
                        ) *
                        usedWidth,

                    y:
                        originY +
                        CGFloat(
                            normalizedY
                        ) *
                        usedHeight
                )
            }

        let minimumDimension =
            min(
                size.width,
                size.height
            )

        self.lineWidth =
            min(
                max(
                    minimumDimension *
                        0.018,
                    2
                ),
                3.5
            )
    }
}

// MARK: - Brand

private struct SimRaLiveActivityBrand: View {

    var body: some View {

        HStack(spacing: 8) {

            Image(
                systemName:
                    "bicycle"
            )
            .font(
                .system(
                    size: 18,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                .blue
            )

            Text("SimRa")
                .font(
                    .system(
                        size: 18,
                        weight: .bold
                    )
                )
                .foregroundStyle(
                    .primary
                )
        }
        .fixedSize()
    }
}

// MARK: - Large Metric

private struct SimRaLargeMetric: View {

    let title:
        String

    let value:
        String

    let systemImage:
        String

    var body: some View {

        HStack(spacing: 9) {

            Image(
                systemName:
                    systemImage
            )
            .font(
                .system(
                    size: 16,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .secondary
            )

            VStack(
                alignment:
                    .leading,
                spacing:
                    2
            ) {

                Text(value)
                    .font(
                        .system(
                            size: 21,
                            weight: .semibold
                        )
                    )
                    .monospacedDigit()
                    .foregroundStyle(
                        .primary
                    )
                    .lineLimit(
                        1
                    )
                    .minimumScaleFactor(
                        0.75
                    )

                Text(title)
                    .font(
                        .system(
                            size: 11,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .lineLimit(
                        1
                    )
            }
        }
    }
}

// MARK: - Hazard Button

private struct SimRaHazardButton: View {

    var body: some View {

        Button(
            intent:
                MarkGeneralIncidentIntent()
        ) {

            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(
                .system(
                    size: 14,
                    weight: .bold
                )
            )
            .foregroundStyle(
                .white
            )
            .frame(
                width: 40,
                height: 40
            )
            .background {

                Circle()
                    .fill(
                        Color.orange
                    )
            }
        }
        .buttonStyle(
            .plain
        )
        .accessibilityLabel(
            "Gefahr melden"
        )
    }
}

// MARK: - Stop Button

private struct SimRaStopButton: View {

    var body: some View {

        Button(
            intent:
                StopRecordingIntent()
        ) {

            Image(
                systemName:
                    "stop.fill"
            )
            .font(
                .system(
                    size: 14,
                    weight: .bold
                )
            )
            .foregroundStyle(
                .white
            )
            .frame(
                width: 40,
                height: 40
            )
            .background {

                Circle()
                    .fill(
                        Color.red
                    )
            }
        }
        .buttonStyle(
            .plain
        )
        .accessibilityLabel(
            "Aufzeichnung stoppen"
        )
    }
}

// MARK: - Content State Helpers

private extension
    SimRaRecordingAttributes.ContentState {

    var formattedDuration:
        String {

        let totalSeconds =
            max(
                elapsedSeconds,
                0
            )

        let hours =
            totalSeconds / 3_600

        let minutes =
            (
                totalSeconds %
                3_600
            ) / 60

        let seconds =
            totalSeconds % 60

        if hours > 0 {

            return String(
                format:
                    "%d:%02d:%02d",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format:
                "%02d:%02d",
                minutes,
                seconds
            )
    }

    var formattedDistance:
        String {

        let distance =
            max(
                distanceMeters,
                0
            )

        if distance >= 1_000 {

            return String(
                format:
                    "%.1f km",
                distance / 1_000
            )
        }

        return String(
            format:
                "%.0f m",
                distance
            )
    }
}
