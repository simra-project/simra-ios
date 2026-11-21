import SwiftUI

struct NewsItem: Identifiable {
    let id = UUID()
    let text: String
    let isHighlighted: Bool
}

struct NewsView: View {
    @State private var newsItems: [NewsItem] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if newsItems.isEmpty {
                    ContentUnavailableView(
                        NSLocalizedString("No news available", comment: "No news available"),
                        systemImage: "newspaper",
                        description: Text(NSLocalizedString("Check back later for updates from SimRa.", comment: "Empty news description"))
                    )
                    .padding(.top, 32)
                } else {
                    ForEach(newsItems) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.isHighlighted ? "star.fill" : "circle.fill")
                                .font(.caption)
                                .foregroundStyle(item.isHighlighted ? .orange : .secondary)
                                .padding(.top, 5)
                            Text(item.text)
                                .font(.body)
                                .foregroundStyle(item.isHighlighted ? .primary : .secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding()
        }
        .navigationTitle(NSLocalizedString("News", comment: "News"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            AppDelegate.shared().news.refresh()
            loadNews()
            AppDelegate.shared().news.seen()
        }
        .onReceive(NotificationCenter.default.publisher(for: .serverNewsDidUpdate)) { _ in
            loadNews()
        }
    }

    private func loadNews() {
        let news = AppDelegate.shared().news
        newsItems = news.newsLines.compactMap { line in
            guard let marker = line.first else { return nil }
            guard ["-", "i", "*"].contains(String(marker)) else { return nil }
            let text = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return NewsItem(text: text, isHighlighted: marker == "*")
        }
        news.seen()
    }
}
