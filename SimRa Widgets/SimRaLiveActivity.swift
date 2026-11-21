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

private typealias RoutePoint = SimRaRecordingAttributes.ContentState.RoutePoint

// MARK: - Live Activity

struct SimRaLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SimRaRecordingAttributes.self) { context in
            SimRaLockScreenView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SimRaBrand()
                        .padding(.leading, 4)
                        .frame(maxHeight: .infinity, alignment: .center)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if context.attributes.tripId != 0 {
                        SimRaActionButtons(size: 40)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.attributes.tripId == 0 {
                        SimRaUploadStatus(context: context)
                    } else {
                        VStack(spacing: 12) {
                            Divider()
                                .opacity(0.3)

                            SimRaMetricsRow(
                                startDate: context.attributes.startDate,
                                distanceMeters: context.state.distanceMeters,
                                isStale: context.isStale,
                                minSpacing: 24
                            )
                            .padding(.horizontal, 4)
                        }
                        .background {
                            SimRaRouteBackground(points: context.state.route)
                                .opacity(0.55)
                        }
                    }
                }

            } compactLeading: {
                Image(systemName: "bicycle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.blue)

            } compactTrailing: {
                if context.attributes.tripId == 0 {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                } else {
                    Text(SimRaFormat.distance(context.state.distanceMeters))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: 64, alignment: .trailing)
                        .opacity(context.isStale ? 0.5 : 1)
                }

            } minimal: {
                Image(systemName: "bicycle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .keylineTint(.blue)
        }
    }
}

// MARK: - Lock Screen

private struct SimRaLockScreenView: View {

    let context: ActivityViewContext<SimRaRecordingAttributes>

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center) {
                SimRaBrand()
                Spacer(minLength: 12)
                if context.attributes.tripId != 0 {
                    SimRaActionButtons(size: 44)
                }
            }

            if context.attributes.tripId == 0 {
                SimRaUploadStatus(context: context)
            } else {
                SimRaMetricsRow(
                    startDate: context.attributes.startDate,
                    distanceMeters: context.state.distanceMeters,
                    isStale: context.isStale,
                    minSpacing: 30
                )
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background {
            if context.attributes.tripId != 0 {
                SimRaRouteBackground(points: context.state.route)
                    .opacity(0.48)
            }
        }
    }
}

// MARK: - Upload Status

private struct SimRaUploadStatus: View {

    let context: ActivityViewContext<SimRaRecordingAttributes>

    var body: some View {
        let total = max(context.state.uploadTotalCount ?? 0, 1)
        let completed = context.state.uploadCompletedCount ?? 0
        let failed = context.state.uploadFailureCount ?? 0
        let finished = context.state.uploadFinished ?? false

        VStack(alignment: .leading, spacing: 8) {
            Text(finished ? "Upload abgeschlossen" : "Fahrten werden hochgeladen")
                .font(.headline)

            ProgressView(
                value: context.state.uploadProgress ?? 0,
                total: 1
            )
            .tint(.blue)

            Text("\(completed) von \(total) Fahrten · \(failed) fehlgeschlagen")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Metrics Row

private struct SimRaMetricsRow: View {

    let startDate: Date
    let distanceMeters: Int
    let isStale: Bool
    let minSpacing: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            SimRaMetric(title: "Zeit", systemImage: "clock") {
                // Fixed reference date from the static attributes:
                // the system counts on its own, no jumps between updates.
                Text(
                    timerInterval: startDate...Date.distantFuture,
                    countsDown: false
                )
                // Timer text is horizontally flexible in widgets.
                .frame(maxWidth: 110, alignment: .leading)
            }

            Spacer(minLength: minSpacing)

            SimRaMetric(
                title: "Strecke",
                systemImage: "point.topleft.down.curvedto.point.bottomright.up"
            ) {
                Text(SimRaFormat.distance(distanceMeters))
            }
        }
        .opacity(isStale ? 0.5 : 1)
    }
}

// MARK: - Metric

private struct SimRaMetric<Value: View>: View {

    let title: LocalizedStringKey
    let systemImage: String
    let value: Value

    init(
        title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder value: () -> Value
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value()
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                value
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Brand

private struct SimRaBrand: View {

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bicycle")
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text(verbatim: "SimRa")
                .fontWeight(.bold)
                .foregroundStyle(.primary)
        }
        .font(.headline.weight(.semibold))
        .fixedSize()
    }
}

// MARK: - Action Buttons

private struct SimRaActionButtons: View {

    let size: CGFloat

