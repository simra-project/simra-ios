import Foundation
import UserNotifications

@objcMembers
public final class News: NSObject {
    public var newsItems: NSMutableArray = []
    public var lastSeenNewsId: Int = 0
    public private(set) var newsLines: [String] = []
    public private(set) var newsVersion: Int
    public var hasUnreadNews: Bool {
        newsVersion > UserDefaults.standard.integer(forKey: "newsVersion")
    }

    private var requestInProgress = false

    public override init() {
        newsVersion = UserDefaults.standard.integer(forKey: "newsVersion")
        super.init()
    }

    public func refresh() {
        guard !requestInProgress else { return }
        requestInProgress = true

        let preferredLanguage = Bundle.preferredLocalizations(from: ["en", "de"]).first ?? "en"
        var components = URLComponents(string: "\(API.apiPrefix())/check/news")
        components?.queryItems = [
            URLQueryItem(name: "clientHash", value: API.clientHash()),
            URLQueryItem(name: "lastSeenNewsID", value: String(newsVersion)),
            URLQueryItem(name: "newsLanguage", value: preferredLanguage)
        ]

        guard let url = components?.url else {
            requestInProgress = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.requestInProgress = false
                guard error == nil,
                      let response = response as? HTTPURLResponse,
                      (200...299).contains(response.statusCode),
                      let data else { return }
                self.process(data)
            }
        }.resume()
    }

    public func process(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.components(separatedBy: .newlines)
        guard let firstLine = lines.first, firstLine.hasPrefix("#"),
              let version = Int(firstLine.dropFirst()),
              version > newsVersion else { return }

        newsLines = Array(lines.dropFirst()).filter { !$0.isEmpty }
        newsVersion = version
        NotificationCenter.default.post(name: .serverNewsDidUpdate, object: nil)
        postLocalNotificationIfAllowed()
    }

    public func seen() {
        Utility.saveInt(key: "newsVersion", value: newsVersion)
        NotificationCenter.default.post(name: .serverNewsDidUpdate, object: nil)
    }

    private func postLocalNotificationIfAllowed() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let schedule: () -> Void = {
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("New SimRa information", comment: "News notification title")
                content.body = NSLocalizedString("New information from SimRa is available.", comment: "News notification body")
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "simra-server-news-\(self.newsVersion)",
                    content: content,
                    trigger: nil
                )
                center.add(request)
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                schedule()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { schedule() }
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }
}

extension Notification.Name {
    static let serverNewsDidUpdate = Notification.Name("serverNewsDidUpdate")
}
