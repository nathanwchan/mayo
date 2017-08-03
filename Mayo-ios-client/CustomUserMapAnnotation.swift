//
//  CustomUserMapAnnotation.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 4/18/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import MapKit

class CustomUserMapAnnotation: MKPointAnnotation {
    var userId: String?
    
    init(userId: String ) {
        self.userId = userId
    }
}
