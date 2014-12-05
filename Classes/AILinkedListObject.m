//
//  AILinkedListObject.m
//  AIUtilities.framework
//
//  Created by Sam McCandlish on 9/6/05.
//  Copyright 2005 the Adium Team. All rights reserved.
//

#import "AILinkedListObject.h"

@interface AILinkedListObject (PRIVATE)
@property (weak, readwrite) AILinkedListObject *lastObject;
@end

@implementation AILinkedListObject
@synthesize lastObject = last;
@synthesize nextObject = next;
@synthesize object;

- (AILinkedListObject *)initWithObject:(id)theObject {
	if ((self = [super init])) {
		object = theObject;
		last = nil;
		next = nil;
	}
	return self;
}

- (void)setNextObject:(AILinkedListObject *)theObject {
	next = theObject;
	theObject.lastObject = self;
}

@end
