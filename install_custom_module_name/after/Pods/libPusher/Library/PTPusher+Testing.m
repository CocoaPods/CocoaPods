//
//  PTPusher+Testing.m
//  libPusher
//
//  Created by Luke Redpath on 11/05/2012.
//  Copyright (c) 2012 LJR Software Limited. All rights reserved.
//

#import "PTPusher+Testing.h"
#import "PTPusherChannelAuthorizationOperation.h"

NSString *const PTPusherAuthorizationBypassURL = @"libpusher://auth/bypass/url";

@implementation PTPusher (Testing)

- (void)enableChannelAuthorizationBypassMode
{
  self.authorizationURL = [NSURL URLWithString:PTPusherAuthorizationBypassURL];
}

@end
