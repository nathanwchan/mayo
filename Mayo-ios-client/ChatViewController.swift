//
//  ChatViewController.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 4/12/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit
import Firebase
import JSQMessagesViewController
import Alamofire

class ChatViewController: JSQMessagesViewController {
    
    var channelRef: FIRDatabaseReference?
    var channelId: String?
    var channelTopic: String?
    var messages = [Message]()
    var currentUserColorIndex: Int? = nil
    
    // array of color hex colors for chat bubbles
    let chatBubbleColors = [
        "C2C2C2", // task owner's bubble color gray
        "08BBDB",
        "FC8FA3",
        "9CD72F",
        "ED801F",
        "B664C4",
        "4A4A4A",
        "4FB5B2",
        "2F96FF",
        "E86D5D",
        "1DAE73",
        "AC664C",
        "508FBC",
        "BCCB4C",
        "7C3EC1",
        "D36679",
        "5AC7CF",
        "CAA63C"
    ]
    
    private lazy var messageRef: FIRDatabaseReference = self.channelRef!.child("messages")
    private var newMessageRefHandle: FIRDatabaseHandle?
    
 

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // disable swipe to navigate
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        // check if the current user id and channel id match
        // if they match, set gray color for the current user(index 0)
        checkColorIndexForCurrentUserIfOwner()
        
        // No avatars
        collectionView!.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView!.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        // turns off attachments button
        self.inputToolbar.contentView.leftBarButtonItem = nil

        
        // set senderid as current user id
        self.senderId = FIRAuth.auth()?.currentUser?.uid
        self.senderDisplayName = ""
        
