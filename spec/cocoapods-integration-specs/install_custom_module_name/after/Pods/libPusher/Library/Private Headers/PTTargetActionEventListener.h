//
//  PTTargetActionEventListener.h
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTEventListener.h"
#import "PTPusherEventDispatcher.h"

@interface PTPusherEventDispatcher (PTTargetActionFactory)
- (PTPusherEventBinding *)addEventListenerForEventNamed:(NSString *)eventName target:(id)target action:(SEL)action;
@end
