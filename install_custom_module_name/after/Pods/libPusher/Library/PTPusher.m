//
//  PTPusher.m
//  PusherEvents
//
//  Created by Luke Redpath on 22/03/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import "PTPusher.h"
#import "PTEventListener.h"
#import "PTPusherEvent.h"
#import "PTPusherChannel.h"
#import "PTPusherEventDispatcher.h"
#import "PTTargetActionEventListener.h"
#import "PTBlockEventListener.h"
#import "PTPusherErrors.h"
#import "PTPusherChannelAuthorizationOperation.h"
#import "PTPusherChannel_Private.h"

#define kPUSHER_HOST @"ws.pusherapp.com"

typedef NS_ENUM(NSUInteger, PTPusherAutoReconnectMode) {
  PTPusherAutoReconnectModeNoReconnect,
  PTPusherAutoReconnectModeReconnectImmediately,
  PTPusherAutoReconnectModeReconnectWithConfiguredDelay,
  PTPusherAutoReconnectModeReconnectWithBackoffDelay
};

NSURL *PTPusherConnectionURL(NSString *host, NSString *key, NSString *clientID, BOOL secure);

NSString *const PTPusherEventReceivedNotification = @"PTPusherEventReceivedNotification";
NSString *const PTPusherEventUserInfoKey          = @"PTPusherEventUserInfoKey";
NSString *const PTPusherErrorDomain               = @"PTPusherErrorDomain";
NSString *const PTPusherFatalErrorDomain          = @"PTPusherFatalErrorDomain";
NSString *const PTPusherErrorUnderlyingEventKey   = @"PTPusherErrorUnderlyingEventKey";

/** The Pusher protocol version, used to determined which features
 are supported.
 */
#define kPTPusherClientProtocolVersion 6

NSURL *PTPusherConnectionURL(NSString *host, NSString *key, NSString *clientID, BOOL encrypted)
{
  NSString *scheme = ((encrypted == YES) ? @"wss" : @"ws");
  NSString *URLString = [NSString stringWithFormat:@"%@://%@/app/%@?client=%@&protocol=%d&version=%@", 
                         scheme, host, key, clientID, kPTPusherClientProtocolVersion, kPTPusherClientLibraryVersion];
  return [NSURL URLWithString:URLString];
}

#define kPTPusherDefaultReconnectDelay 5.0

@interface PTPusher ()
@property (nonatomic, strong, readwrite) PTPusherConnection *connection;
@end

#pragma mark -

@implementation PTPusher {
  NSOperationQueue *authorizationQueue;
  NSUInteger _numberOfReconnectAttempts;
  NSUInteger _maximumNumberOfReconnectAttempts;
  PTPusherEventDispatcher *dispatcher;
  NSMutableDictionary *channels;
}

- (id)initWithConnection:(PTPusherConnection *)connection connectAutomatically:(BOOL)connectAutomatically
{
  if ((self = [self initWithConnection:connection])) {
    if (connectAutomatically) {
      [self connect];
    }
  }
  return self;
}

- (id)initWithConnection:(PTPusherConnection *)connection
{
  if (self = [super init]) {
    dispatcher = [[PTPusherEventDispatcher alloc] init];
    channels = [[NSMutableDictionary alloc] init];
    
    authorizationQueue = [[NSOperationQueue alloc] init];
    authorizationQueue.maxConcurrentOperationCount = 5;
    authorizationQueue.name = @"com.pusher.libPusher.authorizationQueue";
    
    self.connection = connection;
    self.connection.delegate = self;
    self.reconnectDelay = kPTPusherDefaultReconnectDelay;
    
    /* Three reconnection attempts should be more than enough attempts
     * to reconnect where the user has simply locked their device or
     * backgrounded the app.
     *
     * If there is no internet connection, we will only end up retrying
     * once as after the first failure we will no longer auto-retry.
     *
     * We may consider making this user-customisable in future but not 
     * for now.
     */
    _maximumNumberOfReconnectAttempts = 3;
  }
  return self;
}

+ (id)pusherWithKey:(NSString *)key delegate:(id<PTPusherDelegate>)delegate
{
  return [self pusherWithKey:key delegate:delegate encrypted:YES];
}

