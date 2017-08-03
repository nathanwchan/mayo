//
//  AppDelegate.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 4/8/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation
import UserNotifications


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var ref: FIRDatabaseReference!
    

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        

        // setup firebase
        FIRApp.configure()
        
        // log in user annonymously
        FIRAuth.auth()?.signInAnonymously() { (user, error) in
            
            if error != nil {
                print("an error occured during auth")
            }
            
            // user is signed in
            let uid = user!.uid
            let defaults = UserDefaults.standard
            defaults.setValue(uid, forKey: "currentUserId")
            print("userid: \(uid)")
            
            self.ref = FIRDatabase.database().reference()

            self.ref.child("users/\(uid)").observeSingleEvent(of: .value, with: { (snapshot) in
                
                // check if the current user has a score set
                if snapshot.hasChild("score"){
                    let value = snapshot.value as? NSDictionary
                    let score = value?["score"] as? Int //?? 0
                    print("user already has a score of \(String(describing: score)))")
                    
                    // if current user does not have a score set
                } else {
                    // set score to 0
                    print("user does not have points yet")
                    self.ref.child("users/\(uid)/score").setValue(0)
                    print("user score is set to 0")
                    
                }
            })
            
            

            
        }
        
        // check if user has gone through the onboarding
        // and that the user has given access to
        // notifications and location
        let userDefaults = UserDefaults.standard
        let onboardingHasBeenShown = userDefaults.bool(forKey: "onboardingHasBeenShown")
        
        if onboardingHasBeenShown {
            // if the user has given access to all of the authorizations
            // present main
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let MainViewController = storyboard.instantiateViewController(withIdentifier: "MainViewController") as! MainViewController
            let navViewController = UINavigationController(rootViewController:MainViewController)
            self.window?.rootViewController = navViewController
            
        } else {
            // else present authorization
            
            
        }
        
        // setup delegates for messaging
        
        // For iOS 10 data message (sent via FCM)
        FIRMessaging.messaging().remoteMessageDelegate = OnboardingNotifcationsViewController()
        UNUserNotificationCenter.current().delegate = OnboardingNotifcationsViewController()
        
        // try notfications
//        let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
//        application.registerUserNotificationSettings(settings)
//        application.registerForRemoteNotifications()

        
        return true
    }


    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        
        // hide keyboard if its on the screen
        self.window?.endEditing(true)
        
        // disconnect from firebase messaging.
        FIRMessaging.messaging().disconnect()
        print("Disconnected from FCM.")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        FIRMessaging.messaging().appDidReceiveMessage(userInfo)
        
        if let aps = userInfo["aps"] as? NSDictionary {
            
            if let alert = aps["alert"] as? NSDictionary {
                if let title = alert["title"] as? String {
                    if title == "Nearby Task Completed" {
                        print("title: \(title)")
                        if let channelId = userInfo["channelId"] {
                            print("channelId: \(channelId)")
                            FIRMessaging.messaging().unsubscribe(fromTopic: "/topics/\(channelId)")
                        }
                    }
                }
            }
            
            
        }

        
        print("received message in delegate")
        
        print("received notification \(userInfo)")
        
        
        //completionHandler(UIBackgroundFetchResult.newData)
    }
    
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        // send device token to firebase messages server
        FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: FIRInstanceIDAPNSTokenType.sandbox)
       
        //FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: FIRInstanceIDAPNSTokenType.prod)
        
        #if PROD_BUILD
            FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: .prod)
        #else
            FIRInstanceID.instanceID().setAPNSToken(deviceToken, type: .sandbox)
        #endif
        
        var readableToken: String = ""
        for i in 0..<deviceToken.count {
            readableToken += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
        }
        print("Received an APNs device token: \(readableToken)")
        
        // update the user notification token for current user
        updateNotificationTokenForCurrentUser()
        
    }
    
    func updateNotificationTokenForCurrentUser() {
        
        if let refreshedToken = FIRInstanceID.instanceID().token() {
            
            print("InstanceID token: \(refreshedToken)")
            
            // get references to save user token
            ref = FIRDatabase.database().reference()
            
            if let userId = FIRAuth.auth()?.currentUser?.uid {
                
                // save device token for push notifications
                ref.child("users/\(userId)/deviceToken").setValue(refreshedToken)
                
            }
            
        }
        
    }
    
    func tokenRefreshNotification(_ notification: Notification) {
        
        // update the notification token for the current user
        updateNotificationTokenForCurrentUser()
        
        // Connect to FCM since connection may have failed when attempted before having a token.
        connectToFcm()
    }
    
    func connectToFcm() {
        // Won't connect since there is no token
        guard FIRInstanceID.instanceID().token() != nil else {
            return
        }
        
        // Disconnect previous FCM connection if it exists.
        FIRMessaging.messaging().disconnect()
        
        FIRMessaging.messaging().connect { (error) in
            if error != nil {
                print("Unable to connect with FCM. \(error?.localizedDescription ?? "")")
            } else {
                print("Connected to FCM.")
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
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
