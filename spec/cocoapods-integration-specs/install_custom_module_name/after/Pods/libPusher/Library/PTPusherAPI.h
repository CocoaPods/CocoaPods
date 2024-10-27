//
//  PTPusherAPI.h
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

/** A simple interface to the Pusher REST API.
 
 This functionality used to be part of the main PTPusher library but
 has been extracted into a standalone component.
 
 The PTPusher client has support for client-sent events but if your account does not
 support these you can use this class to send events using the standard Pusher REST API.
 
 As well as your Pusher API key, you will also need your app ID and secret key
 for signing requests. You should take care not to expose these in your application's
 header files.
 */
@interface PTPusherAPI : NSObject 

///------------------------------------------------------------------------------------/
/// @name Initialisation
///------------------------------------------------------------------------------------/

/** Designated initializer
 
 You will need your account credentials which can be located on your account dashboard.
 
 @param aKey Your Pusher API key
 @param anAppID Your Pusher app ID
 @param aSecretKey Your Pusher app secret.
 */
- (id)initWithKey:(NSString *)aKey appID:(NSString *)anAppID secretKey:(NSString *)aSecretKey;

///------------------------------------------------------------------------------------/
/// @name Triggering events
///------------------------------------------------------------------------------------/

/** Triggers an event on the specified channel.
 
 The event data will be converted to JSON format so needs to be any object that can be
 transformed into JSON (typically any plist-compatible object).
 
 @param eventName   The name of the event to trigger.
 @param channelName The channel the event should be triggered on.
 @param eventData   The JSON-compatible data object for the event.
 */
- (void)triggerEvent:(NSString *)eventName onChannel:(NSString *)channelName data:(id)eventData socketID:(NSString *)socketID;

@end
