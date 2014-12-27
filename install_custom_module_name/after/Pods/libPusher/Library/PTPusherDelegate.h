//
//  PTPusherDelegate.h
//  libPusher
//
//  Created by Luke Redpath on 22/03/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import "PTPusherMacros.h"

@class PTPusher;
@class PTPusherConnection;
@class PTPusherChannel;
@class PTPusherEvent;
@class PTPusherErrorEvent;

/** Implementing the PTPusherDelegate protocol lets you react to important events in the Pusher client's
  lifetime, such as connection and disconnection, channel subscription and errors.
 
 All of the delegate methods are optional; you only need to implement what is required for your app.
 
 It may be useful to assign a delegate to monitor the status of the connection; you could use this to update
 your user interface accordingly.
 */
@protocol PTPusherDelegate <NSObject>

@optional

///------------------------------------------------------------------------------------/
/// @name Connection handling
///------------------------------------------------------------------------------------/

/** Notifies the delegate that the PTPusher instance is about to connect to the Pusher service.
 
 @param pusher The PTPusher instance that is connecting.
 @param connection The connection for the pusher instance.
 @return NO to abort the connection attempt.
 */
- (BOOL)pusher:(PTPusher *)pusher connectionWillConnect:(PTPusherConnection *)connection;

/** Notifies the delegate that the PTPusher instance has connected to the Pusher service successfully.
 
 @param pusher The PTPusher instance that has connected.
 @param connection The connection for the pusher instance.
 */
- (void)pusher:(PTPusher *)pusher connectionDidConnect:(PTPusherConnection *)connection;

/** Notifies the delegate that the PTPusher instance has disconnected from the Pusher service.
 
 Clients should check the value of the willAttemptReconnect parameter before trying to reconnect manually. 
 In most cases, the client will try and automatically reconnect, depending on the error code returned by
 the Pusher service. 
 
 If willAttemptReconnect is YES, clients can expect a pusher:connectionWillReconnect:afterDelay: message 
 immediately following this one. Clients can return NO from that delegate method to cancel the automatic
 reconnection attempt.
 
 If the client has disconnected due to a fatal Pusher error (as indicated by the error code),
 willAttemptReconnect will be NO and the error domain will be `PTPusherFatalErrorDomain`.
 
 @param pusher The PTPusher instance that has connected.
 @param connection The connection for the pusher instance.
 @param error If the connection disconnected abnormally, error will be non-nil.
 @param willAttemptReconnect YES if the client will try and reconnect automatically.
 */
- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection didDisconnectWithError:(NSError *)error willAttemptReconnect:(BOOL)willAttemptReconnect;

/** Notifies the delegate that the PTPusher instance failed to connect to the Pusher service.
 
 In the case of connection failures, the client will *not* attempt to reconnect automatically.
 Instead, clients should implement this method and check the error code and manually reconnect
 the client if it makes sense to do so.
 
 @param pusher The PTPusher instance that has connected.
 @param connection The connection for the pusher instance.
 @param error The connection error.
 */
- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection failedWithError:(NSError *)error;

/** Notifies the delegate that the PTPusher instance will attempt to automatically reconnect.
 
 You may wish to use this method to keep track of the number of automatic reconnection attempts and abort after a fixed number.
 
 @param pusher The PTPusher instance that has connected.
 @param connection The connection for the pusher instance.
 @return NO if you do not want the client to attempt an automatic reconnection.
 */
- (BOOL)pusher:(PTPusher *)pusher connectionWillAutomaticallyReconnect:(PTPusherConnection *)connection afterDelay:(NSTimeInterval)delay;

///------------------------------------------------------------------------------------/
/// @name Channel subscription and authorization
///------------------------------------------------------------------------------------/

