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

#import "SPFileEntry.h"


@implementation SPFileEntry

+ (NSImage*)imageForStatus:(SPFileStatus)status
{
	switch (status) {
		case SPFileStatusChecking:
			return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
			break;
			
		case SPFileStatusValid:
			return [NSImage imageNamed:NSImageNameStatusAvailable];
			break;
			
		case SPFileStatusInvalid:
			return [NSImage imageNamed:NSImageNameStatusUnavailable];
			break;
			
		case SPFileStatusFileNotFound:
		case SPFileStatusUnknownChecksum:
			return [NSImage imageNamed:NSImageNameStatusNone];
			break;
			
		default:
			return nil;
			break;
	}
	
	return nil;
}

- (instancetype)init
{
	self = [self initWithPath:@"" expectedHash:@""];
	return nil;
}

- (instancetype)initWithPath:(NSString*)path
{
	return self = [self initWithPath:path expectedHash:@""];
}

- (instancetype)initWithPath:(NSString *)path expectedHash:(NSString *)expected
{
	if (self = [super init]) {
		_filePath = [path copy];
		_expected = [expected copy];
		_status = SPFileStatusUnknown;
		_result = @"";
	}
	return self;
}

- (id)valueForUndefinedKey:(id)key
{
	if ([key isEqualToString:@"filepath"]) {
		return _filePath;
	}

	if ([key isEqualToString:@"expected"]) {
		return _expected;
	}

	if ([key isEqualToString:@"result"]) {
		return _result;
	}

    return @"";
}

@end
