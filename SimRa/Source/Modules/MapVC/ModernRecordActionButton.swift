//
//  ModernRecordActionButton.swift
//  SimRa
//
//  Created by Emil Pauls on 29.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

// MARK: - Modern Record Action Button

public struct ModernRecordActionButton: View {

    public let isRecording: Bool
    public let title: String
    public let subtitle: String?
    public let action: () -> Void

    public init(
        isRecording: Bool,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void
    ) {
        self.isRecording = isRecording
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    public var body: some View {
        Button(
            action: action
        ) {
            content
        }
        .buttonStyle(
            RecordButtonStyle(
                tint: accentColor
            )
        )
        .accessibilityElement(
            children: .combine
        )
        .accessibilityLabel(
            title
        )
        .accessibilityValue(
            subtitle ?? ""
        )
        .accessibilityHint(
            isRecording
            ? "Stop the current ride"
            : "Start a new ride"
        )
    }

    private var content: some View {
        VStack(spacing: 3) {
            HStack(spacing: 7) {
                Image(
                    systemName:
                        isRecording
                        ? "stop.fill"
                        : "record.circle"
                )
                .font(
                    .system(
                        size:
                            isRecording
                            ? 19
                            : 18,
                        weight:
                            .semibold
                    )
                )
                .foregroundStyle(
                    accentColor
                )

                Text(title)
                    .font(
                        .body.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(
                        .primary
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            if let subtitle,
               !subtitle.isEmpty {
                Text(subtitle)
                    .font(
                        .caption.weight(
                            .medium
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: 72,
            maxHeight: 72
        )
        .padding(
            .horizontal,
            isRecording ? 21 : 19
        )
        .padding(
            .vertical,
            8
        )
        .contentShape(
            Capsule()
        )
    }

    private var accentColor: Color {
        isRecording
        ? .red
        : .green
    }
}

// MARK: - Button Style

private struct RecordButtonStyle:
    ButtonStyle {

    let tint: Color

    func makeBody(
        configuration:
            Configuration
    ) -> some View {

        configuration.label
            .opacity(
                configuration.isPressed
                ? 0.82
                : 1
            )
            .scaleEffect(
                configuration.isPressed
                ? 0.98
                : 1
            )
            .animation(
                .easeOut(
                    duration: 0.12
                ),
                value:
                    configuration.isPressed
            )
            .modifier(
                RecordButtonBackground(
                    tint: tint
                )
            )
    }
}

// MARK: - Background

private struct RecordButtonBackground:
    ViewModifier {

    let tint: Color

    func body(
        content:
            Content
    ) -> some View {

        if #available(iOS 26.0, *) {
            content
                .buttonStyle(
                    .glass(
                        .clear
                            .tint(
                                tint.opacity(
                                    0.32
                                )
                            )
                            .interactive()
                    )
                )
        } else {
            content
                .background(
                    tint.opacity(0.12),
                    in:
                        Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(
                            tint.opacity(0.20),
                            lineWidth: 1
                        )
                }
        }
    }
}
