//
//  InterfaceController.swift
//  RemindPodWatch Extension
//
//  Created by Rick Liu on 12/29/20.
//

import WatchKit
import Foundation
import WatchConnectivity


class InterfaceController: WKInterfaceController, WCSessionDelegate {
    
    let session = WCSession.default
    @IBOutlet weak var breakTimeLabel: WKInterfaceTimer!
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        NotificationCenter.default.addObserver(self, selector: #selector(receivedPhone(info:)), name: NSNotification.Name(rawValue: "receivedPhone"), object: nil)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        
    }
    
    @objc func receivedPhone(info: Notification){
        let message = info.userInfo!
        let seconds = message["seconds"]
        let currentDate = Date()
        let breakDate = currentDate.addingTimeInterval(seconds as! TimeInterval)
        breakTimeLabel.setDate(breakDate)
        breakTimeLabel.start()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    
    
}
