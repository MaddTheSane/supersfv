//
//  AILinkedListObject.m
//  AIUtilities.framework
//
//  Created by Sam McCandlish on 9/6/05.
//  Copyright 2005 the Adium Team. All rights reserved.
//

#import "AILinkedListObject.h"

@interface AILinkedListObject (PRIVATE)
- (void)setLastObject:(AILinkedListObject *)theObject;
@property (weak, readwrite) AILinkedListObject *lastObject;
@end

@implementation AILinkedListObject
@synthesize lastObject = last;
@synthesize nextObject = next;
@synthesize object;

- (AILinkedListObject *)initWithObject:(id)theObject {
	if ((self = [super init])) {
		object = [theObject retain];
		last = nil;
		next = nil;
	}
	return self;
}

- (void)dealloc {
	[object release];
	[super dealloc];
}

- (void)setNextObject:(AILinkedListObject *)theObject {
	next = theObject;
	[theObject setLastObject:self];
}

- (AILinkedListObject *)lastObject {
	return last;
}

- (AILinkedListObject *)nextObject {
	return next;
}
@end
