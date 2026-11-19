//
//  IdPicker.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import SwiftUI

public struct IdPicker: View {
    public var array: [String]
    @Binding public var arrayIndex: Int

    public init(array: [String], arrayIndex: Binding<Int>) {
        self.array = array
        self._arrayIndex = arrayIndex
    }

    public var body: some View {
        Picker(selection: $arrayIndex) {
            ForEach(0..<array.count, id: \.self) { index in
                Text(array[index]).tag(index)
            }
        } label: {
            HStack {
                Text(array.indices.contains(arrayIndex) ? array[arrayIndex] : "")
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .pickerStyle(.menu)
    }
}