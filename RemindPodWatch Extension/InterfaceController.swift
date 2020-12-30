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
    var actualTimer = Timer()
    var alreadyBreak = false
    @IBOutlet weak var timer: WKInterfaceTimer!
    @IBOutlet weak var textLabel: WKInterfaceLabel!
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    override func awake(withContext context: Any?) {
        textLabel.setText("Time Until Break")
        // Notifier for phone to pass info
        NotificationCenter.default.addObserver(self, selector: #selector(receivedPhone(info:)), name: NSNotification.Name(rawValue: "receivedPhone"), object: nil)
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        //Tell phone I'm activating, to send back updates
        if (session.isReachable){
            session.sendMessage(["update" : true ], replyHandler: nil, errorHandler: nil)
        }
        
    }
    
    @objc func receivedPhone(info: Notification){
        let message = info.userInfo!
        let seconds = message["seconds"]
        print(message)
        if ((message["break"]) as! Bool){
            //If break is true
            if (!alreadyBreak){
                alreadyBreak = true
                enterBreak(seconds as! TimeInterval)
            }
        } else{
            textLabel.setText("Time Until Break")
            actualTimer = Timer.scheduledTimer(timeInterval: seconds as! TimeInterval, target: self, selector: #selector(InterfaceController.enterBreak), userInfo: nil, repeats: false)
            alreadyBreak = false
            
        }
        let currentDate = Date()
        let breakDate = currentDate.addingTimeInterval(seconds as! TimeInterval)
        timer.setDate(breakDate)
        timer.start()
        if ((message["pause"]) as! Bool){
            //Pause timer
            timer.stop()
            actualTimer.isValid ? actualTimer.invalidate() : nil
        }
        
    }
    
    @objc func enterBreak(_ seconds : TimeInterval){
        textLabel.setText("Break Time!")
        let currentDate = Date()
        let breakDate = currentDate.addingTimeInterval(seconds)
        timer.setDate(breakDate)
        timer.start()
        WKInterfaceDevice.current().play(.success)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    
    
}
