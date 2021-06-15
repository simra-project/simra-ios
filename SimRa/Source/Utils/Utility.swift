//
//  Utility.swift
//  SimRa
//
//  Created by Hamza Khan on 21/05/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import UIKit
class Utility: NSObject {
    @objc static func getDocumentDirectory()->String? {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
    }
    @objc static func getFilePath(fileName : String)->String{
        if let documentDirectory = getDocumentDirectory() {
            return documentDirectory.appending("/\(fileName).plist")
        }
        return ""
    }
    @objc static func checkIfFileExist(path: String)->Bool {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            return false
        }
        return true
    }
    private static func createPlist(fileName: String){
        let fileManager = FileManager.default
        let fileNameEnum = PreferenceFileNames.init(rawValue: fileName)
        guard let documentDirectory = getDocumentDirectory() else {
            print("Error while fetching document directy")
            return
        }
        let path = documentDirectory.appending("/\(fileName).plist")
        if(!fileManager.fileExists(atPath: path)){
            print(path)
            let data : [String: String] = [:]
            let someData = NSDictionary(dictionary: data)
            let isWritten = someData.write(toFile: path, atomically: true)
            print("\(fileName) created: \(isWritten)")
        }else{
            print("\(fileName) exists")
            switch fileNameEnum {
            case .simraPrefs:
                setSimraPrefData()
                break
            case .appPrefs:
                setAppPrefData()
                break
            case .keyPrefs:
                setKeyPrefData()
                break
            case .profile:
                setProfileData()
                break
            default:
                break
            }
        }
    }
    private static func getPlistData(fileName: String)->[String: Any]? {
        let path = getFilePath(fileName: fileName)
        var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml // Format of the Property List.
        if Utility.checkIfFileExist(path: path) {
            let plistXML = FileManager.default.contents(atPath: path)!
            do { // convert the data to a dictionary and handle errors.
                var plistData: [String: Any] = [:]
                plistData = try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: &propertyListFormat) as! [String: Any]
                return plistData
            } catch {
                print("Error reading plist: \(error), format: \(propertyListFormat)")
                return nil
            }
        }
        return nil
        
    }
    private static func writeToPlist(fileName: String, dictionaryData: [String: Any]){
        
        let isWritten = NSDictionary(dictionary: dictionaryData).write(toFile: getFilePath(fileName: fileName), atomically: true)
        print("data written: %@", isWritten)
    }
    private static func writeToPlist(fileName: String, key : String , val : Any){
        var dict = [String : Any]()
        if let tempDict = getPlistData(fileName: fileName){
            dict = tempDict
        }
        dict[key] = val
        let isWritten = NSDictionary(dictionary: dict).write(toFile: getFilePath(fileName: fileName), atomically: true)
        print("data written: %@", isWritten)
    }
    private static func getUserDefaults()-> UserDefaults {
        let appDel = UIApplication.shared.delegate as! AppDelegate
        return appDel.defaults
    }
    
    @objc static func remove(key: String) {
        let defaults = getUserDefaults()
        defaults.removeObject(forKey: key)
    }
    
    @objc static func save(key: String, value: Any) {
        let defaults = getUserDefaults()
        defaults.setValue(value, forKey: key)
    }
    
    @objc static func saveBool(key: String, value: Bool) {
        let val = value as Any
        Utility.save(key: key, value: val)
    }
    
    @objc static func saveArray(key: String, value: NSArray) {
        let val = value as Any
        Utility.save(key: key, value: val)
    }
    
    @objc static func saveNSInteger(key: String, value: NSInteger) {
        let val = value as Any
        Utility.save(key: key, value: val)
    }
    
    @objc static func saveDictionary(key: String, value: NSDictionary) {
        let val = value as Any
        Utility.save(key: key, value: val)
    }
    
    @objc static func saveString(key: String, value: String) {
        let val = value as Any
        Utility.save(key: key, value: val)
    }
    
    @objc static func saveInt(key: String, value: Int) {
        let val = value as Any
        Utility.save(key: key, value: val)
    }
    @objc static func getVal(key:String)-> Any?{
        return getUserDefaults().object(forKey: key)
    }
}

