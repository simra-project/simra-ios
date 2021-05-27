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
    @objc static func getUserPreferenceFilePath()->String{
        if let documentDirectory = getDocumentDirectory(){
            return documentDirectory.appending("/\(Constants.userPreferenceFileName).plist")
        }
        return ""
    }
    @objc static func getPreferenceFile()->Bool{
        return checkIfFileExist(path: Utility.getUserPreferenceFilePath())
    }
    @objc static func checkIfFileExist(path: String)->Bool{
        let fileManager = FileManager.default
        if(!fileManager.fileExists(atPath: path)){
            return false
        }
        return true
    }
    @objc static func getUserPreferenceFileData()->[String: Any]{
        let path = Utility.getUserPreferenceFilePath()
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
            let isWritten = preference.write(toFile: path, atomically: true)
            print("data written: %@", isWritten)
            plistData = preference as! [String : Any]
            
        }
        return plistData
    }
    
    private static func writeToPreferenceFile(){
        let path = getUserPreferenceFilePath()
        let preference = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
        let isWritten = preference.write(toFile: path, atomically: true)
        print("data written: %@", isWritten)
    }
    
    private static func getUserDefaults()-> UserDefaults{
        let appDel = UIApplication.shared.delegate as! AppDelegate
        return appDel.defaults

    }
    @objc static func remove(key: String){
        let defaults = getUserDefaults()
        defaults.removeObject(forKey: key)
        Utility.writeToPreferenceFile()

    }
    
    
    @objc static func save(key: String, value : Any){
        
        let defaults = getUserDefaults()
        defaults.setValue(value, forKey: key)
        Utility.writeToPreferenceFile()
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

