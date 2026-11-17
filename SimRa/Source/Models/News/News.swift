//
//  News.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation

@objcMembers
public class News: NSObject {
    
    // Entspricht den Properties aus der alten News.h
    public var newsItems: NSMutableArray = []
    public var lastSeenNewsId: Int = 0
    
    public private(set) var newsLines: [String] = []
    private var newsVersion: Int = 0

    public override init() {
        super.init()
        self.newsLines = []
        self.newsVersion = UserDefaults.standard.integer(forKey: "newsVersion")
    }
    
    private var hasInitialized = false
    private func ensureInitialized() {
        guard !hasInitialized else { return }
        hasInitialized = true
        refresh()
    }

    public func refresh() {
        ensureInitialized()
        let preferredLang = Bundle.preferredLocalizations(from: ["en", "de"]).first ?? "en"
        
        // Zugriff auf Objective-C Klassen (API und NSString-Kategorie)
        let clientHash = API.clientHash()
        let prefix = API.apiPrefix()
        
        let urlString = "\(prefix)/check/news?clientHash=\(clientHash)&lastSeenNewsID=\(newsVersion)&newsLanguage=\(preferredLang)"
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let dataTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, connectionError in
            if connectionError != nil {
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                if let data = data {
                    DispatchQueue.main.async {
                        self?.process(data)
                    }
                }
            }
        }
        dataTask.resume()
    }

    public func process(_ data: Data) {
        guard let dataString = String(data: data, encoding: .utf8) else { return }
        let lines = dataString.components(separatedBy: "\n")
        
        var version = 0
        if lines.count > 0, lines[0].hasPrefix("#") {
            let versionString = String(lines[0].dropFirst())
            let nf = NumberFormatter()
            if let number = nf.number(from: versionString) {
                version = number.intValue
            }
        }
        
        if version > 0 {
            for n in 1..<lines.count {
                let line = lines[n]
                newsLines.append(line)
            }
            newsVersion = version
        }
    }

    public func seen() {
        Utility.saveInt(key: "newsVersion", value: newsVersion)
    }
}

