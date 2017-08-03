//
//  OnboardingLocationsViewController.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 4/16/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import CoreLocation
import AVKit
import AVFoundation


class OnboardingLocationsViewController: UIViewController, CLLocationManagerDelegate {
    
    var locationManager: CLLocationManager?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup and instantiate the location manageer
        locationManager = CLLocationManager()
        
        playVideo()

    }
    
    private func playVideo() {
        
        if let path = Bundle.main.path(forResource: "fux03", ofType: "mp4") {
            
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

    
    // check if location is authorized
    func checkForAuthorization() {
        
        if CLLocationManager.locationServicesEnabled() {
            switch(CLLocationManager.authorizationStatus()) {
                case .notDetermined, .restricted, .denied:
                    print("No access")
                case .authorizedAlways, .authorizedWhenInUse:
                // if location authorized
                // go to main viewcontroller
                    print("Access")
                    let MainViewController = self.storyboard?.instantiateViewController(withIdentifier: "MainViewController") as! MainViewController
                    let navViewController = UINavigationController(rootViewController:MainViewController)
                    self.present(navViewController, animated: true, completion: nil)
                
                    // set onboarding has been shown to true
                    // inside user defaults
                    let userDefaults = UserDefaults.standard
                    userDefaults.set(true, forKey: "onboardingHasBeenShown")

            }
        } else {
            print("Location services are not enabled")
        }
    }
    
    func askForLocationAuth() {
        // get location authorization
        // display user location
        print("askForLocationAuth hit")
        
        if CLLocationManager.locationServicesEnabled() {
            
            // if location services are enables, ask for 
            // access to location
            locationManager?.requestAlwaysAuthorization()
            locationManager?.requestWhenInUseAuthorization()
            locationManager?.delegate = self
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            locationManager?.startUpdatingLocation()
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

extension OnboardingLocationsViewController: AVPlayerViewControllerDelegate {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let location = touch.location(in: self.view)
        
        if location.y > (self.view.bounds.height * 3/4) {
            // ask for access to notifications
            // go to the next screen
            print("3rd video pressed")
            
            // first ask for location authorization
            askForLocationAuth()
            
            // check if location authorized
            // if authorized, go to main view controller
            checkForAuthorization()
        }
        
        
    }
}


