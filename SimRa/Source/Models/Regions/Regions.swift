//
//  Regions.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import CoreLocation

@objcMembers
public class Regions: NSObject {
    public private(set) var regionId: Int = 0
    public private(set) var regionsId: Int = 0
    public private(set) var lastSeenRegionsId: Int = 0
    public private(set) var loaded: Bool = false
    public private(set) var closestsRegions: NSMutableArray = NSMutableArray()

    private var allRegions: [Region] = []

    public override init() {
        super.init()
    }
    
    private var hasInitialized = false
    private func ensureInitialized() {
        guard !hasInitialized else { return }
        hasInitialized = true
        loadRegions()
        loadPreferences()
    }

    public var regionSelected: Bool {
        regionId > 0
    }

    private func loadRegions() {
        if let url = Bundle.main.url(forResource: "regions", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            var tempRegions: [Region] = []
            for (index, dict) in json.enumerated() {
                let reg = Region()
                reg.position = dict["position"] as? Int ?? index
                reg.identifier = dict["identifier"] as? String ?? ""
                reg.englishDescription = dict["englishDescription"] as? String
                reg.germanDescription = dict["germanDescription"] as? String
                if let latVal = dict["lat"] as? Double {
                    reg.lat = NSNumber(value: latVal)
                }
                if let lonVal = dict["lon"] as? Double {
                    reg.lon = NSNumber(value: lonVal)
                }
                tempRegions.append(reg)
            }
            allRegions = tempRegions
            loaded = true
        } else {
            let germanURL = Bundle.main.url(forResource: "constants", withExtension: "plist", subdirectory: nil, localization: "de")
            let germanDict = (germanURL != nil ? NSDictionary(contentsOf: germanURL!) : nil) as? [String: Any]
            let germanRegions = germanDict?["regions"] as? [String] ?? []

            let englishURL = Bundle.main.url(forResource: "constants", withExtension: "plist", subdirectory: nil, localization: "Base") ?? Bundle.main.url(forResource: "constants", withExtension: "plist", subdirectory: nil, localization: "en")
            let englishDict = (englishURL != nil ? NSDictionary(contentsOf: englishURL!) : nil) as? [String: Any]
            let englishRegions = englishDict?["regions"] as? [String] ?? []
            let localesArray = englishDict?["locales"] as? [String] ?? []

            if !localesArray.isEmpty {
                var tempRegions: [Region] = []
                for i in 0..<localesArray.count {
                    let reg = Region()
                    reg.position = i
                    reg.identifier = localesArray[i]
                    if i == 2 {
                        reg.identifier = "!\(reg.identifier)"
                    }
                    reg.englishDescription = i < englishRegions.count ? englishRegions[i] : localesArray[i]
                    reg.germanDescription = i < germanRegions.count ? germanRegions[i] : localesArray[i]
                    tempRegions.append(reg)
                }
                allRegions = tempRegions
                loaded = true
            } else {
                let defaultRegion = Region()
                defaultRegion.position = 0
                defaultRegion.identifier = "berlin"
                defaultRegion.englishDescription = "Berlin/Potsdam"
                defaultRegion.germanDescription = "Berlin/Potsdam"
                defaultRegion.lat = NSNumber(value: 52.52)
                defaultRegion.lon = NSNumber(value: 13.405)
                allRegions = [defaultRegion]
                loaded = true
            }
        }

        closestsRegions.removeAllObjects()
        for reg in allRegions {
            closestsRegions.add(reg)
        }
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "regionId") != nil {
            regionId = defaults.integer(forKey: "regionId")
        }
        if defaults.object(forKey: "regionsId") != nil {
            regionsId = defaults.integer(forKey: "regionsId")
        }
        if defaults.object(forKey: "lastSeenRegionsId") != nil {
            lastSeenRegionsId = defaults.integer(forKey: "lastSeenRegionsId")
        }
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(regionId, forKey: "regionId")
        defaults.set(regionsId, forKey: "regionsId")
        defaults.set(lastSeenRegionsId, forKey: "lastSeenRegionsId")
    }

    public func regionTextsSorted() -> [String] {
        ensureInitialized()
        return allRegions.compactMap { $0.localizedDescription }
    }

    public func computeClosestsRegions(_ location: CLLocation?) {
        ensureInitialized()
        guard let location else { return }
        let sorted = allRegions.sorted { r1, r2 in
            r1.distanceFrom(location) < r2.distanceFrom(location)
        }
        closestsRegions.removeAllObjects()
        for reg in sorted {
            closestsRegions.add(reg)
        }
    }

    public func selectedIsOneOfThe3ClosestsRegions() -> Bool {
        ensureInitialized()
        let count = min(3, closestsRegions.count)
        for i in 0..<count {
            if let reg = closestsRegions[i] as? Region, reg.position == regionId {
                return true
            }
        }
        return false
    }

    public func indexForRegionId() -> Int {
        ensureInitialized()
        for (index, reg) in allRegions.enumerated() {
            if reg.position == regionId {
                return index
            }
        }
        return 0
    }

    public func selectIdSorted(_ id: Int) {
        ensureInitialized()
        if id >= 0, id < allRegions.count, let reg = closestsRegions[id] as? Region {
            regionId = reg.position
            savePreferences()
        }
    }

    public func selectPosition(_ position: Int) {
        ensureInitialized()
        regionId = position
        savePreferences()
    }

    public func currentRegion() -> Region? {
        ensureInitialized()
        for reg in allRegions {
            if reg.position == regionId {
                return reg
            }
        }
        return allRegions.first
    }

    public func seen() {
        lastSeenRegionsId = regionsId
        savePreferences()
    }
}
