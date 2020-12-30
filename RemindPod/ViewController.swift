//
//  ViewController.swift
//  M1-AirPodOSC
//
//  Created by Dylan Marcus on 9/17/20.
//

import UIKit
import CoreMotion
import SwiftOSC
import AVFoundation
import UserNotifications
import WatchConnectivity

//Adding a comment here to see if it syncs up to remote repo
var player: AVAudioPlayer?
var connected = false
var notifying = false
var tiltTimerStarted = false
var enteredBreak = false
var pauseWatch = false
var calibrateAngle = 0.0
var seconds = 1800
var prevSeconds = 1800
var breakSeconds = 120
var prevBreakSeconds = 120
var timer = Timer()
var breakTimer = Timer()
var tiltTimer = Timer()
var isFrequency = true
//Head tracking
var degreesPitch = 0.0
var pitchEnabled = false

//Apple watch
let session = WCSession.default

@available(iOS 14.0, *)
class ViewController: UIViewController, CMHeadphoneMotionManagerDelegate, UIAdaptivePresentationControllerDelegate, AVAudioPlayerDelegate
{
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var connectionMessage: UILabel!
    @IBOutlet weak var pitchValue: UILabel!
    @IBOutlet weak var timeRemainingHeader: UILabel!
    @IBOutlet weak var timerPicker: UIDatePicker!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var disableTimerButton: UIButton!
    @IBOutlet weak var enableBreakButton: UIButton!
    @IBOutlet weak var changeFrequencyButton: UIButton!
    @IBOutlet weak var changeDurationButton: UIButton!
    @IBOutlet weak var enterBreakButton: UIButton!
    @IBOutlet weak var calibrateButton: UIButton!
    
    @IBAction func calibrate(_ sender: Any) {
        //Setting base angle
        calibrateAngle = degreesPitch
    }
    
    //Enable Timer
    @IBAction func enableTimer(_ sender: Any) {
        seconds = 1800 //Random number to make sure breaktime doesn't get enterred 
        timeRemainingHeader.isHidden = false
        timerLabel.isHidden = false
        changeFrequencyButton.isHidden = false
        changeDurationButton.isHidden = false
        enterBreakButton.isHidden = false
        disableTimerButton.isHidden = false
        enableBreakButton.isHidden = true
        startTimerFunction()
    }
    @IBAction func disableTimer(_ sender: Any) {
        timer.isValid ? timer.invalidate() : nil
        timeRemainingHeader.isHidden = true
        timerLabel.isHidden = true
        enterBreakButton.isHidden = true
        changeFrequencyButton.isHidden = true
        changeDurationButton.isHidden = true
        enableBreakButton.isHidden = false
        disableTimerButton.isHidden = true
        pauseWatch = true
        seconds = 0
        updateWatch()
    }
    
