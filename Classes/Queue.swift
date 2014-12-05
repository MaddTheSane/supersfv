//
//  Queue.swift
//  SuperSFV
//
//  Created by C.W. Betts on 12/5/14.
//
//

import Cocoa

class Queue: AILinkedList {
    
    func enqueue(object: AnyObject) {
        insertObjectAtEnd(object)
    }
    
    func dequeue() -> AnyObject? {
        return removeObjectAtEnd()
    }
}
