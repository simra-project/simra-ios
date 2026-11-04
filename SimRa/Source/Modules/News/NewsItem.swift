//
//  NewsItem.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import SwiftUI

// MARK: - Datenmodell für News-Zeilen

struct NewsItem: Identifiable {
    let id = UUID()
    let text: String
    let isHighlighted: Bool
}

// MARK: - SwiftUI View

struct NewsView: View {
    @State private var newsItems: [NewsItem] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if newsItems.isEmpty {
                    Text(NSLocalizedString("No news available", comment: "No news available"))
                        .foregroundColor(.secondary)
                        .padding(.top, 20)
                } else {
                    ForEach(newsItems) { item in
                        Text(item.text)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(item.isHighlighted ? .red : .primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(NSLocalizedString("News", comment: "News"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadNews)
    }

    // Parst die Zeilen aus AppDelegate.news.newsLines exakt wie im alten NewsVC
    private func loadNews() {
        let lines = AppDelegate.shared().news.newsLines
        guard !lines.isEmpty else { return }

        var parsedItems: [NewsItem] = []
        
        for line in lines {
            if line.hasPrefix("-") || line.hasPrefix("i") {
                let text = String(line.dropFirst())
                parsedItems.append(NewsItem(text: text, isHighlighted: false))
            } else if line.hasPrefix("*") {
                let text = String(line.dropFirst())
                parsedItems.append(NewsItem(text: text, isHighlighted: true))
            }
        }
        
        self.newsItems = parsedItems
    }
}
