//
//  CardColors.swift
//  mayo-ios
//
//  Created by Weijie Gao on 4/3/17.
//  Copyright © 2017 Weijie. All rights reserved.
//


import Foundation

class CardColor {
    
    // array of arrays of color choices
    // first hex is start color
    // second hex is end color
    var choices = [
        ["4fb5b2", "bee7c7"], // dark green 1 to light green 1
        ["08bbdb", "d5c2e6"], // light blue 1 to pink 1
        ["e86d5d", "e8c378"], // red 1 to orange 1
        ["9cd72f", "90e2ad"],// dark green 2 to light green 2
        ["c96dd8", "ff91a5"], // purple to pink
        ["e87185", "eae6f2"], // pink to grey
        ["bccb4c", "f3e24d"], // off yellow to yellow
        ["1dae73", "c1d96e"], // dark green 3 to light green 3
        ["ac664c", "cda83d"], // dark brown to light brown
        ["508fbc", "5ac7cf"], // dark blue to light blue
        ["e86d5d", "e8c378"] // dark red to light orange
    ]
    
    private func generateRandomNumber() -> Int {
        // generate random number between 0 and length of color choices
        let randomNumber = Int(arc4random_uniform(UInt32(choices.count)))
        return randomNumber
    }
    
    func generateRandomColor() -> [String] {
        // generate random number 
        let randomNumber = generateRandomNumber()
        
        // use the random number as index for the colors array
        let colorChoices = choices[randomNumber]
        
        // return generated color array
        return colorChoices
    }
}
