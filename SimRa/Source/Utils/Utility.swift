//
//  Utility.swift
//  SimRa
//
//  Created by Hamza Khan on 21/05/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import UIKit
class Utility: NSObject{
    @objc static func getDocumentDirectory()->String?{
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
    }
    
    
    @objc static func checkIfFileExist(path: String)->Bool{
        let fileManager = FileManager.default
        if(!fileManager.fileExists(atPath: path)){
            return false
        }
        return true
    }
   
    @objc static func getFileData(path: String)->[String: Any]{
//        let path = Utility.getMainUserPreferenceFilePath()
        var propertyListFormat =  PropertyListSerialization.PropertyListFormat.xml //Format of the Property List.
        var plistData: [String: Any] = [:]

        if Utility.checkIfFileExist(path: path){
            let plistXML = FileManager.default.contents(atPath: path)!
            do {//convert the data to a dictionary and handle errors.
                plistData = try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: &propertyListFormat) as! [String:Any]
                let defaults = getUserDefaults()
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                defaults.register(defaults: plistData)
                

            } catch {
                print("Error reading plist: \(error), format: \(propertyListFormat)")
            }
        }
        else{
            let preference = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
            let isWritten =  preference.write(toFile: path, atomically: true)
            print("data written: %@", isWritten)
            plistData = preference as! [String : Any]
            
        }
        return plistData
    }
    private static func writeToMainPreferenceFile(){
        let path = getMainUserPreferenceFilePath()
        writeToPreferenceFile(path: path)
    }
    private static func writeToRegionBasedPreferenceFile(){
        let appDel = UIApplication.shared.delegate as! AppDelegate
        if appDel.regions != nil{
            let currentRegion = appDel.regions.filteredRegionId()
            let regionBasedPrefFile = getPreferenceFilePathWithRegion(regionId: currentRegion)
            writeToPreferenceFile(path: regionBasedPrefFile)
        }
    }
    private static func writeToPreferenceFile(path: String){
        let preference = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
        var isWritten = false
//        if checkIfFileExist(path: path){
            isWritten = preference.write(toFile: path, atomically: true)
//        }
//        else{
//            
//        }
        print("data written: %@ at %@", isWritten, path)
    }
    
    private static func getUserDefaults()-> UserDefaults{
        let appDel = UIApplication.shared.delegate as! AppDelegate
        return appDel.defaults

    }
    @objc static func remove(key: String){
        let defaults = getUserDefaults()
        defaults.removeObject(forKey: key)
        Utility.writeToMainPreferenceFile()
        Utility.writeToRegionBasedPreferenceFile()

    }
    
    
    @objc static func save(key: String, value : Any){
        
        let defaults = getUserDefaults()
        defaults.setValue(value, forKey: key)
        Utility.writeToMainPreferenceFile()
        Utility.writeToRegionBasedPreferenceFile()
    }
    @objc static func saveBool(key: String, value: Bool){
        let val = value as Any
        Utility.save(key: key, value: val)
        
    }
    @objc static func saveArray(key: String , value : NSArray){
        let val = value as Any
        Utility.save(key: key, value: val)
        
    }
    @objc static func saveNSInteger(key: String , value : NSInteger){
        let val = value as Any
        Utility.save(key: key, value: val)
        
    }
    @objc static func saveDictionary(key: String , value : NSDictionary){
        let val = value as Any
        Utility.save(key: key, value: val)
        
    }
    @objc static func saveString(key: String , value : String){
        let val = value as Any
        Utility.save(key: key, value: val)
    }
    @objc static func saveInt(key: String , value : Int){
        let val = value as Any
        Utility.save(key: key, value: val)
    }
    
    
}

extension Utility{
    @objc static func getMainUserPreferenceFilePath()->String{
        if let documentDirectory = getDocumentDirectory(){
            return documentDirectory.appending("/\(Constants.userPreferenceFileName).plist")
        }
        return ""
    }
    @objc static func getPreferenceFilePathWithRegion(regionId: Int)->String{
        if let documentDirectory = getDocumentDirectory(){
            return documentDirectory.appending("/\(Constants.userPreferenceFileName)_\(regionId).plist")
        }
        return ""
    }
    @objc static func getMainUserPreferenceFileData()-> [String: Any]{
        return getFileData(path: getMainUserPreferenceFilePath())
    }
    @objc static func getRegionBasedPreferenceFileData(regionId : Int)->[String:Any]{
        let path = getPreferenceFilePathWithRegion(regionId: regionId)
        return getFileData(path: path)
    }
    @objc static func loadRegionBasedPreferenceFileData(regionId:Int){
        let path = getPreferenceFilePathWithRegion(regionId: regionId)

        var propertyListFormat =  PropertyListSerialization.PropertyListFormat.xml //Format of the Property List.
        var plistData: [String: Any] = [:]
        
        if Utility.checkIfFileExist(path: path){
            let plistXML = FileManager.default.contents(atPath: path)!
            do {//convert the data to a dictionary and handle errors.
                plistData = try PropertyListSerialization.propertyList(from: plistXML, options: .mutableContainersAndLeaves, format: &propertyListFormat) as! [String:Any]
                let defaults = getUserDefaults()
                UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                defaults.register(defaults: plistData)
                
                
            } catch {
                print("Error reading plist: \(error), format: \(propertyListFormat)")
            }
        }
    }
}
