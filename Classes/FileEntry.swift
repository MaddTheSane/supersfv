//
//  FileEntry.swift
//  SuperSFV
//
//  Created by C.W. Betts on 12/4/14.
//
//

import Cocoa

class FileEntry: NSObject {
	let defaultKeys: [String]
	var properties: [String: NSObject]
	
	override init() {
		properties = ["status": NSImage(), "filepath": "/", "expected": "", "result": ""]
		defaultKeys = properties.keys.array
		
		super.init()
	}
	
	override func valueForUndefinedKey(key: String) -> AnyObject? {
		return properties[key]
	}
}