extension Utility {
    @objc static func getAllDocumentsPrefLinks()->[String]{
        var pathsArr : [String] = []
        pathsArr.append(getFilePath(fileName: PreferenceFileNames.simraPrefs.getFileName()))
        pathsArr.append(getFilePath(fileName: PreferenceFileNames.appPrefs.getFileName()))
        pathsArr.append(getFilePath(fileName: PreferenceFileNames.profile.getFileName()))
        pathsArr.append(getFilePath(fileName: PreferenceFileNames.keyPrefs.getFileName()))
        let manager = FileManager.default

        for i in 0..<9{
            let profileRegion = getFilePath(fileName: PreferenceFileNames.profile.getFileName() + "_" + String(i))
            if manager.fileExists(atPath: profileRegion){
                pathsArr.append(profileRegion)
            }
        }
        return pathsArr
    }
    @objc static func createSimraPrefs(){
        let strFileName = PreferenceFileNames.simraPrefs.getFileName()
        createPlist(fileName: strFileName)
    }
    @objc static func createAppsPrefs(){
        let strFileName = PreferenceFileNames.appPrefs.getFileName()
        createPlist(fileName: strFileName)
    }
    @objc static func createProfilePrefs(){
        let strFileName = PreferenceFileNames.profile.getFileName()
        createPlist(fileName: strFileName)
    }
    @objc static func createKeyPrefs(){
        let strFileName = PreferenceFileNames.keyPrefs.getFileName()
        createPlist(fileName: strFileName)
    }
    @objc static func createRegionBasedProfilePref(regionId : Int){
        let strFileName = PreferenceFileNames.profile.getFileName()
        let regionBasedProfileName = "\(strFileName)_\(regionId)"
        createPlist(fileName: regionBasedProfileName)
    }
    @objc static func writeProfile(){
        writeToProfile(key: "ageId", val: getUserDefaults().value(forKey: "ageId"))
        writeToProfile(key: "sexId", val: getUserDefaults().value(forKey: "sexId"))
        writeToProfile(key: "experienceId", val: getUserDefaults().value(forKey: "experienceId"))
        writeToProfile(key: "behaviour", val: getUserDefaults().value(forKey: "behaviour"))
        writeToProfile(key: "behaviourValue", val: getUserDefaults().value(forKey: "behaviourValue"))
        writeToProfile(key: "totalIdle", val: getUserDefaults().value(forKey: "totalIdle"))
        writeToProfile(key: "numberOfScary", val: getUserDefaults().value(forKey: "numberOfScary"))
        writeToProfile(key: "totalRides", val: getUserDefaults().value(forKey: "totalRides"))
        writeToProfile(key: "totalLength", val: getUserDefaults().value(forKey: "totalLength"))
        writeToProfile(key: "totalDuration", val: getUserDefaults().value(forKey: "totalDuration"))
        writeToProfile(key: "totalIncidents", val: getUserDefaults().value(forKey: "totalIncidents"))
        writeToProfile(key: "totalSlots", val: getUserDefaults().value(forKey: "totalSlots"))
        writeToProfile(key: "regionId", val: getUserDefaults().value(forKey: "regionId"))
    }
    @objc static func writeRegionBasedProfile(){
        let ad = UIApplication.shared.delegate as! AppDelegate
        let regionId = ad.regions.regionId;
        let keyTotalRides = "totalRides-\(regionId)"
        let keytotalDuration = "totalDuration-\(regionId)"
        let keytotalLength = "totalLength-\(regionId)"

        let keytotalIncidents = "totalIncidents-\(regionId)"
        let keytotalIdle = "totalIdle-\(regionId)"
        let keynumberOfScary = "numberOfScary-\(regionId)"
        let keytotalSlots = "totalSlots-\(regionId)"
        
        let totalRides = getUserDefaults().integer(forKey: keyTotalRides)
        let totalDuration = getUserDefaults().integer(forKey: keytotalDuration)
        let totalLength = getUserDefaults().integer(forKey: keytotalLength)
       
        let totalIncidents = getUserDefaults().integer(forKey: keytotalIncidents)
        let totalIdle = getUserDefaults().integer(forKey: keytotalIdle)
        let numberOfScary = getUserDefaults().integer(forKey: keynumberOfScary)
        let totalSlots = getUserDefaults().array(forKey: keytotalSlots)

        var dict = [String:Any]()
        dict["totalRides"] = totalRides
        dict["totalDuration"] = totalDuration
        dict["totalLength"] = totalLength
        dict["totalIncidents"] = totalIncidents
        dict["totalIdle"] = totalIdle
        dict["numberOfScary"] = numberOfScary
        dict["totalSlots"] = totalSlots
            let plistName = PreferenceFileNames.profile.getFileName() + "_" + "\(String(describing: regionId))"
        writeToPlist(fileName: plistName, dictionaryData: dict)

//        NSMutableArray <NSNumber *> *totalSlots = [[ad.defaults
//        arrayForKey:[@"totalSlots" withRegionId:regionId]] mutableCopy];
    }
    @objc static func writeSimRaPrefs(){
        var dict = [String:Any]()
         let bikeTypeId = getVal(key: "bikeTypeId") as? Int
           let positionId = getVal(key: "positionId") as? Int
           let childSeat = getVal(key: "childSeat") as? Bool
           let trailer = getVal(key: "trailer") as? Bool
           let deferredSecs = getVal(key: "deferredSecs") as? Int
           let deferredMeters = getVal(key: "deferredMeters") as? Int
           let AI = getVal(key: "AI") as? Bool
           let dontShowRegionPrompt = getVal(key: "suppressRegionMessage") as? Bool
           let newsVersion = getVal(key: "newsVersion") as? Int
           let initialMessage = getVal(key: "initialMessage") as? Bool
           let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            dict["bikeTypeId"]      = bikeTypeId
            dict["positionId"]      = positionId
            dict["childSeat"]       = childSeat
            dict["trailer"]         = trailer
            dict["deferredSecs"]    = deferredSecs
            dict["deferredMeters"]  = deferredMeters
            dict["AI"]              = AI
            dict["dontShowRegionPrompt"] = dontShowRegionPrompt
            dict["newsVersion"]     = newsVersion
            dict["initialMessage"]  = initialMessage
            dict["version"]         = version
        writeToPlist(fileName: PreferenceFileNames.simraPrefs.getFileName(), dictionaryData: dict)
    }
    @objc static func writeToKeyPrefs(key : String , val : Any){
        writeToPlist(fileName: PreferenceFileNames.keyPrefs.getFileName(), key: key, val: val)
    }
    @objc static func writeToAppPrefs(key : String , val : Any){
        writeToPlist(fileName: PreferenceFileNames.appPrefs.getFileName(), key: key, val: val)
    }
    @objc static func writeToProfile(key : String , val : Any){
        writeToPlist(fileName: PreferenceFileNames.profile.getFileName(), key: key, val: val)
    }
    @objc static func setProfileData(){
        guard let profileDict = getPlistData(fileName: PreferenceFileNames.profile.getFileName())
        else {
            return
        }
        profileDict.forEach { (key: String, value: Any) in
            save(key: key, value: value)
        }
//        save(key: "ageId", value: profileDict["ageId"])
//        save(key: "sexId", value: profileDict["sexId"])
//        save(key: "experienceId", value: profileDict["experienceId"])
//        save(key: "behaviour", value: profileDict["behaviour"])
//        save(key: "behaviourValue", value: profileDict["behaviourValue"])
//        save(key: "totalIdle", value: profileDict["totalIdle"])
//        save(key: "numberOfScary", value: profileDict["numberOfScary"])
//        save(key: "totalRides", value: profileDict["totalRides"])
//        save(key: "totalLength", value: profileDict["totalLength"])
//        save(key: "totalDuration", value: profileDict["totalDuration"])
//        save(key: "totalIncidents", value: profileDict["totalIncidents"])
//        save(key: "totalSlots", value: profileDict["totalSlots"])

    }
    @objc static func setKeyPrefData(){
        guard let keyPrefs = getPlistData(fileName: PreferenceFileNames.keyPrefs.getFileName())
        else {
            return
        }
        keyPrefs.forEach { (key: String, value: Any) in
            save(key: key, value: value)
        }
    }
    @objc static func setSimraPrefData(){
        guard let simraPrefs = getPlistData(fileName: PreferenceFileNames.simraPrefs.getFileName())
        else {
            return
        }
        simraPrefs.forEach { (key,value) in
            save(key: key, value: value)
        }
//        save(key: "bikeTypeId", value: simraPrefs["bikeTypeId"])
//        save(key: "positionId", value: simraPrefs["positionId"])
//        save(key: "childSeat", value: simraPrefs["childSeat"])
//        save(key: "trailer", value: simraPrefs["trailer"])
//        save(key: "deferredSecs", value: simraPrefs["deferredSecs"])
//        save(key: "deferredMeters", value: simraPrefs["deferredMeters"])
//        save(key: "AI", value: simraPrefs["AI"])
//        save(key: "dontShowRegionPrompt", value: simraPrefs["dontShowRegionPrompt"])
//        save(key: "newsVersion", value: simraPrefs["newsVersion"])
//        save(key: "initialMessage", value: simraPrefs["initialMessage"])
//        save(key: "version", value: simraPrefs["version"])
    }
    @objc static func setAppPrefData(){
        guard let appPrefs = getPlistData(fileName: PreferenceFileNames.appPrefs.getFileName())
        else {
            return
        }
        appPrefs.forEach { (key,value) in
            save(key: key, value: value)
        }
        
    }
    @objc static func getKeyPasswrdForRegion()->[String]{
        guard let dict = getKeyPrefsData() else { return [] }
        let appDel = UIApplication.shared.delegate as! AppDelegate

        let regionID = appDel.regions.regionId
        let profile = "Profile_" + String(regionID)
        
        let keypass = dict[profile] as! String
        return  keypass.components(separatedBy: ",")
        
    
    }
    @objc static func getKeyPrefsData()->[String: Any]?{
        getPlistData(fileName: PreferenceFileNames.keyPrefs.getFileName())
    }
    @objc static func getSimraPrefsData()->[String: Any]?{
        getPlistData(fileName: PreferenceFileNames.simraPrefs.getFileName())
    }
    @objc static func getAppPrefsData()->[String : Any]?{
        getPlistData(fileName: PreferenceFileNames.appPrefs.getFileName())
    }
    @objc static func getProfilePrefsData()->[String : Any]?{
        getPlistData(fileName: PreferenceFileNames.profile.getFileName())
    }
    
