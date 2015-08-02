//
//  FileEntry.swift
//  SuperSFV
//
//  Created by C.W. Betts on 12/4/14.
//
//

import Foundation
import AppKit.NSImage

@objc enum SPFileStatus : Int {
	case Unknown
	case Checking
	case Valid
	case Invalid
	case FileNotFound
	case UnknownChecksum
}

class FileEntry : NSObject {
	class func imageForStatus(status: SPFileStatus) -> NSImage? {
		switch (status) {
		case .Checking:
			return NSImage(named: NSImageNameStatusPartiallyAvailable)
			
		case .Valid:
			return NSImage(named: NSImageNameStatusAvailable)
			
		case .Invalid:
			return NSImage(named: NSImageNameStatusUnavailable)
			
		case .FileNotFound, .UnknownChecksum:
			return NSImage(named: NSImageNameStatusNone)
			
		default:
			return nil;
		}
	}
	
	var status = SPFileStatus.Unknown
	let filePath: String
	var expected: String
	var result: String
	
	convenience init(path: String) {
		self.init(path: path, expectedHash: nil)
	}
	
	init(path: String, expectedHash expected: String!) {
		filePath = path
		self.expected = expected ?? ""
		result = ""
		
		super.init()
	}
}
