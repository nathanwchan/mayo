//
//  OnboardingVideoViewController.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 4/16/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class OnboardingVideoViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        playVideo()
    }

    private func playVideo() {
        
        if let path = Bundle.main.path(forResource: "fux01", ofType: "mp4") {
           
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
    
    


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension OnboardingVideoViewController: AVPlayerViewControllerDelegate {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let location = touch.location(in: self.view)
        print("video pressed")
        
        if location.y > (self.view.bounds.height * 3/4) {
            // go to the next screen
            self.performSegue(withIdentifier: "segueToNotificationsOnboarding", sender: nil)
        }
        
        
    }
}

extension OnboardingVideoViewController: UIGestureRecognizerDelegate {

}