    var body: some View {
        // Generous spacing reduces accidental taps on "Stop".
        HStack(spacing: 14) {
            SimRaCircleIntentButton(
                intent: MarkGeneralIncidentIntent(),
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange,
                label: "Gefahr melden",
                size: size
            )

            SimRaCircleIntentButton(
                intent: StopRecordingIntent(),
                systemImage: "stop.fill",
                tint: .red,
                label: "Aufzeichnung stoppen",
                size: size
            )
        }
    }
}

private struct SimRaCircleIntentButton<Intent: AppIntent>: View {

    let intent: Intent
    let systemImage: String
    let tint: Color
    let label: LocalizedStringKey
    let size: CGFloat

    var body: some View {
        Button(intent: intent) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(tint, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

// MARK: - Route Background

private struct SimRaRouteBackground: View {

    let points: [RoutePoint]

    var body: some View {
        Canvas { context, size in
            let layout = SimRaRouteLayout(points: points, size: size)

            guard layout.points.count > 1,
                  let first = layout.points.first,
                  let last = layout.points.last
            else { return }

            var path = Path()
            path.addLines(layout.points)

            // Soft underlay
            context.stroke(
                path,
                with: .color(Color.blue.opacity(0.10)),
                style: StrokeStyle(
                    lineWidth: layout.lineWidth + 6,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Main route
            context.stroke(
                path,
                with: .color(Color.blue.opacity(0.72)),
                style: StrokeStyle(
                    lineWidth: layout.lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

            // Start point
            context.fill(Self.dot(at: first, radius: 3.5), with: .color(Color.white.opacity(0.95)))
            context.fill(Self.dot(at: first, radius: 2), with: .color(Color.secondary))

            // Current position
            context.fill(Self.dot(at: last, radius: 7), with: .color(Color.blue.opacity(0.12)))
            context.fill(Self.dot(at: last, radius: 4), with: .color(Color.blue))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func dot(at center: CGPoint, radius: CGFloat) -> Path {
        Path(
            ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
    }
}

// MARK: - Route Layout

private struct SimRaRouteLayout {

    let points: [CGPoint]
    let lineWidth: CGFloat

    init(points: [RoutePoint], size: CGSize) {
        let minDimension = min(size.width, size.height)
        lineWidth = min(max(minDimension * 0.018, 2), 3.5)

        guard points.count > 1,
              size.width > 0,
              size.height > 0,
              let minLat = points.map(\.latitude).min(),
              let maxLat = points.map(\.latitude).max(),
              let minLon = points.map(\.longitude).min(),
              let maxLon = points.map(\.longitude).max()
        else {
            self.points = []
            return
        }

        // Equirectangular approximation, sufficient for a single ride.
        let centerLat = (minLat + maxLat) / 2
        let lonScale = max(cos(centerLat * .pi / 180), 0.1)

        let latSpan = max(maxLat - minLat, 0.00001)
        let lonSpan = max((maxLon - minLon) * lonScale, 0.00001)

        let padding = min(max(minDimension * 0.06, 4), 12)
        let availableWidth = max(size.width - padding * 2, 1)
        let availableHeight = max(size.height - padding * 2, 1)

        let scale = min(
            availableWidth / CGFloat(lonSpan),
            availableHeight / CGFloat(latSpan)
        )
        let usedWidth = CGFloat(lonSpan) * scale
        let usedHeight = CGFloat(latSpan) * scale
        let originX = (size.width - usedWidth) / 2
        let originY = (size.height - usedHeight) / 2

        self.points = points.map { point in
            let normalizedX = CGFloat((point.longitude - minLon) * lonScale / lonSpan)
            let normalizedY = CGFloat((maxLat - point.latitude) / latSpan)

            return CGPoint(
                x: originX + normalizedX * usedWidth,
                y: originY + normalizedY * usedHeight
            )
        }
    }
}

// MARK: - Formatting

private enum SimRaFormat {

    /// Locale-aware distance, e.g. "850 m" or "12,3 km" on German devices.
    static func distance(_ meters: Int) -> String {
        let meters = Double(max(meters, 0))

        if meters >= 1_000 {
            return Measurement(value: meters / 1_000, unit: UnitLength.kilometers)
                .formatted(
                    .measurement(
                        width: .abbreviated,
                        usage: .asProvided,
                        numberFormatStyle: .number.precision(.fractionLength(1))
                    )
                )
        }

        return Measurement(value: meters, unit: UnitLength.meters)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .asProvided,
                    numberFormatStyle: .number.precision(.fractionLength(0))
                )
            )
    }
}
