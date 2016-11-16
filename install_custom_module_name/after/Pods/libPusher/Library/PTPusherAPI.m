//
//  PTPusherAPI.m
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import "PTPusherAPI.h"
#import "PTURLRequestOperation.h"
#import "PTJSON.h"
#import "NSString+Hashing.h"
#import "NSDictionary+QueryString.h"


#define kPUSHER_API_DEFAULT_HOST @"api.pusherapp.com"

@implementation PTPusherAPI {
  NSString *key, *appID, *secretKey;
  NSOperationQueue *operationQueue;
}

- (id)initWithKey:(NSString *)aKey appID:(NSString *)anAppID secretKey:(NSString *)aSecretKey
{
  if ((self = [super init])) {
    key = [aKey copy];
    appID = [anAppID copy];
    secretKey = [aSecretKey copy];
    operationQueue = [[NSOperationQueue alloc] init];
  }
  return self;
}


- (void)triggerEvent:(NSString *)eventName onChannel:(NSString *)channelName data:(id)eventData socketID:(NSString *)socketID
{
  NSString *path = [NSString stringWithFormat:@"/apps/%@/channels/%@/events", appID, channelName];
  NSData *bodyData = [[PTJSON JSONParser] JSONDataFromObject:eventData];
  NSString *bodyString = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];
  
  NSMutableDictionary *queryParameters = [NSMutableDictionary dictionary];
  
  queryParameters[@"body_md5"] = [[bodyString MD5Hash] lowercaseString];
  queryParameters[@"auth_key"] = key;
  queryParameters[@"auth_timestamp"] = @([[NSDate date] timeIntervalSince1970]);
  queryParameters[@"auth_version"] = @"1.0";
  queryParameters[@"name"] = eventName;
  
  if (socketID) {
    queryParameters[@"socket_id"] = socketID;
  }
    
  NSString *signatureString = [NSString stringWithFormat:@"POST\n%@\n%@", path, [queryParameters sortedQueryString]];
  
  queryParameters[@"auth_signature"] = [signatureString HMACDigestUsingSecretKey:secretKey];
  
  NSString *URLString = [NSString stringWithFormat:@"https://%@%@?%@", kPUSHER_API_DEFAULT_HOST, path, [queryParameters sortedQueryString]];
  
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
  [request setHTTPBody:bodyData];
  [request setHTTPMethod:@"POST"];
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

  PTURLRequestOperation *operation = [[PTURLRequestOperation alloc] initWithURLRequest:request];
  [operationQueue addOperation:operation];
}

@end
