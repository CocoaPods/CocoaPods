//
//  PTJSON.m
//  libPusher
//
//  Created by Luke Redpath on 30/03/2012.
//  Copyright (c) 2012 LJR Software Limited. All rights reserved.
//

#import "PTJSON.h"
#import "PTPusherMacros.h"

@interface PTNSJSONParser : NSObject <PTJSONParser>
+ (id)NSJSONParser;
@end

@implementation PTJSON

+ (id<PTJSONParser>)JSONParser
{
  return [PTNSJSONParser NSJSONParser];
}

@end

@implementation PTNSJSONParser 

+ (id)NSJSONParser
{
  PT_DEFINE_SHARED_INSTANCE_USING_BLOCK(^{
    return [[self alloc] init];
  });
}

- (NSData *)JSONDataFromObject:(id)object
{
  return [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
}

- (NSString *)JSONStringFromObject:(id)object
{
  return [[NSString alloc] initWithData:[self JSONDataFromObject:object] encoding:NSUTF8StringEncoding];
}

- (id)objectFromJSONData:(NSData *)data
{
  return [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
}

- (id)objectFromJSONString:(NSString *)string
{
  return [self objectFromJSONData:[string dataUsingEncoding:NSUTF8StringEncoding]];
}

@end
