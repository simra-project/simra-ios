//
//  UploaderObject.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import Foundation
import Security

@objcMembers
open class UploaderObject: NSObject, URLSessionDelegate {
    public var version: Int = 1
    public var edited: Bool = false
    public var uploaded: Bool = false
    public var fileHash: String?
    public var filePasswd: String?

    override public init() {
        super.init()
        self.version = 1
    }

    // Must override in subclasses
    open func csvFile() -> URL? {
        return nil
    }

    // Must override in subclasses
    open func save() {
    }

    private lazy var uploadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 300.0
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private func uploadURLComponents(name: String, fileHash: String?, filePasswd: String?) -> URLComponents? {
        let baseURLString = "\(API.APIPrefix)/\(name)"
        guard var components = URLComponents(string: baseURLString) else {
            return nil
        }

        var regionIdentifier = ""
        let regions = Regions()
        if let current = regions.currentRegion() {
            regionIdentifier = current.identifier
        }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "loc", value: regionIdentifier),
            // Changed from String.clientHash to API.clientHash() to fix usage as per instructions
            URLQueryItem(name: "clientHash", value: API.clientHash())
        ]

        if let fileHash = fileHash, let filePasswd = filePasswd, !fileHash.isEmpty, !filePasswd.isEmpty {
            queryItems.insert(URLQueryItem(name: "filePassword", value: filePasswd), at: 1)
            queryItems.insert(URLQueryItem(name: "fileHash", value: fileHash), at: 0)
        }

        components.queryItems = queryItems
        return components
    }

    open func uploadFile(_ name: String, withController controller: NSObject, error errorSelector: Selector, completion completionSelector: Selector) {
        guard let csvFileUrl = self.csvFile() else { return }

        do {
            let data = try Data(contentsOf: csvFileUrl)
            if let string = String(data: data, encoding: .utf8) {
                print("data:\n\(string)")
            }
        } catch {
            print("Error reading csvFile: \(error)")
        }

        var components: URLComponents?

        if let fileHash = self.fileHash, let filePasswd = self.filePasswd {
            if fileHash.isEmpty || filePasswd.isEmpty {
                let keyPass = Utility.getKeyPasswrdForRegion()
                if keyPass.count >= 2 {
                    self.fileHash = keyPass[0]
                    self.filePasswd = keyPass[1]
                }
            }
            components = uploadURLComponents(name: name, fileHash: self.fileHash, filePasswd: self.filePasswd)
        } else {
            components = uploadURLComponents(name: name, fileHash: nil, filePasswd: nil)
        }

        guard let url = components?.url else {
            let urlError = NSError(domain: "SimRa.Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
            controller.performSelector(onMainThread: errorSelector, with: urlError, waitUntilDone: false)
            return
        }

        var request = URLRequest(url: url)
        let hasCredentials = (self.fileHash?.isEmpty == false) && (self.filePasswd?.isEmpty == false)
        request.httpMethod = hasCredentials ? "PUT" : "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        print("request:\n\(request)")

        let dataTask = uploadSession.uploadTask(with: request, fromFile: csvFileUrl) { [weak self] data, response, connectionError in
            guard let self = self else { return }

            if let connectionError = connectionError {
                print("connectionError \(connectionError)")
                controller.performSelector(onMainThread: errorSelector, with: connectionError, waitUntilDone: false)
            } else {
                let responseString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                print("response \(response ?? URLResponse()) \(responseString)")

                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    if request.httpMethod == "POST", let data = data, let dataString = String(data: data, encoding: .utf8) {
                        let components = dataString.components(separatedBy: ",")
                        if components.count == 2 {
                            self.fileHash = components[0]
                            self.filePasswd = components[1]
                            let key = "Profile_\(UserDefaults.standard.integer(forKey: "regionId"))"
                            let value = "\(self.fileHash ?? ""),\(self.filePasswd ?? "")"
                            Utility.writeToKeyPrefs(key: key, val: value)
                        }
                    }
                    self.version += 1
                    self.uploaded = true
                    
                    let reUploadedSelector = NSSelectorFromString("successfullyReUploaded")
                    if self.responds(to: reUploadedSelector) {
                        self.perform(reUploadedSelector)
                    }
                    
                    self.edited = false
                    self.performSelector(onMainThread: #selector(save), with: nil, waitUntilDone: true)
                }

                let dict: [String: Any] = ["response": response as Any, "data": data as Any]
                controller.performSelector(onMainThread: completionSelector, with: dict, waitUntilDone: false)
            }
        }

        dataTask.resume()
    }

    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        if let certificatePath = Bundle.main.path(forResource: "server", ofType: "cer"),
           let certificateData = try? Data(contentsOf: URL(fileURLWithPath: certificatePath)),
           let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) {
            let certificates = [certificate] as CFArray
            SecTrustSetAnchorCertificates(trust, certificates)
            SecTrustSetAnchorCertificatesOnly(trust, true)
        }

        var trustIsValid = false
        if #available(iOS 13.0, *) {
            trustIsValid = SecTrustEvaluateWithError(trust, nil)
        } else {
            var result: SecTrustResultType = .invalid
            let status = SecTrustEvaluate(trust, &result)
            trustIsValid = (status == errSecSuccess && (result == .proceed || result == .unspecified))
        }

        if trustIsValid {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
