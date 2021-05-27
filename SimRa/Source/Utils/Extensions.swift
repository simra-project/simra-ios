//
//  Extensions.swift
//  SimRa
//
//  Created by Hamza Khan on 24/05/2021.
//  Copyright © 2021 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
typealias Action = () -> ()

extension UIAlertController {
    
    @objc static func showAlert(title: String, message: String?,  style : Style, buttonFirstTitle: String, buttonSecondTitle: String, buttonFirstAction: @escaping Action, buttonSecondAction : @escaping Action, over viewController: UIViewController) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: style)
        
        ac.addAction(UIAlertAction(title: buttonFirstTitle, style: .default, handler: { (_) in
           buttonFirstAction()
        }))
        
        ac.addAction(UIAlertAction(title: buttonSecondTitle, style: .default, handler: { (_) in
            buttonSecondAction()
        }))
        
        viewController.present(ac, animated: true)
    }
    @objc static func showActionSheet(title: String, message: String?, buttonFirstTitle: String, buttonSecondTitle: String, buttonThirdTitle: String, buttonFirstAction: @escaping Action, buttonSecondAction : @escaping Action, buttonThirdAction : @escaping Action,  over viewController: UIViewController) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        ac.addAction(UIAlertAction(title: buttonFirstTitle, style: .default, handler: { (_) in
            buttonFirstAction()
        }))
        
        ac.addAction(UIAlertAction(title: buttonSecondTitle, style: .default, handler: { (_) in
            buttonSecondAction()
        }))
        ac.addAction(UIAlertAction(title: buttonThirdTitle, style: .default, handler: { (_) in
            buttonThirdAction()
        }))
        viewController.present(ac, animated: true)
    }
}
