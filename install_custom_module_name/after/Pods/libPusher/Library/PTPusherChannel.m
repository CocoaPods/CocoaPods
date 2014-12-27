//
//  PTPusherClient.m
//  libPusher
//
//  Created by Luke Redpath on 23/04/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import "PTPusherChannel.h"
#import "PTPusher.h"
#import "PTPusherEvent.h"
#import "PTPusherEventDispatcher.h"
#import "PTTargetActionEventListener.h"
#import "PTBlockEventListener.h"
#import "PTPusherChannelAuthorizationOperation.h"
#import "PTPusherErrors.h"
#import "PTJSON.h"

@interface PTPusher ()
- (void)__unsubscribeFromChannel:(PTPusherChannel *)channel;
- (void)beginAuthorizationOperation:(PTPusherChannelAuthorizationOperation *)operation;
@end

@interface PTPusherChannel ()
@property (nonatomic, weak) PTPusher *pusher;
@property (nonatomic, strong) PTPusherEventDispatcher *dispatcher;
@property (nonatomic, assign, readwrite) BOOL subscribed;
@property (nonatomic, readonly) NSMutableArray *internalBindings;
@end

#pragma mark -

@implementation PTPusherChannel

+ (id)channelWithName:(NSString *)name pusher:(PTPusher *)pusher
{
  if ([name hasPrefix:@"private-"]) {
    return [[PTPusherPrivateChannel alloc] initWithName:name pusher:pusher];
  }
  if ([name hasPrefix:@"presence-"]) {
    return [[PTPusherPresenceChannel alloc] initWithName:name pusher:pusher];
  }
  return [[self alloc] initWithName:name pusher:pusher];
}

- (id)initWithName:(NSString *)channelName pusher:(PTPusher *)aPusher
{
  if (self = [super init]) {
    _name = [channelName copy];
    _pusher = aPusher;
    _dispatcher = [[PTPusherEventDispatcher alloc] init];
    _internalBindings = [[NSMutableArray alloc] init];
    
    /*
     Set up event handlers for pre-defined channel events
     
     We *must* use block-based bindings with a weak reference to the channel.
     Using a target-action binding will create a retain cycle between the channel
     and the target/action binding object.
     */
    __weak PTPusherChannel *weakChannel = self;
    
    [self.internalBindings addObject:
     [self bindToEventNamed:@"pusher_internal:subscription_succeeded" 
            handleWithBlock:^(PTPusherEvent *event) {
              [weakChannel handleSubscribeEvent:event];
            }]];
    
    [self.internalBindings addObject:
     [self bindToEventNamed:@"subscription_error" 
            handleWithBlock:^(PTPusherEvent *event) {
              [weakChannel handleSubcribeErrorEvent:event];
            }]];
  }
  return self;
}

- (void)dealloc 
{
  [self.internalBindings enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
    [_dispatcher removeBinding:object];
  }];
}

- (BOOL)isPrivate
{
  return NO;
}

- (BOOL)isPresence
{
  return NO;
}

#pragma mark - Subscription events

- (void)handleSubscribeEvent:(PTPusherEvent *)event
{
  self.subscribed = YES;
  
  if ([self.pusher.delegate respondsToSelector:@selector(pusher:didSubscribeToChannel:)]) {
    [self.pusher.delegate pusher:self.pusher didSubscribeToChannel:self];
  }
}

- (void)handleSubcribeErrorEvent:(PTPusherEvent *)event
{
  if ([self.pusher.delegate respondsToSelector:@selector(pusher:didFailToSubscribeToChannel:withError:)]) {
    NSDictionary *userInfo = @{PTPusherErrorUnderlyingEventKey: event};
    NSError *error = [NSError errorWithDomain:PTPusherErrorDomain code:PTPusherSubscriptionError userInfo:userInfo];
    [self.pusher.delegate pusher:self.pusher didFailToSubscribeToChannel:self withError:error];
  }
}

#pragma mark - Authorization

- (void)authorizeWithCompletionHandler:(void(^)(BOOL, NSDictionary *, NSError *))completionHandler
{
  completionHandler(YES, @{}, nil); // public channels do not require authorization
}

