//
//  News.swift
//  SimRa
//

import Foundation

extension Notification.Name {
    static let simRaNewsReceived = Notification.Name("simRaNewsReceived")
}

@objcMembers
public class News: NSObject {

    public var newsItems: NSMutableArray = []
    public var lastSeenNewsId: Int = 0
    public private(set) var newsLines: [String] = []
    private var newsVersion: Int

    public override init() {
        newsVersion = UserDefaults.standard.integer(forKey: "newsVersion")
        super.init()
    }

    public func refresh() {
        let preferredLang = Bundle.preferredLocalizations(from: ["en", "de"]).first ?? "en"
        var components = URLComponents(
            string: "\(API.apiPrefix())/check/news"
        )
        components?.queryItems = [
            URLQueryItem(name: "clientHash", value: API.clientHash()),
            URLQueryItem(name: "lastSeenNewsID", value: String(newsVersion)),
            URLQueryItem(name: "newsLanguage", value: preferredLang)
        ]

        guard let url = components?.url else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard
                error == nil,
                let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode),
                let data
            else {
                return
            }

            DispatchQueue.main.async {
                self?.process(data)
            }
        }.resume()
    }

    public func process(_ data: Data) {
        guard
            let text = String(data: data, encoding: .utf8),
            let firstLine = text.components(separatedBy: .newlines).first,
            firstLine.hasPrefix("#"),
            let version = Int(firstLine.dropFirst()),
            version > newsVersion
        else {
            return
        }

        let lines = text
            .components(separatedBy: .newlines)
            .dropFirst()
            .filter { line in
                line.hasPrefix("-") || line.hasPrefix("i") || line.hasPrefix("*")
            }

        guard !lines.isEmpty else {
            newsVersion = version
            UserDefaults.standard.set(version, forKey: "newsVersion")
            return
        }

        newsLines = Array(lines)
        newsVersion = version
        UserDefaults.standard.set(version, forKey: "newsVersion")

        NotificationCenter.default.post(
            name: .simRaNewsReceived,
            object: nil,
            userInfo: ["lines": newsLines]
        )
    }

    public func seen() {
        UserDefaults.standard.set(newsVersion, forKey: "newsVersion")
    }
}
