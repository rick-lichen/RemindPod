//
//  breaktimeViewController.swift
//  M1-AirPodOSC
//
//  Created by Rick Liu on 12/25/20.
//

import UIKit

class breaktimeViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    
    var seconds = 0
    @IBOutlet weak var breakSecondsLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        let (h, m, s) = secondsToHoursMinutesSeconds(seconds: seconds)
        breakSecondsLabel.text = "\(h)\(m)\(s)"
        startTimerFunction()
        //When app goes to background & foreground
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    func startTimerFunction(){
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.counter), userInfo: nil, repeats: true)
    }
    @objc func counter(){
        seconds -= 1
        let (h, m, s) = secondsToHoursMinutesSeconds(seconds: seconds)
        breakSecondsLabel.text = "\(h)\(m)\(s)"
        if (seconds <= 0){
            timer.invalidate()
            //Segue back
            onDoneBlock!(true)
            dismiss(animated: true) {
                print("back to main")
            }
        }
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
    //For when break is done, main view controller can then call breaktime over
    var onDoneBlock : ((Bool) -> Void)?
    
    @objc func appMovedToBackground(){
        let defaults = UserDefaults.standard
        defaults.setValue(Date(), forKey: "savedTime")
        
    }
    @objc func appCameToForeground(){
        if (timer.isValid){
            //if timer was started, then update time
            if let savedDate = UserDefaults.standard.object(forKey: "savedTime") as? Date {
                let (h, m, s) = getTimeDifference(startDate: savedDate)
                let elapsedSeconds = (h*60+m)*60+s
                if (seconds > 0){
                    seconds -= elapsedSeconds
                    if (seconds < 0){
                        //If subtracting makes seconds negative, done with break and when user enters app, it should restart timer on its own
                        timer.invalidate()
                        //Segue back
                        onDoneBlock!(true)
                        dismiss(animated: true) {
                            print("back to main")
                        }
                    }
                }
            }
        } else{
            //Clear any saved time
            UserDefaults.standard.removeObject(forKey: "savedTime")
        }
        
    }
    func getTimeDifference(startDate: Date) -> (Int, Int, Int) {
        let difference = Calendar.current.dateComponents([.hour, .minute, .second], from: startDate, to: Date())
        return (difference.hour!, difference.minute!, difference.second!)
        
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}
