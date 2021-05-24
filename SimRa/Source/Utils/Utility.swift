//
//  Utility.swift
//  SimRa
//
//  Created by Hamza Khan on 21/05/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import UIKit
class Utility: NSObject{
    @objc static func getUserPreferenceFilePath()->String{
        if let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first{
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
        let path = Utility.getUserPreferenceFilePath()
        let preference = UserDefaults.standard.dictionaryRepresentation() as NSDictionary
        let isWritten = preference.write(toFile: path, atomically: true)
        print("data written: %@", isWritten)
    }
    
    
    @objc static func remove(key: String){
        let appDel = UIApplication.shared.delegate as! AppDelegate
        let defaults = appDel.defaults
        defaults?.removeObject(forKey: key)
        Utility.writeToPreferenceFile()

    }
    
    
    @objc static func save(key: String, value : Any){
        
        let appDel = UIApplication.shared.delegate as! AppDelegate
        let defaults = appDel.defaults
        defaults?.setValue(value, forKey: key)
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
    
//    @objc static func getFileData(){
//        
//        
//       
//    }
//    @objc static func writeData(){
//        let preferences = Preferences(uploaded:false)
//        let encoder = PropertyListEncoder()
//        encoder.outputFormat = .xml
//        
//        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("\(Constants.userPreferenceFileName).plist")
//        
//        do {
//            let data = try encoder.encode(preferences)
//            try data.write(to: path)
//        } catch {
//            print(error)
//        }
//    }
    
    
}