+ (id)pusherWithKey:(NSString *)key delegate:(id<PTPusherDelegate>)delegate encrypted:(BOOL)isEncrypted
{
  NSURL *serviceURL = PTPusherConnectionURL(kPUSHER_HOST, key, @"libPusher", isEncrypted);
  PTPusherConnection *connection = [[PTPusherConnection alloc] initWithURL:serviceURL];
  PTPusher *pusher = [[self alloc] initWithConnection:connection];
  pusher.delegate = delegate;
  return pusher;
}

#pragma mark - Deprecated methods

+ (id)pusherWithKey:(NSString *)key connectAutomatically:(BOOL)connectAutomatically
{
  PTPusher *client = [self pusherWithKey:key delegate:nil encrypted:YES];
  if (connectAutomatically) {
    [client connect];
  }
  return client;
}

+ (id)pusherWithKey:(NSString *)key connectAutomatically:(BOOL)connectAutomatically encrypted:(BOOL)isEncrypted
{
  PTPusher *client = [self pusherWithKey:key delegate:nil encrypted:isEncrypted];
  if (connectAutomatically) {
    [client connect];
  }
  return client;
}

- (void)dealloc;
{
  [_connection setDelegate:nil];
  [_connection disconnect];
}

#pragma mark - Connection management

- (void)setReconnectDelay:(NSTimeInterval)reconnectDelay
{
  _reconnectDelay = MAX(reconnectDelay, 1);
}

- (void)connect
{
  _numberOfReconnectAttempts = 0;
  [self.connection connect];
}

- (void)disconnect
{
  [self.connection disconnect];
}

#pragma mark - Binding to events

- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName target:(id)target action:(SEL)selector
{
  return [dispatcher addEventListenerForEventNamed:eventName target:target action:selector];
}

- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName handleWithBlock:(PTPusherEventBlockHandler)block
{
  return [self bindToEventNamed:eventName handleWithBlock:block queue:dispatch_get_main_queue()];
}

- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName handleWithBlock:(PTPusherEventBlockHandler)block queue:(dispatch_queue_t)queue
{
  return [dispatcher addEventListenerForEventNamed:eventName block:block queue:queue];
}

- (void)removeBinding:(PTPusherEventBinding *)binding
{
  [dispatcher removeBinding:binding];
}

- (void)removeAllBindings
{
  [dispatcher removeAllBindings];
}

#pragma mark - Subscribing to channels

- (PTPusherChannel *)subscribeToChannelNamed:(NSString *)name
{
  PTPusherChannel *channel = channels[name];
  if (channel == nil) {
    channel = [PTPusherChannel channelWithName:name pusher:self]; 
    channels[name] = channel;
  }
  // private/presence channels require a socketID to authenticate
  if (self.connection.isConnected && self.connection.socketID) {
    [self subscribeToChannel:channel];
  }
  return channel;
}

- (PTPusherPrivateChannel *)subscribeToPrivateChannelNamed:(NSString *)name
{
  return (PTPusherPrivateChannel *)[self subscribeToChannelNamed:[NSString stringWithFormat:@"private-%@", name]];
}

- (PTPusherPresenceChannel *)subscribeToPresenceChannelNamed:(NSString *)name
{
  return (PTPusherPresenceChannel *)[self subscribeToChannelNamed:[NSString stringWithFormat:@"presence-%@", name]];
}

- (PTPusherPresenceChannel *)subscribeToPresenceChannelNamed:(NSString *)name delegate:(id<PTPusherPresenceChannelDelegate>)presenceDelegate
{
  PTPusherPresenceChannel *channel = [self subscribeToPresenceChannelNamed:name];
  channel.presenceDelegate = presenceDelegate;
  return channel;
}

- (PTPusherChannel *)channelNamed:(NSString *)name
{
  return channels[name];
}

/* This is only called when a client explicitly unsubscribes from a channel
 * by calling either [channel unsubscribe] or using the deprecated API 
 * [client unsubscribeFromChannel:].
 *
 * This effectively ends the lifetime of a channel: the client will remove it
 * from it's channels collection and all bindings will be removed. If no other
 * code outside of libPusher has a strong reference to the channel, it will
 * be deallocated.
 *
 * This is different to implicit unsubscribes (where the connection has been lost)
 * where the channel will object will remain and be re-subscribed when connection
 * is re-established.
 *
 * A pusher:unsubscribe event will only be sent if there is a connection, otherwise
 * it's not necessary as the channel is already implicitly unsubscribed due to the
 * disconnection.
 */
