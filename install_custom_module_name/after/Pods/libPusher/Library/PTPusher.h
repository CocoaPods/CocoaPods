//
//  PTPusher.h
//  PusherEvents
//
//  Created by Luke Redpath on 22/03/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTPusherDelegate.h"
#import "PTPusherConnection.h"
#import "PTPusherEventPublisher.h"
#import "PTPusherPresenceChannelDelegate.h"
#import "PTPusherChannelAuthorizationDelegate.h"

/** The name of the notification posted when PTPusher receives an event.
 *
 * This notification will be posted before any other binding is executed.
 *
 */
extern NSString *const PTPusherEventReceivedNotification;

/** The key of the PTPusherEvent object in the PTPusherEventReceivedNotification userInfo dictionary.
 */
extern NSString *const PTPusherEventUserInfoKey;

/** The error domain for all non-fatal PTPusher errors.
 *
 * These will be any errors not in the range of 4000-4099.
 *
 * See: http://pusher.com/docs/pusher_protocol#error-codes
 */
extern NSString *const PTPusherErrorDomain;

/** The error domain for all fatal PTPusher errors.
 *
 * These will be any errors in the range of 4000-4099. If your
 * connection fails or disconnects with one of these errors, you
 * will typically not be able to reconnect immediately (or at all).
 *
 * See: http://pusher.com/docs/pusher_protocol#error-codes
 */
extern NSString *const PTPusherFatalErrorDomain;

/** The key for any underlying PTPusherEvent associated with a PTPusher error's userInfo dictionary.
 */
extern NSString *const PTPusherErrorUnderlyingEventKey;

@class PTPusherChannel;
@class PTPusherPresenceChannel;
@class PTPusherPrivateChannel;
@class PTPusherEventDispatcher;

/** A PTPusher object provides a high level API for communicating with the Pusher service.

 A single instance of `PTPusher` can be used to connect to the service, subscribe to channels and send
 events.

 To create an instance of PTPusher, you will need your Pusher API key. This can be obtained from your account
 dashboard.

 PTPusher's delegate methods allow an object to receive important events in the client and connection's
 lifecycle, such as connection, disconnection, reconnection and channel subscribe/unsubscribe events.

 Whilst PTPusher exposes it's connection object as a readonly property, there is no need to manage or
 create this connection yourself. The connection can be queried for it's current connection state and
 socket ID if needed.

 PTPusher aims to mirror the Pusher Javascript client API as much as possible although whilst the
 Javascript API uses event binding for any system events, such as channel subscription
 libPusher uses standard Cocoa and Objective-C patterns such as delegation and notification where
 it makes sense to do so.

 PTPusher will attempt to try and remain connected whenever possible. If the connection disconnects,
 then depending on the error code returned, it will either try to reconnect immediately, reconnect after
 a configured delay or not reconnect at all. See the project README for more information on this.

 Note: due to various problems people have had connecting to Pusher without SSL over a 3G connection,
 it is highly recommend that you use SSL. For this reason, SSL is enabled by default.
 */
@interface PTPusher : NSObject <PTPusherConnectionDelegate, PTPusherEventBindings>

///------------------------------------------------------------------------------------/
/// @name Properties
///------------------------------------------------------------------------------------/

/** The object that acts as the delegate for the receiving instance.

 The delegate must implement the PTPusherDelegate protocol. The delegate is not retained.
 */
@property (nonatomic, weak) id<PTPusherDelegate> delegate;

/** Specifies the delay between reconnection attempts. Defaults to 5 seconds.
 *
 * If the client disconnects for an unknown reason, the client will attempt to automatically
 * reconnect after this delay has elapsed.
 *
 * PTPusher will not automatically reconnect if `disconnect` is called explicitly and it
 * will also handle reconnection differently if disconnection happens with a known error code,
 * as per the Pusher protocol documentation.
 */
@property (nonatomic, assign) NSTimeInterval reconnectDelay;