#pragma mark - Binding to events

- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName target:(id)target action:(SEL)selector
{
  return [self.dispatcher addEventListenerForEventNamed:eventName target:target action:selector];
}

- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName handleWithBlock:(PTPusherEventBlockHandler)block
{
  return [self bindToEventNamed:eventName handleWithBlock:block queue:dispatch_get_main_queue()];
}

- (PTPusherEventBinding *)bindToEventNamed:(NSString *)eventName handleWithBlock:(PTPusherEventBlockHandler)block queue:(dispatch_queue_t)queue
{
  return [self.dispatcher addEventListenerForEventNamed:eventName block:block queue:queue];
}

- (void)removeBinding:(PTPusherEventBinding *)binding
{
  [self.dispatcher removeBinding:binding];
}

- (void)removeAllBindings
{
  NSMutableArray *bindingsToRemove = [NSMutableArray array];
  
  // need to unpack the bindings from the nested arrays, so we can
  // iterate over them safely whilst removing them from the dispatcher
  for (NSArray *bindingsArray in [self.dispatcher.bindings allValues]) {
    for (PTPusherEventBinding *binding in bindingsArray) {
	    if (![self.internalBindings containsObject:binding]) {
        [bindingsToRemove addObject:binding];
      }
	  }
  }
  
  for (PTPusherEventBinding *binding in bindingsToRemove) {
    [self.dispatcher removeBinding:binding];
  }
}

#pragma mark - Dispatching events

- (void)dispatchEvent:(PTPusherEvent *)event
{
  [self.dispatcher dispatchEvent:event];
  
  [[NSNotificationCenter defaultCenter] 
   postNotificationName:PTPusherEventReceivedNotification 
   object:self 
   userInfo:@{PTPusherEventUserInfoKey: event}];
}

#pragma mark - Internal use only

- (void)subscribeWithAuthorization:(NSDictionary *)authData
{
  if (self.isSubscribed) return;
  
  [self.pusher sendEventNamed:@"pusher:subscribe"
                    data:@{@"channel": self.name}
                 channel:nil];
}

- (void)unsubscribe
{
  [self.pusher __unsubscribeFromChannel:self];
}

- (void)handleDisconnect
{
  self.subscribed = NO;
}

@end

#pragma mark -

@implementation PTPusherPrivateChannel {
  NSOperationQueue *_clientEventQueue;
}

- (id)initWithName:(NSString *)channelName pusher:(PTPusher *)aPusher
{
  if ((self = [super initWithName:channelName pusher:aPusher])) {
    _clientEventQueue = [[NSOperationQueue alloc] init];
    _clientEventQueue.maxConcurrentOperationCount = 1;
    _clientEventQueue.name = @"com.pusher.libPusher.clientEventQueue";
    _clientEventQueue.suspended = YES;
  }
  return self;
}

- (void)handleSubscribeEvent:(PTPusherEvent *)event
{
  [super handleSubscribeEvent:event];
  [_clientEventQueue setSuspended:NO];
}

- (void)handleDisconnect
{
  [super handleDisconnect];
  [_clientEventQueue setSuspended:YES];
}

- (BOOL)isPrivate
{
  return YES;
}

- (void)authorizeWithCompletionHandler:(void(^)(BOOL, NSDictionary *, NSError *))completionHandler
{
  PTPusherChannelAuthorizationOperation *authOperation = [PTPusherChannelAuthorizationOperation operationWithAuthorizationURL:self.pusher.authorizationURL channelName:self.name socketID:self.pusher.connection.socketID];
  
  [authOperation setCompletionHandler:^(PTPusherChannelAuthorizationOperation *operation) {
    completionHandler(operation.isAuthorized, operation.authorizationData, operation.error);
  }];
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSLog(@"willAuthorizeChannelWithRequest: is deprecated and will be removed in 1.6. Use pusher:willAuthorizeChannel:withRequest: instead.");
  if ([self.pusher.delegate respondsToSelector:@selector(pusher:willAuthorizeChannelWithRequest:)]) { // deprecated call
    [self.pusher.delegate pusher:self.pusher willAuthorizeChannelWithRequest:authOperation.mutableURLRequest];
  }
#pragma clang diagnostic pop
    
  if ([self.pusher.delegate respondsToSelector:@selector(pusher:willAuthorizeChannel:withRequest:)]) {
    [self.pusher.delegate pusher:self.pusher willAuthorizeChannel:self withRequest:authOperation.mutableURLRequest];
  }
  
  [self.pusher beginAuthorizationOperation:authOperation];
}

