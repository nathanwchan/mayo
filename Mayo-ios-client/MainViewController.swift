//
//  ViewController.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 4/8/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import GeoFire
import iCarousel
import SwiftMoment
import UserNotifications
import Alamofire
import AVKit
import AVFoundation


class MainViewController: UIViewController{

    @IBOutlet weak var carouselView: iCarousel!
    @IBOutlet weak var mapView: MKMapView!
    
    // tags and constants for subviews
    let COMPLETION_VIEW_TAG = 98
    let USERS_HELPED_BUTTON_TAG = 99
    let NO_USERS_HELPED_BUTTON_TAG = 100
    let CURRENT_USER_TEXTVIEW_TAG = 101
    let POINTS_GRADIENT_VIEW_TAG = 102
    let POINTS_GRADIENT_VIEW_LABEL_TAG = 103
    let POST_NEW_TASK_BUTTON_TAG = 104
    let POINTS_PROFILE_VIEW_TAG = 105
    
    // z index for map annotations
    let FOCUS_MAP_TASK_ANNOTATION_Z_INDEX = 5.0
    let STANDARD_MAP_TASK_ANNOTATION_Z_INDEX = 3.0
    
    // constants for onboarding tasks
    let ONBOARDING_TASK_1_DESCRIPTION = "Helping people around you is simple. Swipe the cards or look around the map."
    let ONBOARDING_TASK_2_DESCRIPTION = "So our AI is a bit bored, help us by sending a message!"
    let ONBOARDING_TASK_3_DESCRIPTION = "Need help? Swipe to the very left to setup a help quest."
    
    // onboarding constants for standard user defaults.
    let ONBOARDING_TASK1_VIEWED_KEY = "onboardingTask1Viewed"
    let ONBOARDING_TASK2_VIEWED_KEY = "onboardingTask2Viewed"
    let ONBOARDING_TASK3_VIEWED_KEY = "onboardingTask3Viewed"
    
    // save the last index for the carousel view
    var lastCardIndex: Int?
    
    // constants for time
    let SECONDS_IN_HOUR = 3600
    
    // flag to check if swiped left to add new item
    var newItemSwiped = false
    
    // chat channels
    var chatChannels: [String] = []
    
    // boolean check for if keyboard is on screen
    var keyboardOnScreen = false
    
    // query distance for getting nearby tasks and users in meters
    let queryDistance = 200.0
    
    // current user uid
    var currentUserId: String?
    
    // checks if the current user saved current task
    var currentUserTaskSaved = false
    
    // user location coordinates
    var userLatitude: CLLocationDegrees?
    var userLongitude: CLLocationDegrees?
    
    // users to thank array
    var usersToThank: [String:Bool] = [:]
    
    // firebase ref
    var ref: FIRDatabaseReference?
    
    var usersRef: FIRDatabaseReference?
    var currentUserHandle: FIRDatabaseHandle?
    
    var tasksRef:FIRDatabaseReference?
    var channelsRef: FIRDatabaseReference?
    
    var tasksRefHandle: FIRDatabaseHandle?
    var tasksCircleQueryHandle: FirebaseHandle?
    
    var tasksDeletedCircleQueryHandle: FirebaseHandle?
    var usersCircleQueryHandle: FirebaseHandle?
    
    var usersDeletedCircleQueryHandle: FirebaseHandle?
    var usersMovedCircleQueryHandle: FirebaseHandle?
    var usersExitCircleQueryHandle: FirebaseHandle?
    
    // create location manager variable
    var locationManager:CLLocationManager!

    
    // tasks array for nearby tasks
    var tasks = [Task?]()

    // geofire
    var tasksLocationsRef:FIRDatabaseReference?
    var usersLocationsRef:FIRDatabaseReference?
    var tasksGeoFire: GeoFire?
    var usersGeoFire: GeoFire?
    
