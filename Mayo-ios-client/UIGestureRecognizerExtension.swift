//
//  UIGestureRecognizerExtension.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 5/25/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit

extension MainViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}