- (void)subscribeWithAuthorization:(NSDictionary *)authData
{
  if (self.isSubscribed) return;
  
  NSMutableDictionary *eventData = [authData mutableCopy];
  eventData[@"channel"] = self.name;
  
  [self.pusher sendEventNamed:@"pusher:subscribe"
                    data:eventData
                 channel:nil];
}

#pragma mark - Triggering events

- (void)triggerEventNamed:(NSString *)eventName data:(id)eventData
{
  if (![eventName hasPrefix:@"client-"]) {
    eventName = [@"client-" stringByAppendingString:eventName];
  }
  
  __weak PTPusherChannel *weakSelf = self;
  
  [_clientEventQueue addOperationWithBlock:^{
    [weakSelf.pusher sendEventNamed:eventName data:eventData channel:weakSelf.name];
  }];
}

@end

#pragma mark -

@interface PTPusherChannelMembers ()

@property (nonatomic, copy, readwrite) NSString *myID;

- (void)reset;
- (void)handleSubscription:(NSDictionary *)subscriptionData;
- (PTPusherChannelMember *)handleMemberAdded:(NSDictionary *)memberData;
- (PTPusherChannelMember *)handleMemberRemoved:(NSDictionary *)memberData;

@end

@implementation PTPusherPresenceChannel

- (id)initWithName:(NSString *)channelName pusher:(PTPusher *)aPusher
{
  if ((self = [super initWithName:channelName pusher:aPusher])) {
    _members = [[PTPusherChannelMembers alloc] init];

    /* Set up event handlers for pre-defined channel events.
     As above, use blocks as proxies to a weak channel reference to avoid retain cycles.
     */
      __weak PTPusherPresenceChannel *weakChannel = self;
    
    [self.internalBindings addObject:
     [self bindToEventNamed:@"pusher_internal:member_added" 
            handleWithBlock:^(PTPusherEvent *event) {
              [weakChannel handleMemberAddedEvent:event];
            }]];
    
    [self.internalBindings addObject:
     [self bindToEventNamed:@"pusher_internal:member_removed" 
            handleWithBlock:^(PTPusherEvent *event) {
              [weakChannel handleMemberRemovedEvent:event];
            }]];
    
  }
  return self;
}

- (void)handleDisconnect
{
  [super handleDisconnect];
  [self.members reset];
}

- (void)subscribeWithAuthorization:(NSDictionary *)authData
{
  [super subscribeWithAuthorization:authData];
  
  NSDictionary *channelData = [[PTJSON JSONParser] objectFromJSONString:authData[@"channel_data"]];
  self.members.myID = channelData[@"user_id"];
}

- (void)handleSubscribeEvent:(PTPusherEvent *)event
{
  [super handleSubscribeEvent:event];
  
  [self.members handleSubscription:event.data];
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if ([self.presenceDelegate respondsToSelector:@selector(presenceChannel:didSubscribeWithMemberList:)]) { // deprecated call
    NSLog(@"presenceChannel:didSubscribeWithMemberList: is deprecated and will be removed in 1.6. Use presenceChannelDidSubscribe: instead.");
    NSMutableArray *members = [NSMutableArray arrayWithCapacity:self.members.count];
    [self.members enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
      [members addObject:obj];
    }];
    [self.presenceDelegate presenceChannel:self didSubscribeWithMemberList:members];
  }
#pragma clang diagnostic pop

  [self.presenceDelegate presenceChannelDidSubscribe:self];
}

- (BOOL)isPresence
{
  return YES;
}

- (NSDictionary *)infoForMemberWithID:(NSString *)memberID
{
  return self.members[memberID];
}

