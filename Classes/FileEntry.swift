/*
SuperSFV is the legal property of its developers, whose names are
listed in the copyright file included with this source distribution.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

//
//  FileEntry.swift
//  SuperSFV
//
//  Created by C.W. Betts on 12/4/14.
//
//

import Foundation
import AppKit.NSImage


class FileEntry : NSObject {
	@objc enum FileStatus : Int {
		case Unknown = 0
		case Checking
		case Valid
		case Invalid
		case FileNotFound
		case UnknownChecksum = -1
	}
	
	class func imageForStatus(status: FileStatus) -> NSImage? {
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
	
	var status = FileStatus.Unknown
	let fileURL: NSURL
	var filePath: String {
		return fileURL.path!
	}
	var expected: String
	var result: String
	
	convenience init(path: String) {
		self.init(path: path, expectedHash: nil)
	}
	
	convenience init(fileURL: NSURL) {
		self.init(fileURL: fileURL, expectedHash: nil)
	}
	
	init(fileURL: NSURL, expectedHash expected: String!) {
		self.fileURL = fileURL
		self.expected = expected ?? ""
		result = ""
		
		super.init()
	}
	
	convenience init(path: String, expectedHash expected: String!) {
		self.init(fileURL: NSURL(fileURLWithPath: path), expectedHash: expected)
	}
}