    //    @objc static func getMainUserPreferenceFilePath()->String {
    //        return getFilePath(fileName: "\(Constants.userPreferenceFileName)")
    //    }
    //
    //    @objc static func getPreferenceFilePathWithRegion(regionId: Int)->String {
    //        return getFilePath(fileName: "\(Constants.userPreferenceFileName)_\(regionId)")
    //    }
    //
    //    @objc static func getMainUserPreferenceFileData()-> [String: Any]? {
    //        return getPlistData(path: getMainUserPreferenceFilePath())
    //    }
    //
    //    @objc static func getRegionBasedPreferenceFileData(regionId: Int)->[String: Any]? {
    //        let path = getPreferenceFilePathWithRegion(regionId: regionId)
    //        return getPlistData(path: path)
    //    }
    //
    //    @objc static func loadRegionBasedPreferenceFileData(regionId: Int) {
    //        let path = getPreferenceFilePathWithRegion(regionId: regionId)
    //        _ = loadPreferenceInUserDefaults(path: path)
    //    }
    //
    //    private static func loadPreferenceInUserDefaults(path: String)-> UserDefaults {
    //        var propertyListFormat = PropertyListSerialization.PropertyListFormat.xml // Format of the Property List.
    //        var plistData: [String: Any] = [:]
    //        let defaults = UserDefaults.standard
    //
    //        if Utility.checkIfFileExist(path: path) {
    //            let plistXML = FileManager.default.contents(atPath: path)!
    //            do { // convert the data to a dictionary and handle errors.
    //                plistData = try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: &propertyListFormat) as! [String: Any]
    //                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
    //                defaults.register(defaults: plistData)
    //
    //            } catch {
    //                print("Error reading plist: \(error), format: \(propertyListFormat)")
    //            }
    //        }
    //        return defaults
    //    }
    //
    //    @objc static func loadUserDefaults()->UserDefaults {
    //        let path = Utility.getMainUserPreferenceFilePath()
    //        return loadPreferenceInUserDefaults(path: path)
    //    }
    //
    //    private static func writeToMainPreferenceFile() {
    //        let path = getMainUserPreferenceFilePath()
    //        writeToPreferenceFile(path: path)
    //    }
    //
    //    private static func writeToRegionBasedPreferenceFile() {
    //        let appDel = UIApplication.shared.delegate as! AppDelegate
    //        if appDel.regions != nil {
    //            let currentRegion = appDel.regions.filteredRegionId()
    //            let regionBasedPrefFile = getPreferenceFilePathWithRegion(regionId: currentRegion)
    //            writeToPreferenceFile(path: regionBasedPrefFile)
    //        }
    //    }
    //
    //    private static func writeToPreferenceFile(path: String) {
    //        let preference = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
    //        var isWritten = false
    //        isWritten = preference.write(toFile: path, atomically: true)
    //        print("data written: %@ at %@", isWritten, path)
    //    }
}