- (void)__unsubscribeFromChannel:(PTPusherChannel *)channel
{
  NSParameterAssert(channel != nil);
  
  [channel removeAllBindings];
  
  if (self.connection.isConnected) {
    [self sendEventNamed:@"pusher:unsubscribe"
                    data:@{@"channel": channel.name}];
  }
  
  [channels removeObjectForKey:channel.name];
  
  if ([self.delegate respondsToSelector:@selector(pusher:didUnsubscribeFromChannel:)]) {
    [self.delegate pusher:self didUnsubscribeFromChannel:channel];
  }
}

- (void)unsubscribeFromChannel:(PTPusherChannel *)channel
{
  [self __unsubscribeFromChannel:channel];
}

- (void)subscribeToChannel:(PTPusherChannel *)channel
{
  [channel authorizeWithCompletionHandler:^(BOOL isAuthorized, NSDictionary *authData, NSError *error) {
    if (isAuthorized && self.connection.isConnected) {
      [channel subscribeWithAuthorization:authData];
    }
    else {
      if (error == nil) {
        error = [NSError errorWithDomain:PTPusherErrorDomain code:PTPusherSubscriptionUnknownAuthorisationError userInfo:nil];
      }
      
      if ([self.delegate respondsToSelector:@selector(pusher:didFailToSubscribeToChannel:withError:)]) {
        [self.delegate pusher:self didFailToSubscribeToChannel:channel withError:error];
      }
    }
  }];
}

- (void)subscribeAll
{
  for (PTPusherChannel *channel in [channels allValues]) {
    [self subscribeToChannel:channel];
  }
}

#pragma mark - Sending events

- (void)sendEventNamed:(NSString *)name data:(id)data
{
  [self sendEventNamed:name data:data channel:nil];
}

- (void)sendEventNamed:(NSString *)name data:(id)data channel:(NSString *)channelName
{
  NSParameterAssert(name);
  
  if (self.connection.isConnected == NO) {
    NSLog(@"Warning: attempting to send event while disconnected. Event will not be sent.");
    return;
  }
  
  NSMutableDictionary *payload = [NSMutableDictionary dictionary];  
  payload[PTPusherEventKey] = name;
  
  if (data) {
    payload[PTPusherDataKey] = data;
  }
  
  if (channelName) {
    payload[PTPusherChannelKey] = channelName;
  }
  [self.connection send:payload];
}

#pragma mark - PTPusherConnection delegate methods

- (BOOL)pusherConnectionWillConnect:(PTPusherConnection *)connection
{
  if ([self.delegate respondsToSelector:@selector(pusher:connectionWillConnect:)]) {
    return [self.delegate pusher:self connectionWillConnect:connection];
  }
  return YES;
}

- (void)pusherConnectionDidConnect:(PTPusherConnection *)connection
{
  _numberOfReconnectAttempts = 0;
  
  if ([self.delegate respondsToSelector:@selector(pusher:connectionDidConnect:)]) {
    [self.delegate pusher:self connectionDidConnect:connection];
  }
  
  [self subscribeAll];
}

- (void)pusherConnection:(PTPusherConnection *)connection didDisconnectWithCode:(NSInteger)errorCode reason:(NSString *)reason wasClean:(BOOL)wasClean
{
  NSError *error = nil;
  
  if (errorCode > 0) {
    if (reason == nil) {
        reason = @"Unknown error"; // not sure what could cause this to be nil, but just playing it safe
    }
    
    NSString *errorDomain = PTPusherErrorDomain;

    if (errorCode >= 400 && errorCode <= 4099) {
      errorDomain = PTPusherFatalErrorDomain;
    }
    
    // check for error codes based on the Pusher Websocket protocol see http://pusher.com/docs/pusher_protocol
    error = [NSError errorWithDomain:errorDomain code:errorCode userInfo:@{@"reason": reason}];
    
    // 4000-4099 -> The connection SHOULD NOT be re-established unchanged.
    if (errorCode >= 4000 && errorCode <= 4099) {
      [self handleDisconnection:connection error:error reconnectMode:PTPusherAutoReconnectModeNoReconnect];
    } else
    // 4200-4299 -> The connection SHOULD be re-established immediately.
    if(errorCode >= 4200 && errorCode <= 4299) {
      [self handleDisconnection:connection error:error reconnectMode:PTPusherAutoReconnectModeReconnectImmediately];
    }
    
    else {
      // i.e. 4100-4199 -> The connection SHOULD be re-established after backing off.
      [self handleDisconnection:connection error:error reconnectMode:PTPusherAutoReconnectModeReconnectWithBackoffDelay];
    }
  }
  else {
    [self handleDisconnection:connection error:error reconnectMode:PTPusherAutoReconnectModeReconnectWithConfiguredDelay];
  }
}

