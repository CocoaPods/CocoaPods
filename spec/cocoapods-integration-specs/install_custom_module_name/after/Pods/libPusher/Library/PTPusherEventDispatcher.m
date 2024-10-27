//
//  PTPusherEventDispatcher.m
//  libPusher
//
//  Created by Luke Redpath on 13/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import "PTPusherEventDispatcher.h"
#import "PTPusherEvent.h"

@interface PTPusherEventBinding ()
- (void)invalidate;
@end

@implementation PTPusherEventDispatcher {
  NSMutableDictionary *_bindings;
}

- (id)init
{
  if ((self = [super init])) {
    _bindings = [[NSMutableDictionary alloc] init];
  }
  return self;
}

#pragma mark - Managing event listeners

- (PTPusherEventBinding *)addEventListener:(id<PTEventListener>)listener forEventNamed:(NSString *)eventName
{
  NSMutableArray *bindingsForEvent = _bindings[eventName];
  
  if (bindingsForEvent == nil) {
    bindingsForEvent = [NSMutableArray array];
    _bindings[eventName] = bindingsForEvent;
  }
  PTPusherEventBinding *binding = [[PTPusherEventBinding alloc] initWithEventListener:listener eventName:eventName];
  [bindingsForEvent addObject:binding];
  
  return binding;
}

- (void)removeBinding:(PTPusherEventBinding *)binding
{
  NSMutableArray *bindingsForEvent = _bindings[binding.eventName];
  
  if ([bindingsForEvent containsObject:binding]) {
    [binding invalidate];
    [bindingsForEvent removeObject:binding];
  }
}

- (void)removeAllBindings
{
  for (NSArray *eventBindings in [_bindings allValues]) {
    for (PTPusherEventBinding *binding in eventBindings) {
	    [binding invalidate];
	  }
  }
  [_bindings removeAllObjects];
}

#pragma mark - Dispatching events

- (void)dispatchEvent:(PTPusherEvent *)event
{
  for (PTPusherEventBinding *binding in _bindings[event.name]) {
    [binding dispatchEvent:event];
  }
}

@end

@implementation PTPusherEventBinding {
  id<PTEventListener> _eventListener;
}

- (id)initWithEventListener:(id<PTEventListener>)eventListener eventName:(NSString *)eventName
{
  if ((self = [super init])) {
    _eventName = [eventName copy];
    _eventListener = eventListener;
  }
  return self;
}

- (void)invalidate
{
  if ([_eventListener respondsToSelector:@selector(invalidate)]) {
    [_eventListener invalidate];
  }
}

- (void)dispatchEvent:(PTPusherEvent *)event
{
  [_eventListener dispatchEvent:event];
}

@end
