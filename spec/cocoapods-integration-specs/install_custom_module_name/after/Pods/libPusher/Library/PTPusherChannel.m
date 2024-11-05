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
#import "PTPusherErrors.h"
#import "PTJSON.h"
#import "NSDictionary+StringValue.h"

@interface PTPusher ()
- (void)__unsubscribeFromChannel:(PTPusherChannel *)channel;
@end

@interface PTPusherChannel ()
@property (nonatomic, weak) PTPusher *pusher;
@property (nonatomic, strong) PTPusherEventDispatcher *dispatcher;
@property (nonatomic, assign, readwrite) BOOL subscribed;
@property (nonatomic, readonly) NSMutableArray *internalBindings;
@end

#pragma mark -

@implementation PTPusherChannel

+ (instancetype)channelWithName:(NSString *)name pusher:(PTPusher *)pusher
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
  [[NSNotificationCenter defaultCenter]
   postNotificationName:PTPusherEventReceivedNotification
   object:self
   userInfo:@{PTPusherEventUserInfoKey: event}];

  [self.dispatcher dispatchEvent:event];
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
  self.members.myID = [channelData stringValueForKey:@"user_id"];
}

- (void)handleSubscribeEvent:(PTPusherEvent *)event
{
  [super handleSubscribeEvent:event];
  [self.members handleSubscription:event.data];
  [self.presenceDelegate presenceChannelDidSubscribe:self];
}

- (BOOL)isPresence
{
  return YES;
}

- (void)handleMemberAddedEvent:(PTPusherEvent *)event
{
  PTPusherChannelMember *member = [self.members handleMemberAdded:event.data];

  [self.presenceDelegate presenceChannel:self memberAdded:member];
}

- (void)handleMemberRemovedEvent:(PTPusherEvent *)event
{
  PTPusherChannelMember *member = [self.members handleMemberRemoved:event.data];

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
  NSString *userID = [memberData stringValueForKey:@"user_id"];
  PTPusherChannelMember *member = [self memberWithID:userID];
  if (member == nil) {
    member = [[PTPusherChannelMember alloc] initWithUserID:userID userInfo:memberData[@"user_info"]];
    _members[member.userID] = member;
  }
  return member;
}

- (PTPusherChannelMember *)handleMemberRemoved:(NSDictionary *)memberData
{
  PTPusherChannelMember *member = [self memberWithID:[memberData stringValueForKey:@"user_id"]];
  if (member) {
    [_members removeObjectForKey:member.userID];
  }
  return member;
}

@end