    // task self destruct timer
    var expirationTimer: Timer? = nil
    var fakeUsersTimer: Timer? = nil
    var fakeUsersCreated = false
    
    
    deinit {
        // get rid of observers when denit
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
                
        // center map to user's location when map appears
        if let userCoordinate = locationManager.location?.coordinate {
            self.mapView.setCenter(userCoordinate, animated: true)
        }
        
        // create fake users when you show
        if self.fakeUsersCreated == false {
            createFakeUsers()
            self.fakeUsersCreated = true
            //setup timer for 7 mins
            Timer.scheduledTimer(withTimeInterval: 240, repeats: false, block: { (Timer) in
                
                // reset the fake users created flag
                self.fakeUsersCreated = false
                
                // invalidate the timer
                Timer.invalidate()
    
            })
            
        }
        
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // check notification id
        if let refreshedToken = FIRInstanceID.instanceID().token() {
            print("InstanceID token: \(refreshedToken)")
        }
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        // allows location manager to update location in the background
        locationManager.allowsBackgroundLocationUpdates = true
        
        // reset users to thank dictionary
        self.usersToThank = [:]
        
        // set current user id
        currentUserId = FIRAuth.auth()?.currentUser?.uid
        
        // show user's position
        mapView.showsUserLocation = true
        // turn off compass on mapview
        mapView.showsCompass = false
        
        // setup mapview delegate
        mapView.delegate = self
        
        
        // setup firebase/geofire
        ref = FIRDatabase.database().reference()
        tasksRef = ref?.child("tasks")
        channelsRef = ref?.child("channels")
        usersRef = ref?.child("users")
        tasksLocationsRef = ref?.child("tasks_locations")
        usersLocationsRef = ref?.child("users_locations")
        tasksGeoFire = GeoFire(firebaseRef: tasksLocationsRef)
        usersGeoFire = GeoFire(firebaseRef: usersLocationsRef)
        
        print(locationManager.location?.coordinate)
        
        // set region that is shown on the map
        setupLocationRegion()
        
        // get updated user location coordinates
        getCurrentUserLocation()
        
        // setup carousel view
        carouselView.type = iCarouselType.linear
        carouselView.isPagingEnabled = true
        carouselView.bounces = true
        carouselView.bounceDistance = 0.2
        
        // add gesture swipe to carousel
        // check if current card is a onboarding task by check the description by adding gesture recognizer
        
        // swipe left recognizer
        let swipeLeftRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.onboardingTaskSwiped(_:)))
        swipeLeftRecognizer.direction = .left
        swipeLeftRecognizer.delegate = self
        
        // swipe right recognizer
        let swipeRightRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(self.onboardingTaskSwiped(_:)))
        swipeRightRecognizer.direction = .right
        swipeRightRecognizer.delegate = self
        
        // add recognizers to the carousel view
        carouselView.addGestureRecognizer(swipeLeftRecognizer)
        carouselView.addGestureRecognizer(swipeRightRecognizer)
        
        
        // create task for current user
        // and also set channel for chat for current user's chat
        if (tasks.count == 0) {
            print("current user task created")
// TODO fix
           tasks.append(
            Task(userId: currentUserId!, taskDescription: "", latitude: self.userLatitude!, longitude: self.userLongitude!, completed: true, timeCreated: Date(), timeUpdated: Date())
            )
            carouselView.reloadData()
        }
        
        // if no chat channels
        // append current user's channel
        if(chatChannels.count == 0){
            print("current user chat channel appended")
            // TODO fix
            chatChannels.append(currentUserId!)
        }
    
        
        // query for tasks nearby
        if let userLatitude = self.userLatitude, let userLongitude = self.userLongitude {
            queryTasksAroundCurrentLocation(latitude: userLatitude, longitude: userLongitude)
            
            // query for users nearby
            queryUsersAroundCurrentLocation(latitude: userLatitude, longitude: userLongitude)
        }
        
        // create points uiview
        let pointsShadowGradientView = createPointsView()
        self.view.addSubview(pointsShadowGradientView)
        
        // observe for points
        observeForCurrentUserPoints()
        
        // add current user's location to geofire
        self.addCurrentUserLocationToFirebase()
    }
    
    func addCurrentUserLocationToFirebase() {
        // add current user's location to firebase/geofire
        self.getCurrentUserLocation()
        self.usersGeoFire?.setLocation( self.locationManager.location, forKey: "\(FIRAuth.auth()?.currentUser?.uid)")
    }
    
    func showUserThankedAnimation() {
        let imageHeight = CGFloat(300)
        let imageWidth = CGFloat(300 * 1.43)
        let centerX = self.view.center.x - CGFloat(imageWidth/2)
        let centerY = self.view.center.y-CGFloat(imageHeight/2) - CGFloat(80)
        let imageView = UIImageView(frame: CGRect(x: centerX, y: centerY, width: imageWidth, height: imageHeight))
        
        var imageListArray: NSMutableArray = []
        for countValue in 1...51
        {
            var imageName : String = "fux00\(countValue).png"
            var image  = UIImage(named:imageName)
            imageListArray.add(image)
        }
        
        
        imageView.animationImages = imageListArray as! [UIImage]
        imageView.animationDuration = 2.8
        self.view.addSubview(imageView)
        imageView.startAnimating()
        Timer.scheduledTimer(withTimeInterval: 2.6, repeats: false) { (Timer) in
            imageView.stopAnimating()
            imageView.removeFromSuperview()
        }
    }
    
    func observeForCurrentUserPoints() {
        // create observer for current user's points
        let currentUserId = FIRAuth.auth()?.currentUser?.uid
        self.currentUserHandle = self.usersRef?.child(currentUserId!).observe(.value, with: { (snapshot) in
            
            let value = snapshot.value as? NSDictionary
            let userPoints = value?["score"] as? Int ?? 0
            
            print("current user just got points \(userPoints)")
            
            // update the points label if they get a point
            let pointsLabel = self.view.viewWithTag(self.POINTS_GRADIENT_VIEW_LABEL_TAG) as! UILabel
            pointsLabel.text = String(userPoints)
            

        })
    }
    
    func checkIfNoPoints() {
        // TODO if the current user has no points
        // make the points gradient view invisible
        
        // if the user has points make the points gradient view visible
    }
    
    // create points view
    func createPointsView() -> UIView{
        
        // create shadow view to superview diagonal gradient
        let shadowView = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        shadowView.backgroundColor = UIColor.clear
        shadowView.center.x = self.view.bounds.maxX - 50
        shadowView.center.y = 73
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 10)
        shadowView.layer.shadowOpacity = 0.3
        shadowView.layer.shadowRadius = 15.0
        
        // create diagonal gradient to show points
        let pointsGradientView = DiagonalGradientView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        pointsGradientView.layer.cornerRadius = pointsGradientView.bounds.width/2
        //pointsGradientView.center.x = self.view.bounds.maxX - 50
        //pointsGradientView.center.y = 73
        pointsGradientView.layer.masksToBounds = true
        pointsGradientView.tag = POINTS_GRADIENT_VIEW_TAG
        
        // create points count label to hold the number of points the current user has
        let pointsLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        pointsLabel.text = "0"
        pointsLabel.font = UIFont.systemFont(ofSize: 24)
        pointsLabel.textColor = UIColor.white
        pointsLabel.textAlignment = .center
        pointsLabel.center.x = pointsGradientView.frame.size.width/2
        pointsLabel.tag = POINTS_GRADIENT_VIEW_LABEL_TAG
        
        pointsGradientView.addSubview(pointsLabel)
        shadowView.addSubview(pointsGradientView)
        
        // add gesture to show points profile view when tapped
        let pointsTapGesture = UITapGestureRecognizer(target: self, action: #selector(self.showPointsProfileView(_:)))
        shadowView.addGestureRecognizer(pointsTapGesture)
        
        return shadowView
    }
    
    func showPointsProfileView(_:UIGestureRecognizer) {
        
        // center the map on current user's location
        if let userCenterCoordinate = locationManager.location?.coordinate {
            self.mapView.setCenter(userCenterCoordinate, animated: true)
        }
        
        // show points pofile view
        let pointsProfileView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: self.view.bounds.height))
        pointsProfileView.center = self.view.center
        pointsProfileView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        pointsProfileView.tag = self.POINTS_PROFILE_VIEW_TAG
        
        // create horizontal gradient card for showing points
        let horizontalGradientView = HorizontalGradientView(frame: CGRect(x: 0, y: 0, width: 335, height: 170))
        horizontalGradientView.center.y = pointsProfileView.bounds.height/4
        horizontalGradientView.center.x = pointsProfileView.center.x
        horizontalGradientView.layer.cornerRadius = 4
        horizontalGradientView.clipsToBounds = true

        
        // create label for text
        let textLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 280, height: 50))
        textLabel.text = "Your mayo points can be exchanged for  rewards in the future so hang on to it!"
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 14)
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.numberOfLines = 2
        textLabel.center.x = pointsProfileView.bounds.width/2 - 25
        textLabel.center.y = 30
        textLabel.textColor = UIColor.white
        
        // create label for 'You have'
        let youHaveLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        youHaveLabel.font = UIFont.systemFont(ofSize: 24)
        youHaveLabel.textColor = UIColor.white
        youHaveLabel.textAlignment = .center
        youHaveLabel.text = "You have"
        youHaveLabel.center.x = pointsProfileView.bounds.width/2 - 20
        youHaveLabel.center.y = textLabel.bounds.maxY + 30
        
        // create close button
        let closeButton = UIButton(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
        let closeImage = UIImage(named: "close")
        closeButton.setImage(closeImage, for: .normal)
        closeButton.center.x = horizontalGradientView.bounds.maxX - 20
        closeButton.center.y = 25
        
        let closeGesture = UITapGestureRecognizer(target: self, action: #selector(self.removePointsProfile(_:)))
        //closeButton.addGestureRecognizer(closeGesture)
            
        // create label for score
        let scoreLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 150, height: 40))
        scoreLabel.font = UIFont.systemFont(ofSize: 24)
        scoreLabel.textColor = UIColor.white
        scoreLabel.textAlignment = .center
        // get the score from points label and set it
        let pointsGradientViewLabel = self.view.viewWithTag(POINTS_GRADIENT_VIEW_LABEL_TAG) as? UILabel
        scoreLabel.text = "\((pointsGradientViewLabel?.text)!)"
        scoreLabel.center.x = horizontalGradientView.bounds.width/2
        scoreLabel.center.y = youHaveLabel.center.y + 50
        
        // add to superview
        horizontalGradientView.addSubview(textLabel)
        horizontalGradientView.addSubview(youHaveLabel)
        horizontalGradientView.addSubview(scoreLabel)
        horizontalGradientView.addSubview(closeButton)
        horizontalGradientView.addGestureRecognizer(closeGesture)
        
        pointsProfileView.addSubview(horizontalGradientView)
        
        self.view.addSubview(pointsProfileView)
        
        
    }
    
    // remove points profile view
    func removePointsProfile(_:UITapGestureRecognizer) {
        let pointsProfileView = self.view.viewWithTag(self.POINTS_PROFILE_VIEW_TAG)
        pointsProfileView?.removeFromSuperview()
    }
    
    // creates 3 fake tasks to show on load
    func createFakeTasks() {
        
        // update user location
        self.getCurrentUserLocation()
        
        // get standard defaults to check if the current user has done the onboarding tasks
        let defaults = UserDefaults.standard
        
        // get the first bool for the onboarding task
        let boolForTask1 = defaults.bool(forKey: self.ONBOARDING_TASK1_VIEWED_KEY)
        
        // only show the first onboarding task if it hasn't been shown before
        if boolForTask1 != true {
            let task1 = Task(userId: "fakeuserid1", taskDescription: self.ONBOARDING_TASK_1_DESCRIPTION, latitude: self.userLatitude! + 0.0003, longitude: self.userLongitude! + 0.0003, completed: false)
            task1.save()
        }
        
            
        // get the second bool for the onboarding task
        let boolForTask2 = defaults.bool(forKey: self.ONBOARDING_TASK2_VIEWED_KEY)
        
        // only show if the second onboarding task if it hasn't been shown before
        if boolForTask2 != true {
            let task2 = Task(userId: "fakeuserid2", taskDescription: self.ONBOARDING_TASK_2_DESCRIPTION, latitude: self.userLatitude! + 0.0001, longitude: self.userLongitude! + 0.0001, completed: false)
            task2.save()
        }
        
        // get the third bool for the onboarding task
        let boolForTask3 = defaults.bool(forKey: self.ONBOARDING_TASK3_VIEWED_KEY)
        
        // only show if the third onboarding task if it hasn't been shown before
        if boolForTask3 != true {
            let task3 = Task(userId: "fakeuserid3", taskDescription: self.ONBOARDING_TASK_3_DESCRIPTION, latitude: self.userLatitude! + 0.0003, longitude: self.userLongitude! - 0.0003, completed: false)
            task3.save()
        }
        
        
        
    }
    
    // creates fake users nearby
    func createFakeUsers() {
        
        // get a random number from 2 to 5 for number of users
        let randomNumberOfUsers = generateRandomNumber(endingNumber: 4) + 2
        
        for _ in 1...randomNumberOfUsers {
            // call create fake users
            createFakeUser()
        }
    }
    
    // create fake user
    func createFakeUser() {
        
        // update current user's location
        self.getCurrentUserLocation()
        
        // generate random lat offet
        let randomLatOffset = generateRandomDegreesOffset()
        
        // generate random long offset
        let randomLongOffset = generateRandomDegreesOffset()
        
        // create new location coordinate
        let newLoc = CLLocationCoordinate2D(latitude: self.userLatitude! + randomLatOffset, longitude: self.userLongitude! + randomLongOffset)
        
        // annotation for user markers
        let fakePin = CustomUserMapAnnotation(userId: "")
        
        fakePin.coordinate = newLoc
        
        
        // add fake user to the map
        self.mapView.addAnnotation(fakePin)
        
        // generate random time interval from 1s to 6 mins
        let timeInterval = generateWeightedTimeInterval()
        
        // remove fake user pin from the map
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeInterval), repeats: false) { (Timer) in
            print("user deleted")
            UIView.animate(withDuration: 1, animations: {
                self.mapView.removeAnnotation(fakePin)
            })
            Timer.invalidate()
        }
    }
    
    // creates random degrees offset from .0001 to .001
    func generateRandomDegreesOffset() -> Double {
        let offset = Double(1 + generateRandomNumber(endingNumber: 10)) * 0.0001
        
        // create random number either 0 or 1
        let sign = generateRandomNumber(endingNumber: 2)
        
        // if sign is 0, return positive
        if sign == 0 {
            return offset
        } else {
            // else, if sign is 1 return negative
            return -offset
        }
    }
    
    // generate random weight interval
    func generateWeightedTimeInterval() -> Int {
        // 20% 1 min
        // 20% 2-3 min
        // 60% 4-6 min
        let weights = [1,1,1,1,2,2,3,3,4,4,4,4,5,5,5,5,6,6,6,6]
        let randomIndex = generateRandomNumber(endingNumber: 20)
        let selectedWeight = weights[randomIndex]
        
        // generate random number/seconds for time interval from 1 to 60
        let randomSeconds = 1 + generateRandomNumber(endingNumber: 60)
        
        // get the random time interval with weight and seconds
        let randomTime = randomSeconds * selectedWeight
        
        return randomTime
    }
    
    // generate random number from 0 to endingNumber
    func generateRandomNumber(endingNumber:Int) -> Int {
        
        // creates random number between 0 and endingNumber 
        // not including randomNumber
        let randomNum:UInt32 = arc4random_uniform(UInt32(endingNumber))
        return Int(randomNum)
    }
    
    
    func deleteFakeUser(_ annotation: MKAnnotation) {
        
        // removes annotation from mapview a user
        self.mapView.removeAnnotation(annotation)
        
    }

    
    // setup pins for nearby tasks
    func addMapPin(task: Task, carouselIndex: Int) {
        
        // add pin for task
        //let annotation = MKPointAnnotation()
        let annotation = CustomTaskMapAnnotation(currentCarouselIndex: carouselIndex, taskUserId: task.userId)
        annotation.coordinate = CLLocationCoordinate2D(latitude: (task.latitude), longitude: (task.longitude))
        self.mapView.addAnnotation(annotation)
        
    }
    
    

    override func viewWillAppear(_ animated: Bool) {
        // hides navigation bar for home viewcontroller
        self.navigationController?.isNavigationBarHidden = true
        subscribeToKeyboardNotifications()

    }
    override func viewWillDisappear(_ animated: Bool) {
        // show navigation bar on chat view controller
        self.navigationController?.isNavigationBarHidden = false
        unsubscribeFromAllNotifications()

    }
    
    // query users nearby
    func queryUsersAroundCurrentLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        
        // Query locations at latitude, longitutde with a radius of queryDistance
        // 200 meters = .2 for geofire units
        let center = CLLocation(latitude: latitude, longitude: longitude)
        let usersCircleQuery = usersGeoFire?.query(at: center, withRadius: queryDistance/1000)
        
        usersCircleQueryHandle = usersCircleQuery?.observe(.keyEntered, with: {
            (key: String!, location: CLLocation!) in
            print("User '\(key)' entered the search area and is at location '\(location)'")
            
            // check that the user is not current user
            if key != FIRAuth.auth()?.currentUser?.uid {
                // get data and place on map
                self.addUserPin(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, userId: key)
            }
        })
        
        // remove users circle when it leaves
        usersExitCircleQueryHandle = usersCircleQuery?.observe(.keyExited, with: { (key: String!, location: CLLocation!) in
            print("user \(key) left the area")
            
            // loop through the user annotations and remove it
            for annotation in self.mapView.annotations {
                if annotation is CustomUserMapAnnotation {
                    let customUserAnnotation = annotation as! CustomUserMapAnnotation
                    if customUserAnnotation.userId == key {
                        self.mapView.removeAnnotation(customUserAnnotation)
                        
                    }
                }
            }
            
        })
        
        // update user location when it moves
        usersMovedCircleQueryHandle = usersCircleQuery?.observe(.keyMoved, with: { (key: String!, location: CLLocation!) in
            print("user \(key) moved ")
            
            // loop through the user annotations and remove it
            for annotation in self.mapView.annotations {
                if annotation is CustomUserMapAnnotation {
                    let customUserAnnotation = annotation as! CustomUserMapAnnotation
                    if customUserAnnotation.userId == key {
                        UIView.animate(withDuration: 1, animations: {
                            customUserAnnotation.coordinate = location.coordinate
                        })
                    }
                }
            }
            
        })
        
        
    }
    
    // get tasks around current location
    func queryTasksAroundCurrentLocation(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        
        let center = CLLocation(latitude: latitude, longitude: longitude)
        
        // Query locations at latitude, longitutde with a radius of queryDistance
        // 200 meters = .2 for geofire units
        let tasksCircleQuery = tasksGeoFire?.query(at: center, withRadius: queryDistance/1000)
        
        tasksDeletedCircleQueryHandle = tasksCircleQuery?.observe(.keyExited, with: { (key: String!, location: CLLocation!) in
            
            // when a new task is deleted
            print("a new key was deleted")
            
            // remove task with that id and get its index
            for (index, task) in self.tasks.enumerated() {
                
                // if the task's id matches the key that was deleted
                // and also check that the task is not equal to current user
                if task?.userId == key && key != FIRAuth.auth()?.currentUser?.uid {
                    
                    // remove the task from the tasks array
                    self.tasks.remove(at: index)
                    
                    // remove chat channel for the task
                    self.chatChannels.remove(at: index)
                    
                    // remove that card based on its key
                    UIView.animate(withDuration: 1, animations: {
                        self.carouselView.removeItem(at: index, animated: true)
                    })
                    
                    // remove the pin for that card from the map
                    for annotation in self.mapView.annotations {
                        
                        // check if its a task map annotation or focused task map annotaiton
                        if annotation is CustomTaskMapAnnotation {
                            
                            let customAnnotation = annotation as! CustomTaskMapAnnotation
                            
                            // check if the index matches the index of the annotation
                            if customAnnotation.currentCarouselIndex == index {
                                // if it matches remove the annotaiton
                                self.mapView.removeAnnotation(customAnnotation)
                                
                                //and change the index for all the icons that are greater than it
                                self.updatePinsAfterDeletion(deletedIndex: index)
                                
                            }
                            
                            
                        }
                        
                        if annotation is CustomFocusTaskMapAnnotation {
                            let customFocusAnnotation = annotation as! CustomFocusTaskMapAnnotation
                            
                            // if the index of of annotation is equal to deleted index
                            if customFocusAnnotation.currentCarouselIndex == index {
                                // remove this annotation
                                self.mapView.removeAnnotation(customFocusAnnotation)
                                
                                //and change the index for all the icons that are greater than it
                                self.updatePinsAfterDeletion(deletedIndex: index)

                            }
                        }
                        
                        // update annotation indexes
                        self.updateMapAnnotationCardIndexes()
                        
                    }
                    
                    
                    
                }
                
            }
            
            
            
            
        })
        
        // listen for changes for when new tasks are created
        tasksCircleQueryHandle = tasksCircleQuery?.observe(.keyEntered, with: { (key: String!, location: CLLocation!) in
            print("Key '\(key)' entered the search area and is at location '\(location)'")
            
            
            let taskRef = self.tasksRef?.child(key)
            
            
            self.tasksRefHandle = taskRef?.observe(FIRDataEventType.value, with: { (snapshot) in
                
                
                let taskDict = snapshot.value as? [String : AnyObject] ?? [:]
                print("key: \(key) task dictionary: \(taskDict)")
                
                let dateformatter = DateStringFormatterHelper()
                
                // Check - don't add tasks that are older than 1 hour
                if !taskDict.isEmpty {
                    
                    // get the time created for the current task
                    let taskTimeCreated = dateformatter.convertStringToDate(datestring: taskDict["timeCreated"] as! String)
                    
                    // get current time
                    let currentTime = Date()
                    
                    // get the difference between time created and current time
                    let timeDifference = currentTime.seconds(from: taskTimeCreated)
                    print("time difference for task: \(timeDifference)")
                    
                    // if time difference is greater than 1 hour (3600 seconds)
                    // return and don't add this task to tasks
                    if timeDifference > self.SECONDS_IN_HOUR {
                        return
                    }
                }
                
                
                // Check - don't add duplicates
                
                // check task exists
                for task in self.tasks {
                    // the task is already present in the tasks
                    if task?.userId == key {
                        // return so no duplicates are added
                        return
                    }
                }

                
                // only process taskDict if not completed 
                // and not equal to own uid
                if !taskDict.isEmpty && taskDict["completed"] as! Bool == false && (key != FIRAuth.auth()?.currentUser?.uid){
                    
                    // send the current user local notification
                    // that there is a new task
                    self.sendNewTaskNotification()
                    
                    // adds key for task to chat channels array
                    self.chatChannels.append(key)
                    
                    let taskCompleted = false
                    let taskTimeCreated = dateformatter.convertStringToDate(datestring: taskDict["timeCreated"] as! String)
                    let taskTimeUpdated = dateformatter.convertStringToDate(datestring: taskDict["timeUpdated"] as! String)
                    let taskDescription = taskDict["taskDescription"] as! String
                    
                    var taskStartColor: String? = nil
                    var taskEndColor: String? = nil
                    
                    let newTask = Task(userId: key, taskDescription: taskDescription, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, completed: taskCompleted, timeCreated: taskTimeCreated, timeUpdated: taskTimeUpdated)
                    
                    // check if the task already has start and end colors saved
                    if taskDict["startColor"] != nil,  taskDict["endColor"] != nil
                    {
                        // if they have start color and end color
                        taskStartColor = taskDict["startColor"] as! String
                        taskEndColor = taskDict["endColor"] as! String
                        
                        newTask.setGradientColors(startColor: taskStartColor, endColor: taskEndColor)
                    } else {
                        // if they have nil for start and end colors
                        newTask.setGradientColors(startColor: nil, endColor: nil)
                    }
                    
                
                    self.tasks.append(newTask)
                    print("tasks: \(self.tasks)")
                    print("tasks count: \(self.tasks.count)")
                    self.carouselView.reloadData()
                    
                    // scroll to first view only if its on first card
                    if self.carouselView.currentItemIndex == 0 {
                        self.carouselView.scrollToItem(at: 1, animated: false)
                    }
                    
                    
                    // add map pin for new task
                    // add carousel index
                    let carouselIndex = self.tasks.count - 1
                    print(carouselIndex)
                    self.addMapPin(task: newTask, carouselIndex: carouselIndex)
                    
                    // CHECK update all of the map annotation indexes
                    self.updateMapAnnotationCardIndexes()
                    
                }

                
                
            })
            
        })
    }
    
    // send a local notification to user when a new task has been added
    func sendNewTaskNotification() {
        self.createLocalNotification(title: "New task nearby", body: "A new task was created nearby")
    }
    
    // after pin at the deleted index is removed, update the
    // pins and their carousel index
    func updatePinsAfterDeletion(deletedIndex: Int) {
        
        for annotation in self.mapView.annotations {
            
            // if annotation is customTaskMapAnnotation
            if annotation is CustomTaskMapAnnotation {
                let customAnnotation = annotation as! CustomTaskMapAnnotation
                if let carouselIndex = customAnnotation.currentCarouselIndex {
                    if carouselIndex > deletedIndex {
                        // if the annotation's carousel is greater than the deleted index decrease by 1
                        customAnnotation.currentCarouselIndex = customAnnotation.currentCarouselIndex! - 1
                    }
                }
                
            }
            
            // if annotation is customFocusTaskMapAnnotation
            if annotation is CustomFocusTaskMapAnnotation {
                let customFocusAnnotation = annotation as! CustomFocusTaskMapAnnotation
                if let carouselIndex = customFocusAnnotation.currentCarouselIndex {
                    if carouselIndex > deletedIndex {
                        // if the annotation's carousel is greater than the deleted index decrease by 1
                        customFocusAnnotation.currentCarouselIndex = customFocusAnnotation.currentCarouselIndex! - 1
                    }
                }
            
            }
            
        }
        
    }
    
    func addUserPin(latitude: CLLocationDegrees, longitude: CLLocationDegrees, userId: String) {
        
        // check that the pin is not the same as current user 
        if userId != FIRAuth.auth()?.currentUser?.uid {
            let userAnnotation = CustomUserMapAnnotation(userId: userId)
            userAnnotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            self.mapView.addAnnotation(userAnnotation)
        }
    }
    
    // get current user's location
    func getCurrentUserLocation() {
        print("getcurrentUserLocation hit")
        // get user location coordinates
        self.userLatitude = locationManager.location?.coordinate.latitude
        self.userLongitude = locationManager.location?.coordinate.longitude

    }
    
    
    // sets up the desplay region
    func setupLocationRegion() {
        print("setupLocationRegionHit")
        // get current location
        getCurrentUserLocation()
        
        // setup zoom level for mapview
        let span = MKCoordinateSpanMake(0.0015, 0.0015)
        
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: userLatitude!, longitude: userLongitude!), span: span)
        mapView.setRegion(region, animated: true)
        
         //setup mapview viewing angle
        let userCoordinate = CLLocationCoordinate2D(latitude: userLatitude!, longitude: userLongitude!)
        let mapCamera = MKMapCamera(lookingAtCenter: userCoordinate, fromDistance: CLLocationDistance(800), pitch: 45, heading: 0)
        mapView.setCamera(mapCamera, animated: true)


    }

   
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if segue.identifier == "mainToChatVC" {
            
            let chatViewController = segue.destination as! ChatViewController
            
            // setup display name and title of chat view controller
            chatViewController.title = "Mayo"
            //set sendername to empty string for now
            chatViewController.senderDisplayName = ""
            
            // get the current index of carousel view
            let channelIndex = self.carouselView.currentItemIndex
            
            // get colors from gradient view
            let shadowView = self.carouselView.currentItemView as! UIView
            let gradientView = shadowView.subviews[0] as! GradientView
            let startColor = gradientView.startColor
            let endColor = gradientView.endColor
            
            
            // use the index to fetch the id of the chat channel
            let chatChannelId = chatChannels[channelIndex]
            
            // pass the task description for the current task
            let currentTask = self.tasks[channelIndex] as! Task
            chatViewController.channelTopic = currentTask.taskDescription
            
            // pass chat channel id to the chat view controller
            chatViewController.channelId = chatChannelId
            
            // set channel and ref for chat view controller
            chatViewController.channelRef = channelsRef?.child(chatChannelId)
            
            print("channel list; \(self.chatChannels)")
        }
        
        
        
    }


}





