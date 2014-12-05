//
//  AILinkedList.m
//  AIUtilities.framework
//
//  Created by Sam McCandlish on 9/6/05.
//  Copyright 2005 the Adium Team. All rights reserved.
//

#import "AILinkedList.h"
#import "SuperSFV-Swift.h"
#import <Foundation/Foundation.h>

@interface AILinkedList (PRIVATE)
- (id)linkedListObjectAtIndex:(NSUInteger)index;
@end

@implementation AILinkedList {
    LinkedListObject *front, *back;
}
@synthesize count;

- (id)init {
	if ((self = [super init])) {
		front = nil;
		back = nil;
		count = 0;
	}
	return self;
}

- (void)dealloc {
	@synchronized(self) {
		LinkedListObject *tmp;
		while (front != nil) {
			tmp = front;
			front = [front nextObject];
		}
	}
}

// ditches all the objects..
- (void)dump {
    int i;
	@synchronized(self) {
        i = count;
        while (--i >= 0)
            [self removeObjectAtIndex:i];
    }
}

- (id)linkedListObjectAtIndex:(NSUInteger)index {
	LinkedListObject *current;
	
	@synchronized(self) {
		if (index >= count)
			current = nil;
			//[NSException raise:NSRangeException format:@"The index %d is out of range.", index];
		
		else if (index == 0)
			current = front;
		
		else if (index == (count - 1))
			current = back;
		
		else {
			unsigned i;
			current = front;
			
			for (i=0; i<index; i++) {
				current = [current nextObject];
			}
		}
	}
	return current;
}

- (id)objectAtIndex:(unsigned)index {
	id theObject;
	@synchronized(self) {
		theObject = [[self linkedListObjectAtIndex:index] object];
	}
	return theObject;
}

- (id)objectAtFront {
	id theObject;
	@synchronized(self) {
		theObject = [self objectAtIndex:0];
	}
	return theObject;
}

- (id)objectAtEnd {
	id theObject;
	@synchronized(self) {
		theObject = [self objectAtIndex:(count - 1)];
	}
	return theObject;
}

- (NSUInteger)count {
	NSUInteger theCount;
	@synchronized(self) {
		theCount = count;
	}
	return theCount;
}

- (void)insertObject:(id)object atIndex:(NSUInteger)index {
	@synchronized(self) {
		if (index > count)
			[NSException raise:NSRangeException format:@"The index %lu is out of range.", (unsigned long)index];
		
		LinkedListObject *newObject = [[LinkedListObject alloc] initWithObject:object];
		LinkedListObject *last, *next, *tmp;
		unsigned i;
		
		if (index == count) {
			last = back;
			next = nil;
		}
		else {
			last = nil;
			next = front;
			for (i=0; i<index; i++) {
				tmp = last;
				last = next;
				next = [tmp nextObject];
			}
		}
		
		if (last == nil)
			front = newObject;
		if (next == nil)
			back = newObject;
		
		[last setNextObject:newObject];
		[newObject setNextObject:next];
		count++;
	}
}

- (void)insertObjectAtFront:(id)object {
	@synchronized(self) {
		[self insertObject:object atIndex:0];
	}
}

- (void)insertObjectAtEnd:(id)object {
	@synchronized(self) {
		[self insertObject:object atIndex:count];
	}
}

- (id)removeObjectAtIndex:(NSUInteger)index {
	id goneID;
	@synchronized(self) {
		LinkedListObject *goneObject = [self linkedListObjectAtIndex:index];
		if (goneObject == nil) {
			goneID = nil;
		}
		else {
			LinkedListObject *last = [goneObject lastObject], *next = [goneObject nextObject];
			
			if (last == nil)
				front = next;
			if (next == nil)
				back = last;
			[last setNextObject:next];
			count--;
			goneID = [goneObject object];
		}
	}
	return goneID;
}

- (id)removeObjectAtFront {
	id theObject;
	@synchronized(self) {
		theObject = [self removeObjectAtIndex:0];
	}
	return theObject;
}

- (id)removeObjectAtEnd {
	id theObject;
	@synchronized(self) {
		theObject = [self removeObjectAtIndex:(count - 1)];
	}
	return theObject;
}
@end
