//
//  NSDictionary+StringValue.m
//  libPusher
//
//  Created by Yufei Tang on 2015-10-01.
//
//

#import "NSDictionary+StringValue.h"

@implementation NSDictionary (StringValue)

- (NSString *)stringValueForKey:(id)key {
  id object = [self objectForKey:key];
  return [self convertObjectToString:object];
}

- (void)enumerateStringKeysAndObjectsUsingBlock:(void (^)(NSString *key, id object, BOOL *stop))block {
  [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    NSString *stringKey = [self convertObjectToString:key];
    block(stringKey, obj, stop);
  }];
}

- (NSString *)convertObjectToString:(id)object {
  if ([object isKindOfClass:[NSString class]]) {
    return object;
  } else if ([object isKindOfClass:[NSNumber class]]) {
    return [object stringValue];
  } else {
    return [object description];
  }
}

@end
