//
//  AILinkedList.h
//  AIUtilities.framework
//
//  Created by Sam McCandlish on 9/6/05.
//  Copyright 2005 the Adium Team. All rights reserved.
//

#import <Foundation/NSObject.h>

@class AILinkedListObject;

@interface AILinkedList : NSObject {
	AILinkedListObject *front, *back;
}
/* Returns the object */
- (id)objectAtIndex:(unsigned)index; /* O(N) */
- (id)objectAtFront; /* O(1) */
- (id)objectAtEnd; /* O(1) */


@property (readonly) NSUInteger count; /* O(1) */
- (void)dump;

- (void)insertObject:(id)object atIndex:(NSUInteger)index; /* O(N) */
- (void)insertObjectAtFront:(id)object; /* O(1) */
- (void)insertObjectAtEnd:(id)object; /* O(1) */

/* Returns the object removed */
- (id)removeObjectAtIndex:(NSUInteger)index; /* O(N) */
- (id)removeObjectAtFront; /* O(1) */
- (id)removeObjectAtEnd; /* O(1) */

- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end
