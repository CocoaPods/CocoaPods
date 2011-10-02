//
//  RKTUser.m
//  RKTwitter
//
//  Created by Blake Watters on 9/5/10.
//  Copyright 2010 Two Toasters. All rights reserved.
//

#import "RKTUser.h"

@implementation RKTUser

@synthesize userID = _userID;
@synthesize name = _name;
@synthesize screenName = _screenName;

- (void)dealloc {
    [_userID release];
	[_name release];
	[_screenName release];
    
    [super dealloc];
}

@end