/** The connection object for this client.

 Each instance uses a single connection only. Most clients will likely only ever need a single
 PTPusher object and therefore a single connection.

 The connection is exposed to provide access to it's socketID and connection state. Clients
 should not attempt to manage this connection directly.
 */
@property (nonatomic, strong, readonly) PTPusherConnection *connection;

/** The authorization URL for private subscriptions.

 All private channels (including presence channels) require authorization in order to subscribe.

 Authorization happens on your own server. When subscribing to a private or presence channel,
 an authorization POST request will be sent to the URL specified by this property.

 Attempting to subscribe to a private or presence channel without setting this property will
 result in an assertion error.

 For more information on channel authorization, [see the Pusher documentation website](http://pusher.com/docs/authenticating_users).
 */
@property (nonatomic, strong) NSURL *authorizationURL;

/** Used to authorize access to private and presence channels.
 *
 * Whenever a request to subscribe to a private or presence channel is made, the client will ask
 * the channelAuthorizationDelegate delegate to perform the authorization and call back to the client
 * when it has finished.
 *
 * Note: if you set this property, the built-in server based authorization will not be performed
 * and it is up to you to correctly implement the delegate protocol to authorize channel access.
 *
 * @see PTPusherChannelAuthorizationDelegate
 */
@property (nonatomic, weak) id<PTPusherChannelAuthorizationDelegate> channelAuthorizationDelegate;

///------------------------------------------------------------------------------------/
/// @name Creating new instances
///------------------------------------------------------------------------------------/

/** Initialises a new instance. This is the designated initialiser.
 *
 * Clients should typically use one of the factory methods provided, which will configure the
 * connection object for you using the standard Pusher host and port.
 *
 * If you need to connect to Pusher using an alternative endpoint URL, e.g. for testing
 * purposes, then you can initialise an instance of `PTPusherConnection` with an appropriate
 * URL and pass it into this method.
 *
 * @param connection An initialised connection for this instance.
 */
- (id)initWithConnection:(PTPusherConnection *)connection;

/** Returns a new PTPusher instance with a connection configured with the given key.

 @param key         Your application's API key. It can be found in the API Access section of your application within the Pusher user dashboard.
 @param delegate    The delegate for this instance
 @param isEncrypted If yes, a secure connection over SSL will be established.
 */
+ (instancetype)pusherWithKey:(NSString *)key delegate:(id<PTPusherDelegate>)delegate encrypted:(BOOL)isEncrypted;

/** Returns a new PTPusher instance with a connection configured with the given key and allows to set different cluster

 @param key         Your application's API key. It can be found in the API Access section of your application within the Pusher user dashboard.
 @param delegate    The delegate for this instance
 @param isEncrypted If yes, a secure connection over SSL will be established.
 @param cluster     If set, connects to the provided cluster
 */

+ (instancetype)pusherWithKey:(NSString *)key delegate:(id<PTPusherDelegate>)delegate encrypted:(BOOL)isEncrypted cluster:(NSString *) cluster;

/** Returns a new PTPusher instance with an connection configured with the given key.

 Instances created using this method will be encrypted by default. This requires SSL access on your account,
 which is generally recommended for mobile connections.

 @param key       Your application's API key. It can be found in the API Access section of your application within the Pusher user dashboard.
 @param delegate  The delegate for this instance
 */
+ (instancetype)pusherWithKey:(NSString *)key delegate:(id<PTPusherDelegate>)delegate;

///------------------------------------------------------------------------------------/
/// @name Managing the connection
///------------------------------------------------------------------------------------/

/** Establishes a connection to the Pusher server.

 If already connected, this method does nothing.
 */
- (void)connect;

/** Disconnects from the Pusher server.

 If already disconnected, this method does nothing. PTPusher will not attempt to
 reconnect if you call this method. To reconnect, you must call `connect` again.
 */
- (void)disconnect;

///------------------------------------------------------------------------------------/
/// @name Subscribing to channels
///------------------------------------------------------------------------------------/

