//
//  PTPusherClient.h
//  libPusher
//
//  Created by Luke Redpath on 23/04/2010.
//  Copyright 2010 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTPusherEventPublisher.h"
#import "PTEventListener.h"
#import "PTPusherPresenceChannelDelegate.h"
#import "PTPusherMacros.h"

@class PTPusher;
@class PTPusherEventDispatcher;

/** A PTPusherChannel object represents a single Pusher channel.
 
 Channels can be used as a means of filtering or controlling access to events.
 
 Channels do not need to be explicitly created; they are created on demand. To obtain
 an instance of a PTPusherChannel, you need to subscribe to it first.
 
 You should not create PTPusherChannel instances directly as they require subscription and
 possibly authorization; you should instead use the subscribeTo methods provided by PTPusher.
 
 There are three types of channel:
 
 + Public channels can be subscribed to by anyone who knows their name.
 
 + Private channels allow you to control access to the data you are broadcasting.
 
 + Presence channels you to 'register' user information on subscription, and let other members of the channel know who's online.
 
 Channels can be subscribed to or unsubscribed to at any time, even before the initial 
 Pusher connection has been established.
 
 Generally, channel objects will exist from the point of creation until you explicitly unsubscribe
 from them, unless you maintain your own strong references to the channel object. Channels become
 implicitly unsubscribed when the connection is lost but will be re-subscribed once connection 
 is re-established. This means you can use the same channel object across connections.
 
 See the README for more information on channel object lifetime.
 */
@interface PTPusherChannel : NSObject <PTPusherEventBindings, PTEventListener>

///------------------------------------------------------------------------------------/
/// @name Properties
///------------------------------------------------------------------------------------/

/** The channel name.
 */
@property (nonatomic, readonly) NSString *name;

/** Indicates that this channel has been subscribed to.
 
 Whilst public channels are subscribed to immediately, presence and private channels require
 authorization first. This property will be set to YES once an internal Pusher event has
 been received indicating that the channel subscription has been registered.
 
 You can bind to events on a channel without waiting for it to become subscribed and any
 event bindings will be kept if the channel becomes unsubscribed due to a loss of connection.
 */
@property (nonatomic, readonly, getter=isSubscribed) BOOL subscribed;

/** Indicates whether or not this is a private channel.
 */
@property (nonatomic, readonly) BOOL isPrivate;

/** Indicates whether or not this is a presence channel.
 */
@property (nonatomic, readonly) BOOL isPresence;

+ (id)channelWithName:(NSString *)name pusher:(PTPusher *)pusher;
- (id)initWithName:(NSString *)channelName pusher:(PTPusher *)pusher;
- (void)authorizeWithCompletionHandler:(void(^)(BOOL, NSDictionary *, NSError *))completionHandler;

///------------------------------------------------------------------------------------/
/// @name Unsubscribing
///------------------------------------------------------------------------------------/

/** Unsubscribes from the channel.
 
 PTPusher will remove any strong references to the channel when you unsusbcribe. If you
 do not have any strong references to the channel object, it will be deallocated after
 unsubscribing.
 
 If there is an active connection when this is called, an unsubscribe event will be
 ssent to the server.
 */
- (void)unsubscribe;

@end

/** A PTPusherPrivateChannel object represents a private Pusher channel.
 
 Private channels should be used when access to the channel needs to be restricted in some way. 
 In order for a user to subscribe to a private channel permission must be authorised.
 
 Private channel names always have the prefix of "private-".
 
 Only private and presence channels support client triggered events.
 */
@interface PTPusherPrivateChannel : PTPusherChannel

///------------------------------------------------------------------------------------/
/// @name Triggering events
///------------------------------------------------------------------------------------/

/** Triggers a named event directly over the connection.
 
 Client events have the following restrictions:
 
 + The user must be subscribed to the channel that the event is being triggered on.
 
 + Client events can only be triggered on private and presence channels because they require authentication.
 
 + Client events must be prefixed by client-. Events with any other prefix will be rejected by the Pusher server, as will events sent to channels to which the client is not subscribed.
 
 If you attempt to trigger event on a channel while isSubscribed is NO, the event will not be sent.
 
 If the event name does not have a prefix of "client-", it will be added automatically.
 
 The event data must be an object that can be serialized as JSON, typically an NSArray or NSDictionary although
 it could be a simple string.
 */
