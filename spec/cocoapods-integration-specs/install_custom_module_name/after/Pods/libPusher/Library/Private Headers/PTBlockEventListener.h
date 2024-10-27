//
//  PTBlockEventListener.h
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTEventListener.h"
#import "PTPusherEventDispatcher.h"

typedef void (^PTBlockEventListenerBlock)(PTPusherEvent *);

@interface PTPusherEventDispatcher (PTBlockEventFactory)

- (PTPusherEventBinding *)addEventListenerForEventNamed:(NSString *)eventName 
                                block:(PTBlockEventListenerBlock)block 
                                queue:(dispatch_queue_t)queue;

@end

