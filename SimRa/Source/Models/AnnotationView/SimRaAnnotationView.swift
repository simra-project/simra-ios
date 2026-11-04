//
//  SimRaAnnotationView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct SimRaAnnotationView: View {

    // MARK: - Input

    let personImage: UIImage?

    let recording: Bool

    /// Speed in meters per second.
    let speed: Double

    /// Course in degrees.
    let course: Double

    /// Acceleration values.
    let accx: Double
    let accy: Double
    let accz: Double

    /// Heading in degrees.
    let heading: Double

    // MARK: - Constants

    private let size: CGFloat = 36

    private let ringWidth: CGFloat = 2.5

    private let maximumSpeedKPH: Double = 50

    // MARK: - Body

    var body: some View {

        ZStack {

            // MARK: Base

            Circle()
                .fill(
                    .ultraThinMaterial
                )

            // MARK: Person Image

            personImageView

            // MARK: Speed Ring

            speedRing

            // MARK: Acceleration Indicator

            accelerationIndicator

            // MARK: Heading Indicator

            headingIndicator

            // MARK: Recording Status

            recordingIndicator

            // MARK: Outer Border

            Circle()
                .stroke(
                    recording
                    ? Color.red.opacity(0.95)
                    : Color.primary.opacity(0.28),
                    lineWidth:
                        ringWidth
                )
        }
        .frame(
            width: size,
            height: size
        )
        .clipShape(
            Circle()
        )
        .shadow(
            color: .black.opacity(0.15),
            radius: 2,
            y: 1
        )
        .accessibilityHidden(true)
    }

    // MARK: - Person

    @ViewBuilder
    private var personImageView: some View {

        if let personImage {

            Image(
                uiImage:
                    personImage
            )
            .resizable()
            .scaledToFill()
            .frame(
                width:
                    size - 6,
                height:
                    size - 6
            )
            .clipShape(
                Circle()
            )

        } else {

            Image(
                systemName:
                    "person.fill"
            )
            .font(
                .system(
                    size: 17,
                    weight: .medium
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
    }

    // MARK: - Speed

    @ViewBuilder
    private var speedRing: some View {

        let speedKPH =
            max(
                0,
                speed * 3.6
            )

        let progress =
            min(
                speedKPH
                / maximumSpeedKPH,
                1
            )

        Circle()
            .trim(
                from: 0,
                to: progress
            )
            .stroke(
                speedColor(
                    for:
                        speedKPH
                ),
                style:
                    StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
            )
            .rotationEffect(
                .degrees(-90)
            )
            .padding(
                1.5
            )
            .opacity(
                speedKPH > 0
                    ? 0.95
                    : 0
            )
    }

    private func speedColor(
        for speedKPH: Double
    ) -> Color {

        switch speedKPH {

        case ..<15:
            return .green

        case ..<30:
            return .yellow

        case ..<40:
            return .orange

        default:
            return .red
        }
    }

    // MARK: - Acceleration

    @ViewBuilder
    private var accelerationIndicator: some View {

        let magnitude =
            sqrt(
                accx * accx
                +
                accy * accy
                +
                accz * accz
            )

        let normalized =
            min(
                max(
                    magnitude / 3.0,
                    0
                ),
                1
            )

        Circle()
            .stroke(
                accelerationColor(
                    magnitude:
                        magnitude
                ),
                lineWidth:
                    1.5
            )
            .scaleEffect(
                0.82
                +
                (0.14 * normalized)
            )
            .opacity(
                normalized > 0.05
                    ? 0.35 + (0.45 * normalized)
                    : 0
            )
    }

    private func accelerationColor(
        magnitude: Double
    ) -> Color {

        switch magnitude {

        case ..<1.0:
            return .green

        case ..<2.0:
            return .yellow

        case ..<3.0:
            return .orange

        default:
            return .red
        }
    }

    // MARK: - Heading

    @ViewBuilder
    private var headingIndicator: some View {

        let normalizedHeading =
            normalizedAngle(
                heading > 0
                    ? heading
                    : course
            )

        Image(
            systemName:
                "location.north.fill"
        )
        .font(
            .system(
                size: 11,
                weight: .bold
            )
        )
        .foregroundStyle(
            .blue
        )
        .rotationEffect(
            .degrees(
                normalizedHeading
            )
        )
        .offset(
            y:
                -(size / 2 - 7)
        )
        .shadow(
            color: .black.opacity(0.22),
            radius: 1,
            y: 1
        )
    }

    private func normalizedAngle(
        _ angle: Double
    ) -> Double {

        var value =
            angle
                .truncatingRemainder(
                    dividingBy: 360
                )

        if value < 0 {
            value += 360
        }

        return value
    }

    // MARK: - Recording

    @ViewBuilder
    private var recordingIndicator: some View {

        if recording {

            RoundedRectangle(
                cornerRadius: 3
            )
            .fill(
                .red
            )
            .frame(
                width: 11,
                height: 11
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 3
                )
                .stroke(
                    .white.opacity(0.9),
                    lineWidth: 1
                )
            }
            .shadow(
                color:
                    .black.opacity(0.2),
                radius: 1
            )

        } else {

            Circle()
                .fill(
                    .red
                )
                .frame(
                    width: 11,
                    height: 11
                )
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(0.9),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color:
                        .black.opacity(0.2),
                    radius: 1
                )
        }
    }
}

struct SimRaAnnotationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(
            spacing: 24
        ) {

            SimRaAnnotationView(
                personImage: nil,
                recording: false,
                speed: 0,
                course: 0,
                accx: 0,
                accy: 0,
                accz: 0,
                heading: 0
            )

            SimRaAnnotationView(
                personImage: nil,
                recording: true,
                speed: 8.33,
                course: 90,
                accx: 0.8,
                accy: 0.5,
                accz: 0.2,
                heading: 90
            )
        }
        .padding()
    }
}
