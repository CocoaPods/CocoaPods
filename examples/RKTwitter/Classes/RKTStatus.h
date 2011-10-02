//
//  RKTStatus.h
//  RKTwitter
//
//  Created by Blake Watters on 9/5/10.
//  Copyright 2010 Two Toasters. All rights reserved.
//

#import "RKTUser.h"

@interface RKTStatus : NSObject {
	NSNumber* _statusID;
	NSDate* _createdAt;
	NSString* _text;
	NSString* _urlString;
	NSString* _inReplyToScreenName;
	NSNumber* _isFavorited;	
	RKTUser* _user;
}

/**
 * The unique ID of this Status
 */
@property (nonatomic, retain) NSNumber* statusID;

/**
 * Timestamp the Status was sent
 */
@property (nonatomic, retain) NSDate* createdAt;

/**
 * Text of the Status
 */
@property (nonatomic, retain) NSString* text;

/**
 * String version of the URL associated with the Status
 */
@property (nonatomic, retain) NSString* urlString;

/**
 * The screen name of the User this Status was in response to
 */
@property (nonatomic, retain) NSString* inReplyToScreenName;

/**
 * Is this status a favorite?
 */
@property (nonatomic, retain) NSNumber* isFavorited;

/**
 * The User who posted this status
 */
@property (nonatomic, retain) RKTUser* user;

@end
