//
//  NSDictionary+QueryString.m
//  libPusher
//
//  Created by Luke Redpath on 23/04/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import "NSDictionary+QueryString.h"


@implementation NSDictionary (QueryString)

- (NSString *)sortedQueryString;
{
  NSMutableArray *parts = [[NSMutableArray alloc] initWithCapacity:[[self allKeys] count]];
  NSArray *sortedKeys = [[self allKeys] sortedArrayUsingSelector:@selector(localizedCompare:)];
  for (NSString *key in sortedKeys) {
    NSString *part = [[NSString alloc] initWithFormat:@"%@=%@", key, [self valueForKey:key]];
    [parts addObject:part];
  }
  NSString *queryString = [parts componentsJoinedByString:@"&"];

  return queryString;
}

@end
