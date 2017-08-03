//
//  OnboardingNotifcationsViewController.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 4/16/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import UserNotifications
import Firebase
import AVKit
import AVFoundation

class OnboardingNotifcationsViewController: UIViewController {
    
    let NOTIFICATION_VIEW_TAG = 1000

    var isGrantedNotificationAccess = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        playVideo()

        // Do any additional setup after loading the view.
    }
    
    private func playVideo() {
        
        if let path = Bundle.main.path(forResource: "fux02", ofType: "mp4") {
            
            let player = AVPlayer(url: URL(fileURLWithPath: path))
            let playerController = AVPlayerViewController()
            
            playerController.player = player
            playerController.showsPlaybackControls = false
            
            self.addChildViewController(playerController)
            self.view.addSubview(playerController.view)
            playerController.view.frame = self.view.frame
            
            player.play()
        } else {
            print("error, fux video not found")
        }
        
        
    }

    
    func registerForPushNotifications(application: UIApplication) {
       // let notificationSettings = UIUserNotificationSettings(
          //  forTypes: [.Badge, .Sound, .Alert], categories: nil)
        //application.registerUserNotificationSettings(notificationSettings)
    }

   
    @IBAction func notificationTap(_ sender: Any) {

        checkNotificationAuth()
        
        if self.isGrantedNotificationAccess {
            self.performSegue(withIdentifier: "segueToLocationsOnboarding", sender: nil)
        }
        
    }
    
    func checkNotificationAuth() -> Void {
        if !isGrantedNotificationAccess {
            
            if #available(iOS 10.0, *){
                
                
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound], completionHandler: { (granted, error) in
                    self.isGrantedNotificationAccess = granted
                    
                    if granted {
                        self.performSegue(withIdentifier: "segueToLocationsOnboarding", sender: nil)
                        
                    } else {
                        // user didn't give authorization
                        print("user didn't give notification authorization")
                    }
                })
                
                

            
            } else {
                
                // TODO: double check
                let settings: UIUserNotificationSettings =
                    UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
                UIApplication.shared.registerUserNotificationSettings(settings)
                self.performSegue(withIdentifier: "segueToLocationsOnboarding", sender: nil)
                
            }
            
            UIApplication.shared.registerForRemoteNotifications()
            
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension OnboardingNotifcationsViewController: UNUserNotificationCenterDelegate {
    

    // shows notifications when app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
  
       
        let currentViewController = getCurrentViewController()
        let notificationTitle = notification.request.content.title
        
        // TODO: if current view controller is not nil
        if let viewController = currentViewController {
            
            // if the current user is in main view controller
            // and the user was thanked, show the you were thanked animation
            if viewController is MainViewController && notificationTitle == "You were thanked!" {
                let mainViewController = viewController as! MainViewController
                mainViewController.showUserThankedAnimation()
            }
            
            //if current view controller is in a chat view controller
            if viewController is ChatViewController {
                //if the current chat view controller is the same id as the current notification's id
                // don't show the notification
                
                // get data from notification for the channel id that the notification was sent from
                if let channelId = notification.request.content.userInfo["channelId"] {
                    let chatViewController = viewController as! ChatViewController
                    let channelIdString = channelId as! String
                    
                    // if current user is in the same channel as where the notification was sent from
                    if let chatChannelId = chatViewController.channelId {
                        
                        // don't send a message
                        if channelIdString == chatChannelId {
                            return
                        } else {
                        // if current user is in a different channel than where the notification was sent from
                        // send a system notification to the other channel
                            completionHandler([.alert, .badge, .sound])
                            return
                        
                        }
                    }
                    
                }
                
            }
            else {
                
                // if the user is on the home screen
                // always show the system notification and bring the user to the correct task based on the notification
                completionHandler([.alert, .badge, .sound])
            
            }
            
        }
        
    }
    
    // custom notfications function if needed in the future
    func checkNotificationOnHomeScreenAndShowCustomNotification(notificationTitle: String, viewController: UIViewController) {
        
        // if the notification is one of the left hand side
        // message notifications, show that with the left notification
        
        if notificationTitle == "New message posted in your quest" || notificationTitle == "New Message Posted" {
            
            // if title is new message posted, add gesture recognizer
            // to take user to the right chat
            if notificationTitle == "New Message Posted" {
                // add gesture recognizer to go to the specific chat channel TODO
                self.createLeftCornerNotification(viewController: viewController, message: notificationTitle)
            } else {
                // otherwise take the user to their own chat channel
                // create left side notification
                self.createLeftCornerNotification(viewController: viewController, message: notificationTitle)
                
            }
            
            // else show the center notification
        } else {
            
            // create center notification
            self.createCenterNotification(viewController: viewController, message: notificationTitle, hasCloseButton: true)
            
            
        }

    }
    
    // notification that shows up on the left side of the screen
    func createLeftCornerNotification(viewController: UIViewController, message: String){
        
        // create shadow view for notification
        
        // create notification view and setup info
        let notificationView = HorizontalGradientView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        notificationView.tag = NOTIFICATION_VIEW_TAG
        notificationView.center.x = 150
        notificationView.center.y = viewController.view.bounds.height * 1/10
        notificationView.backgroundColor = UIColor.clear
        notificationView.layer.shadowColor = UIColor.black.cgColor
        notificationView.layer.shadowOffset = CGSize(width: 0, height: 10)
        notificationView.layer.shadowOpacity = 0.3
        notificationView.layer.shadowRadius = 15.0
        
        let notificationMessageImage = UIImage(named: "messageImage")
        let notificationMessageImageView = UIImageView(image: notificationMessageImage)
        notificationMessageImageView.center.x = 51
        notificationMessageImageView.center.y = notificationView.bounds.height / 2
        notificationView.addSubview(notificationMessageImageView)
        
        let notificationLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 20))
        notificationLabel.text = message //"New message for you"
        notificationLabel.center.x = notificationMessageImageView.center.x + 122
        notificationLabel.textColor = UIColor.white
        notificationLabel.center.y = notificationView.bounds.height / 2
        notificationView.addSubview(notificationLabel)
        
        // notification arrow
        let notificationArrow = UIImage(named: "notificationArrow")
        let notificationArrowImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 9, height: 13))
        notificationArrowImageView.image = notificationArrow
        notificationArrowImageView.center.x = 14.5
        notificationArrowImageView.center.y = notificationView.bounds.height / 2
        notificationView.addSubview(notificationArrowImageView)
        
        // add touch gesture recognizer for views
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.goToOwnChat(_:)))
        notificationView.addGestureRecognizer(gestureRecognizer)
        
        // add view
        viewController.view.addSubview(notificationView)

    }
    
    // create notifications that show up on the center of the screen.
    func createCenterNotification(viewController: UIViewController, message: String, hasCloseButton: Bool) {
        
        // create notification view and setup info
        let notificationView = HorizontalGradientView(frame: CGRect(x: 0, y: 0, width: 335, height: 60))
        notificationView.tag = NOTIFICATION_VIEW_TAG
        notificationView.layer.cornerRadius = 4
        notificationView.center.x = viewController.view.center.x
        notificationView.center.y = viewController.view.bounds.height * 1/10
        notificationView.backgroundColor = UIColor.clear
        notificationView.layer.shadowColor = UIColor.black.cgColor
        notificationView.layer.shadowOffset = CGSize(width: 0, height: 10)
        notificationView.layer.shadowOpacity = 0.3
        notificationView.layer.shadowRadius = 15.0
        
        let notificationLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 20))
        notificationLabel.text = message //"New message for you"
        notificationLabel.font = UIFont.systemFont(ofSize: 14)
        notificationLabel.center.x = notificationView.center.x - 20
        notificationLabel.textColor = UIColor.white
        notificationLabel.center.y = notificationView.bounds.height / 2
        notificationView.addSubview(notificationLabel)
        
        // if there is a close button, show the close
        if hasCloseButton {
            
            // notification close button
            let notificationCloseButton = UIImage(named: "close")
            let notificationCloseImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 11, height: 11))
            notificationCloseImageView.image = notificationCloseButton
            notificationCloseImageView.center.x = notificationView.bounds.maxX-20
            notificationCloseImageView.center.y = notificationView.bounds.height / 2
            notificationView.addSubview(notificationCloseImageView)
            
        }
        
        // add touch gesture recognizer for views
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.closeNotification(_:)))
        notificationView.addGestureRecognizer(gestureRecognizer)
        
       
        
        // add notification to the view
        viewController.view.addSubview(notificationView)

        
    }

    
    
    // close notification handler
    func closeNotification(_ sender: UITapGestureRecognizer) {
        
        print("close notification clicked")
        
        // find notification view then delete it
        let currentViewController = self.getCurrentViewController()
        if let notificationView = currentViewController?.view.viewWithTag(NOTIFICATION_VIEW_TAG) {
            notificationView.removeFromSuperview()
        }
    }
    
    // go to own chat view for notification
    func goToOwnChat(_ sender: UITapGestureRecognizer) {
        
        // remove notification
        self.closeNotification(sender)
        
        
        // call goToChatForNotification with own uid
        goToChatForNotification(sender, channelId: (FIRAuth.auth()?.currentUser?.uid)!)

    }
    
    // go to chat view for notified chat
    func goToChatForNotification(_ sender: UITapGestureRecognizer, channelId: String) {
        
        // remove the notification from the view
        let currentViewController = self.getCurrentViewController()
        if let notificationView = currentViewController?.view.viewWithTag(NOTIFICATION_VIEW_TAG) {
            notificationView.removeFromSuperview()
        }
        
        // go to the chat view for notified chat
        if let navController = self.getNavigationController() {
            
            // create the chat view controller
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let chatViewController = storyboard.instantiateViewController(withIdentifier: "chatViewController") as! ChatViewController
            
            // setup channel ref and pass it to chatViewController
            // get main reference
            let ref = FIRDatabase.database().reference().child("channels")
            
            // get reference to the chat channel
            let chatChannelRef = ref.child(channelId)
            
            chatViewController.channelRef = chatChannelRef
            navController.pushViewController(chatViewController, animated: true)
            
        }
        
        print("gesture view tapped")
    }
    
    // Returns the most recently presented UIViewController (visible)
    func getCurrentViewController() -> UIViewController? {
        
        // If the root view is a navigation controller, we can just return the visible ViewController
        if let navigationController = getNavigationController() {
            
            return navigationController.visibleViewController
        }
        
        // Otherwise, we must get the root UIViewController and iterate through presented views
        if let rootController = UIApplication.shared.keyWindow?.rootViewController {
            
            var currentController: UIViewController! = rootController
            
            // Each ViewController keeps track of the view it has presented, so we
            // can move from the head to the tail, which will always be the current view
            while( currentController.presentedViewController != nil ) {
                
                currentController = currentController.presentedViewController
            }
            return currentController
        }
        return nil
    }
    
    // Returns the navigation controller if it exists
    func getNavigationController() -> UINavigationController? {
        
        if let navigationController = UIApplication.shared.keyWindow?.rootViewController  {
            
            return navigationController as? UINavigationController
        }
        return nil
    }
    


}
extension OnboardingNotifcationsViewController: FIRMessagingDelegate {
    func applicationReceivedRemoteMessage(_ remoteMessage: FIRMessagingRemoteMessage) {
        
        print("hit firebase received remote message")
    }
}

extension OnboardingNotifcationsViewController: AVPlayerViewControllerDelegate {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let location = touch.location(in: self.view)
        
        if location.y > (self.view.bounds.height * 3/4) {
            // ask for access to notifications
            // go to the next screen
             print("2nd video pressed")
            
            checkNotificationAuth()
            
            if self.isGrantedNotificationAccess {
                self.performSegue(withIdentifier: "segueToLocationsOnboarding", sender: nil)
            }
        }
        
        
    }
}