- (NSArray *)memberIDs
{
  NSMutableArray *memberIDs = [NSMutableArray array];
  [self.members enumerateObjectsUsingBlock:^(PTPusherChannelMember *member, BOOL *stop) {
    [memberIDs addObject:member.userID];
  }];
  return memberIDs;
}

- (NSInteger)memberCount
{
  return self.members.count;
}

- (void)handleMemberAddedEvent:(PTPusherEvent *)event
{
  PTPusherChannelMember *member = [self.members handleMemberAdded:event.data];
  
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if ([self.presenceDelegate respondsToSelector:@selector(presenceChannel:memberAddedWithID:memberInfo:)]) { // deprecated call
    NSLog(@"presenceChannel:memberAddedWithID:memberInfo: is deprecated and will be removed in 1.6. Use presenceChannel:memberAdded: instead.");
    [self.presenceDelegate presenceChannel:self memberAddedWithID:member.userID memberInfo:member.userInfo];
  }
#pragma clang diagnostic pop

  [self.presenceDelegate presenceChannel:self memberAdded:member];
}

- (void)handleMemberRemovedEvent:(PTPusherEvent *)event
{
  PTPusherChannelMember *member = [self.members handleMemberRemoved:event.data];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  if ([self.presenceDelegate respondsToSelector:@selector(presenceChannel:memberRemovedWithID:atIndex:)]) { // deprecated call
    NSLog(@"presenceChannel:memberRemovedWithID:atIndex: is deprecated and will be removed in 1.6. Use presenceChannel:memberRemoved: instead.");
    // we just send an index of -1 here: I don't want to jump through hoops to support a deprecated API call
    [self.presenceDelegate presenceChannel:self memberRemovedWithID:member.userID atIndex:-1];
  }
#pragma clang diagnostic pop
  
  [self.presenceDelegate presenceChannel:self memberRemoved:member];
}

@end

#pragma mark -

@implementation PTPusherChannelMember

- (id)initWithUserID:(NSString *)userID userInfo:(NSDictionary *)userInfo
{
  if ((self = [super init])) {
    _userID = [userID copy];
    _userInfo = [userInfo copy];
  }
  return self;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<PTPusherChannelMember id:%@ info:%@>", self.userID, self.userInfo];
}

- (id)objectForKeyedSubscript:(id <NSCopying>)key
{
  return self.userInfo[key];
}

@end

@implementation PTPusherChannelMembers {
  NSMutableDictionary *_members;
}

- (id)init
{
  self = [super init];
  if (self) {
    _members = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)reset
{
  _members = [[NSMutableDictionary alloc] init];
  self.myID = nil;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<PTPusherChannelMembers members:%@>", _members];
}

- (NSInteger)count
{
  return _members.count;
}

- (id)objectForKeyedSubscript:(id <NSCopying>)key
{
  return _members[key];
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block
{
  [_members enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    block(obj, stop);
  }];
}


- (PTPusherChannelMember *)me
{
  return self[self.myID];
}

- (PTPusherChannelMember *)memberWithID:(NSString *)userID
{
  return self[userID];
}

#pragma mark - Channel event handling

- (void)handleSubscription:(NSDictionary *)subscriptionData
{
  NSDictionary *memberHash = subscriptionData[@"presence"][@"hash"];
  
  [memberHash enumerateKeysAndObjectsUsingBlock:^(NSString *userID, NSDictionary *userInfo, BOOL *stop) {
    PTPusherChannelMember *member = [[PTPusherChannelMember alloc] initWithUserID:userID userInfo:userInfo];
    _members[userID] = member;
  }];
}

- (PTPusherChannelMember *)handleMemberAdded:(NSDictionary *)memberData
{
  PTPusherChannelMember *member = [self memberWithID:memberData[@"user_id"]];
  if (member == nil) {
    member = [[PTPusherChannelMember alloc] initWithUserID:memberData[@"user_id"] userInfo:memberData[@"user_info"]];
    _members[member.userID] = member;
  }
  return member;
}

- (PTPusherChannelMember *)handleMemberRemoved:(NSDictionary *)memberData
{
  PTPusherChannelMember *member = [self memberWithID:memberData[@"user_id"]];
  if (member) {
    [_members removeObjectForKey:member.userID];
  }
  return member;
}

@end
