//
//  PTPusherConnection.h
//  libPusher
//
//  Created by Luke Redpath on 13/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTPusherMacros.h"

@class PTPusherConnection;
@class PTPusherEvent;

@protocol PTPusherConnectionDelegate <NSObject>
- (BOOL)pusherConnectionWillConnect:(PTPusherConnection *)connection;
- (void)pusherConnectionDidConnect:(PTPusherConnection *)connection;
- (void)pusherConnection:(PTPusherConnection *)connection didDisconnectWithCode:(NSInteger)errorCode reason:(NSString *)reason wasClean:(BOOL)wasClean;
- (void)pusherConnection:(PTPusherConnection *)connection didFailWithError:(NSError *)error wasConnected:(BOOL)wasConnected;
- (void)pusherConnection:(PTPusherConnection *)connection didReceiveEvent:(PTPusherEvent *)event;
@end

extern NSString *const PTPusherConnectionEstablishedEvent;
extern NSString *const PTPusherConnectionPingEvent;

typedef enum {
  PTPusherConnectionDisconnecting = 0,
  PTPusherConnectionDisconnected,
  PTPusherConnectionConnecting,
  PTPusherConnectionAwaitingHandshake,
  PTPusherConnectionConnected
} PTPusherConnectionState;

@interface PTPusherConnection : NSObject

@property (nonatomic, weak) id<PTPusherConnectionDelegate> delegate;

/** Indicates if the connection is connected to the Pusher service.
 
 @return YES, if the socket has connected and a handshake has been received from the server, otherwise NO.
 */
@property (nonatomic, readonly, getter=isConnected) BOOL connected;

/** The unique socket ID for this connection.
 
 Every time the connection connects to the service, a new socket ID is received on handshake.
 
 This is normally used when authorizing private and presence channel subscriptions.
 */
@property (nonatomic, copy, readonly) NSString *socketID;

/** The Pusher service URL.
 */
@property (nonatomic, readonly) NSURL *URL;

/* If the connection does not receive any new data within the time specified,
 a ping event will be sent.
 
 Defaults to 120s as recommended by the Pusher protocol documentation. You should not
 normally need to change this.
 */
@property (nonatomic, assign) NSTimeInterval activityTimeout;

/* The amount of time to wait for a pong in response to a ping before disconnecting.
 
 Defaults to 30s as recommended by the Pusher protocol documentation. You should not
 normally need to change this.
 */
@property (nonatomic, assign) NSTimeInterval pongTimeout;

///------------------------------------------------------------------------------------/
/// @name Initialisation
///------------------------------------------------------------------------------------/

/** Creates a new PTPusherConnection instance.
 
 Connections are not opened immediately; an explicit call to connect is required.
 
 @param aURL      The websocket endpoint
 @param delegate  The delegate for this connection
 */
- (id)initWithURL:(NSURL *)aURL;

///------------------------------------------------------------------------------------/
/// @name Managing connections
///------------------------------------------------------------------------------------/

/** Establishes a web socket connection to the Pusher server.
 
 The delegate will only be sent a didConnect message when the web socket receives a 
 'connection_established' event from Pusher, regardless of the web socket's connection state.
 
 Calling this does nothing if already connected.
 */
- (void)connect;

/** Closes the web socket connection 
 
 Calling this does nothing if already disconnected.
 */
- (void)disconnect;

///------------------------------------------------------------------------------------/
/// @name Sending data
///------------------------------------------------------------------------------------/

/** Sends an object over the web socket connection.
 
 The object will be serialized to JSON before sending, so the object must be anything
 that can be converted into JSON (typically, any plist compatible object).
 */
- (void)send:(id)object;

@end
