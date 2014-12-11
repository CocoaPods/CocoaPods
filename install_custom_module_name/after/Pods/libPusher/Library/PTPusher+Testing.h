//
//  PTPusher+Testing.h
//  libPusher
//
//  Created by Luke Redpath on 11/05/2012.
//  Copyright (c) 2012 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTPusher.h"

extern NSString *const PTPusherAuthorizationBypassURL;

@interface PTPusher (Testing)

- (void)enableChannelAuthorizationBypassMode;

@end
