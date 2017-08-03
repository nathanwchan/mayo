//
//  CustomFocusTaskMapAnnotation.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 4/25/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import MapKit

class CustomFocusTaskMapAnnotation: MKPointAnnotation {
    var currentCarouselIndex: Int?
    var taskUserId: String?
    
    init(currentCarouselIndex: Int, taskUserId: String ) {
        self.currentCarouselIndex = currentCarouselIndex
        self.taskUserId = taskUserId
    }
}
