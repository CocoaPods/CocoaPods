//
//  PTPusherChannelAuthorizationOperation.h
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTPusherChannelAuthorizationDelegate.h"
#import "PTURLRequestOperation.h"

@class PTPusherChannelAuthorizationOperation;

@interface PTPusherChannelServerBasedAuthorization : NSObject <PTPusherChannelAuthorizationDelegate>

@property (nonatomic, readonly) NSURL *authorizationURL;

- (id)initWithAuthorizationURL:(NSURL *)URL;
- (void)customizeOperationsWithBlock:(void (^)(PTPusherChannelAuthorizationOperation *request, PTPusherChannel *))requestBlock;

@end

typedef enum {
  PTPusherChannelAuthorizationConnectionError = 100,
  PTPusherChannelAuthorizationBadResponseError
} PTPusherChannelAuthorizationError;

@interface PTPusherChannelAuthorizationOperation : PTURLRequestOperation

@property (nonatomic, copy) void (^completionHandler)(PTPusherChannelAuthorizationOperation *);
@property (nonatomic, readonly, getter=isAuthorized) BOOL authorized;
@property (nonatomic, strong, readonly) NSDictionary *authorizationData;
@property (nonatomic, copy) NSDictionary *customRequestParameters;
@property (unsafe_unretained, nonatomic, readonly) NSMutableURLRequest *mutableURLRequest;
@property (nonatomic, readonly) NSError *error;

+ (id)operationWithAuthorizationURL:(NSURL *)URL channelName:(NSString *)channelName socketID:(NSString *)socketID;
@end
