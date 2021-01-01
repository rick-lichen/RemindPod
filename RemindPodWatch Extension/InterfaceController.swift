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
    var seconds = 1800.0
    var prevSeconds = 1800.0
    var breakSeconds = 120.0
    var prevBreakSeconds = 120.0
    var timerStarted = false
    let session = WCSession.default
    var actualTimer = Timer() 
    var alreadyBreak = false
    
    @IBOutlet weak var timerLabel: WKInterfaceLabel!
    @IBOutlet weak var textLabel: WKInterfaceLabel!
    @IBOutlet weak var watchButton: WKInterfaceButton!
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    }
    
    override func awake(withContext context: Any?) {
        textLabel.setText("Time Until Break")
        // Notifier for phone to pass info
        NotificationCenter.default.addObserver(self, selector: #selector(receivedPhone(info:)), name: NSNotification.Name(rawValue: "receivedPhone"), object: nil)
        //Disable timer in the very beginning
        disableTimer()
        //Clear any saved time
        UserDefaults.standard.removeObject(forKey: "savedTime")
        
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        if (actualTimer.isValid){
            //Get any passed time and update it on screen
            if let savedDate = UserDefaults.standard.object(forKey: "savedTime") as? Date {
                let (h, m, s) = getTimeDifference(startDate: savedDate)
                let elapsedSeconds = (h*60+m)*60+s
                if (alreadyBreak){
                    //If it was already break time when app was exited
                    breakSeconds -= Double(elapsedSeconds)
                } else {
                    if (seconds > 0){
                        seconds -= Double(elapsedSeconds)
                        if (seconds < 0){
                            //If subtracting makes seconds negative, enter break time with break second = spillover
                            breakSeconds += seconds
                            alreadyBreak = true
                            //If breakSeconds also becomes negative, just restart timer. Otherwise enter break (when seconds =0, it'll automatically enter break
                            if (breakSeconds < 0){
                                //Invalidate previous timer
                                //Reset seconds
                                seconds = prevSeconds
                                startTimer()
                            }
                        }
                    }
                }
                
            }
        } else{
            //Clear any saved time
            UserDefaults.standard.removeObject(forKey: "savedTime")
        }
        //Tell phone I'm activating, to send back updates
        if (session.isReachable){
            session.sendMessage(["update" : true, "started" : timerStarted, "seconds" : seconds], replyHandler: nil, errorHandler: nil)
        }
        
    }
    func getTimeDifference(startDate: Date) -> (Int, Int, Int) {
        let difference = Calendar.current.dateComponents([.hour, .minute, .second], from: startDate, to: Date())
        return (difference.hour!, difference.minute!, difference.second!)
        
    }
    
    @objc func receivedPhone(info: Notification){
        let message = info.userInfo!
        print(message)
        if ((message["phone"]) as! Bool){
            //If phone just wants an update
            if (session.isReachable){
                session.sendMessage(["update" : true, "started" : timerStarted, "seconds" : seconds], replyHandler: nil, errorHandler: nil)
            }
        } 
        if ((message["pause"]) as! Bool){
            print("pause is true, timerstarted is \(timerStarted)")
            if (!((message["started"]) as! Bool) && timerStarted){
                //Don't pause timer if we've started already and they haven't
            } else{
                disableTimer()
            }
        } else{
            if ((message["break"]) as! Bool){
                breakSeconds = message["seconds"] as! Double
                //If break is true
                if (!alreadyBreak){
                    //If haven't enterred break already
                    prevBreakSeconds = breakSeconds
                    enterBreak()
                } else{
                    //update the timer?
                }
            } else{
                seconds = message["seconds"] as! Double
                if (!timerStarted){
                    //If timer didn't start yet, or if it shouldn't be break on the watch anymore.  start on watch and update prev seconds
                    prevSeconds = seconds
                }
                startTimer()
            }
        }
    }
    func disableTimer(){
        print("disabling timer")
        timerStarted = false
        timerLabel.setText("00:00:00")
        actualTimer.isValid ? actualTimer.invalidate() : nil
        watchButton.setTitle("Start Break Timer")
    }
    
    @objc func startTimer(){
        print("starting timer")
        print("seconds = \(seconds)")
        //Invalidate current timer if one was running and set it to nil
        print("timer is currently \(actualTimer.isValid)")
        actualTimer.isValid ? actualTimer.invalidate() : nil
        //Display timer
        timerLabel.setText("\(seconds)")
        textLabel.setText("Time Until Break")
        //Actual timer
        actualTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(InterfaceController.counter), userInfo: nil, repeats: true)
        alreadyBreak = false
        timerStarted = true
        watchButton.setTitle("Enter Break")
        print("at end of starttimer, actualtimer is \(actualTimer.isValid)")
    }
    
    @objc func counter(){
        print("in counter")
        if (alreadyBreak){
            //counter for break time
            if (breakSeconds > 0){
                breakSeconds -= 1.0
                let (h, m, s) =  secondsToHoursMinutesSeconds(seconds: Int(breakSeconds))
                timerLabel.setText("\(h)\(m)\(s)")
            } else{
                //Reset seconds
                seconds = prevSeconds
                startTimer()
            }
        } else{
            //Normal timer
            if (seconds > 0){
                seconds -= 1.0
                let (h, m, s) =  secondsToHoursMinutesSeconds(seconds: Int(seconds))
                timerLabel.setText("\(h)\(m)\(s)")
            } else {
                //If seconds expired – time for break!
                //Set breakseconds to previous
                breakSeconds = prevBreakSeconds
                enterBreak()
            }
        }
    }
    @objc func enterBreak(){
        //Invalidate any timers
        actualTimer.isValid ? actualTimer.invalidate() : nil
        //Display timer
        textLabel.setText("Break Time!")
        //Vibrate watch
        WKInterfaceDevice.current().play(.success)
        //Actual timer
        actualTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(InterfaceController.counter), userInfo: nil, repeats: true)
        timerStarted = true
        alreadyBreak = true
        watchButton.setTitle("Skip Break")
    }
    
    @IBAction func buttonPressed() {
        if (!timerStarted){
            //Timer didn't start yet, so button is to start timer
            //Reset seconds
            seconds = prevSeconds
            startTimer()
        } else {
            //Timer has started
            if (alreadyBreak){
                //If it's break time already, then pressing should skip break
                //Skipping break by starting timer
                //Reset seconds
                seconds = prevSeconds
                startTimer()
            } else {
                //Pressing here means to enter break
                //Set breakseconds to previous
                breakSeconds = prevBreakSeconds
                enterBreak()
            }
        }
    }
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        let defaults = UserDefaults.standard
        defaults.setValue(Date(), forKey: "savedTime")
    }
    
    //Helper method for formatting
    func secondsToHoursMinutesSeconds (seconds : Int) -> (String, String, String) {
        //Formatting of timer display
        var hString = ""
        var mString = ""
        var sString = ""
        let (h,m,s) = (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
        if (h != 0){
            if (h < 10){
                hString = "0\(h) : "
            } else{
                hString = "\(h) : "
            }
        }
        if (m < 10){
            mString = "0\(m) : "
        } else {
            mString = "\(m) : "
        }
        if (s < 10){
            sString = "0\(s)"
        } else {
            sString = "\(s)"
        }
        return (hString, mString, sString)
    }
    
}
