//
//  PTPusherChannelAuthorizationOperation.h
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTURLRequestOperation.h"

typedef enum {
  PTPusherChannelAuthorizationConnectionError = 100,
  PTPusherChannelAuthorizationBadResponseError
} PTPusherChannelAuthorizationError;

@interface PTPusherChannelAuthorizationOperation : PTURLRequestOperation

@property (nonatomic, copy) void (^completionHandler)(PTPusherChannelAuthorizationOperation *);
@property (nonatomic, readonly, getter=isAuthorized) BOOL authorized;
@property (nonatomic, strong, readonly) NSDictionary *authorizationData;
@property (weak, nonatomic, readonly) NSMutableURLRequest *mutableURLRequest;
@property (nonatomic, readonly) NSError *error;

+ (id)operationWithAuthorizationURL:(NSURL *)URL channelName:(NSString *)channelName socketID:(NSString *)socketID;
@end
