//
//  News.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import UserNotifications

@objcMembers
public final class News: NSObject {
    public var newsItems: NSMutableArray = []
    public var lastSeenNewsId: Int = 0
    public private(set) var newsLines: [String]
    public private(set) var newsVersion: Int
    public var hasUnreadNews: Bool {
        newsVersion > UserDefaults.standard.integer(forKey: "newsVersion")
    }

    private static let latestVersionKey = "newsLatestVersion"
    private static let newsLinesKey = "newsLines"

    private var requestInProgress = false

    public override init() {
        let defaults = UserDefaults.standard
        newsVersion = defaults.integer(forKey: Self.latestVersionKey)
        if newsVersion == 0 {
            newsVersion = defaults.integer(forKey: "newsVersion")
        }
        newsLines = defaults.stringArray(forKey: Self.newsLinesKey) ?? []
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
        guard let firstLine = lines.first, firstLine.hasPrefix("#") else { return }
        let versionText = String(firstLine.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let version = Int(versionText), version > newsVersion else { return }

        newsLines = Array(lines.dropFirst()).filter { !$0.isEmpty }
        newsVersion = version
        UserDefaults.standard.set(version, forKey: Self.latestVersionKey)
        UserDefaults.standard.set(newsLines, forKey: Self.newsLinesKey)
        NotificationCenter.default.post(name: .serverNewsDidUpdate, object: nil)
        postLocalNotificationIfAllowed()
    }

    public func seen() {
        Utility.saveInt(key: "newsVersion", value: newsVersion)
        NotificationCenter.default.post(name: .serverNewsDidUpdate, object: nil)
    }

    public static func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func postLocalNotificationIfAllowed() {
        guard UserDefaults.standard.bool(forKey: "serverNewsNotificationsEnabled") else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let schedule: () -> Void = {
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("New SimRa information", comment: "News notification title")
                let announcement = self.newsLines.first.map {
                    String($0.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                } ?? ""
                let message = announcement.isEmpty
                    ? NSLocalizedString("New information from SimRa is available.", comment: "News notification body")
                    : announcement
                content.body = String(message.prefix(140))
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
            case .notDetermined, .denied:
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