/** Subscribes to the named channel.

 This method can be used to subscribe to any type of channel, including private and
 presence channels by including the appropriate channel name prefix.

 Note: this method returns the channel object immediately, but it might not yet be
 subscribed - subscription is asynchronous. You do not have to wait for a channel
 to become subscribed before setting up event bindings. If you care about when the
 channel is subscribed, you can use key-value observing on it's `isSubscribed`
 property or implement the appropriate `PTPusherDelegate` method.

 It is valid to call this (or any of the other subscribe methods) while the client is
 not connected. All channels default to unsubscribed and any subcribed channels will
 become implicitly unsubscribed if the client disconnects. When the client connects,
 all channels will be re-subscribed to automatically.

 When you subscribe to a channel, `PTPusher` keeps a strong reference to that channel
 and maintains that reference until the channel is explicitly unsubscribed (by calling
 `-[PTPusherChannel unsubscribe]`.

 If you maintain your own strong reference to the returned channel object, you should
 be aware that once unsubscribed, the object will no longer be of any use. For this
 reason you should be wary of passing around strong references to channels that you
 may unsubscribe from.

 For more information on channel lifetime, see the README.

 @param name The name of the channel to subscribe to.
 @returns The channel object.
 */
- (PTPusherChannel *)subscribeToChannelNamed:(NSString *)name;

/** Subscribes to the named private channel.

 The "private-" prefix should be excluded from the name; it will be added automatically.

 @param name The name of the channel (without the private prefix) to subscribe to.
 */
- (PTPusherPrivateChannel *)subscribeToPrivateChannelNamed:(NSString *)name;

/** Subscribes to the named presence channel.

 The "presence-" prefix should be excluded from the name; it will be added automatically.

 @param name The name of the channel (without the presence prefix) to subscribe to.
 */
- (PTPusherPresenceChannel *)subscribeToPresenceChannelNamed:(NSString *)name;

/** Subscribes to the named presence channel.

 The "presence-" prefix should be excluded from the name; it will be added automatically.

 Whilst the presence delegate can be set on the channel after it is returned, to ensure
 events are not missed, it is advised that you call this method and specify a delegate. The
 delegate will be assigned before subscription happens.

 @param name The name of the channel (without the presence prefix) to subscribe to.
 @param presenceDelegate The presence delegate for this channel.
 */
- (PTPusherPresenceChannel *)subscribeToPresenceChannelNamed:(NSString *)name delegate:(id<PTPusherPresenceChannelDelegate>)presenceDelegate;

/** Unsubscribes from all Pusher channels and stops holding reference to them.

 If the channels are not referenced anywhere else, they will be deallocated from memory.

 If there are no channels at all, nothing will change.
 */
- (void)unsubscribeAllChannels;

/** Returns a previously subscribed channel with the given name.

 If the channel specified has not been subscribed to previously, or has been explicilty
 unsubscribed from, this will return nil.

 This method will return channels that have become implicitly unsubscribed from if the
 client has disconnected.

 @param name The name of the channel required.
 */
- (PTPusherChannel *)channelNamed:(NSString *)name;


/** Returns a shallow copy dictionary of previously subscribed channels.

 */
- (NSDictionary *)subscribedChannels;

///------------------------------------------------------------------------------------/
/// @name Publishing events
///------------------------------------------------------------------------------------/

/** Sends an event directly over the connection's socket.

 Whilst Pusher provides a REST API for publishing events, it also supports the sending of
 events directly from clients over the client's existing connection.

 Client events have the following restrictions:

 + The user must be subscribed to the channel that the event is being triggered on.

 + Client events can only be triggered on private and presence channels because they require authentication.

 + Client events must be prefixed by client-. Events with any other prefix will be rejected by the Pusher server, as will events sent to channels to which the client is not subscribed.

 This method does nothing to enforce the first two restrictions. It is instead recommended that
 you use the `PTPusherChannel` event triggering API rather than calling this method directly.

 @warning Note: This Pusher feature is currently in beta and requires enabling on your account.
 */
- (void)sendEventNamed:(NSString *)name data:(id)data channel:(NSString *)channelName;

@end

