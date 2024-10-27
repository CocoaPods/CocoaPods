//
//  PTPusherChannel_Private.h
//  libPusher
//
//  Created by Luke Redpath on 25/11/2013.
//
//

/**
 * These methods are for internal use only.
 */
@interface PTPusherChannel ()
- (void)subscribeWithAuthorization:(NSDictionary *)authData;
- (void)unsubscribe;
- (void)handleDisconnect;
@end