// MARK: carousel view
extension MainViewController: iCarouselDelegate, iCarouselDataSource {
    func carousel(_ carousel: iCarousel, viewForItemAt index: Int, reusing view: UIView?) -> UIView {
        
        print("index hit: \(index)")
        
        
        // 1st card if user didn't swipe for new task
        if index == 0 && !self.newItemSwiped && self.tasks.count > 1 {
    
                let tempView = UIView(frame: CGRect(x: 0, y: 0, width: 335, height:212))
                tempView.backgroundColor = UIColor.white
                
                let plusView = UIImageView(frame: CGRect(x: 300, y: 91, width: 30, height: 30))
                plusView.image = #imageLiteral(resourceName: "plusIcon")
                tempView.addSubview(plusView)
                tempView.layer.cornerRadius = 4
                
            
                //tempView.layer.cornerRadius = 4
                tempView.layer.shadowColor = UIColor.black.cgColor
                tempView.layer.shadowOffset = CGSize(width: 0, height: 10)  //Here you control x and y
                tempView.layer.shadowOpacity = 0.3
                tempView.layer.shadowRadius = 15.0 //Here your control your blur
                tempView.layer.masksToBounds =  false
            
                return tempView
            
        }
        
        // if there is only 1 card and no surrounding cards
        // show the first card
        
        // 1st task if user swiped for new task or there is no other tasks
        if (index == 0 && self.newItemSwiped) || self.tasks.count <= 1 {
            // setup temporary view as gradient view
            let tempView = GradientView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width * 0.9, height:212))
            
            
            // get the first task
            let task = self.tasks[index] as! Task
            