    //Timer
    @IBAction func doneButtonPressed(_ sender: Any) {
        if (isFrequency){
            //Came through change break frequency – update seconds
            seconds = Int(timerPicker.countDownDuration)
            prevSeconds = seconds
            startTimerFunction()
        } else {
            //Came through change break duration
            breakSeconds = Int(timerPicker.countDownDuration)
            prevBreakSeconds = breakSeconds
            doneButton.isHidden = true
            timerPicker.isHidden = true
        }
        //Unpause watch
        pauseWatch = false
        updateWatch()
    }
    func startTimerFunction(){
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.counter), userInfo: nil, repeats: true)
        doneButton.isHidden = true
        timerPicker.isHidden = true
        //Also start timer on watch by passing in seconds needed for timer
        enteredBreak = false
        updateWatch()
    }
    @IBAction func showFrequencyPicker(_ sender: Any) {
        timerPicker.isHidden = false
        doneButton.isHidden = false
        isFrequency = true
        timer.isValid ? timer.invalidate() : nil
        //set timer selection to previous selected time
        timerPicker.countDownDuration = TimeInterval(prevSeconds)
        //Pause watch
        pauseWatch = true
        updateWatch()
    }
    @IBAction func showDurationPicker(_ sender: Any) {
        timerPicker.isHidden = false
        doneButton.isHidden = false
        isFrequency = false
        timerPicker.countDownDuration = TimeInterval(breakSeconds)
    }
    
    @objc func counter(){
        if (seconds > 0){
            seconds -= 1
            let (h, m, s) =  secondsToHoursMinutesSeconds(seconds: seconds)
            timerLabel.text = "\(h)\(m)\(s)"
        } else {
            //If seconds expired – time for break!
            enterBreakTimeVC()
        }
    }
    @objc func breakTimeOver(){
        //invalidate any existing timer
        timer.isValid ? timer.invalidate() : nil
        //Starts timer again
        print("Starting timer again")
        //Updating seconds to their previous
        seconds = prevSeconds
        breakSeconds = prevBreakSeconds
        startTimerFunction()
        //Enable tracking when break's over (check first if airpods is connected)
        if (connected){
            pitchEnabled = true
        }
    }
    
    //Enter Break
    @IBAction func enterBreak(_ sender: Any) {
        seconds = 0
        enterBreakTimeVC()
    }
    func enterBreakTimeVC(){
        timerLabel.text = "Restarting Timer..." //For next timer
        //invalidate any existing timer
        timer.isValid ? timer.invalidate() : nil
        let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        guard let destinationVC = mainStoryboard.instantiateViewController(identifier: "breaktimeViewController") as? breaktimeViewController else {
            print("Couldn't find VC")
            return
        }
        destinationVC.seconds = breakSeconds
        destinationVC.onDoneBlock = { result in
            //Call breakTimeOver
            self.breakTimeOver()
        }
        destinationVC.presentationController?.delegate = self
        present(destinationVC, animated: true, completion: nil)
        //Disable tracking during break
        pitchEnabled = false
        //Play sound
        playSound("timer")
        
        //Userdefaults, save the time at which we enterred break, in case watch requests update during break
        let defaults = UserDefaults.standard
        defaults.setValue(Date(), forKey: "enterBreak")
        //Set enteredbreak = true for watch
        enteredBreak = true
        updateWatch()
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        //When break time and user swipes to dismiss, start timer again
        breakTimeOver()
    }
    func showBreakAlert() {
        let alertController = UIAlertController(title: "Break Time!", message:
                                                    "Take a break! Stretch and move around :)", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Gotcha",
                                                style: UIAlertAction.Style.default,
                                                handler: {(alert: UIAlertAction!) in notifying = false}))
        self.present(alertController, animated: true, completion: nil)
    }
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
    var motionManager: CMHeadphoneMotionManager!
    override func viewDidLoad() {
        super.viewDidLoad()
        //Hide timer elements
        timerPicker.isHidden = true
        doneButton.isHidden = true
        timeRemainingHeader.isHidden = true
        timerLabel.isHidden = true
        enterBreakButton.isHidden = true
        changeFrequencyButton.isHidden = true
        changeDurationButton.isHidden = true
        calibrateButton.isHidden = true
        disableTimerButton.isHidden = true
        
        //Prevents device from going to sleep
        UIApplication.shared.isIdleTimerDisabled = true
        
        //Notifications
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if(granted){
                print("Notification enabled")
            } else{
                let alertController = UIAlertController(title: "Notification Disabled", message:
                                                            "If you wish to receive updates when your break timer is up, please turn enable notifications in System Preferences!", preferredStyle: .alert)
                self.present(alertController, animated: true, completion: nil)
            }
        }
        
        //Airpods pro motion
        motionManager = CMHeadphoneMotionManager()
        motionManager.delegate = self
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { (motion, error) in
                if (pitchEnabled){
                    degreesPitch = (motion?.attitude.pitch)! * 180 / Double.pi
                    let printTilt = String(format: "%.2f", degreesPitch)
                    self.pitchValue.text = "\(printTilt)º"
                    if (degreesPitch < calibrateAngle-15.00 && !notifying && !tiltTimerStarted){
                        //Timer to see if user continues to tilt head forward
                        print("starting timer")
                        tiltTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(ViewController.stillTilting), userInfo: nil, repeats: false)
                        tiltTimerStarted = true
                    }
                }
            }
        }
        //When app goes to background & foreground
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        //Receive update requests from watch
        NotificationCenter.default.addObserver(self, selector: #selector(receivedWatch(info:)), name: NSNotification.Name(rawValue: "receivedWatch"), object: nil)
        
    }
    @objc func receivedWatch(info: Notification){
        let message = info.userInfo!
        if ((message["update"]) as! Bool){
            updateWatch()
        }
    }
    //Check if user's head is still tilted after 3 seconds (avoid quick glancing downs)
    @objc func stillTilting(){
        print("timer expired")
        if (degreesPitch < calibrateAngle - 15.00 && !notifying){
            print("notifying")
            notifying = true
            self.showTiltAlert()
            self.playSound("alert")
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)    //Vibrates as well
        }
        tiltTimerStarted = false
    }
    
    @objc func appMovedToBackground() {
        //Save current date
        let defaults = UserDefaults.standard
        defaults.setValue(Date(), forKey: "savedTime")
        //Notification if timer is in progress
        if (timer.isValid){
            //Notification content
            let content = UNMutableNotificationContent()
            content.title = "Break Time!"
            content.body = "Stretch, move your head around, and relax your eyes! Please come back to the app to restart timer"
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "timer.mp3"))
            
            //Trigger with timer's seconds
            let date = Date().addingTimeInterval(TimeInterval(seconds))
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            
            //Creating request
            let uuidString = UUID().uuidString
            let request = UNNotificationRequest(identifier: uuidString, content: content, trigger: trigger)
            
            //Register request
            let center = UNUserNotificationCenter.current()
            center.add(request) { (error) in
                //Check error parameter and handle errors
            }
        }
    }
    @objc func appCameToForeground() {
        if (timer.isValid){
            //if timer was started, then update time
            if let savedDate = UserDefaults.standard.object(forKey: "savedTime") as? Date {
                let (h, m, s) = getTimeDifference(startDate: savedDate)
                let elapsedSeconds = (h*60+m)*60+s
                print(elapsedSeconds)
                if (seconds > 0){
                    seconds -= elapsedSeconds
                    if (seconds < 0){
                        //If subtracting makes seconds negative, enter break time with break second = spillover
                        breakSeconds += seconds
                        seconds = 0
                        //If breakSeconds also becomes negative, just restart timer. Otherwise enter break (when seconds =0, it'll automatically enter break
                        if (breakSeconds < 0){
                            //Invalidate previous timer
                            breakTimeOver()
                        }
                    }
                }
            }
            //Also clear any pending notifications
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
        } else{
            //Clear any saved time
            UserDefaults.standard.removeObject(forKey: "savedTime")
        }
        
    }
    func getTimeDifference(startDate: Date) -> (Int, Int, Int) {
        let difference = Calendar.current.dateComponents([.hour, .minute, .second], from: startDate, to: Date())
        return (difference.hour!, difference.minute!, difference.second!)
        
    }
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        print("connect")
        connectionMessage.text = "Airpods Pro Connected"
        pitchEnabled = true
        connected = true
        calibrateButton.isHidden = false
    }
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        print("disconnect")
        connectionMessage.text = "Please connect to your Airpods Pro"
        pitchEnabled = false
        connected = false
        pitchValue.text = "N/A"
        calibrateButton.isHidden = true
    }
    //Show alert when head is tilted forward too much
    func showTiltAlert() {
        let alertController = UIAlertController(title: "Head Tilt", message:
                                                    "Keep your head up!", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Gotcha",
                                                style: UIAlertAction.Style.default,
                                                handler: {(alert: UIAlertAction!) in notifying = false}))
        self.present(alertController, animated: true, completion: nil)
    }
    func playSound(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.ambient, mode: .default, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            
            /* The following line is required for the player to work on iOS 11. Change the file type accordingly*/
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            
            /* iOS 10 and earlier require the following line:
             player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileTypeMPEGLayer3) */
            
            guard let player = player else { return }
            player.play()
            player.delegate = self
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        //When alert finishes playing, keep playing background music
        try? AVAudioSession.sharedInstance().setActive(false)
        if (self.presentedViewController != nil && notifying){
            self.dismiss(animated: true) {
                notifying = false
            }
        }
    }
    func updateWatch(){
        if (session.isPaired && session.isWatchAppInstalled && session.isReachable){
            var secondsSend = 0
            if (enteredBreak){
                let defaults = UserDefaults.standard
                let (h,m,s) = getTimeDifference(startDate: defaults.object(forKey: "enterBreak") as! Date)
                let elapsedSeconds = (h*60+m)*60+s
                secondsSend = breakSeconds - elapsedSeconds
            } else{
                if (!timer.isValid){
                    //If timer hasn't started yet
                    secondsSend = 0
                    pauseWatch = true
                } else{
                    secondsSend = seconds
                    pauseWatch = false
                }
            }
            print("sending message")
            session.sendMessage(["break" : enteredBreak ,"seconds" : secondsSend, "pause" : pauseWatch], replyHandler: nil, errorHandler: nil)
        }
    }
  
}

