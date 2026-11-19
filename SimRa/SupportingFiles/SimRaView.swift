//
//  SimRaView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct SimRaView: View {

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Spacer()

                // MARK: App Icon

                Image(
                    systemName: "bicycle.circle.fill"
                )
                .font(
                    .system(
                        size: 80,
                        weight: .regular
                    )
                )
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

                // MARK: Title

                VStack(spacing: 6) {
                    Text("SimRa")
                        .font(
                            .largeTitle.weight(
                                .bold
                            )
                        )
                        .foregroundStyle(.primary)

                    Text(
                        "Sicherheit im Radverkehr — TU Berlin"
                    )
                    .font(
                        .headline
                    )
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                }

                Spacer()

                // MARK: Start Recording

                Button {
                    // Action for starting recording or navigation
                } label: {
                    Text("Start Recording")
                        .font(
                            .headline.weight(
                                .semibold
                            )
                        )
                        .foregroundStyle(.white)
                        .frame(
                            maxWidth: .infinity
                        )
                        .frame(
                            minHeight: 52
                        )
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(.blue)
                .padding(.horizontal)
                .accessibilityLabel(
                    NSLocalizedString(
                        "Aufnahme starten",
                        comment: "Start recording"
                    )
                )
                .accessibilityHint(
                    NSLocalizedString(
                        "Startet eine neue SimRa-Aufnahme.",
                        comment: "Start recording hint"
                    )
                )
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    SimRaView()
}
