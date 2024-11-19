//
//  PTPusherEvent.h
//  PusherEvents
//
//  Created by Luke Redpath on 22/03/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const PTPusherDataKey;
extern NSString *const PTPusherEventKey;
extern NSString *const PTPusherChannelKey;

/** A value object representing a Pusher event.
 
 All events dispatched by libPusher (via either bindings or notifications) will be represented
 by instances of this class.
 */
@interface PTPusherEvent : NSObject

///------------------------------------------------------------------------------------/
/// @name Properties
///------------------------------------------------------------------------------------/

/** The event name.
 */
@property (nonatomic, readonly) NSString *name;

/** The channel that this event originated from.
 */
@property (strong, nonatomic, readonly) NSString *channel;

/** The event data.
 
 Event data will typically be any kind of object that can be represented as JSON, often
 an NSArray or NSDictionary but can be a simple string.
 */
@property (strong, nonatomic, readonly) id data;

/** The time the event was received.
 */
@property (nonatomic, readonly, strong) NSDate *timeReceived;

- (id)initWithEventName:(NSString *)name channel:(NSString *)channel data:(id)data;
+ (instancetype)eventFromMessageDictionary:(NSDictionary *)dictionary;

@end

typedef enum {
  PTPusherErrorUnknown = -1,
  PTPusherErrorSSLRequired = 4000,
  PTPusherErrorApplicationUnknown = 4001,
  PTPusherErrorApplicationDisabled = 4002
} PTPusherServerErrorCodes;

/** A special sub-class of Pusher event, representing pusher:error events.
 
 This will be yielded to the Pusher client delegate as well as through the normal event
 dispatch mechanism.
 
 This class adds some convenient properties for accessing error details.
 */
@interface PTPusherErrorEvent : PTPusherEvent

/** A textual description of the error.
 */
@property (weak, nonatomic, readonly) NSString *message;

/** The error code. See PTPusherServerErrorCodes for available errors.
 */
@property (nonatomic, readonly) NSInteger code;

@end
