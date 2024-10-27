//
//  PTEventListener.h
//  PusherEvents
//
//  Created by Luke Redpath on 22/03/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>


@class PTPusherEvent;

@protocol PTEventListener <NSObject>

- (void)dispatchEvent:(PTPusherEvent *)event;

@optional

- (void)invalidate;

@end
