//
//  TextViewExtension.swift
//  Mayo-ios-client
//
//  Created by Weijie Gao on 5/25/17.
//  Copyright © 2017 Weijie. All rights reserved.
//

import UIKit

extension MainViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.alpha == 0.5 {
            textView.text = nil
            textView.alpha = 1
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "What do you need help with?"
            textView.alpha = 0.5
        }
    }
    
    
    func textViewDidChange(_ textView: UITextView) {
        
        
        // change the post button isEnabled
        // if there is text inside the textView
        // also check that it is alpha of 1 so it is not the placeholder
        if textView.alpha == 1 && textView.text.characters.count > 0 {
            
            if let post_new_task_button = self.view.viewWithTag(self.POST_NEW_TASK_BUTTON_TAG) as? UIButton {
                
                // set post new task button to enabled
                post_new_task_button.isEnabled = true
                // change the alpha for the button to 1
                post_new_task_button.alpha = 1.0
                
            }
            
        } else {
            // if character check is not satisfired or alpha == 1 not satisfied
            // disable the post button
            
            if let post_new_task_button = self.view.viewWithTag(self.POST_NEW_TASK_BUTTON_TAG) as? UIButton {
                
                // set post new task button to enabled
                post_new_task_button.isEnabled = false
                
                // change alpha to 0.5 for the post button
                post_new_task_button.alpha = 0.5
                
            }
        }
        
        
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        let maxtext: Int = 78
        //If the text is larger than the maxtext, the return is false
        
        return textView.text.characters.count + (text.characters.count - range.length) <= maxtext
    }
    
    
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(_ notification: Notification) {
        if !keyboardOnScreen {
            self.view.frame.origin.y -= self.keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(_ notification: Notification) {
        if keyboardOnScreen {
            self.view.frame.origin.y += self.keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(_ notification: Notification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(_ notification: Notification) {
        keyboardOnScreen = false
    }
    
    func keyboardHeight(_ notification: Notification) -> CGFloat {
        return ((notification as NSNotification).userInfo![UIKeyboardFrameBeginUserInfoKey] as! NSValue).cgRectValue.height
    }
    
}

