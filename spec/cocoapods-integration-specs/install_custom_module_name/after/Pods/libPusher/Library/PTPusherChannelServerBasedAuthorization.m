//
//  PTPusherChannelServerBasedAuthorization.m
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import "PTPusherChannelServerBasedAuthorization.h"
#import "NSDictionary+QueryString.h"
#import "PTJSON.h"
#import "PTPusherChannel.h"
#import "PTPusher.h"

@implementation PTPusherChannelServerBasedAuthorization {
  NSOperationQueue *authorizationQueue;
  void (^_requestBlock)(PTPusherChannelAuthorizationOperation *, PTPusherChannel *);
}

- (id)initWithAuthorizationURL:(NSURL *)URL
{
  if ((self = [super init])) {
    _authorizationURL = URL;

    authorizationQueue = [[NSOperationQueue alloc] init];
    authorizationQueue.maxConcurrentOperationCount = 5;
    authorizationQueue.name = @"com.pusher.libPusher.authorizationQueue";
  }
  return self;
}

- (void)customizeOperationsWithBlock:(void (^)(PTPusherChannelAuthorizationOperation *request, PTPusherChannel *))requestBlock
{
  _requestBlock = [requestBlock copy];
}

- (void)pusherChannel:(PTPusherChannel *)channel requiresAuthorizationForSocketID:(NSString *)socketID completionHandler:(void (^)(BOOL, NSDictionary *, NSError *))completionHandler
{
  PTPusherChannelAuthorizationOperation *authOperation = [PTPusherChannelAuthorizationOperation operationWithAuthorizationURL:self.authorizationURL channelName:channel.name socketID:socketID];

  [authOperation setCompletionHandler:^(PTPusherChannelAuthorizationOperation *operation) {
    completionHandler(operation.isAuthorized, operation.authorizationData, operation.error);
  }];

  if (_requestBlock) {
    _requestBlock(authOperation, channel);
  }

  [authorizationQueue addOperation:authOperation];
}

@end

#pragma mark -

@interface PTPusherChannelAuthorizationOperation ()
@property (nonatomic, strong, readwrite) NSDictionary *authorizationData;
@property (nonatomic, readwrite) NSError *error;
@end

@implementation PTPusherChannelAuthorizationOperation {
  NSDictionary *requestParameters;
}

- (NSMutableURLRequest *)mutableURLRequest
{
  // we can be sure this is always mutable
  return (NSMutableURLRequest *)URLRequest;
}

+ (id)operationWithAuthorizationURL:(NSURL *)URL channelName:(NSString *)channelName socketID:(NSString *)socketID
{
  NSAssert(URL, @"URL is required for authorization! (Did you set PTPusher.authorizationURL?)");

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
  [request setHTTPMethod:@"POST"];
  [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

  NSMutableDictionary *requestParameters = [NSMutableDictionary dictionary];
  [requestParameters setObject:socketID forKey:@"socket_id"];
  [requestParameters setObject:channelName forKey:@"channel_name"];

  return [[self alloc] initWithURLRequest:request parameters:requestParameters];
}

- (id)initWithURLRequest:(NSURLRequest *)request parameters:(NSDictionary *)parameters
{
  if ((self = [super initWithURLRequest:request])) {
    requestParameters = [parameters copy];
  }
  return self;
}

- (void)start
{
  NSMutableDictionary *parameters = [requestParameters mutableCopy];

  if (self.customRequestParameters) {
    [parameters addEntriesFromDictionary:self.customRequestParameters];
  }

  [self.mutableURLRequest setHTTPBody:[[parameters sortedQueryString] dataUsingEncoding:NSUTF8StringEncoding]];

  [super start];
}

- (void)finish
{
  if (self.isCancelled) {
    [super finish];
    return;
  }

  if (self.connectionError) {
    self.error = [NSError errorWithDomain:PTPusherErrorDomain code:PTPusherChannelAuthorizationConnectionError userInfo:@{NSUnderlyingErrorKey: self.connectionError}];
  }
  else {
    _authorized = YES;

    if ([URLResponse isKindOfClass:[NSHTTPURLResponse class]]) {
      _authorized = ([(NSHTTPURLResponse *)URLResponse statusCode] == 200 || [(NSHTTPURLResponse *)URLResponse statusCode] == 201);
    }

    if (_authorized) {
      _authorizationData = [[PTJSON JSONParser] objectFromJSONData:responseData];

      if (![_authorizationData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *userInfo = nil;

        if (_authorizationData) { // make sure it isn't nil as a result of invalid JSON first
          userInfo = @{@"reason": @"Authorization data was not a dictionary", @"authorization_data": _authorizationData};
        }
        else {
          userInfo = @{@"reason": @"Authorization data was not valid JSON"};
        }

        self.error = [NSError errorWithDomain:PTPusherErrorDomain code:PTPusherChannelAuthorizationBadResponseError userInfo:userInfo];

        _authorized = NO;
      }
    }
  }

  if (self.completionHandler) {
    self.completionHandler(self);
  }

  [super finish];
}

@end