        // listen for new messages
        observeMessages()
    }
    
    private func checkColorIndexForCurrentUserIfOwner() {
        // set the color index to 0 if the current channel was created
        // by the current user
        if let channelId = self.channelId {
            if FIRAuth.auth()?.currentUser?.uid == channelId {
                // if the user id and the channel id match
                // set the current color index to 0
                self.currentUserColorIndex = 0
                print("current user color index was set")
            }
        }
    }
    
    // create new message
    private func addMessage(withId id: String, name: String, text: String, colorIndex: Int) {
        
        let message = Message(senderId: id, senderDisplayName: name, text: text, colorIndex: colorIndex)
        //JSQMessage(senderId: id, displayName: name, text: text) {
            
        messages.append(message)
        
    }
    
    override func textViewDidChange(_ textView: UITextView) {
        super.textViewDidChange(textView)
        // If the text is not empty, the user is typing
        print(textView.text != "")
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        
        // check if current user color index is set
        if self.currentUserColorIndex == nil {
            // check if current user is in the conversation
            self.channelRef?.child("users").observeSingleEvent(of: .value, with: { (snapshot) in
                
                // boolean flag to check if current user is in the conversation already
                var currentUserIsInConversation:Bool = false
                let usersValue = snapshot.value as? NSDictionary ?? [:]
                for (userId, colorIndex) in usersValue {
                   // if a key matches the current user's uid
                    if userId as? String == FIRAuth.auth()?.currentUser?.uid {
                        // set the color index to the value
                        self.currentUserColorIndex = colorIndex as? Int
                        // break out of the loop
                        currentUserIsInConversation = true
                        break
                    }
                    
                }
                // if the user is not in the conversation
                if currentUserIsInConversation == false {
                    
                    // add the user to the conversation and increment users counter
                    let usersCountAndNewColorIndex = usersValue.allKeys.count
                    
                    //save the index
                    self.channelRef?.child("users").child((FIRAuth.auth()?.currentUser?.uid)!).setValue(usersCountAndNewColorIndex)
                    self.currentUserColorIndex = usersCountAndNewColorIndex
                    self.saveMessageAndUpdate(text: text, senderId: senderId, senderDisplayName: senderDisplayName, date: date)
                    
                    // update the current task with emoji star U+2B50
                    
                    
                } else {
                    
                    // user is already in the conversation and is found
                    // rest of update
                    self.saveMessageAndUpdate(text: text, senderId: senderId, senderDisplayName: senderDisplayName, date: date)
                }
                
                
            
            }, withCancel: { (error) in
                print(error)
            })
            
            
        } else {
            self.saveMessageAndUpdate(text: text, senderId: senderId, senderDisplayName: senderDisplayName, date: date)
        }
        
    }
    
    // TODO update the task with star emoji for description
    func updateTaskDescriptionWithStarEmoji() {
        let viewControllersCount = self.navigationController?.viewControllers.count
        if let mainViewController = self.navigationController?.viewControllers[viewControllersCount! -  2] as? MainViewController {
        }
        
    }
    
    func saveMessageAndUpdate(text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        // check if the sender is the same as the channel id
        // which means that the user who is sending is part of their own
        // if the ids match, then add the screaming face emoticon
        var textToSend = text
        if senderId == self.channelId {
            let screamingFaceEmoji = "\u{1F631} " //U+1F631
            textToSend = screamingFaceEmoji + text!
            
        }
        
        // get the current user's color index if the user is already in the conversation
        
        // if the user is not currently in the conversation
        // add the user to the conversation and create an index for them
        
        // the color index is the color of the current user's bubble
        // it is determined by the current user's position in the current chat channel
        let dateFormatter = DateStringFormatterHelper()
        let dateCreated = dateFormatter.convertDateToString(date: Date())
        
        
        let itemRef = messageRef.childByAutoId()
        let messageItem = [
            "senderId": senderId!,
            "senderName": senderDisplayName!,
            "text": textToSend!,
            "colorIndex": "\(self.currentUserColorIndex!)",
            "dateCreated": dateCreated
        ]
        
        itemRef.setValue(messageItem)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        if let channelId = self.channelId {
            
            self.sendNotificationToTopic(channelId: channelId)
            
            FIRMessaging.messaging().subscribe(toTopic: "/topics/\(channelId)")
            
        }
        finishSendingMessage()
    }
    
    // TODO: send notification to the topic for specific channel id
    func sendNotificationToTopic(channelId: String) {
        
        // setup alamofire url
        let fcmURL = "https://fcm.googleapis.com/fcm/send"
        
        // TODO: add application/json and add authorization key
        var channelTopicMessage = ""
        if let channelTopic = self.channelTopic {
            channelTopicMessage = channelTopic
        }
        let parameters: Parameters = [
            "to": "/topics/\(channelId)",
            "priority": "high",
            "notification": [
                "body": "Someone posted in \(channelTopicMessage)",
                "title": "New Message Posted",
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
    
    // listen for new messags
    private func observeMessages() {
        messageRef = channelRef!.child("messages")

        let messageQuery = messageRef.queryLimited(toLast:25)
        
        //  We can use the observe method to listen for new
        // messages being written to the Firebase DB
        newMessageRefHandle = messageQuery.observe(.childAdded, with: { (snapshot) -> Void in
            
            let messageData = snapshot.value as! Dictionary<String, String>
            
            
            if let id = messageData["senderId"] as String!, let name = messageData["senderName"] as String!, let text = messageData["text"] as String!, text.characters.count > 0, let colorIndexAsInt = Int(messageData["colorIndex"]!) {
                
                self.addMessage(withId: id, name: name, text: text, colorIndex: colorIndexAsInt)
                
            
                self.finishReceivingMessage()
            } else {
                print("Error! Could not decode message data")
            }
        })
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        let message = messages[indexPath.item]
        cell.textView?.textColor = UIColor.white
        
        //if message.senderId == senderId {
        //  cell.textView?.textColor = UIColor.white
        //} else {
        //    cell.textView?.textColor = UIColor.black
        //}
        return cell
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        
        if message.senderId() == senderId {
            // TODO get the correct index for the sender
            // pass in the correct index to get the correct color
            let messageColorIndex = message.colorIndex != nil ? message.colorIndex! : 0
            let outgoingBubbleImage = setupOutgoingBubble(colorIndex: messageColorIndex)
            return outgoingBubbleImage
        } else {
            let messageColorIndex = message.colorIndex != nil ? message.colorIndex! : 0
            let incomingBubbleImage = setupIncomingBubble(colorIndex: messageColorIndex)
            return incomingBubbleImage
        }
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }

   
    private func setupOutgoingBubble(colorIndex: Int) -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        let indexAfterModulo = colorIndex % self.chatBubbleColors.count
        return bubbleImageFactory!.outgoingMessagesBubbleImage(with: UIColor.hexStringToUIColor(hex: self.chatBubbleColors[indexAfterModulo]))
    }
    
    // TODO: change the color of the chat user
    // based on who it is
    // annonymous colors
    private func setupIncomingBubble(colorIndex: Int) -> JSQMessagesBubbleImage {
        let bubbleImageFactory = JSQMessagesBubbleImageFactory()
        let indexAfterModulo = colorIndex % self.chatBubbleColors.count
        return bubbleImageFactory!.incomingMessagesBubbleImage(with: UIColor.hexStringToUIColor(hex: self.chatBubbleColors[indexAfterModulo]))//UIColor.jsq_messageBubbleLightGray())
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
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
