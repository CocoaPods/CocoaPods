//
//  PTPusherEventPublisher.h
//  libPusher
//
//  Created by Luke Redpath on 13/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PTPusherEvent;
@class PTPusherEventBinding;

typedef void (^PTPusherEventBlockHandler) (PTPusherEvent *);

/** Describes an object that provides events that can be bound to.
 
 Events in Pusher form the basis of all communication with the service. They are
 named messages that can carry arbitrary user data. All events in libPusher are
 represented by the class `PTPusherEvent`.
 
 An object that implements this protocol allows for binding to events. There are
 currently two classes that implement this protocol: `PTPusher` and `PTPusherChannel`.
 
 There are two primary binding mechanisms: target/action based and block-based. Which
 one you use depends entirely on the requirements of your application.
 */
@protocol PTPusherEventBindings <NSObject>

/** Binds to the named event using the target/action mechanism.
 
 When the named event is received, the specified selector will be called on target, passing
 the `PTPusherEvent` as the only argument.
 
 The following code snippet sets up a binding for the event "new-message" on any channel:
 
    [pusher bindToEventNamed:@"new-message" target:self action:@selector(handleNewMessageEvent:)];
 
 Then the event is triggered, the event will be dispatched to the target/action pair:
 
    - (void)handleNewMessageEvent:(PTPusherEvent *)event
    {
      // do something with event
    }
 */
- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName target:(id)target action:(SEL)selector;

/** Binds to the named event using a block callback.
 
 When the event is received, the block will be called with the `PTPusherEvent` as the only block argument.
 
 The following code snippet sets up a binding for the event "new-message" on any channel and handles that
 event when it is triggered:
 
    [pusher bindToEventNamed:@"new-message" handleWithBlock:^(PTPusherEvent *event) {
      // do something with event
    }];
 
 The callback blocks will be dispatched asynchronously using Grand Central Dispatch on the main queue.
 */
- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName handleWithBlock:(PTPusherEventBlockHandler)block;

/** Binds to the named event using a block callback.
 
 Works the same as bindToEventNamed:handleWithBlock: but dispatches the callback block on the specified
 Grand Central Dispatch queue.
 
 You can use this method if you wish to handle events in a background or custom priority queue.
 */
- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName handleWithBlock:(PTPusherEventBlockHandler)block queue:(dispatch_queue_t)queue;

/** Removes the specified binding.
 
 Any further events will not trigger any callbacks after the binding has been removed.
 */
- (void)removeBinding:(PTPusherEventBinding *)binding;

/** Removes all bindings that have been set up.
 
  Any retained references to PTPusherEventBinding objects will become invalid.
 */
- (void)removeAllBindings;

@end
