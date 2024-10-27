//
//  NSDictionary+StringValue.h
//  libPusher
//
//  Created by Yufei Tang on 2015-10-01.
//
//

#import <Foundation/Foundation.h>

@interface NSDictionary (StringValue)

- (NSString *)stringValueForKey:(id)key;

- (void)enumerateStringKeysAndObjectsUsingBlock:(void (^)(NSString *key, id object, BOOL *stop))block;

@end