- (void)pusherConnection:(PTPusherConnection *)connection didFailWithError:(NSError *)error wasConnected:(BOOL)wasConnected
{
  if (wasConnected) {
    [self handleDisconnection:connection error:error reconnectMode:PTPusherAutoReconnectModeReconnectImmediately];
  }
  else {
    if ([self.delegate respondsToSelector:@selector(pusher:connection:failedWithError:)]) {
      [self.delegate pusher:self connection:connection failedWithError:error];
    }
  }
}

- (void)pusherConnection:(PTPusherConnection *)connection didReceiveEvent:(PTPusherEvent *)event
{
  if ([event isKindOfClass:[PTPusherErrorEvent class]]) {
    if ([self.delegate respondsToSelector:@selector(pusher:didReceiveErrorEvent:)]) {
      [self.delegate pusher:self didReceiveErrorEvent:(PTPusherErrorEvent *)event];
    }
  }
  
  if (event.channel) {
    [channels[event.channel] dispatchEvent:event];
  }
  [dispatcher dispatchEvent:event];
  
  [[NSNotificationCenter defaultCenter] 
     postNotificationName:PTPusherEventReceivedNotification
     object:self 
     userInfo:@{PTPusherEventUserInfoKey: event}];
}

- (void)handleDisconnection:(PTPusherConnection *)connection error:(NSError *)error reconnectMode:(PTPusherAutoReconnectMode)reconnectMode
{
  [authorizationQueue cancelAllOperations];
  
  for (PTPusherChannel *channel in [channels allValues]) {
    [channel handleDisconnect];
  }
  
  if ([self.delegate respondsToSelector:@selector(pusher:connectionDidDisconnect:)]) { // deprecated call
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSLog(@"pusher:connectionDidDisconnect: is deprecated and will be removed in 1.6. Use pusher:connection:didDisconnectWithError:willAttemptReconnect: instead.");
    [self.delegate pusher:self connectionDidDisconnect:connection];
#pragma clang diagnostic pop
  }

  if ([self.delegate respondsToSelector:@selector(pusher:connection:didDisconnectWithError:)]) { // deprecated call
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSLog(@"pusher:connectionDidDisconnectWithError: is deprecated and will be removed in 1.6. Use pusher:connection:didDisconnectWithError:willAttemptReconnect: instead.");
    [self.delegate pusher:self connection:connection didDisconnectWithError:error];
#pragma clang diagnostic pop
  }
  
  BOOL willReconnect = NO;
  
  if (reconnectMode > PTPusherAutoReconnectModeNoReconnect && _numberOfReconnectAttempts < _maximumNumberOfReconnectAttempts) {
    willReconnect = YES;
  }
    
  if ([self.delegate respondsToSelector:@selector(pusher:connection:didDisconnectWithError:willAttemptReconnect:)]) {
    [self.delegate pusher:self connection:connection didDisconnectWithError:error willAttemptReconnect:willReconnect];
  }
  
  if (willReconnect) {
    [self reconnectUsingMode:reconnectMode];
  }
}

#pragma mark - Private

- (void)beginAuthorizationOperation:(PTPusherChannelAuthorizationOperation *)operation
{
  [authorizationQueue addOperation:operation];
}

- (void)reconnectUsingMode:(PTPusherAutoReconnectMode)reconnectMode
{
  _numberOfReconnectAttempts++;
  
  NSTimeInterval delay;
  
  switch (reconnectMode) {
    case PTPusherAutoReconnectModeReconnectImmediately:
      delay = 0;
      break;
    case PTPusherAutoReconnectModeReconnectWithConfiguredDelay:
      delay = self.reconnectDelay;
      break;
    case PTPusherAutoReconnectModeReconnectWithBackoffDelay:
      delay = self.reconnectDelay * _numberOfReconnectAttempts;
      break;
    default:
      delay = 0;
      break;
  }
  
  if ([self.delegate respondsToSelector:@selector(pusher:connectionWillAutomaticallyReconnect:afterDelay:)]) {
    BOOL shouldProceed = [self.delegate pusher:self connectionWillAutomaticallyReconnect:_connection afterDelay:delay];
    
    if (!shouldProceed) return;
  }
  
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC);
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    [_connection connect];
  });
}

@end