/** Notifies the delegate of the request that will be used to authorize access to a channel.
 
 When using the Pusher Javascript client, authorization typically relies on an existing session cookie
 on the server; when the Javascript client makes an AJAX POST to the server, the server can return
 the user's credentials based on their current session.
 
 When using libPusher, there will likely be no existing server-side session; authorization will
 need to happen by some other means (e.g. an authorization token or HTTP basic auth).
 
 By implementing this delegate method, you will be able to set any credentials as necessary by
 modifying the request as required (such as setting POST parameters or headers).
 
 @param pusher The PTPusher instance that is requesting authorization
 @param channel The channel that requires authorizing
 @param request A mutable URL request that will be POSTed to the configured `authorizationURL`
 */
- (void)pusher:(PTPusher *)pusher willAuthorizeChannel:(PTPusherChannel *)channel withRequest:(NSMutableURLRequest *)request;

/** Notifies the delegate that the PTPusher instance has subscribed to the specified channel.
 
 This method will be called after any channel authorization has taken place and when a subscribe event has been received.
 
 @param pusher The PTPusher instance that has connected.
 @param channel The channel that was subscribed to.
 */
- (void)pusher:(PTPusher *)pusher didSubscribeToChannel:(PTPusherChannel *)channel;

/** Notifies the delegate that the PTPusher instance has unsubscribed from the specified channel.
 
 This method will be called immediately after unsubscribing from a channel.
 
 @param pusher The PTPusher instance that has connected.
 @param channel The channel that was unsubscribed from.
 */
- (void)pusher:(PTPusher *)pusher didUnsubscribeFromChannel:(PTPusherChannel *)channel;

/** Notifies the delegate that the PTPusher instance failed to subscribe to the specified channel.
 
 The most common reason for subscribing failing is authorization failing for private/presence channels.
 
 @param pusher The PTPusher instance that has connected.
 @param channel The channel that was subscribed to.
 @param error The error returned when attempting to subscribe.
 */
- (void)pusher:(PTPusher *)pusher didFailToSubscribeToChannel:(PTPusherChannel *)channel withError:(NSError *)error;

///------------------------------------------------------------------------------------/
/// @name Errors
///------------------------------------------------------------------------------------/

/** Notifies the delegate that an error event has been received.
 
 If a client is binding to all events, either through the client or using NSNotificationCentre, they will also
 receive notification of this event like any other.
 
 @param pusher The PTPusher instance that received the event.
 @param errorEvent The error event.
 */
- (void)pusher:(PTPusher *)pusher didReceiveErrorEvent:(PTPusherErrorEvent *)errorEvent;


///------------------------------------------------------------------------------------/
/// @name Deprecated methods
///------------------------------------------------------------------------------------/

/** Notifies the delegate that the PTPusher instance has disconnected from the Pusher service.
 
 @deprecated Use pusher:connection:didDisconnectWithError:willAttemptReconnect:
 @param pusher The PTPusher instance that has connected.
 @param connection The connection for the pusher instance.
 */
- (void)pusher:(PTPusher *)pusher connectionDidDisconnect:(PTPusherConnection *)connection __PUSHER_DEPRECATED__;

/** Notifies the delegate that the PTPusher instance has disconnected from the Pusher service.
 
 @deprecated Use pusher:connection:didDisconnectWithError:willAttemptReconnect:
 @param pusher The PTPusher instance that has connected.
 @param connection The connection for the pusher instance.
 @param error If the connection disconnected abnormally, error will be non-nil.
 */
- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection didDisconnectWithError:(NSError *)error __PUSHER_DEPRECATED__;

/** Notifies the delegate of the request that will be used to authorize access to a channel.
 
 When using the Pusher Javascript client, authorization typically relies on an existing session cookie
 on the server; when the Javascript client makes an AJAX POST to the server, the server can return
 the user's credentials based on their current session.
 
 When using libPusher, there will likely be no existing server-side session; authorization will
 need to happen by some other means (e.g. an authorization token or HTTP basic auth).
 
 By implementing this delegate method, you will be able to set any credentials as necessary by
 modifying the request as required (such as setting POST parameters or headers).
 */
- (void)pusher:(PTPusher *)pusher willAuthorizeChannelWithRequest:(NSMutableURLRequest *)request __PUSHER_DEPRECATED__;

@end
