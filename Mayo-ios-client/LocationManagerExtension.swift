//
//  LocationManagerExtension.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 5/25/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import CoreLocation

extension MainViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // if the user moves
        let newLocation = locations.last
        
        // check location is working
        //print("current user location \(newLocation)")
        
        
        // check if he/she has a task that is currently active
        let currentUserTask = self.tasks[0]
        
        if currentUserTask?.completed == false {
            
            
            // if they have a task active, check the distance to the task
            let distanceToOwnTask = newLocation?.distance(from: CLLocation(latitude: currentUserTask!.latitude, longitude: currentUserTask!.longitude))
            
            // if the location is greater than queryDistance(200 m)
            if distanceToOwnTask! >  self.queryDistance {
                
                // then notify user that their task is has deleted
                self.createLocalNotification(title: "You’re out of range so the quest ended :(", body: "Post again if you still need help.")
                
                // delete the task
                self.deleteAndResetCurrentUserTask()
                
                // remove own annotation from mapview
                self.removeCurrentUserTaskAnnotation()
                
                // invalidate the timer for expiration
                if self.expirationTimer != nil {
                    self.expirationTimer?.invalidate()
                    self.expirationTimer = nil
                }
                
            }
            
        }
        
    }
}
