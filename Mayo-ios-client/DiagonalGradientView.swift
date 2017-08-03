//
//  DiagonalGradientView.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 5/1/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit

@IBDesignable final class DiagonalGradientView: UIView {
    
    // blue colors for points
    // start hex 508FBC
    // end hex 5AC7CF
    
    @IBInspectable var startColor: UIColor = UIColor.hexStringToUIColor(hex: "508FBC")
    @IBInspectable var endColor: UIColor = UIColor.hexStringToUIColor(hex: "5AC7CF")
    
    
    override func draw(_ rect: CGRect) {
        
        // create diagonal gradient view
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.frame = CGRect(x: CGFloat(0), y: CGFloat(0), width: self.frame.size.width, height: self.frame.size.height)
        
        // set start and end colors
        gradient.colors = [startColor.cgColor, endColor.cgColor]
        
        // set start adn end points for diagonal gradient
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)

        layer.insertSublayer(gradient, at: 0)
        
    }


}