- (void)triggerEventNamed:(NSString *)eventName data:(id)eventData;

@end

@class PTPusherChannelMembers;

/** A PTPusherPresenceChannel object represents a Pusher presence channel.
 
 Presence channels build on the security of Private channels and expose the additional feature 
 of an awareness of who is subscribed to that channel. This makes it extremely easy to build 
 chat room and "who's online" type functionality to your application.
 
 Presence channel names always have the prefix of "presence-".
 
 Unlike the Pusher Javascript client API, PTPusherPresenceChannel does not use events to notify
 when members are added or removed. Instead, you should assign a presenceDelegate which will
 be notified of these events.
 
 @see PTPusherPresenceChannelDelegate
 */
@interface PTPusherPresenceChannel : PTPusherPrivateChannel

///------------------------------------------------------------------------------------/
/// @name Properties
///------------------------------------------------------------------------------------/

/** The presence delegate for the receiver.
 
 The presence delegate will be notified of presence channel-specific events, such as the initial
 member list on subscription and member added/removed events.
 */
@property (nonatomic, weak) id<PTPusherPresenceChannelDelegate> presenceDelegate;

/** Returns the channel member list.
 */
@property (nonatomic, readonly) PTPusherChannelMembers *members;

///------------------------------------------------------------------------------------/
/// @name Deprecated methods
///------------------------------------------------------------------------------------/

/** Returns a dictionary of member metadata (email, name etc.) for the given member ID.
 *
 * @deprecated Use the members object.
 */
- (NSDictionary *)infoForMemberWithID:(NSString *)memberID __PUSHER_DEPRECATED__;

/** Returns an array of available member IDs 
 *
 * @deprecated Use the members object.
 */
- (NSArray *)memberIDs __PUSHER_DEPRECATED__;

/** Returns the number of members currently connected to this channel.
 *
 * @deprecated Use the members object.
 */
- (NSInteger)memberCount __PUSHER_DEPRECATED__;
@end

/** Represents a single member in a presence channel.
 *
 * Object subscripting can be used to access individual keys in a user's info dictionary.
 *
 */
@interface PTPusherChannelMember : NSObject

/** The user's ID.
 */
@property (nonatomic, readonly) NSString *userID;

/** A dictionary of user info - this is normally application specific.
 *
 */
@property (nonatomic, readonly) NSDictionary *userInfo;

/** Provides object subscripting access to userInfo data.
 */
- (id)objectForKeyedSubscript:(id <NSCopying>)key;

@end

/** Represents an unordered collection of members in a presence channel.
 *
 * Individual members are represented by instances of the class PTPusherChannelMember.
 *
 * This object supports subscripting for member access (where the user ID is the key).
 *
 * If you require an ordered list of members (e.g. to display in a table view)
 * you should implement the presence delegate methods and maintain your own ordered list.
 *
 */
@interface PTPusherChannelMembers : NSObject

/** The number of members in the channel.
 */
@property (nonatomic, readonly) NSInteger count;

/** The ID of the client's member.
 */
@property (nonatomic, copy, readonly) NSString *myID;

/** The client member.
 */
@property (nonatomic, readonly) PTPusherChannelMember *me;

/** Can be used to look up a channel member by ID.
 
 @return The member with the given ID, or nil if it does not exist.
 */
- (PTPusherChannelMember *)memberWithID:(NSString *)userID;

/** Can be used to iterate over each member in the channel.
 */
- (void)enumerateObjectsUsingBlock:(void (^)(id obj, BOOL *stop))block;

/** Provides object subscripting access to members by key.
 
 @param key The member ID
 @returns The member with the specified ID, or nil if it does not exist.
 */
- (id)objectForKeyedSubscript:(id <NSCopying>)key;

@end
