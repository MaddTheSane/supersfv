//
//  LinkedListObject.swift
//  SuperSFV
//
//  Created by C.W. Betts on 12/5/14.
//
//

import Cocoa

//class LinkedListObject<X: AnyObject>: NSObject {
class LinkedListObject: NSObject {
	private(set) weak var lastObject: LinkedListObject?
	weak var nextObject: LinkedListObject? {
		didSet {
			nextObject?.lastObject = self
		}
	}
	/*
@property (weak, readonly) AILinkedListObject *lastObject;
@property (weak, nonatomic) AILinkedListObject *nextObject;
*/
	
	
	let object: AnyObject
	init(object: AnyObject) {
		self.object = object
		
		super.init()
	}
}
