//
//  DSBarChart.swift
//  SimRa
//
//  SwiftUI replacement for the former DSBarChart.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI

struct DSBarChart: View {

    let references: [String]
    let values: [Double]

    init(
        references: [String],
        values: [Double]
    ) {
        self.references = references
        self.values = values
    }

    var body: some View {
        GeometryReader { geometry in

            let count = min(
                references.count,
                values.count
            )

            if count > 0 {

                let maximum = max(
                    values.prefix(count).max() ?? 0,
                    1
                )

                HStack(
                    alignment: .bottom,
                    spacing: 8
                ) {

                    ForEach(
                        0..<count,
                        id: \.self
                    ) { index in

                        bar(
                            reference: references[index],
                            value: values[index],
                            maximum: maximum
                        )
                        .frame(
                            maxWidth: .infinity
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)

            } else {

                ContentUnavailableView(
                    "Keine Daten",
                    systemImage: "chart.bar",
                    description: Text(
                        "Für diese Statistik sind noch keine Werte vorhanden."
                    )
                )
            }
        }
    }

    private func bar(
        reference: String,
        value: Double,
        maximum: Double
    ) -> some View {

        let ratio = min(
            max(value / maximum, 0),
            1
        )

        return VStack(
            spacing: 6
        ) {

            Text(formattedValue(value))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geometry in

                VStack {
                    Spacer()

                    RoundedRectangle(
                        cornerRadius: 6,
                        style: .continuous
                    )
                    .fill(
                        barColor(
                            ratio: ratio
                        )
                    )
                    .frame(
                        height: max(
                            geometry.size.height * ratio,
                            value > 0 ? 4 : 1
                        )
                    )
                }
            }

            Text(reference)
                .font(.caption2)
                .foregroundStyle(.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(height: 18)
        }
    }

    private func formattedValue(
        _ value: Double
    ) -> String {

        if value.rounded() == value {
            return String(
                Int(value)
            )
        }

        return String(
            format: "%.1f",
            value
        )
    }

    private func barColor(
        ratio: Double
    ) -> Color {

        let value = min(
            max(ratio, 0),
            1
        )

        return Color(
            red: value,
            green: 1 - value,
            blue: 0,
            opacity: 0.82
        )
    }
}
