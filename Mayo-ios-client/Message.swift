//
//  Message.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 5/29/17.
//  Copyright © 2017 Weijie. All rights reserved.
//
import JSQMessagesViewController
import Foundation

class Message : NSObject, JSQMessageData {
    
    var senderId_ : String!
    var senderDisplayName_ : String!
    var date_ : NSDate
    var isMediaMessage_ : Bool
    var hash_ : Int = 0
    var text_ : String
    var colorIndex: Int?
    
    init(senderId: String, senderDisplayName: String?, text: String, colorIndex: Int) {
        self.senderId_ = senderId
        self.senderDisplayName_ = senderDisplayName
        self.date_ = NSDate()
        self.isMediaMessage_ = false

        
        let randomNum:UInt32 = arc4random_uniform(100000)
        let randomInt:Int = Int(randomNum)
        self.hash_ = randomInt
        
        self.text_ = text
        self.colorIndex = colorIndex
    }
    
    func senderId() -> String! {
        return senderId_
    }
    
    func senderDisplayName() -> String! {
        return senderDisplayName_
    }
    
    func date() -> Date {
        return date_ as Date
    }
    
    func isMediaMessage() -> Bool {
        return isMediaMessage_
    }
    
    
    func messageHash() -> UInt {
        return UInt(hash_)
    }
    
    func text() -> String! {
        return text_
    }
}