            // if it already has start and end color, use it start and end color for the tempview
            if let taskStartColor = task.startColor, let taskEndColor = task.endColor {
                
                tempView.startColor = UIColor.hexStringToUIColor(hex: taskStartColor)
                tempView.endColor = UIColor.hexStringToUIColor(hex: taskEndColor)
                
                // if the task doesn't have a start and end color yet
                // use the start and end color to save it
            } else {
                
                let cardColor = CardColor()
                let randomColorGradient = cardColor.generateRandomColor()
                
                // save task random colors to task
                let randomStartColor = randomColorGradient[0]
                let randomEndColor = randomColorGradient[1]
                
                task.startColor = randomStartColor
                task.endColor = randomEndColor
                
                // use task's start and end color for the view
                tempView.startColor = UIColor.hexStringToUIColor(hex: randomStartColor)
                tempView.endColor = UIColor.hexStringToUIColor(hex: randomEndColor)
                
                
            }
            
            
            //setup textView for gradient viwe
            let textView = UITextView(frame: CGRect(x: 0, y: 0, width: (tempView.bounds.width*8.5/10), height: 212*3/4))
            textView.textColor = UIColor.white
            textView.contentInset = UIEdgeInsets(top: 15, left: 0, bottom: 0, right: 0)
            // turn off auto correction
            textView.autocorrectionType = .no
            
            // if current user has saved task
            // their task description
            if self.currentUserTaskSaved {
                textView.alpha = 1
                textView.text = task.taskDescription
                
                // disable editing
                textView.isEditable = false
            } else {
                
                // enable editing
                textView.isEditable = true
                
                // show placeholder
                textView.text = "What do you need help with?"
                textView.alpha = 0.5
                //textView.becomeFirstResponder()
                
            }
            
            textView.center.x = tempView.center.x
            textView.backgroundColor = UIColor.clear
            textView.textAlignment = .left
            textView.font = UIFont.systemFont(ofSize: 24)
            textView.delegate = self
            textView.tag = CURRENT_USER_TEXTVIEW_TAG
            tempView.addSubview(textView)
            
            
            // if the user has saved their task
            // rendr message button
            if currentUserTaskSaved {
                let messageView = UIButton(frame: CGRect(x: (tempView.bounds.width * 1/4), y: (tempView.bounds.height * 3/4), width: 24, height: 24))
                messageView.setImage(UIImage(named: "messageImage"), for: .normal)
                messageView.addTarget(self, action: #selector(goToChat(sender:)), for: .touchUpInside)
                
                tempView.addSubview(messageView)
                
            } else {
            // if user has not saved task
            // show close button
                let closeView = UIButton(frame: CGRect(x: (tempView.bounds.width * 1/4), y: (tempView.bounds.height * 3/4), width: 24, height: 24))
                closeView.setImage(UIImage(named: "close"), for: .normal)
                closeView.addTarget(self, action: #selector(discardCurrentUserTask(sender:)), for: .touchUpInside)
                
                // check if there are more than 1 card
                // if there is only 1 card disable the close button
                if self.tasks.count <= 1 {
                    
                    // disable the close view
                    closeView.alpha = 0.5
                    closeView.isEnabled = false
                    
                } else {
                    
                    // enable the close view
                    closeView.alpha = 1
                    closeView.isEnabled = true
                    
                }
                
                tempView.addSubview(closeView)
            }
            
            
            var doneView: UIButton?
            
            // if current user task saved
            // complete the task
            if self.currentUserTaskSaved {
                
               
                
                // add done view to finish or save the task
                doneView = UIButton(frame: CGRect(x: (tempView.bounds.width * 3/4), y: (tempView.bounds.height * 3/4), width: 24, height: 24))
                doneView?.setImage(UIImage(named: "check"), for: .normal)
                doneView?.addTarget(self, action: #selector(self.markTaskAsComplete), for: .touchUpInside)
                tempView.addSubview(doneView!)

            } else {
                
                
                // create doneview that says post
                // and allows user to post their message
                doneView = UIButton(frame: CGRect(x: (tempView.bounds.width * 3/4 - 20), y: (tempView.bounds.height * 3/4), width: 50, height: 24))
                doneView?.setTitle("Post", for: .normal)
                // disable the post button at first
                doneView?.isEnabled = false
                doneView?.tag = self.POST_NEW_TASK_BUTTON_TAG
                //change the opacity to 0.5 for the button at first
                doneView?.alpha = 0.5
                doneView?.titleLabel?.font = UIFont.systemFont(ofSize: 24)
                doneView?.addTarget(self, action: #selector(createTaskForCurrentUser(sender:)), for: .touchUpInside)
                tempView.addSubview(doneView!)
            
            }
            
            
            // add temp view to shadow view
            let shadowView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width * 0.9, height: 212))
            shadowView.backgroundColor = UIColor.clear
            shadowView.layer.shadowColor = UIColor.black.cgColor
            shadowView.layer.shadowOffset = CGSize(width: 0, height: 10)
            shadowView.layer.shadowOpacity = 0.3
            shadowView.layer.shadowRadius = 15.0
            
            shadowView.addSubview(tempView)
            
            // add instructions for "Automatically expires in 1hr or if you leave the area" at bottom label
            let bottomNoticeLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 350, height: 50))
            bottomNoticeLabel.textColor = UIColor.white
            bottomNoticeLabel.text = "Automatically expires in 1hr or if you leave the area"
            bottomNoticeLabel.textAlignment = .center
            bottomNoticeLabel.font = UIFont.systemFont(ofSize: 11)
            bottomNoticeLabel.center.x = tempView.center.x
            bottomNoticeLabel.center.y = tempView.bounds.maxY + 15
            shadowView.addSubview(bottomNoticeLabel)
            
