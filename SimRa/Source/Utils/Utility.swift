//
//  Utility.swift
//  SimRa
//
//  Created by Hamza Khan on 21/05/2021.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import UIKit
import Foundation
import CoreLocation
import AVFoundation

class Utility: NSObject {
    
    // MARK: - Preferences
    
    enum PreferenceFileNames: String, CaseIterable {
        case simraPrefs = "simraPrefs"
        case appPrefs = "appPrefs"
        case keyPrefs = "keyPrefs"
        case profile = "profile"
    }
    
    // MARK: - Document Directory
    
    @objc static func getDocumentDirectory() -> String? {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            return path
        }
        return nil
    }
    
    @objc static func getFilePath(fileName: String) -> String {
        if let documentDirectory = getDocumentDirectory() {
            return documentDirectory.appending("/\(fileName).plist")
        }
        return ""
    }
    
    @objc static func checkIfFileExist(path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    // MARK: - Profile Preferences
    
    private static func createPlist(fileName: String) {
        guard let documentDirectory = getDocumentDirectory() else {
            print("Error while fetching document directory")
            return
        }
        
        let path = documentDirectory.appending("/\(fileName).plist")
        
        if !FileManager.default.fileExists(atPath: path) {
            let data: [String: String] = [:]
            let someData = NSDictionary(dictionary: data)
            someData.write(toFile: path, atomically: true)
        }
    }
    
    private static func getPlistData(fileName: String) -> [String: Any]? {
        let path = getFilePath(fileName: fileName)
        
        if FileManager.default.fileExists(atPath: path) {
            guard let plistXML = FileManager.default.contents(atPath: path) else {
                return nil
            }
            
            do {
                let plistData = try PropertyListSerialization.propertyList(
                    from: plistXML,
                    options: .mutableContainersAndLeaves,
                    format: nil
                ) as? [String: Any]
                return plistData
            } catch {
                print("Error reading plist: \(error), path: \(path)")
                return nil
            }
        }
        return nil
    }
    
    private static func writeToPlist(fileName: String, dictionaryData: [String: Any]) {
        let isWritten = NSDictionary(dictionary: dictionaryData).write(
            toFile: getFilePath(fileName: fileName),
            atomically: true
        )
        print("data written: \(isWritten)")
    }
    
    private static func writeToPlist(fileName: String, key: String, val: Any) {
        var dict = [String: Any]()
        if let tempDict = getPlistData(fileName: fileName) {
            dict = tempDict
        }
        dict[key] = val
        writeToPlist(fileName: fileName, dictionaryData: dict)
    }
    
    private static func getUserDefaults() -> UserDefaults {
        return UserDefaults.standard
    }
    
    @objc static func remove(key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    @objc static func save(key: String, value: Any) {
        UserDefaults.standard.setValue(value, forKey: key)
    }
    
    @objc static func saveBool(key: String, value: Bool) {
        save(key: key, value: value)
    }
    
    @objc static func saveArray(key: String, value: NSArray) {
        save(key: key, value: value)
    }
    
    @objc static func saveNSInteger(key: String, value: NSInteger) {
        save(key: key, value: value)
    }
    
    @objc static func saveDictionary(key: String, value: NSDictionary) {
        save(key: key, value: value)
    }
    
    @objc static func saveString(key: String, value: String) {
        save(key: key, value: value)
    }
    
    @objc static func saveInt(key: String, value: Int) {
        save(key: key, value: value)
    }
    
    @objc static func getVal(key: String) -> Any? {
        return UserDefaults.standard.object(forKey: key)
    }
    
    // MARK: - Profile Management
    
    @objc static func createSimraPrefs() {
        createPlist(fileName: "simraPrefs")
    }
    
    @objc static func createAppsPrefs() {
        createPlist(fileName: "appPrefs")
    }
    
    @objc static func createProfilePrefs() {
        createPlist(fileName: "profile")
    }
    
    @objc static func createKeyPrefs() {
        createPlist(fileName: "keyPrefs")
    }
    
    @objc static func createRegionBasedProfilePref(regionId: Int) {
        createPlist(fileName: "profile_\(regionId)")
    }
    
    private static func writeProfileValue(key: String) {
        guard UserDefaults.standard.value(forKey: key) != nil else {
            return
        }
    }
    
    @objc static func writeProfile() {
        writeProfileValue(key: "ageId")
        writeProfileValue(key: "sexId")
        writeProfileValue(key: "experienceId")
        writeProfileValue(key: "behaviour")
        writeProfileValue(key: "behaviourValue")
        writeProfileValue(key: "totalIdle")
        writeProfileValue(key: "numberOfScary")
        writeProfileValue(key: "totalRides")
        writeProfileValue(key: "totalLength")
        writeProfileValue(key: "totalDuration")
        writeProfileValue(key: "totalIncidents")
        writeProfileValue(key: "totalSlots")
    }
    
    @objc static func writeRegionBasedProfile(regionId: Int) {
        var dict = [String: Any]()
        
        let regionIdValue = UserDefaults.standard.integer(forKey: "regionId")
        dict["regionId"] = regionIdValue
        
        // Profil Werte
        dict["totalRides"] = UserDefaults.standard.integer(forKey: "totalRides")
        dict["totalDuration"] = UserDefaults.standard.integer(forKey: "totalDuration")
        dict["totalLength"] = UserDefaults.standard.integer(forKey: "totalLength")
        dict["totalIncidents"] = UserDefaults.standard.integer(forKey: "totalIncidents")
        dict["totalIdle"] = UserDefaults.standard.integer(forKey: "totalIdle")
        dict["numberOfScary"] = UserDefaults.standard.integer(forKey: "numberOfScary")
        dict["totalSlots"] = UserDefaults.standard.array(forKey: "totalSlots")
        writeToPlist(fileName: "profile_\(regionId)", dictionaryData: dict)
    }
    
    @objc static func writeSimRaPrefs() {
        var dict = [String: Any]()
        if let bikeTypeId = getVal(key: "bikeTypeId") as? Int { dict["bikeTypeId"] = bikeTypeId }
        if let positionId = getVal(key: "positionId") as? Int { dict["positionId"] = positionId }
        if let childSeat = getVal(key: "childSeat") as? Bool { dict["childSeat"] = childSeat }
        if let trailer = getVal(key: "trailer") as? Bool { dict["trailer"] = trailer }
        if let deferredSecs = getVal(key: "deferredSecs") as? Int { dict["deferredSecs"] = deferredSecs }
        if let deferredMeters = getVal(key: "deferredMeters") as? Int { dict["deferredMeters"] = deferredMeters }
        if let AI = getVal(key: "AI") as? Bool { dict["AI"] = AI }
        if let openBikeSensor = getVal(key: "openBikeSensor") as? Bool { dict["openBikeSensor"] = openBikeSensor }
        if let dontShowRegionPrompt = getVal(key: "suppressRegionMessage") as? Bool { dict["dontShowRegionPrompt"] = dontShowRegionPrompt }
        if let newsVersion = getVal(key: "newsVersion") as? Int { dict["newsVersion"] = newsVersion }
        if let initialMessage = getVal(key: "initialMessage") as? Bool { dict["initialMessage"] = initialMessage }
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String { dict["version"] = version }
        writeToPlist(fileName: "simraPrefs", dictionaryData: dict)
    }
    
    @objc static func writeToKeyPrefs(key: String, val: Any) {
        writeToPlist(fileName: "keyPrefs", key: key, val: val)
    }
    
    @objc static func writeToAppPrefs(key: String, val: Any) {
        writeToPlist(fileName: "appPrefs", key: key, val: val)
    }
    
    @objc static func writeToProfile(key: String, val: Any) {
        writeToPlist(fileName: "profile", key: key, val: val)
    }
    
    @objc static func getKeyPrefsData() -> [String: Any]? {
        return getPlistData(fileName: "keyPrefs")
    }
    
    @objc static func getKeyPasswrdForRegion() -> [String] {
        guard let dict = getKeyPrefsData() else {
            return []
        }
        let regionId = UserDefaults.standard.integer(forKey: "regionId")
        let profile = "Profile_\(regionId)"
        
        if let keypass = dict[profile] as? String {
            return keypass.components(separatedBy: ",")
        }
        return []
    }
    
    @objc static func getSimraPrefsData() -> [String: Any]? {
        return getPlistData(fileName: "simraPrefs")
    }
    
    @objc static func getAppPrefsData() -> [String: Any]? {
        return getPlistData(fileName: "appPrefs")
    }
    
    @objc static func getProfilePrefsData() -> [String: Any]? {
        return getPlistData(fileName: "profile")
    }
    
    // MARK: - Setup Helper Functions
    
    @objc static func setSimraPrefData() {
        guard let simraPrefs = getPlistData(fileName: "simraPrefs") else {
            return
        }
        simraPrefs.forEach { key, value in
            save(key: key, value: value)
        }
    }
    
    @objc static func setKeyPrefData() {
        guard let keyPrefs = getPlistData(fileName: "keyPrefs") else {
            return
        }
        keyPrefs.forEach { key, value in
            save(key: key, value: value)
        }
    }
    
    @objc static func setAppPrefData() {
        guard let appPrefs = getPlistData(fileName: "appPrefs") else {
            return
        }
        appPrefs.forEach { key, value in
            save(key: key, value: value)
        }
    }
    
    @objc static func setProfileData() {
        guard let profileDict = getPlistData(fileName: "profile") else {
            return
        }
        profileDict.forEach { key, value in
            save(key: key, value: value)
        }
    }
    
    // MARK: - All Document Links
    
    @objc static func getAllDocumentsPrefLinks() -> [String] {
        var pathsArr: [String] = []
        pathsArr.append(getFilePath(fileName: "simraPrefs"))
        pathsArr.append(getFilePath(fileName: "appPrefs"))
        pathsArr.append(getFilePath(fileName: "profile"))
        pathsArr.append(getFilePath(fileName: "keyPrefs"))
        
        for i in 0 ..< 9 {
            let profileRegion = getFilePath(fileName: "profile_\(i)")
            if FileManager.default.fileExists(atPath: profileRegion) {
                pathsArr.append(profileRegion)
            }
        }
        return pathsArr
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
