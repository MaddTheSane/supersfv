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
	@objc(FileStatus) enum Status : Int {
		case unknown = 0
		case checking
		case valid
		case invalid
		case fileNotFound
		case unknownChecksum = -1
	}
	
	class func image(forStatus status: Status) -> NSImage? {
		switch (status) {
		case .checking:
			return NSImage(named: NSImage.Name.statusPartiallyAvailable)
			
		case .valid:
			return NSImage(named: NSImage.Name.statusAvailable)
			
		case .invalid:
			return NSImage(named: NSImage.Name.statusUnavailable)
			
		case .fileNotFound, .unknownChecksum:
			return NSImage(named: NSImage.Name.statusNone)
			
		default:
			return nil;
		}
	}
	
	@objc var status = Status.unknown
	@objc let fileURL: URL
	@objc var filePath: String {
		return fileURL.path
	}
	@objc var expected: String
	@objc var result: String
	
	convenience init(path: String) {
		self.init(path: path, expectedHash: nil)
	}
	
	convenience init(fileURL: URL) {
		self.init(fileURL: fileURL, expectedHash: nil)
	}
	
	init(fileURL: URL, expectedHash expected: String!) {
		self.fileURL = fileURL
		self.expected = expected ?? ""
		result = ""
		
		super.init()
	}
	
	convenience init(path: String, expectedHash expected: String!) {
		self.init(fileURL: URL(fileURLWithPath: path), expectedHash: expected)
	}
	
	override var description: String {
		return "\(filePath): expected \(expected), result \(result)"
	}
}