            return shadowView
        }
        
        // if index out of bound
        if (index >= (self.tasks.count)) {
            // create invisible card
            print("clear card created")
            let tempView = UIView(frame: CGRect(x: 0, y: 0, width: 335, height:212))
            tempView.backgroundColor = UIColor.clear
            tempView.layer.masksToBounds = false
            return tempView
        } else {
            
            // STANDARD VIEW - for most cards
            
            // get the corresponding task
            let task = self.tasks[index] as! Task
            
            // setup temporary view as gradient view
            let tempView = GradientView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width * 0.9, height:212))
            let cardColor = CardColor()
            
            // if task doesn't have a  start color and end color
            // create random colors for it
            if (task.startColor == nil) || (task.endColor == nil) {
                
                // get random star and end colors
                let randomColorGradient = cardColor.generateRandomColor()
                
                // save the colors to the task
                task.setGradientColors(startColor: randomColorGradient[0], endColor: randomColorGradient[1])
                task.save()
                
                // set the color gradient colors for the card
                tempView.startColor = UIColor.hexStringToUIColor(hex: randomColorGradient[0])
                tempView.endColor = UIColor.hexStringToUIColor(hex: randomColorGradient[1])
            } else {
                
            // else
            // use the colors that are already saved for the task
                tempView.startColor = UIColor.hexStringToUIColor(hex: task.startColor!)
                tempView.endColor = UIColor.hexStringToUIColor(hex: task.endColor!)
            }
            
            // setup label for gradient view
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 212*3/4))
            label.lineBreakMode = NSLineBreakMode.byWordWrapping
            label.numberOfLines = 4
            label.text = task.taskDescription
            label.textAlignment = .left

            //label.center.x = tempView.center.x
            //label.center.y = tempView.bounds.minY + 50
            
            //align label to the left side of the card
            label.translatesAutoresizingMaskIntoConstraints = false
            // create constraints
            let horizontalConstraint = NSLayoutConstraint(item: label, attribute: .leading, relatedBy: NSLayoutRelation.equal, toItem: tempView, attribute: .leading, multiplier: 1, constant: 20)
            let verticalConstraint = NSLayoutConstraint(item: label, attribute: .top, relatedBy: NSLayoutRelation.equal, toItem: tempView, attribute: .top, multiplier: 1, constant: 20)
            let widthConstraint = NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 300)
            
            label.font = UIFont.systemFont(ofSize: 24)
            label.textColor = UIColor.white
            tempView.addSubview(label)
            // add edge constraints to the label
            tempView.addConstraints([horizontalConstraint, verticalConstraint,  widthConstraint])
            
        
            // setup clickable button for gradient view
            let messageButton = UIButton(frame: CGRect(x: 0, y: 212*3/4, width: 150, height: 20))
            messageButton.center.x = tempView.center.x
            messageButton.setTitle("I can help", for: .normal)
            let messageImage = UIImage(named: "messageImage") as UIImage?
            messageButton.setImage(messageImage, for: .normal)
            messageButton.imageView?.contentMode = .scaleAspectFit
            messageButton.setTitleColor(UIColor.darkGray, for: .highlighted)
            messageButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
            messageButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
            messageButton.addTarget(self, action: #selector(goToChat(sender:)), for: .touchUpInside)
            tempView.addSubview(messageButton)
            
            // add temp view to shadow view
            let shadowView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width * 0.9, height: 212))
            shadowView.backgroundColor = UIColor.clear
            shadowView.layer.shadowColor = UIColor.black.cgColor
            shadowView.layer.shadowOffset = CGSize(width: 0, height: 10)
            shadowView.layer.shadowOpacity = 0.3
            shadowView.layer.shadowRadius = 15.0
            
            shadowView.addSubview(tempView)
            
            // create label to show how long ago it was created
            let bottomLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
            // use Moment to get the time ago for task at current index
            let taskTimeCreated = moment((self.tasks[index]?.timeCreated)!)
            print("time ago created \(taskTimeCreated.fromNow())")
            print(self.tasks[index]?.timeCreated)
            
            // set label with time ago "x min ago"
            bottomLabel.textAlignment = .center
            bottomLabel.font = UIFont.systemFont(ofSize: 11)
            bottomLabel.center.x = tempView.center.x
            let tempViewBottom = tempView.bounds.maxY
            bottomLabel.center.y = tempViewBottom + 15
            bottomLabel.textColor = UIColor.white
            bottomLabel.text = "\(taskTimeCreated.fromNow())"
            
            // add bottom label to shadow view
            shadowView.addSubview(bottomLabel)
            
            
            
            return shadowView
        }
        
    }
    
    func onboardingTaskSwiped(_:UIGestureRecognizer) {
        // check if current card is an onboarding card
        let currentCardIndex = self.carouselView.currentItemIndex
        // if it is delete it
        self.checkAndRemoveOnboardingTasks(carousel: self.carouselView, cardIndex: currentCardIndex)
    }
    
    
    func sendNotificationToTopicOnCompletion(channelId: String, taskMessage: String) {
        
        // setup alamofire url
        let fcmURL = "https://fcm.googleapis.com/fcm/send"
        
        // add application/json and add authorization key
        let parameters: Parameters = [
            "to": "/topics/\(channelId)",
            "priority": "high",
            "notification": [
                "body": "'\(taskMessage)' was completed",
                "title": "Nearby Task Completed",
                "content_available": true,
            ],
            "data": [
                "channelId": "\(channelId)"
            ]
        ]
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "key=AAAA_PfLtDY:APA91bEJwfVWF3BNAsx86Lwt_kWpRBZt3cPV_czIbRlTGj8utDmGw8MUyHVEA3dDZmxYz5mrXkAK6zxeTMLv_-0Rcdrx_nve6pOOkaT04xBeAosqsB7Zd7IoXyMfmfW2bkcaT4CmVXGL"
        ]
        Alamofire.request(fcmURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
        print("notification posted")
        
    }
    
    
    
    
    
    // completion function for check mark
    func markTaskAsComplete(){
        
        // show the alert that completes the quest
        self.showAlertForCompletion()
    }
    
    func showAlertForCompletion() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let actionCancel = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction) in
            //This is called when the user presses the cancel button.
            print("You've pressed the cancel button")
        }
        let actionMarkAsComplete = UIAlertAction(title: "Mark quest as done", style: .default) { (action:UIAlertAction) in
            //This is called when the user presses the complete button.
            
            // reset current user's task
            self.currentUserTaskSaved = false
        
            // let users know it was completed
            let currentUserTask = self.tasks[0] as! Task
            let currentUserKey = FIRAuth.auth()?.currentUser?.uid
            let taskMessage = currentUserTask.taskDescription
            
            // unsubscribe current user from their own notification channel
            FIRMessaging.messaging().unsubscribe(fromTopic: "/topics/\(currentUserKey)")
            
            print("taskMessage \(currentUserTask.taskDescription) \(taskMessage)")
            self.sendNotificationToTopicOnCompletion(channelId: currentUserKey!, taskMessage: taskMessage)
            
            self.tasks[0] = Task(userId: currentUserKey!, taskDescription: "", latitude: (self.locationManager.location?.coordinate.latitude)!, longitude: (self.locationManager.location?.coordinate.longitude)!, completed: true)
            
            // get the channel's last messages for each user and then delete
            // the task, conversation channel, and location
            self.channelsRef?.child(currentUserKey!).observeSingleEvent(of: .value, with: { (snapshot) in
                
                // Get value for snapshot
                let value = snapshot.value as? NSDictionary
                let users = value?["users"] as? NSDictionary ?? [:]
                let messages = value?["messages"] as? NSDictionary ?? [:]
                
                print("conversation channel value: \(value)")
                print("users \(users)")
                print("messages \(messages) keys \(messages.allKeys)")
                //let username = value?["username"] as? String ?? ""
                var usersMessagesDictionary: [String:String] = [:]
                for userKey in users.allKeys{
                    
                    if let userKeyString = userKey as? String {
                        if userKeyString == currentUserKey! {
                            // if the user key is the same as the current user
                            // continue to next iteration of loop
                            continue
                        }
                        
                    // if the current userkey is not the current user
                    // use it to find the last message for this user
                    // add the user key and message to usermessages dictionary
                        for messageKey in messages.allKeys {
                            let message = messages[messageKey] as? [String: String]
                            if userKeyString == message?["senderId"] {
                                
                                // we found last message for this user,
                                // add data to users messages dictionary
                                usersMessagesDictionary[userKeyString] = message?["text"]!
                                break
                            }
                        }
                        
                    }
                    
                }
            
                
                // delete the task
                self.deleteTaskForUser(userId: currentUserKey!)
                
                // delete the task location
                self.deleteTaskLocationForUser(userId: currentUserKey!)
                
                // delete the task conversation
                self.deleteTaskConversationForUser(userId: currentUserKey!)
                
                //set textView back to editable
                let currentUserTextView = self.view.viewWithTag(self.CURRENT_USER_TEXTVIEW_TAG) as! UITextView
                currentUserTextView.isEditable = true
                
                // get start and end color from card
                let shadowView = self.carouselView.itemView(at: 0) as! UIView
                let gradientView = shadowView.subviews[0] as! GradientView
                let startColor = gradientView.startColor
                let endColor = gradientView.endColor
                
                // make carousel view invisible
                self.carouselView.isHidden = true
                
                // complete the current task
                self.newItemSwiped = false
                self.carouselView.reloadItem(at: 0, animated: false)
                
                // remove task annotation on mapview
                self.removeCurrentUserTaskAnnotation()
                
                // create shadow view for completion view
                let completionShadowView = self.createCompletionShadowView()
                
                // finish present view to select who helped you
                let completionView = self.createCompletionGradientView(startColor: startColor, endColor: endColor)
                
                // add text label to ask who helped the user
                let completionLabel = self.createCompletionViewLabel(completionView: completionView)
                
                // loop through dictionary of users helped messages
                // maximum of 5 messages
                var count = 0
                for (userKey, userMessage) in usersMessagesDictionary {
                    // loop through the dictionary and create
                    // a button with message for each of the users up to 5
                    if count < 5 {
                        //create a button view and add it to the completion view
                        let chatUserMessageButton = self.createMessageToThankUser(messageText: userMessage, completionView: completionView, tagNumber: count, userId: userKey)
                        
                        completionView.addSubview(chatUserMessageButton)
                        // update the count
                        count+=1
                    } else {
                        break
                    }
                }
                
                
                
                // add smiley face button for people who helped
                let usersHelpedButton = self.createUsersHelpedButton(completionView: completionView)
                
                // add frowney face button for no one helped
                let usersNoHelpButton = self.createUsersNoHelpButton(completionView: completionView)
                
                // add subviews to view
                completionView.addSubview(usersHelpedButton)
                completionView.addSubview(usersNoHelpButton)
                completionView.addSubview(completionLabel)
                
                // TODO add slide up animation
                completionShadowView.addSubview(completionView)
                self.view.addSubview(completionShadowView)
                
                
            }) { (error) in
                print(error.localizedDescription)
            }
            
        }
        alert.addAction(actionMarkAsComplete)
        alert.addAction(actionCancel)
        
        self.present(alert, animated: true, completion:nil)

    }
    
    func createCompletionShadowView() -> UIView {
        let completionShadowView = UIView(frame: CGRect(x: 0, y: 0, width: (self.view.bounds.width * 9/10), height: (self.view.bounds.height * 9/10)))
        completionShadowView.center = self.view.center
        completionShadowView.layer.shadowColor = UIColor.black.cgColor
        completionShadowView.layer.shadowOffset = CGSize(width: 0, height: 10)
        completionShadowView.layer.shadowOpacity = 0.3
        completionShadowView.layer.shadowRadius = 15.0
        completionShadowView.tag = self.COMPLETION_VIEW_TAG
        return completionShadowView
    }
    
    func createCompletionGradientView(startColor: UIColor, endColor: UIColor) -> UIView {
        let completionView = GradientView(frame: CGRect(x: 0, y: 0, width: (self.view.bounds.width * 9/10), height: (self.view.bounds.height * 9/10)))
        completionView.startColor = startColor
        completionView.endColor = endColor
        completionView.layer.cornerRadius = 4
        completionView.clipsToBounds = true
        return completionView
    }
    
    func createCompletionViewLabel(completionView: UIView) -> UILabel {
        let completionLabel = UILabel(frame: CGRect(x: 0, y: 0, width: completionView.bounds.width*9/10, height: completionView.bounds.height))
        completionLabel.center.x = completionView.center.x
        completionLabel.center.y = completionView.bounds.height * 1/10
        completionLabel.font = UIFont.systemFont(ofSize: 24)
        completionLabel.text = "Who helped you out? Say thanks and pay it forward."
        completionLabel.lineBreakMode = NSLineBreakMode.byWordWrapping
        completionLabel.numberOfLines = 2
        completionLabel.textColor = UIColor.white
        return completionLabel
    }
    
    func createUsersHelpedButton(completionView: UIView) -> UIButton {
        let usersHelpedButton = UIButton(frame: CGRect(x: 0, y: 0, width: completionView.bounds.width, height: 42))
        usersHelpedButton.titleLabel?.textAlignment = .center
        usersHelpedButton.setImage(UIImage(named: "smileyFace"), for: .normal)
        usersHelpedButton.isEnabled = false
        usersHelpedButton.setTitle("Thanks!", for: .normal)
        usersHelpedButton.tintColor = UIColor.white
        usersHelpedButton.center.x = completionView.center.x
        usersHelpedButton.center.y = completionView.bounds.height*8/10
        usersHelpedButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        usersHelpedButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        usersHelpedButton.tag = self.USERS_HELPED_BUTTON_TAG
        usersHelpedButton.alpha = 0.5
        usersHelpedButton.addTarget(self, action: #selector(self.handleUsersHelpedButtonPressed), for: .touchUpInside)
        return usersHelpedButton
    }
    
    func createUsersNoHelpButton(completionView: UIView) -> UIView {
        let usersNoHelpButton = UIButton(frame: CGRect(x: 0, y: 0, width: completionView.bounds.width, height: 42))
        usersNoHelpButton.setImage(UIImage(named: "frownFace"), for: .normal)
        usersNoHelpButton.titleLabel?.textAlignment = .center
        usersNoHelpButton.setTitle("No one helped me", for: .normal)
        usersNoHelpButton.tintColor = UIColor.white
        usersNoHelpButton.center.x = completionView.center.x
        usersNoHelpButton.center.y = completionView.bounds.height*9/10
        usersNoHelpButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        usersNoHelpButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        usersNoHelpButton.tag = self.NO_USERS_HELPED_BUTTON_TAG
        usersNoHelpButton.addTarget(self, action: #selector(self.handleNoOneHelpedButtonPressed), for: .touchUpInside)
        return usersNoHelpButton
    }
    
    func createMessageToThankUser(messageText: String, completionView: UIView, tagNumber: Int, userId: String) -> UIView {
        
        var messageButtonText = messageText
        // check if the message text is over 40 characters
        // if it is, cut it off and add ...
        if messageText.characters.count > 30 {
            let index = messageText.index(messageText.startIndex, offsetBy: 30)
            messageButtonText = messageText.substring(to: index)
            messageButtonText += " ..."
        }
        
        
        let chatUserMessageButton = UIButton(frame: CGRect(x: 0, y: 0, width: (completionView.bounds.width * 8/10), height: 52))
        chatUserMessageButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        chatUserMessageButton.tag = tagNumber
        chatUserMessageButton.setTitleColor(UIColor.darkGray, for: .normal)
        chatUserMessageButton.center.y = completionView.bounds.height*3/10 + CGFloat(62 * tagNumber)
        chatUserMessageButton.center.x = self.view.center.x-20
        chatUserMessageButton.setTitle(messageButtonText, for: .normal)
        chatUserMessageButton.backgroundColor = UIColor.white
        chatUserMessageButton.contentHorizontalAlignment = .left
        chatUserMessageButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        chatUserMessageButton.sizeToFit()
        chatUserMessageButton.titleLabel?.lineBreakMode = NSLineBreakMode.byWordWrapping
        chatUserMessageButton.titleLabel?.numberOfLines = 2
        chatUserMessageButton.alpha = 0.5
        
        // add user id to the button layer as data passed
        chatUserMessageButton.layer.setValue(userId, forKey: "userId")

        // TODO add target function for when the user clicks on a message button
        chatUserMessageButton.addTarget(self, action: #selector(self.handleCompletionViewChatUserMessageButtonPressed(sender:)), for: .touchUpInside)
        return chatUserMessageButton
    }

    

    // delete the task conversation
    func deleteTaskConversationForUser(userId: String) {
        self.channelsRef?.child(userId).removeValue()
    }
    
    // delete the current user's task
    func deleteTaskForUser(userId: String)  {
        self.tasksRef?.child(userId).removeValue()
    }
    
    // delete the task location
    func deleteTaskLocationForUser(userId: String) {
        self.tasksGeoFire?.removeKey(userId)
    }
    
    func deleteAndResetCurrentUserTask() {
        let currentUserKey = FIRAuth.auth()?.currentUser?.uid
        self.tasks[0] = Task(userId: currentUserKey!, taskDescription: "", latitude: (self.locationManager.location?.coordinate.latitude)!, longitude: (self.locationManager.location?.coordinate.longitude)!, completed: true)
        
        // delete the task
        self.tasksRef?.child(currentUserKey!).removeValue()
        
        // delete the task location
        self.tasksGeoFire?.removeKey(currentUserKey)
        
        // delete the task conversation
        self.channelsRef?.child(currentUserKey!).removeValue()
        
        // reset boolean flags
        
        // flag for if the current task is saved
        self.currentUserTaskSaved = false
        
        // flag for if user swiped for new task
        self.newItemSwiped = false
        
        // reload carousel view for first card
        self.carouselView.reloadItem(at: 0, animated: true)
        
        // if the user is currently viewing their own card
        if self.carouselView.currentItemIndex == 0 {
            
            // transition to first card if there is another card
            if self.tasks.count > 1 {
                self.carouselView.scrollToItem(at: 1, animated: false)
                self.newItemSwiped = false
                self.carouselView.reloadItem(at: 0, animated: true)
                
            // or else show the the swiped card
            } else {
                self.newItemSwiped = true
                self.carouselView.reloadItem(at: 0, animated: true)
            }
            
        }
        
    }
    
    // action for when users complete task
    // and some users helped
    func handleUsersHelpedButtonPressed(sender: UIButton) {
        let completionView = self.view.viewWithTag(COMPLETION_VIEW_TAG)
        
        // fade out completion view before removing
        UIView.animate(withDuration: 1, animations: {
            completionView?.alpha = 0
        }) { _ in
            
            let usersToThankCopy = self.usersToThank

            // thank the users that are in the thank users dictionary
            for userId in usersToThankCopy.keys {
                
                self.usersRef?.child(userId).observeSingleEvent(of: .value, with: { (snapshot) in
                    
                    // get the user dictionary
                    let value = snapshot.value as? NSDictionary
                    
                    // get the user's current score
                    let userScore = value?["score"] as? Int
                    
                    // get the user's current deviceToken
                    let deviceToken = value?["deviceToken"] as? String
                    
                    // increment the score
                    if userScore != nil {
                        let newScore = userScore! + 1
                        
                        // send update to the user's score
                        self.usersRef?.child(userId).child("score").setValue(newScore)
                        print("new score set")
                    }
                    
                    // send the user a notification that they were thanked
                    if deviceToken != nil {
                        self.sendYouWereThankedNotification(deviceToken: deviceToken!)
                    }

                }, withCancel: { (error) in
                    print(error.localizedDescription)
                })
                
                
            }
            
            // reset the dictionary
            self.usersToThank = [:]
            
            completionView?.removeFromSuperview()
            // toggle carouselView to visible if hidden
            if self.carouselView.isHidden == true {
                self.carouselView.isHidden = false
            }
            //scroll to first item if there is one
            if self.carouselView.itemView(at: 1) != nil {
                self.carouselView.scrollToItem(at: 1, animated: false)
            }
        }
    }
    
    // sends a notification to a user letting know that they were thanked 
    // for a task
    func sendYouWereThankedNotification(deviceToken: String) {
        
        // setup alamofire url
        let fcmURL = "https://fcm.googleapis.com/fcm/send"
        print("device token \(deviceToken.characters.count) \(deviceToken)")
        // add application/json and add authorization key
        let parameters: Parameters = [
            "to": "\(deviceToken)",
            "priority": "high",
            "notification": [
                "body": "You were thanked by a nearby user",
                "title": "You were thanked!"
            ]
        ]
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "Authorization": "key=AAAA_PfLtDY:APA91bEJwfVWF3BNAsx86Lwt_kWpRBZt3cPV_czIbRlTGj8utDmGw8MUyHVEA3dDZmxYz5mrXkAK6zxeTMLv_-0Rcdrx_nve6pOOkaT04xBeAosqsB7Zd7IoXyMfmfW2bkcaT4CmVXGL"
        ]
        Alamofire.request(fcmURL, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers).response { (response) in
            // print out error if there is one
            print("http response")
            print("device token \(deviceToken)")
            print("Request: \(response.request)")
            print("Response: \(response.response)")
            print("Error: \(response.error)")
            
        }

    }
    
    // action for when users complete task
    // and no users helped
    func handleNoOneHelpedButtonPressed(sender: UIButton) {
        let completionView = self.view.viewWithTag(COMPLETION_VIEW_TAG)
        
        
        // fade out completion view before removing
        UIView.animate(withDuration: 1, animations: {
            completionView?.alpha = 0
        }) { _ in
            
            // reset the users to thank dictionary
            self.usersToThank = [:]
            
            completionView?.removeFromSuperview()
            // toggle carouselView to visible if hidden
            if self.carouselView.isHidden == true {
                self.carouselView.isHidden = false
            }
            //scroll to first item if there is one
            if self.carouselView.itemView(at: 1) != nil {
                self.carouselView.scrollToItem(at: 1, animated: false)
            }
        }
        
    }
    
    
    // action handler for chat messages
    func handleCompletionViewChatUserMessageButtonPressed(sender: UIButton) {
        
        // get the userId from the button
        let chatUserId = sender.layer.value(forKey: "userId") as? String
        
        // toggle the alpha of sender
        if sender.alpha == 0.5 {
            sender.alpha = 1
            
            // add the chatUserId into the users to thank array
            if chatUserId != nil {
                self.usersToThank[chatUserId!] = true
            }
            
            let usersHelpedButton = self.view.viewWithTag(USERS_HELPED_BUTTON_TAG) as! UIButton
            
            // if users helped button is faded
            if usersHelpedButton.alpha == 0.5 {
                // set to full opacity
                usersHelpedButton.alpha = 1
            }
            
            // if users helped button is disabled, enable it
            if usersHelpedButton.isEnabled == false {
                usersHelpedButton.isEnabled = true
            }
            
        } else {
            sender.alpha = 0.5
            
            // remove the chatUserId from the users to thank dictionary
            if chatUserId != nil {
                self.usersToThank.removeValue(forKey: chatUserId!)
            }
            
        }
        
        
    }
    
    // MARK: new task created
    
    // action for done button item
    func createTaskForCurrentUser(sender: UIButton) {
        
        // TODO keyboard bug when user hits home button
        // create/update new task item for current user
        if self.keyboardOnScreen == true {
            UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
            //set keyboard to off screen
            self.keyboardOnScreen = false
        }
        
        // get textview
        let currentUserTextView = self.view.viewWithTag(CURRENT_USER_TEXTVIEW_TAG) as! UITextView
        
        
        if let currentUserTask = self.tasks[0] {
            // taskdescription to be textView
            currentUserTask.latitude = (locationManager.location?.coordinate.latitude)!
            currentUserTask.longitude = (locationManager.location?.coordinate.longitude)!
            currentUserTask.completed = false
            currentUserTask.taskDescription = currentUserTextView.text
            
            // save the user's current task
            currentUserTask.save()
            
            // TODO create users list for current user's conversation channel
            // and update the users list by appending the current user's id to the list
            let currentUserChannelId = FIRAuth.auth()?.currentUser?.uid
            // update the number of users in the channel
            // and update the current user to the users list
            self.channelsRef?.child(currentUserChannelId!).child("users").child(currentUserChannelId!).setValue(0)
            //self.channelsRef?.child(currentUserChannelId!).child("users_count").setValue(1)
            
            // TODO subscribe the current user to their own channel
            
            
            //add new annotation to the map for the current user's task
            let currentUserMapTaskAnnotation = CustomCurrentUserTaskAnnotation(currentCarouselIndex: 0)
            // set location for the annotation
            currentUserMapTaskAnnotation.coordinate = (locationManager.location?.coordinate)!
            self.mapView.addAnnotation(currentUserMapTaskAnnotation)
            
            // subscribe current user to their own channel when 
            // task is created
            if let channelId = FIRAuth.auth()?.currentUser?.uid
            {
                FIRMessaging.messaging().subscribe(toTopic: "/topics/\(channelId)")
            }
            
            // save current user task description to check if its
            // the same when timer is done
            let currentUserTaskDescription = currentUserTask.taskDescription
            
            // start timer to check if it has expired
            self.expirationTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(SECONDS_IN_HOUR), repeats: false) { (Timer) in
                
                // finish deleting task
                print("timer is up and user's task will be deleted")
                
                // get the current user's task
                let currentUserTask = self.tasks[0]
                
                // if the current user's task has not been completed
                // and it is the same task (don't notify expiration if its a different task)
                if currentUserTask?.completed != true && currentUserTask?.taskDescription == currentUserTaskDescription {
                    
                    // create notification that the task is out of time
                    self.createLocalNotification(title: "Your help quest expired. Still need help?", body: "Click to make a new help task")
                    
                    // reset the current user's task
                    // delete the task if it has expired
                    self.deleteAndResetCurrentUserTask()
                    
                    // remove own annotation on the map
                    self.removeCurrentUserTaskAnnotation()
                    
                }
                
                // reset expiration timer
                self.expirationTimer = nil
                
                // invalidate the current timer
                Timer.invalidate()
            }
            
            
        }
        self.currentUserTaskSaved = true
        self.carouselView.reloadItem(at: 0, animated: false)
    
        
    }
    
    // get rid of annotation when user deletes annotation
    func removeCurrentUserTaskAnnotation() {
        // loop through annotation in map view
        for annotation in self.mapView.annotations {
            // if one of them is a customCurrentUserTaskAnnotation
            if annotation is CustomCurrentUserTaskAnnotation {
                // get rid of it
                self.mapView.removeAnnotation(annotation)
            }
        }
    }
    
    // create custom notification
    func createLocalNotification(title: String, body: String?){
        
        // create content
        let content = UNMutableNotificationContent()
        content.title = title
        if let contentBody = body {
            content.body = contentBody
        }
        content.sound = UNNotificationSound.default()
        
        // create trigger
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest.init(identifier: "taskExpirationNotification", content: content, trigger: trigger)
        
        // schedule the notification
        let center = UNUserNotificationCenter.current()
        center.add(request, withCompletionHandler: { (error) in
            print(error)
        })

    }
    
   
    
    // action for close button item
    func discardCurrentUserTask(sender: UIButton) {
        
        // flip flag for new item swiped
        self.newItemSwiped = false
        
        // and scroll to index 1 task card
        if (self.carouselView.itemView(at: 1) != nil) {
            self.carouselView.scrollToItem(at: 1, animated: false)
        }
        
        // reload the first card with animation
        self.carouselView.reloadItem(at: 0, animated: true)
        
    }
    
    // action for chat to go to chat window
    func goToChat(sender: UIButton) {
        // if the keyboard is out
        // remove it
        if self.keyboardOnScreen {
            UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        
    
        self.performSegue(withIdentifier: "mainToChatVC", sender: nil)
    }
    
    // fired off when user begins dragging the carousel
    func carouselWillBeginDragging(_ carousel: iCarousel) {
  
    }
    
    // function called when carousel view scrolls
    func carouselDidScroll(_ carousel: iCarousel) {
        
        
        if(carousel.scrollOffset < 0.15 && self.newItemSwiped == false) {
            
            self.newItemSwiped = true
            UIView.animate(withDuration: 1, animations: {
                carousel.reloadItem(at: 0, animated: true)
            })
            
        }

    }
    
    // called when animation is about to start
    func carouselWillBeginScrollingAnimation(_ carousel: iCarousel) {
        
        
    }
    
    func checkAndRemoveOnboardingTasks(carousel: iCarousel, cardIndex: Int) {
        let defaults = UserDefaults.standard
        // check if one of the onboarding tasks is at the current index
        let currentTask = self.tasks[cardIndex] as! Task
        
        if currentTask.taskDescription == self.ONBOARDING_TASK_1_DESCRIPTION {
            
            // set onboarding task 1 viewed to true
            defaults.set(true, forKey: self.ONBOARDING_TASK1_VIEWED_KEY)
            self.removeOnboardingFakeTask(carousel: carousel, cardIndex: cardIndex)
            
        } else if currentTask.taskDescription == self.ONBOARDING_TASK_2_DESCRIPTION {
            
            // set onboarding task 1 viewed to true
            defaults.set(true, forKey: self.ONBOARDING_TASK2_VIEWED_KEY)
            self.removeOnboardingFakeTask(carousel: carousel, cardIndex: cardIndex)
            
        } else if currentTask.taskDescription == self.ONBOARDING_TASK_3_DESCRIPTION {
            
            // set onboarding task 1 viewed to true
            defaults.set(true, forKey: self.ONBOARDING_TASK3_VIEWED_KEY)
            self.removeOnboardingFakeTask(carousel: carousel, cardIndex: cardIndex)
            
        }
    }
    
    // remove the task if it is onboarding task
    func removeOnboardingFakeTask(carousel: iCarousel, cardIndex: Int) {
        // delete that task and card and map icon
        self.tasks.remove(at: cardIndex)
        carousel.removeItem(at: cardIndex, animated: true)
        for annotation in self.mapView.annotations {
            if annotation is CustomFocusTaskMapAnnotation  {
                let customAnnotation = annotation as! CustomFocusTaskMapAnnotation
                if customAnnotation.currentCarouselIndex == cardIndex {
                    // if its equal to the current index remove it
                    print("customAnnotation \(customAnnotation.currentCarouselIndex)")
                    self.mapView.removeAnnotation(customAnnotation)
                }
            }
            
            if annotation is CustomTaskMapAnnotation  {
                let customAnnotation = annotation as! CustomTaskMapAnnotation
                
                if customAnnotation.currentCarouselIndex == cardIndex {
                    // if its equal to the current index remove it
                    print("customAnnotation \(customAnnotation.currentCarouselIndex)")
                    self.mapView.removeAnnotation(customAnnotation)
                }
            }
        }
        
        // update the rest of the annotations
        self.updateMapAnnotationCardIndexes()
    }
    
    /// function to test map annotations error
    func testMapAnnotations() {
        // print out all the annotations and their indexes
        print("new line ------")
        for annotation in self.mapView.annotations {
            if annotation is CustomFocusTaskMapAnnotation {
                let customAnnotation = annotation as! CustomFocusTaskMapAnnotation
                print("customFocusTaskMapAnnotation \(customAnnotation.currentCarouselIndex!) \(customAnnotation.taskUserId!)")
            } else if annotation is CustomTaskMapAnnotation {
                let customAnnotation = annotation as! CustomTaskMapAnnotation
                print("customTaskMapAnnotation \(customAnnotation.currentCarouselIndex!) \(customAnnotation.taskUserId!)")
            } else if annotation is CustomCurrentUserTaskAnnotation {
                let customAnnotation = annotation as! CustomCurrentUserTaskAnnotation
                print("customCurrentUserTaskAnnotation \(customAnnotation.currentCarouselIndex!)")
                
            }
            
            
        }
        // print out the current carousel index
        print(self.carouselView.currentItemIndex)
        //print out the tasks in tasks array and their associated index and user id
        for (index, task) in self.tasks.enumerated() {
            print("Item \(index): \(task?.userId)")
        }
        
    }
    
    // update map annotations after the tasks/indexes are changed
    func updateMapAnnotationCardIndexes() {
        // loop through each annotation and check if they are task or focus task annotations
        for annotation in self.mapView.annotations {
            
            if annotation is CustomTaskMapAnnotation {
                
                // loops through the tasks array and find the corresponding task
                let customAnnotation = annotation as! CustomTaskMapAnnotation
                
                for (index, task) in self.tasks.enumerated() {
                    
                    // check if the task has the same id as the annotation
                    if let taskUserId = customAnnotation.taskUserId {
                        if taskUserId == task?.userId {
                        
                            // if they match update the annotation with the correct index
                            customAnnotation.currentCarouselIndex = index
                            break
                        }
                    }
                    
                }

                
            } else if annotation is CustomFocusTaskMapAnnotation {
                
                // loops through the tasks array and find the corresponding task
                let customAnnotation = annotation as! CustomFocusTaskMapAnnotation
                
                for (index, task) in self.tasks.enumerated() {
                    
                    // check if the task has the same id as the annotation
                    if let taskUserId = customAnnotation.taskUserId{
                        if taskUserId == task?.userId {
                            
                            // if they match update the annotation with the correct index
                            customAnnotation.currentCarouselIndex = index
                            break
                        }
                    }
                    
                }

                
            }
            
        }
        
        
    }
   
    
    // change the center of the map based on the currently selected task
    func carouselCurrentItemIndexDidChange(_ carousel: iCarousel) {
        
        // test for bugs for map annotations
        testMapAnnotations()
        
        self.updateMapAnnotationCardIndexes()
        
        // use the last item index (it gets updated at the end of the method)
        // and check if the last card is an onboarding task
        //if let lastCardIndex = self.lastCardIndex, lastCardIndex != carousel.currentItemIndex {
        //    self.checkAndRemoveOnboardingTasks(carousel: carousel, lastCardIndex: lastCardIndex)
        //}
        
        // loop through the annotations currently on the map
        let annotations = self.mapView.annotations
        for annotation in annotations {
            
            // check if the annotation is a custom current user task annotation
            if annotation is CustomCurrentUserTaskAnnotation{
                // remove and add it back on
                
                // reload annotation
                let annotationClone = annotation
                self.mapView.removeAnnotation(annotation)
                self.mapView.addAnnotation(annotationClone)
                
            }
            
            // check for the annotation for current card
            if annotation is CustomTaskMapAnnotation  {
                let mapTaskAnnotation = annotation as! CustomTaskMapAnnotation
                if mapTaskAnnotation.currentCarouselIndex == self.carouselView.currentItemIndex {
                    // once the right annotation is found
                
                    // add the annotation with a different class
                    // create new focus annotation class for the current map icon
                    let index = self.carouselView.currentItemIndex
                    
                    // get user id for the task
                    let taskUserId = (mapTaskAnnotation.taskUserId != nil) ? mapTaskAnnotation.taskUserId! : ""
                    
                    let focusAnnotation = CustomFocusTaskMapAnnotation(currentCarouselIndex: index, taskUserId: taskUserId)
                    focusAnnotation.coordinate = mapTaskAnnotation.coordinate
                    self.mapView.addAnnotation(focusAnnotation)
                    let focusAnnotationView = self.mapView.view(for: focusAnnotation)
                    
                    // remove the annotation from the map
                    self.mapView.removeAnnotation(mapTaskAnnotation)
                }
            }
            
            if annotation is CustomFocusTaskMapAnnotation {
                let customFocusTaskAnnotation = annotation as! CustomFocusTaskMapAnnotation
                // get the current index
                let index = self.carouselView.currentItemIndex
                
                // get the user id from the annotation
                let taskUserId = (customFocusTaskAnnotation.taskUserId != nil) ? customFocusTaskAnnotation.taskUserId! : ""

                // add regular task icon
                let taskAnnoation = CustomTaskMapAnnotation(currentCarouselIndex: index, taskUserId: taskUserId)
                taskAnnoation.coordinate = customFocusTaskAnnotation.coordinate
                self.mapView.addAnnotation(taskAnnoation)
                
                // remove focus task icon
                self.mapView.removeAnnotation(customFocusTaskAnnotation)
            }
            
        }
        
        let taskIndex = carouselView.currentItemIndex
        
        if taskIndex >= 0 {
            if let task = tasks[taskIndex] {
                
                let taskLat = task.latitude
                let taskLong = task.longitude
                let taskCoordinate = CLLocationCoordinate2D(latitude: taskLat, longitude: taskLong)
                self.mapView.setCenter(taskCoordinate, animated: true)
                print("map center changed to lat:\(task.latitude) long:\(task.longitude)")
            }
        }
        
        // update the last carousel card index
        //self.lastCardIndex = carousel.currentItemIndex
        
        
        
        
//        if taskIndex >= 1 {
//            if self.keyboardOnScreen == true {
//                self.keyboardOnScreen = false
//                UIApplication.shared.sendAction(#selector(UIApplication.resignFirstResponder), to: nil, from: nil, for: nil)
//            }
//            
//        }
        
        
        
    }
    func carousel(_ carousel: iCarousel, valueFor option: iCarouselOption, withDefault value: CGFloat) -> CGFloat {
        if option == iCarouselOption.spacing {
            return value * 1.03
        }
        return value
    }
    func numberOfItems(in carousel: iCarousel) -> Int {
        return tasks.count
    }
    
}




// MARK: - MainViewController (Notifications)

extension MainViewController {
    
    func subscribeToKeyboardNotifications() {
        subscribeToNotification(.UIKeyboardWillShow, selector: #selector(keyboardWillShow))
        subscribeToNotification(.UIKeyboardWillHide, selector: #selector(keyboardWillHide))
        subscribeToNotification(.UIKeyboardDidShow, selector: #selector(keyboardDidShow))
        subscribeToNotification(.UIKeyboardDidHide, selector: #selector(keyboardDidHide))
    }
    
    func subscribeToNotification(_ name: NSNotification.Name, selector: Selector) {
        NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
    }
    
    func unsubscribeFromAllNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
}


