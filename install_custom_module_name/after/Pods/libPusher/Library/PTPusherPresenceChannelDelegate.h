//
//  PTPusherPresenceChannelDelegate.h
//  libPusher
//
//  Created by Luke Redpath on 14/08/2011.
//  Copyright 2011 LJR Software Limited. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PTPusherMacros.h"

@class PTPusherChannelMember;
@class PTPusherPresenceChannel;

@protocol PTPusherPresenceChannelDelegate <NSObject>

/** Notifies the delegate that the presence channel subscribed successfully.
 
 Whenever you subscribe to a presence channel, a list of current subscribers will be returned by Pusher.
 
 The members list can be accessed using the `members` property on the channel.

 @param channel The presence channel that was subscribed to.
 */
- (void)presenceChannelDidSubscribe:(PTPusherPresenceChannel *)channel;

/** Notifies the delegate that a member has joined the channel.
 
 @param channel The presence channel that was subscribed to.
 @param member The member that was removed.
 */

- (void)presenceChannel:(PTPusherPresenceChannel *)channel memberAdded:(PTPusherChannelMember *)member;

/** Notifies the delegate that a member has left from the channel.

 @param channel The presence channel that was subscribed to.
 @param member The member that was removed.
 */
- (void)presenceChannel:(PTPusherPresenceChannel *)channel memberRemoved:(PTPusherChannelMember *)member;

#pragma mark - Deprecated methods

@optional

/** Notifies the delegate that the presence channel subscribed successfully.
 @deprecated Use presenceChannelDidSubscribe: and access the members property.
 */
- (void)presenceChannel:(PTPusherPresenceChannel *)channel didSubscribeWithMemberList:(NSArray *)members __PUSHER_DEPRECATED__;

/** Notifies the delegate that a member has joined the channel.
 @deprecated Use presenceChannel:memberAdded:
 */

- (void)presenceChannel:(PTPusherPresenceChannel *)channel memberAddedWithID:(NSString *)memberID memberInfo:(NSDictionary *)memberInfo __PUSHER_DEPRECATED__;

/** Notifies the delegate that a member subscribed to the presence channel has unsubscribed.
 @deprecated Use presenceChannel:memberRemoved:
 */
- (void)presenceChannel:(PTPusherPresenceChannel *)channel memberRemovedWithID:(NSString *)memberID atIndex:(NSInteger)index __PUSHER_DEPRECATED__;

@end
