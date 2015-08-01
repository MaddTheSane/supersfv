//
//  AILinkedListObject.h
//  AIUtilities.framework
//
//  Created by Sam McCandlish on 9/6/05.
//  Copyright 2005 the Adium Team. All rights reserved.
//

#import <Foundation/Foundation.h>

/* For use by AILinkedList, you probably don't need this. */
@interface AILinkedListObject : NSObject
- (instancetype)initWithObject:(id)theObject NS_DESIGNATED_INITIALIZER;

@property (strong, readonly) id object;

- (void)setNextObject:(AILinkedListObject *)theObject;

@property (weak, readonly) AILinkedListObject *lastObject;
@property (strong, nonatomic) AILinkedListObject *nextObject;
@end
