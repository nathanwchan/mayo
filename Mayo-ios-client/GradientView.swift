//
//  GradientView.swift
//  mayo-ios
//
//  Created by Weijie Gao on 3/27/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit

@IBDesignable final class GradientView: UIView {

    @IBInspectable var startColor: UIColor = UIColor.clear
    @IBInspectable var endColor: UIColor = UIColor.clear
    
    var labelCount: Int = 0
    
    override func draw(_ rect: CGRect) {
        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.frame = CGRect(x: CGFloat(0), y: CGFloat(0), width: self.frame.size.width, height: self.frame.size.height)
        
        gradient.colors = [startColor.cgColor, endColor.cgColor]
        layer.insertSublayer(gradient, at: 0)
        
        //let radius: CGFloat = self.frame.width / 2.0
        //change it to .height if you need spread for height
        //let shadowPath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: 2.1 * radius, height: self.frame.height))
        //Change 2.1 to amount of spread you need and for height replace the code for height
        layer.cornerRadius = 4
        self.clipsToBounds = true
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 10)  //Here you control x and y
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 15.0 //Here your control your blur
        layer.masksToBounds =  true
        

        
    }

}
