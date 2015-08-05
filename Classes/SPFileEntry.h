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

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPFileStatus) {
	SPFileStatusUnknown = 0,
	SPFileStatusChecking,
	SPFileStatusValid,
	SPFileStatusInvalid,
	SPFileStatusFileNotFound,
	SPFileStatusUnknownChecksum = -1
};

@interface SPFileEntry : NSObject
+ (nullable NSImage*)imageForStatus:(SPFileStatus)status;

@property SPFileStatus status;
@property (readonly, copy) NSString *filePath;
@property (copy) NSString *expected;
@property (copy) NSString *result;

- (instancetype)initWithPath:(NSString*)path;
- (instancetype)initWithPath:(NSString*)path expectedHash:(NSString*)expected NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
