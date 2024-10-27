//
//  PTBlockEventListener.m
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import "PTBlockEventListener.h"

@interface PTBlockEventListener : NSObject <PTEventListener>
@end

@implementation PTBlockEventListener {
  PTBlockEventListenerBlock _block;
  dispatch_queue_t _queue;
  BOOL _invalid;
}

- (id)initWithBlock:(PTBlockEventListenerBlock)aBlock dispatchQueue:(dispatch_queue_t)aQueue
{
  NSParameterAssert(aBlock);
  
  if ((self = [super init])) {
    _block = [aBlock copy];
    _queue = aQueue;
    _invalid = NO;
#if !OS_OBJECT_USE_OBJC
    dispatch_retain(_queue);
#endif
  }
  return self;
}

- (void)dealloc
{
#if !OS_OBJECT_USE_OBJC
  dispatch_release(_queue);
#endif
}

- (void)invalidate
{
  _invalid = YES;
}

- (void)dispatchEvent:(PTPusherEvent *)event
{
  dispatch_async(_queue, ^{
    if (!_invalid) {
      _block(event);
    }
  });
}

@end

@implementation PTPusherEventDispatcher (PTBlockEventFactory)

- (PTPusherEventBinding *)addEventListenerForEventNamed:(NSString *)eventName
                                                  block:(PTBlockEventListenerBlock)block
                                                  queue:(dispatch_queue_t)queue
{
  PTBlockEventListener *listener = [[PTBlockEventListener alloc] initWithBlock:block dispatchQueue:queue];
  return [self addEventListener:listener forEventNamed:eventName];
}

@end
